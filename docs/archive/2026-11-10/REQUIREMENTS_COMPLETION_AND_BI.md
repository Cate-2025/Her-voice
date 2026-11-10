> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../README.md).

# HERVOICE requirements completion and business intelligence roadmap

> Historical planning/review reference. For current deployment steps and expected results, use [Deployment](DEPLOYMENT.md). Older implementation limits below may have been superseded.

Prepared 15 October 2026 against consolidated main commit `f1ef1c9`.

HERVOICE has a connected reporting and case-coordination prototype. Reaching the original plan requires completing evidence handling, durable offline work, reporting privacy choices, fuller case workflows and their external support. Business intelligence also needs consistent operational data and institutional definitions before useful charts can be trusted.

This is a planning document. It implements no feature, changes no configuration, selects no supplier and makes no deployment commitment. Proposed owners and acceptance conditions below are suggestions for agreement. Existing test results are taken from the consolidation record; tests were not rerun for this documentation pass.

## 1. Basis and how to read this document

The original source is `/home/emmaa/Desktop/case.doc`, whose supplied content covers sections 6–10. Section 10 lists ten expected outcomes. Sections 7–9 also require registration, support resources, secure storage, administrative insights and an offline/network design. All are addressed here.

Current-state evidence:

- [Consolidation review](CONSOLIDATION_REVIEW.md): branch decisions and previously completed verification.
- [API contract](../../reference/API_CONTRACT.md): implemented endpoints and known lifecycle gaps.
- [Flutter implementation plan](FLUTTER_IMPLEMENTATION_PLAN.md): earlier engineering proposals, not proof of completion.
- [Connected client store](../../../flutter_app/lib/core/connected_store.dart): session state, submission retries, case loading and notifications.
- [Database models](../../../backend/app/models.py), [report routes](../../../backend/app/routers/reports.py), [officer routes](../../../backend/app/routers/officer.py), [evidence routes](../../../backend/app/routers/evidence.py) and [pattern service](../../../backend/app/services/patterns.py): current server behaviour.

Two completion levels are distinguished:

| Level | Meaning |
|---|---|
| Original-plan prototype | A fictional-data demonstration of the stated features, backed by working integrations and repeatable tests. Merely displaying a screen does not meet this level. |
| Institutional pilot | A limited real-user service with approved access rules, accountable staff, appropriate hosting, support, recovery procedures and reviewed handling of sensitive information. Prototype test success alone does not establish readiness. |

A percentage-complete figure would be misleading: a small-looking upload button depends on a substantial storage and verification lifecycle, while a large screen may already be mostly complete.

## 2. Requirement summary

| ID | Original requirement | Current position | Principal missing piece |
|---|---|---|---|
| R1 | Secure student authentication | Seeded accounts and expiring JWT sign-in work | Real account onboarding/recovery and session lifecycle |
| R2 | Create and submit an incident report | Connected no-file submission works | Durable operation recovery and a complete draft lifecycle |
| R3 | Attach and securely manage evidence | Reservation scaffolding; connected uploads disabled | Verified private storage and authorised retrieval |
| R4 | Incident timeline | One event in the client; multiple accepted by API | Multi-event editing and faithful chronological presentation |
| R5 | Confidential reporting | Account-linked access controls exist | Approved identity-disclosure rules implemented end to end |
| R6 | Case-status tracking | Current server status is visible | Durable status history and follow-up semantics |
| R7 | Administrative case management | Officer queue, detail, transitions and audit records work | Assignment, evidence review, complete action workflows and insights |
| R8 | Offline creation and synchronisation | In-memory editing and same-session retries | Encrypted durable storage and persistent sync operations |
| R9 | Secure notifications | Neutral in-app notifications work | Reliable delivery lifecycle; push/SMS where approved |
| R10 | Recurring-report pattern detection | Basic distinct-account threshold exists | Consistent matching, explainable alert lifecycle and validation |
| R11 | Support resources, from section 7 | General guidance exists | Verified directory and accountable content maintenance |
| R12 | Hosting, network, storage and operations | Local development setup works | Managed environments, recovery, monitoring and release operation |
| R13 | Authorised reports and analytics, from section 7 | Operational data exists; no general BI product | Metric definitions, curated data access and aggregate reporting |

## 3. Work needed for each requirement

### R1. Secure student authentication

