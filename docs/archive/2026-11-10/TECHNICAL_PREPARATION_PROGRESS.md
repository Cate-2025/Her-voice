> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../README.md).

# Technical preparation progress

30 October 2026. This pass implements groundwork authorised while administrative feedback is pending. It does not change case assignment, status meanings, disclosure policy, retention periods or approved institutional wording. The earlier stakeholder DOCX remains the decision workbook; its source-review snapshot precedes these changes.

## Delivered

- Separated shared Flutter models/store contracts from demo fixtures. Extracted draft-save queuing, report mapping and frozen submission intent into named components. The connected store remains a coordinator; no new state framework was introduced.
- Coalesced redundant same-account metadata saves while a write is active, preserving explicit flush and pre-submission durability. Controlled test: 200 edits plus final flush require two vault writes while storage is blocked; no claim of physical-device speed/power improvement.
- Bounded case/alert API requests to 100 rows and updated both clients to follow pages. Flutter detail loads run in batches of at most four, maintaining presentation order and account-generation checks. Remaining total-list memory and notification pagination limitations are documented.
- Added staging/production configuration rejection for development placeholders, local evidence/mail, non-HTTPS storage/browser origins and unsupported JWT algorithms. Added bounded storage calls, reused S3 clients and database connection/statement limits.
- Added dependency readiness distinct from liveness; errors are neutral and no-store. Hosted Swagger/OpenAPI endpoints are disabled.
- Added an unprivileged API Dockerfile, separate HTTPS/restart Compose setup, optional Firebase mount and explicit migration/initial-admin bootstrap. No accounts or services were created by this pass.
- Removed release signing's debug fallback; documented owner-supplied signing configuration and added an HTTPS startup guard for connected release builds.
- Added technical CI for backend/Flutter/admin checks and container build, and operating/deployment/recovery/release guides.

## Review order

1. Read CODE_STRUCTURE_AND_RECOVERY.md for component and failure explanations.
2. Use [Deployment](DEPLOYMENT.md) for the current ordered hosting steps; the operations runbook is now a supporting reference.
3. Follow ANDROID_RELEASE.md after an approved URL and signing owner exist.
4. Complete the stakeholder workbook before implementing policy-dependent workflow changes.

## External requirements still pending

Hosting/DNS and operator ownership; real PostgreSQL/S3/SMTP/Firebase configuration; image and proxy startup; TLS/renewal and reboot checks; monitored failures and a full database/evidence restore; physical Android profiling, secure-storage behaviour, signed-update acceptance and draft migration across URL/signing changes; real browser/accessibility acceptance. Evidence malware scanning/quarantine, assignment-scoped access and institution-approved policy remain v1 gates.

Docker runtime checks are blocked by operating-system permission to /var/run/docker.sock, even outside the tool sandbox. No Docker group, daemon, host firewall or user permissions were changed. Compose structure can be validated without the daemon; image execution needs an authorised host or CI.

## Integration cautions

Roll out the API and paginated clients together when there are more than 100 cases. The personal prototype server was not restarted or migrated. Re-run the backend normally to load code changes; hot reload alone does not reconfigure a signed Android build. Existing development API address and wireless-debugging setup remain unchanged.

Offset pagination is eventually consistent during concurrent changes. Do not treat its output as a reconciled BI export. Backups and monitoring steps are documented but not installed on an external service. CI is prepared locally and has not run remotely until this work is committed/pushed through the normal review process.

## Verification recorded for this pass

- 53 backend tests passed against isolated temporary PostgreSQL, including hosted configuration, readiness failure, bounded lists, initial-admin bootstrap and earlier evidence/access/retry tests.
- 53 Flutter tests passed; one optional live API journey was skipped because no separate live test server was configured. Final static analysis is clean; the loading tests were rerun after cleanup.
- Three admin confirmation tests passed: valid button markup, cancellation without an update and one confirmed transition with stale-status protection. These use a stubbed DOM, not a real browser.
- Android debug APK compilation passed. A release dry run refused missing release signing with the intended message; no release key or signed release was generated.
- Compose base/Firebase override configuration validation and whitespace checks passed. Docker image startup/build remains unverified locally due to Docker socket permissions. Prepared CI has not run remotely.
- Existing Starlette test-client deprecation and Android Firebase/Kotlin/SDK tooling warnings remain. They did not fail tests or debug compilation; dependency/toolchain migration needs its own validated pass.


## Follow-up review on 1 November 2026

The second file review found and corrected issues that do not depend on administrative policy:

- Late failed Flutter sign-in attempts no longer clear a newer account's token. Old refresh/submission continuations stop before issuing follow-up requests with the new account's credentials.
- The admin HTTP helper rejects stale responses even if the account changes during JSON parsing; an old 401 cannot sign out a new session.
- Both clients detect repeated full pages, rather than looping indefinitely against an older server that ignores pagination.
- Readiness refuses to route traffic when the installed database migration revision does not match the image. Process liveness remains independent.
- Hosted configuration rejects missing storage hosts, embedded storage credentials and browser origins containing paths. The image now defaults to production settings instead of relying on the operator to override development mode.

These changes have targeted regression coverage. Full Flutter suite: 57 passed and one optional live API journey skipped. Static analysis is clean. Admin suite: six tests passed. Final backend verification is recorded below. Docker execution, provider integrations, real device/browser acceptance and stakeholder decisions remain external checks; no real accounts, prototype records or running services were altered.

Final backend result for the follow-up review: 58 tests passed against isolated PostgreSQL. The six focused Flutter race/loading tests also passed after style cleanup. Compose validation and whitespace checks passed. The existing Starlette test-client deprecation remains non-failing. This pass changed no Android native configuration, and did not generate a new desktop APK or claim a new signed-release/device acceptance run.

## Final pre-manual review on 1 November 2026

Found a retry defect in the encrypted draft vault: failed secure-key lookup/creation futures remained cached for the lifetime of the vault. Failed entries are now evicted so a later explicit retry can recover after a temporary secure-storage error. Successful keys remain cached; existing encrypted data still requires its original key. Regression cases cover transient key read and key write failures, including reopening saved ciphertext with the persisted key.

Replaced the remaining attachment error's “milestone” wording with a device-specific user message. Added MANUAL_TESTING_CHECKLIST.md with build provenance, ordered checks, expected outcomes and explicit untested/provider-dependent items. No running service, existing device data or desktop APK was changed.

Verification: 59 Flutter tests passed; one optional live API test skipped. Flutter analysis and whitespace checks passed. The initial sandboxed test attempt could not bind the runner's local socket; the permitted rerun completed successfully. Backend code was unchanged in this final pass; its previous 58-test result was not rerun or counted as fresh verification.
