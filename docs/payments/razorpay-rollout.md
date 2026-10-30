# LED payments — Razorpay implementation and rollout gates

## Architecture

- LED remains one app. JURIS is an integrated LED module, not a separate product.
- Razorpay is the initial Windows/desktop checkout candidate.
- JURIS Credits and Case Tokens are distinct server-side balances under the existing shared LED/JURIS account structure.
- Prices and grants are server-owned. The client selects a pack ID only; it cannot submit an amount or a number of credits.
- Checkout order creation requires a verified Firebase user. Credits are granted only after a server-verified captured payment or a valid Razorpay payment.captured webhook.
- The payment ledger uses the same _server_token_accounts/{uid}/balances/{juris|case} and ledger collections as the JURIS finance repository. Each Razorpay order is credited at most once.
- The integration is fail-closed until PAYMENTS_ENABLED=true and all Razorpay secrets are configured in the gateway hosting environment.

## Current pack denominations

The implementation defines ₹100, ₹250, ₹500 and ₹1,000 packs for either balance. At the current product rule of ₹1 per Credit/Case Token, the number of units equals the rupee amount. These are technical starter denominations and should be confirmed before enabling live payments.

## Gateway environment variables

Configure only in FastAPI Cloud secrets; never commit real values:

- PAYMENTS_ENABLED=false (keep false until merchant approval, policy checks and staging tests are complete)
- RAZORPAY_KEY_ID
- RAZORPAY_KEY_SECRET
- RAZORPAY_WEBHOOK_SECRET

Configure the Razorpay webhook URL as https://<LED-gateway-host>/v1/payments/webhook and subscribe to payment.captured and payment_link.paid. Do not point this at the JURIS service.

## Endpoints

- GET /v1/payments/packs — publish available denominations.\n- POST /v1/payments/links — authenticated; creates a hosted Razorpay checkout URL for Windows.\n- GET /v1/payments/links/{reference_id} — authenticated status polling after checkout; the balance changes only after the signed payment_link.paid webhook.
- POST /v1/payments/orders — authenticated; accepts {"packId": "juris_credits_100"} or a case_tokens_* pack ID.
- POST /v1/payments/verify — authenticated; validates Razorpay checkout HMAC and then fetches payment status from Razorpay before granting.
- POST /v1/payments/webhook — verifies the raw-body webhook HMAC and processes captured payments idempotently.

## Platform policy and cost

- Windows PC non-game app: Microsoft Store Policy 10.8 permits secure third-party purchase APIs for digital items/services. The app must identify the commerce provider, authenticate the user, obtain transaction confirmation, comply with PCI DSS obligations, and disclose third-party checkout in Partner Center.
- Android: use Google Play Billing for the Play-distributed app by default. India alternative billing is an optional, enrolled user-choice program with required APIs/reporting and an adjusted Play service fee; it is not a blanket fee bypass. Do not route Play-installed Android users directly to Razorpay unless the app is enrolled and implements the current program requirements.
- Razorpay's published standard plan is generally 2% plus GST, with some methods at 3%; merchant eligibility, settlement terms and actual rate must be confirmed before launch.
- Do not deploy, enable live payments, or perform real-money tests until the merchant account is approved, secrets are configured, legal business/KYC obligations are satisfied, refund/support processes exist, and staging verification passes.

## Client integration status

- Windows: the Balances screen now loads the server-owned packs, requests an authenticated hosted payment link, opens the returned HTTPS `shortUrl` in the system browser, and exposes a status-check action for the returned `referenceId`. It disables another checkout while one reference is awaiting confirmation. The UI never credits a balance locally; it refreshes only after the gateway reports that the signed webhook has been processed.
- Android: Razorpay checkout is not exposed. The Play-distributed Android app still needs Google Play Billing purchase flow, backend purchase-token verification and acknowledgement, or a separately approved India alternative-billing implementation. Do not route Android users to the Windows Razorpay flow.
- Subscriptions: the Plans & Upgrades catalogue remains informational. These top-up endpoints do not activate subscription plans or entitlements; subscriptions need their own server-authoritative purchase and renewal flow.
- Store-console setup, merchant KYC/approval, refund/support processes, production secrets, and staging verification remain release blockers. Keep `PAYMENTS_ENABLED=false` until those gates are complete.