**Current position.** Password hashes, seeded student/officer/admin accounts, JWT expiry, role checks and `/auth/me` exist. The client holds its token in memory. Sign-out clears local data; expiry permits same-account reauthentication while the process remains alive. There is no active registration or password-recovery flow.

**Work to complete.** Agree whether registration uses university identity, verified university email or administrator invitations. Build the selected onboarding flow, prevent self-assignment of officer/admin privileges and support account activation/deactivation. Add account recovery appropriate to that identity source. Define and implement session expiry, renewal/revocation, logout and device-loss behaviour. If persistent sessions are wanted, store credentials/keys using platform-backed facilities rather than ordinary preferences. Add throttling and tests for expired, disabled, revoked and cross-account sessions.

**External requirements.** University identity/IT owner; an eligibility source or identity-provider integration; email delivery if verification/reset links are used; a process for granting and withdrawing staff roles. A fictional identity fixture is enough for a prototype demonstration, but it does not establish university eligibility verification.

**Completion evidence.** A new eligible student can obtain access and recover it through the agreed route; an ineligible account cannot; a deactivated officer cannot retain access under the defined session policy. Wrong-role and cross-student tests pass.

**BI implication.** Distinguish accounts from people. Count only a defined population of active/eligible accounts; never use login counts as a measure of incidents. Keep authentication secrets and identity contact details outside analytical datasets.

### R2. Creation and submission of an incident report

**Current position.** A student can enter one incident, consent and submit it. The API creates a private server draft, checks ownership, finalises once and persists the report. Same-session retries freeze the request and reuse its operation key. The client loses the pending operation and local draft on process death or explicit sign-out.

**Work to complete.** Persist the submission intent, immutable request snapshot, operation key and returned server ID before progressing to the next stage. Recover an uncertain outcome by checking/replaying that same operation. Add a defined server-draft retrieve/update/version/delete lifecycle and cleanup rules for abandoned drafts. Specify what happens if a submitted report needs correction or withdrawal; do not silently overwrite the original account. Agree unknown-subject and approximate-date handling. Add structured categories only after the institution defines them and their purpose. Integrate optional evidence without making it mandatory for reporting.

**External requirements.** A case-handling owner must approve the intake fields, minimum information, reporting categories, correction/withdrawal procedure and what submission authorises. No additional commercial service is inherently required beyond the backend/database.

**Completion evidence.** Kill the app after server creation or finalisation, reopen and recover exactly one report. A new login cannot expose someone else's pending work. A student can report without evidence; invalid and incomplete submissions receive actionable errors. Submitted amendments remain traceable.

**BI implication.** Define the counting unit: one report is not necessarily one incident, one reporter or one case investigation. Use actual submission time for intake measures; exclude server drafts and retries. Keep incident occurrence and reporting time separate.

### R3. Attachment and secure management of supporting evidence

**Current position.** The API can reserve metadata and generate a signed upload URL for an owned draft. It records a reserved state. There is no upload-completion verification endpoint. Finalisation blocks unverified retained evidence, so the connected client correctly disables attachments. A signed-URL helper is not a completed evidence vault.

**Work to complete.** Provision a private bucket and implement the lifecycle: reserve → transfer → verify → retain or reject. Verify actual object existence, byte size, file type and checksum; do not trust the submitted metadata. Make reservation/completion retries safe. Protect verified bytes from later replacement, including reuse of a still-valid upload URL. Enforce per-file, file-count, total-size and account quotas. Implement progress, interruption recovery, removal before submission, abandoned-object cleanup and expiry handling. Add case-authorised listing/download, access audit and an officer UI. For a real pilot, implement the agreed quarantine/scanning and retention/deletion processes and test storage restoration.

**External requirements.** Private object storage; storage administration and key management; capacity/egress budget; a scanning service or operated scanner if required by the pilot; institution-approved evidence handling, access and retention procedures. Recording guidance must be reviewed by the responsible institution; this document does not decide legal admissibility.

**Completion evidence.** A real test file survives interruption, is verified, belongs to the correct case and is retrievable only by authorised users. Missing, oversized, mismatched, overwritten or unverified bytes cannot be finalised as valid evidence. Download authorisation is checked again when access is requested. Issuing a URL is recorded separately from an actual successful transfer where that evidence is needed.

**BI implication.** Aggregate type, verified byte volume, upload success/failure and storage growth can guide operations. Evidence quantity is not a credibility score. Do not put file contents, filenames or signed URLs in the general analytics layer. A valid checksum demonstrates byte integrity, not that the allegation is true.

