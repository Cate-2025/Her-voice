> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../README.md).

# Gap-bridging progress — 18 October 2026

This is the current implementation tracker against the [original comparison](REQUIREMENTS_COMPLETION_AND_BI.md). The comparison remains a historical baseline. This pass delivers a working block of recovery, evidence, email access and dated status tracking; it does not mark the entire original plan complete.

## Decisions confirmed

- Keep drafts encrypted after sign-out; recover them after the **same account** authenticates again.
- Use email verification for registration, with **no domain restriction for now**. Email ownership is verified; university eligibility is not.
- Preserve the previous decision: officers do not see account identity; an administrator can reveal it with an audited reason. Files, names and embedded metadata can still identify people.

## Current requirement position

| Requirement | Delivered now / earlier | Still remaining |
|---|---|---|
| R1 Accounts | Email-code registration and password reset, student-only self-registration, single-use/expiring codes, attempt/resend limits, login throttling; reset revokes previous JWT sessions and push devices | Real SMTP configuration and delivery acceptance; university eligibility if later required; refresh tokens/session management and staff-role administration |
| R2 Reporting | Android saves encrypted local drafts and the original submission intent/key/server ID. A retry after reopening reuses the same operation | Full server-draft edit/delete/version lifecycle; amendments/withdrawal; uncertainty in date/subject; recovery from permanent validation failures |
| R3 Evidence | Android copies selected bytes into encrypted app storage. Authenticated upload with stable file ID, bounded size/count, checksum/signature checks, storage read-back, retry deduplication; verified officer download and access audit | S3/MinIO integration acceptance, malware quarantine/scanning, lifecycle/retention and orphan cleanup, account/storage quotas, institutional handling policy |
| R4 Timeline | Backend accepts multiple events; officer view renders them | Multi-event student editor and structured student timeline, approximate dates and amendment history |
| R5 Confidentiality | Officer responses omit account identity; admin reveal requires reason and audit; consent mentions file metadata risk | Institutional disclosure/access matrix, notice versioning, infrastructure/export controls; truly anonymous intake remains a separate decision |
| R6 Status | Dated student history built from submission timestamp and committed status audit events; current status and stale-update protection | Specific student follow-up messages, reopening/withdrawal rules, pagination and response-target definitions |
| R7 Case handling | Queue/filter/status confirmation, evidence list and audited download, controlled identity reveal | Assignment/reassignment and assignment-scoped permissions, notes/referrals, alert decisions, outcome definitions, controlled exports |
| R8 Offline | Android draft/evidence persistence and restart-safe retry; local saving works without the API in an existing session | Fresh offline unlock, automatic/background sync, attachment transfer resumption from a byte offset, representative device/backup/full-storage testing |
| R9 Notifications | In-app read-all and Android Firebase integration with delivery queue/retries | Firebase configuration and phone acceptance, more granular preferences, optional SMS decision |
| R10 Patterns | Existing distinct-account threshold and officer alert display | Controlled subject matching, versioned/explainable rules, scheduled evaluation and alert recurrence/review lifecycle |
| R11 Support | General guidance | Verified contacts, availability, ownership and offline directory |
| R12 Operations | Local migrated PostgreSQL, private prototype file storage, encrypted Android data, backup exclusions and tests | Hosting/TLS, production encryption/key operation, backup/restore, monitoring, release signing, CI, retention and security/device review |
| R13 BI | Submission timestamps, dated transitions, evidence audit and notification delivery states provide better source data | Metric definitions, approved aggregate endpoints/dashboard, disclosure/export rules, reconciliation and ownership |

## How to run this block

1. Stop the existing API through the terminal/IDE session that launched it.
2. From `backend`, install updated dependencies with `.venv/bin/python -m pip install -r requirements-dev.txt`.
3. Run `.venv/bin/python -m scripts.run_prototype`. It applies migration `0004`, keeps existing accounts/passwords and stores test evidence privately under `backend/.prototype/evidence/`.
4. Stop and rerun the Android app through Android Studio; native storage dependencies require a full restart. Retain the existing `HERVOICE_API_BASE_URL` and ADB reverse mapping.
5. Refresh the officer dashboard to load its new evidence controls.
6. For email verification, follow [email setup](EMAIL_ACCESS_SETUP.md). Registration remains disabled until a delivery mode is selected. Seeded accounts remain usable.

