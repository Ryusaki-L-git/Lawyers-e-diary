"""Shared fixtures for the LED eCourts gateway tests.

The fake Firestore database mirrors document reads/writes in memory so no
real Firebase project, credentials, or network is required.
"""

from __future__ import annotations

from types import SimpleNamespace

import pytest


class _Snapshot:
    """Minimal stand-in for a Firestore DocumentSnapshot."""

    def __init__(self, exists: bool, data):
        self.exists = exists
        self._data = data or {}

    def to_dict(self):
        return dict(self._data)


@pytest.fixture
def make_db():
    """Build an in-memory fake Firestore db.

    `snapshots` maps (collection_path, document_id) -> data dict or None
    (None means the document does not exist).

    The returned db exposes `collection(name).document(id).get()` and
    `run_transaction(work)`, the surface used by gateway/firestore_authz.py.
    """

    def build(snapshots: dict) -> SimpleNamespace:
        store = dict(snapshots)

        class FakeRef:
            def __init__(self, db, path, doc_id):
                self._db = db
                self.path = path
                self.id = doc_id

            def collection(self, name):
                return FakeColl(self._db, f"{self.path}/{self.id}", name)

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

            def update(self, data):
                existing = self._db._store.get((self.path, self.id))
                merged = dict(existing or {})
                merged.update(data)
                self._db._store[(self.path, self.id)] = merged

            def delete(self):
                self._db._store.pop((self.path, self.id), None)

        class FakeColl:
            def __init__(self, db, parent, name):
                self._db = db
                self.path = name if not parent else f"{parent}/{name}"

            def document(self, doc_id):
                return FakeRef(self._db, self.path, doc_id)

            def where(self, field, op, value):
                return FakeQuery(self._db, self.path, field, op, value)


        class FakeQuery:
            def __init__(self, db, collection_path, field, op, value):
                self._db = db
                self._collection_path = collection_path
                self._field = field
                self._op = op
                self._value = value

            def where(self, field, op, value):
                # Chain multiple where clauses (simplified: AND all)
                return FakeQuery(
                    self._db, self._collection_path, field, op, value
                )

            def get(self):
                results = []
                for (path, doc_id), data in self._db._store.items():
                    # Match documents in this collection (top-level or sub-collection).
                    if path != self._collection_path and not path.startswith(
                        self._collection_path + "/"
                    ):
                        continue
                    if path == self._collection_path and doc_id == "":
                        continue  # Skip collection root
                    if data is None:
                        continue
                    if self._field in data:
                        doc_value = data[self._field]
                        match = False
                        if self._op == ">=":
                            if isinstance(doc_value, str) and isinstance(self._value, str):
                                match = doc_value >= self._value
                        elif self._op == ">":
                            if isinstance(doc_value, str) and isinstance(self._value, str):
                                match = doc_value > self._value
                        elif self._op == "==":
                            match = doc_value == self._value
                        elif self._op == "<":
                            if isinstance(doc_value, str) and isinstance(self._value, str):
                                match = doc_value < self._value
                        if match:
                            results.append(_Snapshot(True, dict(data)))
                return results

        class FakeTxn:
            def __init__(self, db):
                self._db = db
                self.updates = []
                self.sets = []
                self.deletes = []

            def get(self, ref):
                # Check pending writes within this transaction first.
                for path, doc_id, data in self.sets:
                    if ref.path == path and ref.id == doc_id:
                        return _Snapshot(True, dict(data))
                for path, doc_id in self.deletes:
                    if ref.path == path and ref.id == doc_id:
                        return _Snapshot(False, None)
                for path, doc_id, data in self.updates:
                    if ref.path == path and ref.id == doc_id:
                        # Merge update with existing store data.
                        existing = self._db._store.get((path, doc_id))
                        merged = dict(existing or {})
                        merged.update(data)
                        return _Snapshot(True, merged)
                return self._db._get(ref)

            def set(self, ref, data):
                self.sets.append((ref.path, ref.id, dict(data)))
                # Write through to store so subsequent gets see it.
                self._db._store[(ref.path, ref.id)] = dict(data)

            def update(self, ref, data):
                self.updates.append((ref.path, ref.id, dict(data)))
                # Write through to store so subsequent gets see it.
                existing = self._db._store.get((ref.path, ref.id))
                merged = dict(existing or {})
                merged.update(data)
                self._db._store[(ref.path, ref.id)] = merged

            def delete(self, ref):
                self.deletes.append((ref.path, ref.id))
                self._db._store.pop((ref.path, ref.id), None)

        class FakeDb:
            def __init__(self, store):
                self._store = store
                self._last_txn = None

            def collection(self, name):
                return FakeColl(self, "", name)

            def _get(self, ref):
                data = self._store.get((ref.path, ref.id))
                if data is None:
                    return _Snapshot(False, None)
                return _Snapshot(True, data)

            def get(self, ref):
                return self._get(ref)

            def run_transaction(self, work):
                txn = FakeTxn(self)
                self._last_txn = txn
                work(txn)
                return txn

        return FakeDb(store)

    return build


@pytest.fixture
def settings_dict():
    return {
        "FIREBASE_PROJECT_ID": "proj",
        "FIREBASE_SERVICE_ACCOUNT_JSON": '{"type":"service_account","private_key":"x","client_email":"a@b.iam.gserviceaccount.com"}',
        "ECOURTS_API_KEY": "test-key",
        "ECOURTS_BASE_URL": "https://example.com",
    }


@pytest.fixture
def env_settings(monkeypatch, settings_dict):
    for key, value in settings_dict.items():
        monkeypatch.setenv(key, value)