### R4. Incident timeline creation

**Current position.** The client collects one dated event. The backend accepts multiple timeline events, but the client currently combines their narratives and presents the first event's date/location rather than a full structured multi-event timeline.

**Work to complete.** Let students add, edit, reorder and remove events before submission, with separate dates, locations and narratives. Render all returned events individually in student and officer views. Model uncertain dates/time precision explicitly instead of inventing an exact timestamp. Define post-submission additions and amendments with their author, recorded time and version. Maintain the distinction between incident events and administrative status changes.

**External requirements.** Agreed terminology and date-uncertainty handling from students and case officers; a review of whether location precision is necessary. A mapping service is not required for a useful text-based timeline.

**Completion evidence.** Several events entered out of order display correctly after reload; timezone conversion preserves their meaning; approximate dates remain approximate; changing an event does not destroy the recorded history under the agreed policy.

**BI implication.** Store occurrence time, precision and capture time separately. Otherwise a reporting-delay chart can manufacture false precision or confuse repeated incidents with duplicated reports. Show unknown dates as unknown, not zero delay.

### R5. Confidential reporting and levels of identity disclosure

**Current position.** Reports are linked to authenticated accounts in the database. Owner/role checks apply and response summaries omit reporter identity. The client uses the `confidential` mode, but there is no separately implemented identity-release policy. Anonymous submission is unavailable.

**Work to complete.** Define exactly who can see report content, account identity and contact information, and under which circumstances each can be disclosed. Implement those rules in endpoints, queries, dashboard views, exports and audits. Review infrastructure/log access too; hiding a field in a response is insufficient. Present the actual policy before submission and record the relevant notice/choice version. If anonymous reporting from section 7.2 is retained, build it as a separate capability and recovery flow, including anonymous upload authorisation, abuse controls and lost-code rules. Do not quietly attach an authenticated identity to an anonymous request.

**External requirements.** A named university policy owner, case-management lead and privacy/security reviewer must settle the disclosure framework and exceptional-access process. These are institutional decisions, not choices the app should invent. Applicable obligations require institution-specific review before real-case use.

**Completion evidence.** An agreed role/action matrix passes negative tests across detail endpoints, files, searches and exports. Identity access is deliberate and auditable. Anonymous access, if offered, works without a student account and has a clear recovery boundary. User-facing wording matches the actual implementation.

**BI implication.** Access to case content must not automatically grant access to identified analytics. Avoid small aggregates or combinations that reveal a reporter. Anonymous submissions cannot automatically be counted as independent people. Keep these limitations explicit in dashboards.

### R6. Case-status tracking

**Current position.** Students can reload submitted cases and see current status. Officer status changes are audited, but there is no dedicated student-facing dated status-history model/API. A general `updated_at` field can change for reasons other than the status being measured.

**Work to complete.** Record an authoritative transition event with case ID, old/new status, event time, actor and appropriate reason/visibility. Define student-visible messages and exactly what “action required” and “closed” mean. Add pagination, last-refresh/error states, and status history. Decide whether reopening, withdrawal and follow-up are needed and how they alter the lifecycle. Guard concurrent officer updates so an old screen cannot unknowingly overwrite newer work.

**External requirements.** Case officers must agree statuses, responsibilities, working-calendar rules and any response targets. Do not promise an investigation deadline that the institution has not adopted and staffed.

**Completion evidence.** A sequence of valid changes produces an ordered history; invalid/repeated/conflicting updates behave consistently. The student sees the correct history and action explanation after reconnecting. “Closed” does not imply a particular finding unless that is separately recorded and authorised for display.

**BI implication.** Reliable transition times enable time to acknowledgement, time in status and backlog ageing. Never substitute latest modification time for first acknowledgement or closure time. Audit records may help reconstruct existing changes, but their completeness and meaning must be validated before analytical use.

### R7. Administrative case management

**Current position.** The browser dashboard supports officer sign-in, queue/detail, permitted status changes and an active pattern-alert list. Case actions have audit records. Access is broadly role-based; an assignment field exists without a complete assignment workflow. Evidence review and a general analytics/export interface are unfinished.

**Work to complete.** Define queue ownership, triage, assignment/reassignment and exceptional access. Implement matching authorisation checks, filters, pagination and conflict handling. Add evidence controls from R3, chronology from R4/R6 and the agreed case notes/actions/referrals. Complete alert review controls and record reviewer decisions. Build exports only with explicit audience, field selection, audit and retention rules. Model outcome and closure reason only after their meanings are agreed; do not equate administrative closure with a misconduct finding.

