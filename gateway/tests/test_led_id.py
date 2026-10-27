"""Tests for gateway/led_id.py allocation logic."""

from __future__ import annotations

from types import SimpleNamespace
import datetime

import pytest

from gateway.led_id import allocate_led_id, _is_valid_counter


class TestIsValidCounter:
    def test_zero_valid(self):
        assert _is_valid_counter(0) is True

    def test_positive_valid(self):
        assert _is_valid_counter(1) is True
        assert _is_valid_counter(9999) is True

    def test_negative_invalid(self):
        assert _is_valid_counter(-1) is False

    def test_float_invalid(self):
        assert _is_valid_counter(1.5) is False

    def test_bool_invalid(self):
        assert _is_valid_counter(True) is False

    def test_string_invalid(self):
        assert _is_valid_counter("5") is False

    def test_none_invalid(self):
        assert _is_valid_counter(None) is False


def _make_db(snapshots):
    """Build a fake db from conftest-style snapshots."""
    # Reuse the conftest make_db fixture by calling it indirectly.
    # We'll construct a minimal fake here.
    store = dict(snapshots)

    class FakeRef:
        def __init__(self, db, path, doc_id):
            self._db = db
            self.path = path
            self.id = doc_id

        def collection(self, name):
            return FakeColl(self._db, f"{self.path}/{self.id}" if self.path else "", name)

        def get(self):
            return self._db._get(self)

        def set(self, data, merge=False):
            if merge:
                existing = self._db._store.get((self.path, self.id))
                merged = dict(existing or {})
                merged.update(data)
                self._db._store[(self.path, self.id)] = merged
            else:
                self._db._store[(self.path, self.id)] = dict(data)

    class FakeColl:
        def __init__(self, db, parent, name):
            self._db = db
            self.path = name if not parent else f"{parent}/{name}"

        def document(self, doc_id):
            return FakeRef(self._db, self.path, doc_id)

    class FakeTxn:
        def __init__(self, db):
            self._db = db

        def get(self, ref):
            data = self._db._store.get((ref.path, ref.id))
            if data is None:
                return SimpleNamespace(exists=False, to_dict=lambda: None)
            return SimpleNamespace(exists=True, to_dict=lambda d=data: dict(d))

        def set(self, ref, data, merge=False):
            if merge:
                existing = self._db._store.get((ref.path, ref.id))
                merged = dict(existing or {})
                merged.update(data)
                self._db._store[(ref.path, ref.id)] = merged
            else:
                self._db._store[(ref.path, ref.id)] = dict(data)

    class FakeDb:
        def __init__(self, store):
            self._store = store

        def collection(self, name):
            return FakeColl(self, "", name)

        def _get(self, ref):
            data = self._store.get((ref.path, ref.id))
            if data is None:
                return SimpleNamespace(exists=False, to_dict=lambda: None)
            return SimpleNamespace(exists=True, to_dict=lambda d=data: dict(d))

        def run_transaction(self, work):
            txn = FakeTxn(self)
            work(txn)
            return txn

    return FakeDb(store)


def test_first_allocation():
    db = _make_db({})
    db._store[("users", "uid-1")] = {"name": "Alice", "advocateType": "Junior"}
    result = allocate_led_id(db, "uid-1")
    assert result["created"] is True
    assert result["ledId"].endswith("-2026")
    # Check user doc
    user_doc = db._store[("users", "uid-1")]
    assert user_doc["ledId"] == result["ledId"]
    assert user_doc["profileCompleted"] is True
    # Check directory
    dir_doc = db._store[("led_id_directory", result["ledId"])]
    assert dir_doc["uid"] == "uid-1"
    # Check counter
    counter = db._store[("metadata", "counters")]
    assert counter["userCount"] == 1


def test_retry_reuses_id():
    db = _make_db({})
    db._store[("users", "uid-2")] = {"name": "Bob", "advocateType": "Senior"}
    r1 = allocate_led_id(db, "uid-2")
    counter_before = db._store[("metadata", "counters")]["userCount"]
    r2 = allocate_led_id(db, "uid-2")
    counter_after = db._store[("metadata", "counters")]["userCount"]
    assert r1["ledId"] == r2["ledId"]
    assert r2["created"] is False
    assert counter_before == counter_after


