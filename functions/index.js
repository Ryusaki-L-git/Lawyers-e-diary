"use strict";

const { getApps, initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { defineSecret } = require("firebase-functions/params");
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { isValidCounterValue } = require("./counter_validation");
const { buildCnrOnlyCaseRecord } = require("./case_record_policy");
const { isDirectCaseOwner } = require("./case_authorization_policy");

if (getApps().length === 0) {
	initializeApp();
}

const db = getFirestore();
const ecourtsApiKey = defineSecret("ECOURTS_API_KEY");
const ecourtsBaseUrl = defineSecret("ECOURTS_BASE_URL");
const cnrPattern = /^[A-Z0-9]{16}$/;
const knownProviderFields = new Set([
	"cnr_number",
	"cnr",
	"case_no",
	"case_number",
	"case_type",
	"filing_date",
	"registration_date",
	"case_status",
	"status",
	"stage_of_case",
	"stage",
	"court_name",
	"court_number_chamber",
	"court_number",
	"state_name",
	"state",
	"district_name",
	"district",
	"petitioner",
	"petitioners",
	"petitioner_names",
	"petitioner_advocate",
	"respondent",
	"respondents",
	"respondent_names",
	"respondent_advocate",
	"next_hearing_date",
	"last_hearing_date",
	"case_acts",
	"acts",
	"orders",
	"history",
]);

function isRecord(value) {
	return value !== null && typeof value === "object" && !Array.isArray(value);
}

function validateCaseId(value) {
	if (typeof value !== "string") {
		throw new HttpsError("invalid-argument", "A case identifier is required.");
	}
	const caseId = value.trim();
	if (
		caseId.length === 0 ||
		Buffer.byteLength(caseId, "utf8") > 256 ||
		caseId.includes("/") ||
		/[\u0000-\u001f\u007f]/.test(caseId) ||
		caseId === "." ||
		caseId === ".."
	) {
		throw new HttpsError("invalid-argument", "The case identifier is invalid.");
	}
	return caseId;
}

function storedCnr(caseData) {
	const values = ["cuid", "cnrNumber", "cnr"]
		.map((key) => caseData[key])
		.filter((value) => typeof value === "string" && value.trim().length > 0);
	if (values.length === 0) {
		throw new HttpsError(
			"failed-precondition",
			"This case does not have a CNR number.",
		);
	}
	const normalized = values.map((value) => value.trim().toUpperCase());
	if (normalized.some((value) => !cnrPattern.test(value))) {
		throw new HttpsError(
			"failed-precondition",
			"This case does not contain a valid 16-character CNR number.",
		);
	}
	if (new Set(normalized).size !== 1) {
		throw new HttpsError(
			"failed-precondition",
			"The stored CUID and CNR fields do not match.",
		);
	}
	return normalized[0];
}
function assertCloudPlan(userSnapshot) {
	const subscription = userSnapshot.exists
		? userSnapshot.data().subscription
		: null;
	if (!isRecord(subscription) || subscription.tier !== "cloud_subscriber") {
		throw new HttpsError(
			"failed-precondition",
			"eCourts refresh requires a Cloud Subscriber plan.",
		);
	}
}

async function readAuthorizationDocuments(
	uid,
	caseData,
	transaction,
	authEmail,
	emailVerified,
) {
	const userRef = db.collection("users").doc(uid);
	const userRead = transaction ? transaction.get(userRef) : userRef.get();
	const teamId = typeof caseData.teamId === "string" ? caseData.teamId.trim() : "";

	if (teamId.length === 0 || teamId.includes("/")) {
		return { userSnapshot: await userRead, teamSnapshot: null, memberSnapshots: [] };
	}

	const teamRef = db.collection("teams").doc(teamId);
	const membersRef = teamRef.collection("members");
	const memberRef = membersRef.doc(uid);
	const teamRead = transaction ? transaction.get(teamRef) : teamRef.get();
	const memberRead = transaction ? transaction.get(memberRef) : memberRef.get();
	const memberReads = [memberRead];
	if (emailVerified && typeof authEmail === "string" && authEmail.trim()) {
		const emailQuery = membersRef
			.where("email", "==", authEmail.trim().toLowerCase())
			.where("isActive", "==", true);
		memberReads.push(transaction ? transaction.get(emailQuery) : emailQuery.get());
	}
	const [userSnapshot, teamSnapshot, ...memberResults] = await Promise.all([
		userRead,
		teamRead,
		...memberReads,
	]);
	const memberSnapshots = [];
	for (const memberResult of memberResults) {
		if (Array.isArray(memberResult.docs)) {
			memberSnapshots.push(...memberResult.docs);
		} else {
			memberSnapshots.push(memberResult);
		}
	}
	return { userSnapshot, teamSnapshot, memberSnapshots };
}

function isAuthorizedCaseUser(uid, caseData, teamSnapshot, memberSnapshots) {
	// ownerUid is canonical whenever present. A stale legacy userId
	// must not grant access to another advocate's original private record.
	if (isDirectCaseOwner(uid, caseData)) {
		return true;
	}

	// Non-team assigned cases may be accessed by the assigned user.
	if (!teamSnapshot?.exists) {
		return caseData.assignedTo === uid ||
			caseData.assignedUserUid === uid;
	}

	if (teamSnapshot.data().isActive === false) {
		return false;
	}

	const team = teamSnapshot.data();

	// Team owner always has access to team cases.
	if (team.ownerId === uid) {
		return true;
	}

	// For team cases, only the actively assigned member gets access.
	const isAssigned =
		caseData.assignedTo === uid ||
		caseData.assignedUserUid === uid;

	if (!isAssigned) {
		return false;
	}

	// The assigned user must still be an active team member.
	return memberSnapshots.some(
		(memberSnapshot) =>
			memberSnapshot.exists &&
			memberSnapshot.data().isActive !== false,
	);
}

function providerText(value, fieldName) {
	if (value === null || value === undefined) return null;
	if (typeof value !== "string" && typeof value !== "number") {
		throw new HttpsError(
			"data-loss",
			"The eCourts provider returned an unexpected response.",
		);
	}
	const text = String(value).trim();
	return text.length === 0 ? null : text;
}

function firstProviderValue(data, keys) {
	for (const key of keys) {
		if (data[key] !== null && data[key] !== undefined && data[key] !== "") {
			return data[key];
		}
	}
	return null;
}

function providerStringList(value) {
	if (value === null || value === undefined) return [];
	const values = Array.isArray(value) ? value : [value];
	return values
		.map((item) => providerText(item, "list"))
		.filter((item) => item !== null);
}

function mapOrders(value) {
	if (value === null || value === undefined) return [];
	if (!Array.isArray(value)) {
		throw new HttpsError(
			"data-loss",
			"The eCourts provider returned an unexpected response.",
		);
	}
	return value.filter(isRecord).map((item) => ({
		date: providerText(
			firstProviderValue(item, ["date", "order_date", "hearing_date"]),
			"orders.date",
		),
		detail: providerText(
			firstProviderValue(item, ["detail", "business", "description"]),
			"orders.detail",
		),
	}));
}

function mapProviderResponse(payload, cnr) {
	if (!isRecord(payload)) {
		throw new HttpsError(
			"data-loss",
			"The eCourts provider returned an unexpected response.",
		);
	}
	const data = Object.hasOwn(payload, "data") ? payload.data : payload;
	if (!isRecord(data) || !Object.keys(data).some((key) => knownProviderFields.has(key))) {
		throw new HttpsError(
			"data-loss",
			"The eCourts provider returned an unexpected response.",
		);
	}

	const returnedCnr = providerText(firstProviderValue(data, ["cnr_number", "cnr"]), "cnr");
	if (returnedCnr !== null && returnedCnr.toUpperCase() !== cnr) {
		throw new HttpsError(
			"data-loss",
			"The eCourts provider returned a different case identifier.",
		);
	}

	return {
		cnr,
		case_number: providerText(firstProviderValue(data, ["case_no", "case_number"]), "case_number"),
		case_type: providerText(data.case_type, "case_type"),
		filing_date: providerText(data.filing_date, "filing_date"),
		registration_date: providerText(data.registration_date, "registration_date"),
		status: providerText(firstProviderValue(data, ["case_status", "status"]), "status"),
		stage_of_case: providerText(firstProviderValue(data, ["stage_of_case", "stage"]), "stage_of_case"),
		court_name: providerText(data.court_name, "court_name"),
		court_number: providerText(firstProviderValue(data, ["court_number_chamber", "court_number"]), "court_number"),
		state: providerText(firstProviderValue(data, ["state_name", "state"]), "state"),
		district: providerText(firstProviderValue(data, ["district_name", "district"]), "district"),
		petitioner_names: providerStringList(firstProviderValue(data, ["petitioner", "petitioners", "petitioner_names"])),
		respondent_names: providerStringList(firstProviderValue(data, ["respondent", "respondents", "respondent_names"])),
		petitioner_advocate: providerText(data.petitioner_advocate, "petitioner_advocate"),
		respondent_advocate: providerText(data.respondent_advocate, "respondent_advocate"),
		next_hearing_date: providerText(data.next_hearing_date, "next_hearing_date"),
		last_hearing_date: providerText(data.last_hearing_date, "last_hearing_date"),
		orders: mapOrders(firstProviderValue(data, ["orders", "history"])),
		acts: providerStringList(firstProviderValue(data, ["case_acts", "acts"])),
		retrieved_at: new Date().toISOString(),
		provider: "ecourtsindia",
	};
}

async function fetchFromECourts(cnr) {
	const apiKey = ecourtsApiKey.value().trim();
	const configuredBaseUrl = ecourtsBaseUrl.value().trim().replace(/\/+$/, "");
	if (!apiKey || !configuredBaseUrl) {
		throw new HttpsError(
			"failed-precondition",
			"The eCourts provider is not configured.",
		);
	}

	let url;
	try {
		const baseUrl = new URL(configuredBaseUrl);
		if (
			baseUrl.protocol !== "https:" ||
			baseUrl.username ||
			baseUrl.password ||
			baseUrl.search ||
			baseUrl.hash
		) {
			throw new Error("Invalid base URL");
		}
		url = `${configuredBaseUrl}/v1/cases/cnr/${encodeURIComponent(cnr)}`;
	} catch (_) {
		throw new HttpsError(
			"failed-precondition",
			"The eCourts provider is not configured correctly.",
		);
	}

	let response;
	try {
		response = await fetch(url, {
			method: "GET",
			headers: { "x-api-key": apiKey, Accept: "application/json" },
			signal: AbortSignal.timeout(20000),
			redirect: "error",
		});
	} catch (error) {
		if (error?.name === "TimeoutError" || error?.name === "AbortError") {
			logger.warn("eCourts provider request timed out.");
			throw new HttpsError("deadline-exceeded", "The eCourts provider timed out.");
		}
		logger.warn("eCourts provider could not be reached.");
		throw new HttpsError("unavailable", "The eCourts provider is unavailable.");
	}

	if (response.status === 404) {
		throw new HttpsError("not-found", "The case was not found in eCourts.");
	}
	if (response.status === 400) {
		throw new HttpsError("invalid-argument", "The eCourts provider rejected this CNR.");
	}
	if (response.status === 401 || response.status === 403) {
		logger.error("eCourts provider rejected server authentication.");
		throw new HttpsError("failed-precondition", "The eCourts provider rejected its configured credentials.");
	}
	if (response.status === 429) {
		throw new HttpsError("resource-exhausted", "The eCourts provider rate limit was reached.");
	}
	if (response.status >= 500) {
		logger.warn("eCourts provider returned a server error.");
		throw new HttpsError("unavailable", "The eCourts provider is unavailable.");
	}
	if (response.status !== 200) {
		throw new HttpsError("unavailable", "The eCourts provider could not complete the request.");
	}

	let payload;
	try {
		payload = await response.json();
	} catch (_) {
		throw new HttpsError("data-loss", "The eCourts provider returned malformed JSON.");
	}
	return mapProviderResponse(payload, cnr);
}

exports.refreshCaseFromECourts = onCall(
	{
		region: "us-central1",
		timeoutSeconds: 60,
		secrets: [ecourtsApiKey, ecourtsBaseUrl],
	},
	async (request) => {
		if (!request.auth) {
			throw new HttpsError("unauthenticated", "Sign in to refresh a case.");
		}
		const uid = request.auth.uid;

		try {
			const caseId = validateCaseId(request.data?.caseId);
			const caseRef = db.collection("cases").doc(caseId);
			const caseSnapshot = await caseRef.get();
			if (!caseSnapshot.exists) {
				throw new HttpsError("not-found", "The requested case was not found.");
			}

			const initialCaseData = caseSnapshot.data();
			const initialAccess = await readAuthorizationDocuments(
				uid,
				initialCaseData,
				undefined,
				request.auth.token.email,
				request.auth.token.email_verified === true,
			);
			assertCloudPlan(initialAccess.userSnapshot);
			if (!isAuthorizedCaseUser(
				uid,
				initialCaseData,
				initialAccess.teamSnapshot,
				initialAccess.memberSnapshots,
			)) {
				throw new HttpsError("permission-denied", "You are not authorized to access this case.");
			}

			const cnr = storedCnr(initialCaseData);
			const ecourtsData = await fetchFromECourts(cnr);

			await db.runTransaction(async (transaction) => {
				const freshCaseSnapshot = await transaction.get(caseRef);
				if (!freshCaseSnapshot.exists) {
					throw new HttpsError("not-found", "The requested case was not found.");
				}
				const freshCaseData = freshCaseSnapshot.data();
				const freshAccess = await readAuthorizationDocuments(
					uid,
					freshCaseData,
					transaction,
					request.auth.token.email,
					request.auth.token.email_verified === true,
				);
				assertCloudPlan(freshAccess.userSnapshot);
				if (!isAuthorizedCaseUser(
					uid,
					freshCaseData,
					freshAccess.teamSnapshot,
					freshAccess.memberSnapshots,
				)) {
					throw new HttpsError("permission-denied", "You are not authorized to access this case.");
				}
				if (storedCnr(freshCaseData) !== cnr) {
					throw new HttpsError(
						"failed-precondition",
						"The case CNR changed during refresh. Please try again.",
					);
				}
				transaction.update(caseRef, { ecourts_data: ecourtsData });
			});

			return { caseId, cnr, ecourts_data: ecourtsData };
		} catch (error) {
			if (error instanceof HttpsError) throw error;
			logger.error("LED eCourts refresh failed during an internal operation.");
			throw new HttpsError("internal", "Unable to refresh this case from eCourts.");
		}
	},
);

// ─────────────────────────────────────────────────────────────────────────────
// LED User ID allocation (server-authoritative year).
//
// Reuses the existing Firebase Functions v2 + firebase-admin infrastructure.
// This is LOCAL SOURCE ONLY. It is not deployed in this run. Deployment
// requires Firebase Blaze billing, a successful `firebase deploy --only
// functions`, and client-side wiring (firebase_functions package + a call
// to this function instead of the client-side transaction).
//
// Contract (Option A): single global sequence, year suffix from server time,
// numeric component zero-padded to 4 digits but allowed to grow beyond 4.
// ─────────────────────────────────────────────────────────────────────────────
exports.allocateLedId = onCall(
	{
		region: "us-central1",
		timeoutSeconds: 60,
	},
	async (request) => {
		if (!request.auth) {
			throw new HttpsError("unauthenticated", "Sign in to complete your profile.");
		}
		const uid = request.auth.uid;
		const serverYear = new Date().getFullYear();

		try {
			const result = await db.runTransaction(async (transaction) => {
				const userRef = db.collection("users").doc(uid);
				const userSnap = await transaction.get(userRef);
				const existing = userSnap.exists ? userSnap.data() : null;

				const storedLedId =
					typeof existing?.ledId === "string" ? existing.ledId.trim() : "";

				// Reuse path: preserve exact ID, no counter increment.
				if (storedLedId.length > 0) {
					const name =
						typeof existing?.name === "string" ? existing.name.trim() : "";
					if (name.length === 0) {
						throw new HttpsError(
							"failed-precondition",
							"Profile name is required before an LED ID can be assigned.",
						);
					}
					const advocateType =
						typeof existing?.advocateType === "string"
							? existing.advocateType.trim()
							: "";

					const directoryRef = db.collection("led_id_directory").doc(storedLedId);
					const directorySnap = await transaction.get(directoryRef);
					if (directorySnap.exists) {
						const ownerUid = directorySnap.data()?.uid;
						if (typeof ownerUid === "string" && ownerUid !== uid) {
							throw new HttpsError(
								"permission-denied",
								"The LED directory entry for this ID is owned by another account.",
							);
						}
					}

					transaction.set(
						directoryRef,
						{
							uid: uid,
							ledId: storedLedId,
							name: name,
							advocateType: advocateType,
							profileCompleted: true,
							updatedAt: new Date(),
						},
						{ merge: true },
					);

					transaction.set(
						userRef,
						{ ledId: storedLedId, profileCompleted: true, updatedAt: new Date() },
						{ merge: true },
					);

					return { ledId: storedLedId, created: false };
				}

				// H3: validate required profile fields BEFORE counter allocation.
				const name =
					typeof existing?.name === "string" ? existing.name.trim() : "";
				if (name.length === 0) {
					throw new HttpsError(
						"failed-precondition",
						"Profile name is required before an LED ID can be assigned.",
					);
				}
				const advocateType =
					typeof existing?.advocateType === "string"
						? existing.advocateType.trim()
						: "";

				const counterRef = db.collection("metadata").doc("counters");
				const counterSnap = await transaction.get(counterRef);
				const rawCount = counterSnap.exists ? counterSnap.data().userCount : 0;

				// M5: reject invalid counter state; do not truncate or normalize.
				if (!isValidCounterValue(rawCount)) {
					throw new HttpsError(
						"failed-precondition",
						"The LED ID counter is in an invalid state.",
					);
				}

				const nextCount = rawCount + 1;
				const padded = String(nextCount).padStart(4, "0");
				const ledId = `${padded}-${serverYear}`;

				transaction.set(
					counterRef,
					{ userCount: nextCount, updatedAt: new Date() },
					{ merge: true },
				);

				transaction.set(
					userRef,
					{ ledId: ledId, profileCompleted: true, updatedAt: new Date() },
					{ merge: true },
				);

				transaction.set(
					db.collection("led_id_directory").doc(ledId),
					{
						uid: uid,
						ledId: ledId,
						name: name,
						advocateType: advocateType,
						profileCompleted: true,
						updatedAt: new Date(),
					},
					{ merge: true },
				);

				return { ledId: ledId, created: true };
			});

			return result;
		} catch (error) {
			if (error instanceof HttpsError) throw error;
			logger.error("LED ID allocation failed during an internal operation.");
			throw new HttpsError("internal", "Unable to allocate an LED ID.");
		}
	},
);


// Create a separate, private-by-default case registration for the recipient.
// CNR identifies the court case; it is not a shared workspace or permission.
exports.transferCaseToAdvocate = onCall(
	{
		region: "us-central1",
		timeoutSeconds: 60,
	},
	async (request) => {
		if (!request.auth) {
			throw new HttpsError("unauthenticated", "Sign in to transfer a case.");
		}
		const sourceUid = request.auth.uid;
		const caseId = validateCaseId(request.data?.caseId);
		const targetUid =
			typeof request.data?.targetLawyerId === "string"
				? request.data.targetLawyerId.trim()
				: "";
		if (!targetUid || targetUid.length > 128 || targetUid.includes("/")) {
			throw new HttpsError("invalid-argument", "A valid recipient account is required.");
		}
		if (targetUid === sourceUid) {
			throw new HttpsError("invalid-argument", "Choose a different recipient.");
		}

		const sourceRef = db.collection("cases").doc(caseId);
		const targetUserRef = db.collection("users").doc(targetUid);
		try {
			return await db.runTransaction(async (transaction) => {
				const [sourceSnap, targetUserSnap] = await Promise.all([
					transaction.get(sourceRef),
					transaction.get(targetUserRef),
				]);
				if (!sourceSnap.exists) {
					throw new HttpsError("not-found", "The source case was not found.");
				}
				const source = sourceSnap.data();
				const sourceOwnerUid =
					typeof source.ownerUid === "string" ? source.ownerUid : source.userId;
				if (sourceOwnerUid !== sourceUid) {
					throw new HttpsError("permission-denied", "You cannot transfer this case.");
				}
				if (!targetUserSnap.exists) {
					throw new HttpsError("not-found", "The recipient account was not found.");
				}
				const targetData = targetUserSnap.data();
				const targetLedId =
					typeof targetData.ledId === "string" ? targetData.ledId.trim() : "";
				if (!/^\d{4,}-\d{4}$/.test(targetLedId)) {
					throw new HttpsError(
						"failed-precondition",
						"The recipient must have a completed LED ID before receiving a case.",
					);
				}
				const targetDirectoryRef = db.collection("led_id_directory").doc(targetLedId);
				const targetDirectorySnap = await transaction.get(targetDirectoryRef);
				if (
					!targetDirectorySnap.exists ||
					targetDirectorySnap.data()?.uid !== targetUid ||
					targetDirectorySnap.data()?.profileCompleted !== true
				) {
					throw new HttpsError("permission-denied", "The recipient LED ID could not be verified.");
				}
				const cnr = storedCnr(source);
				const registryRef = targetUserRef.collection("case_cuid_registry").doc(cnr);
				const registrySnap = await transaction.get(registryRef);
				if (registrySnap.exists) {
					const registeredCaseId = registrySnap.data()?.caseId;
					if (typeof registeredCaseId !== "string" || !registeredCaseId.trim()) {
						throw new HttpsError("failed-precondition", "The recipient CNR registry requires migration.");
					}
					const registeredCaseRef = db.collection("cases").doc(registeredCaseId);
					const registeredCaseSnap = await transaction.get(registeredCaseRef);
					if (!registeredCaseSnap.exists) {
						throw new HttpsError("failed-precondition", "The recipient CNR registry points to a missing case record.");
					}
					const registeredCase = registeredCaseSnap.data();
					if ((registeredCase.ownerUid ?? registeredCase.userId) !== targetUid || storedCnr(registeredCase) !== cnr) {
						throw new HttpsError("failed-precondition", "The recipient CNR registry does not match its case record.");
					}
					return { caseId: registeredCaseId, created: false, cuid: cnr };
				}
				const targetCases = db.collection("cases")
					.where("ownerUid", "==", targetUid)
					.where("cuid", "==", cnr)
					.limit(1);
				const legacyTargetCases = db.collection("cases")
					.where("userId", "==", targetUid)
					.where("cnrNumber", "==", cnr)
					.limit(50);
				const [existing, legacyExisting] = await Promise.all([
					transaction.get(targetCases),
					transaction.get(legacyTargetCases),
				]);
				const legacyDuplicate = legacyExisting.docs.find((doc) => {
					const data = doc.data();
					// Old transfer code could change userId while leaving ownerUid
					// on the source record. Do not mistake that for recipient ownership.
					if (typeof data.ownerUid === "string" && data.ownerUid !== targetUid) return false;
					return storedCnr(data) === cnr;
				});
				const duplicate = !existing.empty ? existing.docs[0] : legacyDuplicate ?? null;
				if (duplicate) {
					const duplicateData = duplicate.data();
					if ((duplicateData.ownerUid ?? duplicateData.userId) !== targetUid || storedCnr(duplicateData) !== cnr) {
						throw new HttpsError("failed-precondition", "The existing recipient case requires migration.");
					}
					transaction.create(registryRef, { uid: targetUid, cuid: cnr, caseId: duplicate.id, updatedAt: new Date() });
					return { caseId: duplicate.id, created: false, cuid: cnr };
				}
				// The cloud registration is only CNR + minimum ownership/sync metadata.
				// Recipient private case fields are created locally and are never copied.
				const recipientCaseRef = db.collection("cases").doc();
				const recipientRecord = buildCnrOnlyCaseRecord({
					ownerUid: targetUid,
					ownerLedId: targetLedId,
					cnr,
					now: new Date(),
				});
				transaction.create(recipientCaseRef, recipientRecord);
				transaction.create(registryRef, { uid: targetUid, cuid: cnr, caseId: recipientCaseRef.id, updatedAt: new Date() });
				return { caseId: recipientCaseRef.id, created: true, cuid: cnr };
			});
		} catch (error) {
			if (error instanceof HttpsError) throw error;
			logger.error("Case transfer failed.");
			throw new HttpsError("internal", "Unable to create the recipient's independent case record.");
		}
	},
);