**External requirements.** Named and trained case officers; an escalation path; an agreed operating procedure; workload ownership; decision authority; support/referral partners. A dashboard cannot provide case-handling capacity by itself.

**Completion evidence.** An authorised officer can handle an assigned fictional case from receipt through the agreed closure process, including evidence and student updates. An unassigned or unauthorised officer is denied according to the policy. Access and decisions can be reviewed later.

**BI implication.** Assignment history, transitions and agreed outcome codes support workload and process analysis. Raw closure counts are not a fair staff performance measure without case complexity, staffing and service-quality context. Keep institutional trend views separate from operational case detail.

### R8. Offline report creation and synchronisation

**Current position.** Editing can continue in memory during an existing session and a network failure can be retried. Closing/killing the process loses drafts, attachments and pending-operation state. The preserved older client used a plain SQLite payload queue; that does not satisfy secure local storage merely by being persistent.

**Work to complete.** Select and validate encrypted local database/file storage on Android with keys protected by platform facilities. Persist account-scoped drafts, event records, attachment copies and operation state. Define what sign-out locks or deletes, secure-key loss, uninstall/backup behaviour and storage-full recovery. Build a persistent outbox: an authorised intention to submit, its exact payload/key, upload progress and server IDs. Resume after reconnection and process death, with bounded retries, backoff, conflict handling and same-account reauthentication. Decide whether recovery initially runs in the foreground; background execution requires additional device testing. Connectivity alone must not submit an ordinary private draft that the user never chose to send.

**External requirements.** Representative physical Android devices and network conditions; an approved local-data policy; storage/key-management expertise; agreement on local retention and recovery limits. No separate cloud “sync product” is required: this can be implemented against the existing API.

**Completion evidence.** Create a draft with files offline, kill/reopen the app, recover it, explicitly queue submission, reconnect and receive exactly one server case. Repeat with token expiry, lost success responses, account switching, revoked access and full storage. Inspect device storage and backups for unintended plaintext copies.

**BI implication.** Retries and reconnects are operations, not new reports. Separate client operation IDs from report IDs. Measure sync success and delay only for authorised queued submissions. Do not upload private draft content or instrument every draft action merely to build a conversion funnel.

### R9. Secure notifications

**Current position.** Officer status changes generate neutral in-app notices. The client explicitly refreshes and can mark a notice read. Push delivery, device registration and SMS are not implemented. Notifications currently have no case relationship exposed to the client, which directs the user to their records rather than a specific case.

**Work to complete.** Define notification categories, recipient preferences and safe wording. Add an access-controlled case relationship if direct navigation is required. Keep notification creation transactional with the triggering case change. For push, add device-token registration/rotation/revocation, a durable delivery queue, retries and provider-result handling. If SMS fallback is chosen, define eligible events, verified numbers, consent/preferences and when fallback is appropriate. A push provider accepting a message does not prove that a student received or read it; a missing push acknowledgement alone is not proof that SMS is safe or necessary. Test lock-screen previews, logged-out navigation and shared-device behaviour.

**External requirements.** Push-service project/credentials and a responsible operator; SMS provider/sender setup and recurring usage budget if SMS is approved; institution-approved messages and contact preferences. These are channels to procure/configure, not providers selected by this document.

**Completion evidence.** Each case event creates one logical notice; delivery retries do not create duplicate logical notices. Expired device tokens are handled. Restricted details appear only after authentication and authorisation. In-app read, provider accepted and confirmed delivery remain distinct states.

**BI implication.** Measure delivery pipeline reliability with explicit denominators. Label read rates as in-app interaction rates, not proof of understanding, availability or wellbeing. Do not use phone numbers or device tokens as general BI dimensions.

### R10. Basic pattern detection for recurring reports

**Current position.** The rule counts distinct non-null authenticated reporter IDs for an exact staff-reference string over 90 days, based on submission time with a legacy creation-time fallback. It triggers at three distinct accounts and reuses an unreviewed alert. Drafts/anonymous reports do not contribute. Evaluation is triggered by application actions; there is no scheduled freshness pass. An existing alert can remain open after its count drops, and review alone does not specify whether unchanged underlying reports may create a new alert later.