def test_missing_name_rejected():
    db = _make_db({})
    db._store[("users", "uid-3")] = {"name": "", "advocateType": "Junior"}
    with pytest.raises(Exception):
        allocate_led_id(db, "uid-3")
    # Counter should not exist or not be incremented
    counter = db._store.get(("metadata", "counters"))
    assert counter is None or counter.get("userCount", 0) == 0


def test_invalid_counter_rejected():
    db = _make_db({})
    db._store[("users", "uid-4")] = {"name": "Diana", "advocateType": "Junior"}
    db._store[("metadata", "counters")] = {"userCount": 3.5}
    with pytest.raises(Exception):
        allocate_led_id(db, "uid-4")


def test_missing_directory_recreated():
    db = _make_db({})
    db._store[("users", "uid-5")] = {"name": "Eve", "advocateType": "Junior"}
    r1 = allocate_led_id(db, "uid-5")
    led_id = r1["ledId"]
    # Remove directory entry
    del db._store[("led_id_directory", led_id)]
    r2 = allocate_led_id(db, "uid-5")
    assert r2["ledId"] == led_id
    assert ("led_id_directory", led_id) in db._store


def test_directory_ownership_protected():
    db = _make_db({})
    db._store[("users", "uid-6")] = {"name": "Frank", "advocateType": "Junior"}
    r1 = allocate_led_id(db, "uid-6")
    led_id = r1["ledId"]
    # Tamper: set directory owner to another UID
    db._store[("led_id_directory", led_id)]["uid"] = "other-uid"
    with pytest.raises(Exception):
        allocate_led_id(db, "uid-6")
    # Verify not overwritten
    assert db._store[("led_id_directory", led_id)]["uid"] == "other-uid"


def test_distinct_users():
    db = _make_db({})
    db._store[("users", "uid-a")] = {"name": "User A", "advocateType": "Junior"}
    db._store[("users", "uid-b")] = {"name": "User B", "advocateType": "Junior"}
    r1 = allocate_led_id(db, "uid-a")
    r2 = allocate_led_id(db, "uid-b")
    assert r1["ledId"] != r2["ledId"]
    counter = db._store[("metadata", "counters")]
    assert counter["userCount"] == 2



def test_stale_counter_never_overwrites_existing_directory_id():
    db = _make_db({})
    db._store[("users", "uid-new")] = {
        "name": "New User",
        "advocateType": "Junior",
    }
    # Simulate a stale/reset counter while an ID for the current year exists.
    db._store[("metadata", "counters")] = {"userCount": 0}
    year = datetime.datetime.now(datetime.timezone.utc).year
    occupied_id = f"0001-{year}"
    db._store[("led_id_directory", occupied_id)] = {
        "uid": "existing-owner",
        "ledId": occupied_id,
        "name": "Existing User",
        "profileCompleted": True,
    }

    result = allocate_led_id(db, "uid-new")

    next_id = f"0002-{year}"
    assert result["ledId"] == next_id
    assert db._store[("led_id_directory", occupied_id)]["uid"] == "existing-owner"
    assert db._store[("led_id_directory", next_id)]["uid"] == "uid-new"
    assert db._store[("metadata", "counters")]["userCount"] == 2



def test_existing_directory_id_is_reused_when_profile_mapping_is_missing():
    db = _make_db({})
    year = datetime.datetime.now(datetime.timezone.utc).year
    existing_id = f"0001-{year}"
    db._store[("users", "uid-recover")] = {
        "name": "Recovered User",
        "advocateType": "Senior",
    }
    db._store[("metadata", "counters")] = {"userCount": 0}
    db._store[("led_id_directory", existing_id)] = {
        "uid": "uid-recover",
        "ledId": existing_id,
        "name": "Recovered User",
        "profileCompleted": True,
    }

    result = allocate_led_id(db, "uid-recover")

    assert result == {"ledId": existing_id, "created": False}
    assert db._store[("users", "uid-recover")]["ledId"] == existing_id
    assert db._store[("metadata", "counters")]["userCount"] == 1