No running personal prototype database was modified during automated tests. Do not uninstall the Android app to update it if you want to retain its new local drafts. An uninstall, clearing app data or loss of the device key makes device-only drafts unrecoverable. Source files selected from Downloads/gallery remain outside HERVOICE's control.

## Recovery and evidence behavior

Android stores encrypted state/files in app-private storage using AES-GCM and a per-server/account key protected by Android secure storage. Metadata is atomically replaced; submission intent must finish saving before a network submission begins. The UI reports pending/failed local saves, and explicit Save/sign-out waits for storage. Do not force-close while the UI says saving. A crash cannot turn a replay of an already saved operation into a new request ID.

Saved data is separated by **API base URL and account ID**. Changing the configured API URL opens a different local scope. A valid online sign-in is required after process restart; this version does not store passwords/JWTs for offline unlock. Ordinary private drafts never submit merely because connectivity returns. Reopen a pending draft and explicitly retry it from Review. Pending contents stay frozen to prevent retrying an altered report.

Up to five supported files, each at most 10 MB, can be selected on Android. The app saves encrypted copies, then uploads them during explicit submission, showing which file is being transferred. A failed transfer retries the whole file using its original ID. Server verification checks actual byte count, SHA-256, supported format signature and storage read-back. Verified objects use server-only storage keys separate from legacy upload-URL keys; replay does not overwrite verified evidence. These checks do not establish malware safety, full document validity or the truth of an allegation.

The prototype runner uses private local files rather than requiring a separate MinIO process. Normal manually configured deployments default to S3-compatible storage. Local server files rely on filesystem/host protection; production disk/bucket encryption and backups must be configured separately. Downloads are authenticated, attachment-only, not publicly mounted, and audited before bytes are returned. An audit records authorisation to transfer, not proof that the officer opened the file. Existing legacy reserved metadata is not automatically marked verified.

Encrypted bytes left behind by a crash before their draft reference is saved, or server objects written before a database failure, may remain as orphans; automated retention/cleanup is still pending. There is no claim of forensic secure erasure. Keep this prototype on fictional data.

## Acceptance checklist on the actual Android phone

- [ ] Start a draft, type details, choose a fictional file, Save, close the app and sign in again: recover both.
- [ ] Sign out and use another account: the first account's drafts remain hidden. Switch back and recover them.
- [ ] Disconnect the API during an existing session, edit and save locally, reconnect and explicitly submit.
- [ ] Interrupt a submission, reopen/sign in and retry: verify one report and one copy of each attachment.
- [ ] Download the submitted file as an officer and compare it with the original. Other students must be denied; draft files must not appear to officers.
- [ ] Change Submitted → Received → Under review; verify the student's dated history.
- [ ] Verify email and password-reset flows with the configured mail delivery; old sessions fail after reset.
- [ ] Test low storage, device lock/reboot, TalkBack, large text, system Back and backup/transfer exclusions on representative phones.

The automated vault tests use real encryption/filesystem operations with an injected test key store. They do not replace physical-device verification of Android Keystore and OEM backup behavior. Real SMTP, S3 and Firebase delivery remain external integration checks.

## Next implementation block

Prioritise the multi-event student timeline, assignment-scoped officer workflow and explicit follow-up actions. Then complete alert-review lifecycle and a verified support directory. Governed BI should use agreed metric definitions and these dated operational events; broad analytics/export access is not implied by officer access.


## Verification recorded

- 32 backend tests passed against isolated PostgreSQL, including migration round trips, email-code boundaries, reset session revocation, concurrent upload deduplication, storage corruption and case history.
- 50 Flutter tests passed including encrypted restart recovery, cross-account isolation, ciphertext tampering, failed-save prevention of network submission, email form validation and the live API/file-download journey.
- Android debug APK and web release builds succeeded. Static analysis and whitespace checks are recorded with the final handoff.
- Temporary acceptance servers were stopped after testing. The user's existing prototype server/data were not restarted or migrated by this pass.
- Actual Android Keystore/device behavior, dashboard browser interaction and real SMTP/S3/Firebase delivery remain manual/external checks. The existing Firebase Core future-Kotlin-compatibility and Starlette/httpx deprecation warnings remain; they did not fail these builds/tests.

Implementation references: [Flutter secure storage](https://pub.dev/packages/flutter_secure_storage), [AES-GCM library](https://pub.dev/packages/cryptography), and [application support directory](https://pub.dev/documentation/path_provider/latest/path_provider/getApplicationSupportDirectory.html). The hardware key store is exercised by the Android app, while automated vault tests inject a fictional key provider.