**Work to complete.** Agree and version the rule, including its threshold, window, eligible records and meaning of independence. Introduce a controlled subject reference or reviewed matching process; separate unknown subjects and avoid automatically merging similar names. Store the contributing report IDs, rule version, evaluation time and reviewer decision for each alert. Define refresh, expiry, changed evidence, reviewed-alert recurrence and dismissal behaviour. Add scheduled evaluation if counts are presented as current. Test duplicate accounts, repeated reports from one account, spelling differences, window boundaries, closed cases and concurrent evaluations. Evaluate with institution-approved synthetic scenarios and later appropriately authorised review data.

**External requirements.** A trusted subject directory or accountable matching owner; case-review expertise to approve the rule and respond to alerts; a defined review queue and response responsibility. No machine-learning service is required for this original basic rule.

**Completion evidence.** Explain every alert using its qualifying records and rule version; one person's repeated submissions do not inflate independence; name collisions do not combine unrelated subjects; reviewed/expired alerts behave as agreed. An authorised reviewer can record and audit the action taken.

**BI implication.** This is a restricted decision-support signal, not proof of misconduct, an individual risk score or an automatic sanction. Account uniqueness is only a proxy for reporter independence. Keep case-identifiable alerts separate from aggregate institutional analytics. Alert count is not a misconduct-prevalence measure.

### R11. Support resources

**Current position.** General support guidance exists. The university contact directory is deliberately unpopulated because contacts and availability have not been verified.

**Work to complete.** Add a maintained directory with service type, verified contact route, availability, eligibility, cost where relevant, confidentiality explanation and last-reviewed date. Make appropriate support information reachable without starting a report. Define an offline cache and stale-content behaviour. Test contact actions on Android. Keep emergency wording accurate to the service actually offered.

**External requirements.** Counselling/student-support contacts, service-owner consent to publish details, a content editor and a recurring verification process. External mapping is optional if a useful address/directions cannot be provided more simply.

**Completion evidence.** Each listed service is verified by its owner; unavailable or outdated details are identifiable and corrected through an assigned process. A student can find support without submitting an allegation.

**BI implication.** A clicked contact link is not proof that support was received. Any referral-completion measurement requires a separately agreed process and minimum necessary data; it should not expose counselling attendance in ordinary case analytics.

### R12. Infrastructure, security and operation

**Current position.** A local runner provisions PostgreSQL, applies migrations and seeds fictional users. Android and web builds have succeeded. This is development infrastructure; production hosting, storage operation, recovery and device acceptance are not established by those builds.

**Work to complete.** Establish separate development/test/pilot environments, API/domain/TLS configuration, managed secrets, database and object-store access boundaries, backups and a demonstrated restore procedure. Define data retention/deletion across the application, files, backups, logs and analytical copies. Add monitoring with redacted logs, operational alerts, rate limits, job scheduling, quotas, upgrade/rollback procedures and CI checks. Create an owned release/signing process for Android. Test real devices, accessibility, low bandwidth, lifecycle and failure recovery. Arrange a security review before real-case use and implement its agreed findings.

**External requirements.** Hosting and storage capacity; domain/certificate administration; service operators; repository/build access; backup location and encryption-key responsibility; a support/incident contact; representative devices and participating testers. Budget for ongoing operation, not only initial deployment.

**Completion evidence.** A fresh environment can be deployed from documented steps; a backup can restore both cases and matching evidence objects; a failed release can be rolled back; outages are noticed and owned. Approved users can complete the full workflow over the intended network on the presentation/pilot device.

**BI implication.** Define who operates data refresh, verifies counts and responds to failures. Restore/deletion procedures must cover analytical copies too. Mark last successful refresh; stale dashboards must not appear current.

### R13. Authorised administrative insights and reporting

**Current position.** There are operational report records, current statuses, audit events and pattern alerts. There is no general analytics data model, metric catalogue, audience-specific reporting service or reporting dashboard. Original section 7 explicitly includes authorised administrative insights and reports/analytics, so this work belongs to the original direction even though section 10 lists pattern detection separately.

**Work to complete.** Start by agreeing decisions the institution wants to make, then define measures and minimum data needed. Establish consistent categories, case events and data-quality checks. Implement permission-controlled aggregate queries/views and, when justified by scale, a separate analytical store or read replica. Add an approved reporting interface, export controls, freshness indicators and reconciliation against source cases. Protect small groups and prevent filters/exports from undermining those protections. Pilot each metric with its actual decision owner.

**External requirements.** A reporting sponsor, metric owners, a data steward and reviewers who approve audiences and disclosure rules. A dedicated paid BI platform is not a prerequisite for the first useful dashboard. Tool procurement can follow actual requirements for scheduled reports, access management and scale.

**Completion evidence.** Each displayed value has a definition, source, period, owner and access rule; test data reproduces the expected number; authorised viewers see useful aggregates without inappropriate case detail; reports lead to an agreed operational decision rather than unsupported conclusions.

**BI implication.** The detail in section 5 below is the proposed starting design, not an implemented analytics service.

## 4. External dependency register

The project needs both services and people. An endpoint can be implemented by developers; an institutional responsibility or definition cannot be supplied by code.

| Dependency | Enables | Who should supply/own it | Needed for fictional prototype | Additional pilot decision |
|---|---|---|---|---|
| Student eligibility and staff role source | R1, R5, R7 | University IT and authorised role administrator | Representative test accounts/onboarding fixture | Real eligibility, account removal and role approval |
| Reporting and disclosure policy | R2, R5–R7 | Case-management and institutional policy owners | Documented scenario and role matrix | Approved handling, identity disclosure and escalation |
| Subject directory and category dictionary | R2, R10, R13 | Data steward and relevant institutional office | Synthetic stable IDs and agreed test categories | Authoritative updates, ambiguous matches, correction ownership |
| Support directory | R11 | Counselling/student-support service owners | Clearly labelled verified or fictional demonstration data | Valid contacts, hours, periodic review |
| API hosting, domain and TLS | R1–R13 networked features | University IT or appointed operator | Local service/controlled test environment | Availability, access, updates, location and capacity |
| PostgreSQL hosting and backup | Core records and BI | Database operator | Local PostgreSQL and restore exercise | Recovery targets, monitoring, backup access and retention |
| Private object storage | R3, R8 | Storage/security operator | Operated test bucket with real upload checks | Capacity, encryption/key ownership, retrieval and retention |
| Quarantine/scanning capability | R3 pilot handling | Security/storage operator | Explicit test behaviour; no claim of unimplemented scanning | File-risk policy and operated scanning workflow |
| Email delivery | R1 if email-based onboarding/recovery | Identity/service operator | Test mailbox or controlled mail fixture | Sender identity, abuse handling and delivery operation |
| Push delivery | R9 | Application/service operator | Test project and test devices if demonstrated | Credentials, device lifecycle and delivery monitoring |
| SMS channel | R9 if retained | Service operator and institutional sponsor | Controlled test integration if in demonstration scope | Sender setup, verified contacts, preference rules and cost |
| Devices, testers and accessibility feedback | All mobile journeys | Team and agreed user representatives | At least the actual demo device and failure scenarios | Representative users/devices and acceptance process |
| Case officers and referral services | R7, R11 | Institution | People assigned to fictional demo roles | Training, staffing, service hours and escalation coverage |
| Analytics definitions and disclosure review | R10, R13 | Reporting sponsor and data steward | Synthetic metrics and agreed calculation rules | Audience limits, small-group rules and publication approval |

Exact providers, prices, jurisdiction-specific obligations and service commitments have not been researched or selected in this document. Hosting location, recording guidance, retention and identity disclosure remain decisions for the appropriate institutional reviewers.

Budget categories to estimate later: API/database compute, evidence storage and transfer, backups, email/SMS delivery, security monitoring/review, release administration and staff support. Evidence volume and retention drive storage cost; SMS volume drives per-message cost; neither can be estimated responsibly from the repository alone.

## 5. Business intelligence in practical terms

### 5.1 What BI is intended to help decide

In this project, BI means turning governed operational records into information that helps authorised people allocate support, understand workload and improve the reporting process. Useful starting questions include:

- Are submitted reports being acknowledged within the institution's agreed target?
- Where is the case-handling backlog growing, and how old is it?
- Are upload or connectivity problems preventing intended submissions?
- Is staffing/case allocation keeping up with incoming work?
- Are recurring-report alerts receiving human review?

Reporting volume cannot reveal the true incidence of harassment on its own. An increase could reflect more incidents, greater trust, awareness campaigns, easier access or changes in definitions. The application does not observe people who never report. Population rates would require an authoritative denominator and careful interpretation; they are not automatically available from account or report counts.

### 5.2 Separate three audiences

| View | Audience | Appropriate content |
|---|---|---|
| Operational case dashboard | Authorised case handlers | Permitted case-level facts, evidence and actions needed for assigned work |
| Institutional service analytics | Approved managers/data analysts | Aggregate volumes, backlog, turnaround and reliability with disclosure controls |
| Recurring-report review queue | Specifically authorised reviewers | Restricted alerts and supporting report references; human review required |

Combining these into a single unrestricted dashboard would expose more sensitive information than most analytical decisions require. Giving an analyst a pseudonymous ID does not automatically make detailed case rows anonymous.

### 5.3 Candidate metrics and whether the current data supports them

These are proposals for institutional agreement, not targets or implemented dashboards.

| Measure | Proposed definition | Current source position | What must be settled/added |
|---|---|---|---|
| Submitted report intake | Count distinct report IDs with `submitted_at` in the reporting period; exclude drafts | Submission timestamp exists; aggregate endpoint/view absent | Period/timezone, legacy-null policy and exclusion of fictional/test records |
| Current backlog | Count submitted reports in agreed open statuses at snapshot time | Current status exists | Which statuses count as open; snapshots if historical backlog is needed |
| Backlog age | Snapshot time minus submission time for each open case; report distribution/age bands | Submission and current status exist | Time basis and age bands; unknown timestamps handled explicitly |
| Time to first acknowledgement | First transition to the agreed acknowledged state minus submission time | Some transitions recorded in audit logs; no dedicated history contract | Validate audit coverage, establish durable events and define working vs elapsed time |
| Time to closure | Agreed closure time minus submission time | Current status alone is insufficient; audit may help after validation | Closure event, reasons, reopened-case handling and cohort definition |
| Acknowledgement target attainment | Eligible reports acknowledged within target divided by the defined eligible cohort | No approved target/cohort or reporting model | Avoid excluding overdue unacknowledged cases; define cutoff and pending cases |
| Officer workload | Open assigned cases per authorised officer/team | Assignment field exists; workflow/history incomplete | Assignment lifecycle, transfers and workload interpretation |
| Evidence upload success | Distinct successful verified upload operations divided by distinct initiated upload operations in a defined cohort | Upload lifecycle unfinished | Operation IDs, terminal outcomes, retry deduplication and pending treatment |
| Submission/sync reliability | Confirmed submission operations divided by authorised attempted submission operations | Server confirmations exist; durable client operation records absent | Consented/minimal telemetry, failure states, offline visibility and observation window |
| Notification reliability | Channel delivery outcomes divided by eligible delivery attempts, separately from logical notifications | In-app creation/read times exist; external delivery records absent | Provider semantics, retries, unavailable receipts and channel denominators |
| Alert review turnaround | Review time minus alert creation time for reviewed alerts, alongside age/count of unreviewed alerts | Creation/review timestamps exist | Stable recurrence rules, rule version and reviewer workflow |
| Data completeness | Share of eligible records with agreed required structured fields | Few structured reporting fields exist | Required vs optional/unknown definitions; missing data is not zero |

Use medians and useful distributions rather than only averages where delays are skewed. Do not compare only closed cases and ignore cases that remain open. Do not compare departments or officers without checking differences in workload, reporting practices and available context. Keep case outcomes separate from operational completion measures.

### 5.4 Data foundations needed before richer BI

1. **A metric dictionary.** For each metric, record the decision it serves, precise calculation, unit, exclusions, time basis, refresh frequency, audience and owner.
2. **Stable operational identifiers.** Distinguish account, report, incident event, submission operation, evidence object, notification and alert. Joining these tables naïvely can multiply counts; for example, a report with three events and two files is still one report.
3. **Structured definitions.** Agree category codes, statuses, closure reasons, subject-reference matching and optional organisational dimensions. The current report model has free-text subject/course references and no full reporting-category taxonomy. Do not invent demographic fields just to make charts more detailed.
4. **Reliable event history.** Record important transitions and distinguish occurred time, recorded time, submitted time, notified time and reviewed time. Preserve timezone and uncertainty where relevant.
5. **Data lineage and quality.** Trace an aggregate to its permitted source records and transformation version. Check duplicates, missing timestamps, invalid transitions and stale updates. Historical records without a field must not be given fabricated values during migration.
6. **Controlled analytical access.** Start with approved aggregate views/endpoints. For a small prototype, a separate warehouse is not necessary. Add a read replica or analytical store when query load, governance or reporting needs justify it. Never expose privileged production credentials directly in a desktop dashboard file.
7. **Separation of test data.** Use isolated fictional environments or an explicit environment/data classification. Never mix seeded demonstration reports into real institutional indicators.
8. **Disclosure and retention rules.** Determine who can export, how small groups are protected and how deletion/restriction propagates into analytical copies. A filter or a series of overlapping reports must not defeat small-group protections.

A practical flow is: authorised application events → validated operational records → restricted reporting views/transformations → audience-specific aggregates → reviewed decisions. Raw evidence and narrative text do not need to enter that flow for the initial service metrics.

### 5.5 Minimum useful BI delivery

Begin with a small fictional-data dashboard showing submitted intake, current backlog, backlog age, status distribution and alert-review ageing. Label reporting period, timezone, last refresh and known missing data. Add acknowledgement and closure measures only after event definitions and history are reliable. Add upload/sync and external-notification measures after those lifecycles exist.

Before approval, compare every metric with hand-calculated synthetic examples, including duplicate retries, multiple events/files per report, incomplete dates, unclosed cases, reviewed/reopened alerts and empty cohorts. Empty or unavailable measures should display “not available” or an explained empty state, not a misleading zero.

Business intelligence is therefore a modest interface but a meaningful data-and-process requirement. Much of its foundation belongs in the ordinary reporting, case-handling and notification work rather than being added only at the end.

## 6. Suggested order and decision gates

This sequence is a proposal for the next work plan, not work already approved or implemented by this document.

| Stage | Work to agree/deliver | Exit condition |
|---|---|---|
| A. Definitions and ownership | Identity route, role matrix, disclosure policy, statuses, intake categories, support contacts and metric definitions | Named owners and an agreed fictional scenario; unresolved promises remain gated |
| B. Complete durable reporting | R2/R4/R8: protected local drafts, event editing, persistent submission operations and recovery | Offline draft and files survive restart; explicit sync creates one case |
| C. Complete evidence | R3 with storage, verification, retrieval and cleanup | Student attaches verified evidence; authorised officer retrieves the same bytes |
| D. Complete coordinated handling | R5–R7/R10: access rules, assignment, status history, alert review and student follow-up | Full role-aware scenario from intake to agreed closure is repeatable |
| E. Complete access/support/delivery | R1/R9/R11: onboarding/recovery, verified resources and required notification channels | Intended users can gain access and receive safe, usable updates |
| F. Demonstrate original prototype | Rehearse the section 10 journey with real services and fictional data | Report, evidence, timeline, offline recovery, officer handling, notifications and alert review all have recorded acceptance evidence |
| G. Add governed BI and pilot operations | R12/R13: aggregates, deployment, restore rehearsal, monitoring, reviews and staff operation | Approved audiences can trust metrics and the institution can operate a limited pilot |

Definitions, event history and data quality must begin in stage A and continue through B–E; stage G is not a reason to postpone them. Some engineering work can overlap after contracts are settled. Push/SMS scope should be explicitly agreed because the original architecture mentions them, while the current milestone implements only in-app updates.

## 7. Decisions needed from people outside development

| Decision to obtain | Why it blocks completion | Suggested decision owner |
|---|---|---|
| How students prove eligibility and recover access | Determines R1 workflows and integrations | University IT/identity owner |
| Who sees identity and who handles a report | Determines R5 authorisation and user promises | Institutional policy and case-management leads |
| Meaning of receipt, review, action required, closure and any targets | Determines R6/R7 workflows and BI calculations | Case-management lead |
| How named/unknown subjects are matched | Determines pattern correctness and privacy risks | Directory/data steward and authorised reviewers |
| Reporting categories and permitted analytical audiences | Determines useful structured data and exports | Reporting sponsor/data steward |
| Evidence, local-draft, backup and analytics retention | Determines storage/deletion design and costs | Institutional data owners with relevant reviewers |
| Which support contacts can be published | Determines whether R11 is usable | Support service owners |
| Which notices use push or SMS and under what preferences | Determines delivery work, exposure and recurring costs | Service owner and institutional sponsor |
| Hosting/operator responsibility and recovery expectations | Determines whether the system can be maintained | IT operations/sponsor |
| Who signs off acceptance with actual devices/users | Determines whether completion has been demonstrated | Project owner and designated user representatives |

The immediate next step is to turn agreed items into work packages with an owner, dependency and acceptance evidence. This document intentionally leaves application behaviour unchanged.
