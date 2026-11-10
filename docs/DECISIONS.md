# HERVOICE — scope and stakeholder decisions

Consolidated 10 November 2026. This is the current answer sheet for the product
owner and stakeholders. It carries forward D01–D16 from the archived Word workbook
without carrying forward its outdated implementation snapshot.

Current behaviour is in [Description](DESCRIPTION.md), technical actions in
[Deployment](DEPLOYMENT.md), and acceptance in [Release checklist](RELEASE_CHECKLIST.md).
An unanswered item remains open; it is not approval.

## Agreements already reflected in the app

- Email-code registration and recovery, with no email-domain restriction.
  Verification establishes mailbox control, not university affiliation.
- Encrypted Android drafts retained after sign-out and reopened by the same
  account, on the same device and API URL.
- Account identity hidden from normal officer case responses; authorised
  administrators have a reason-recorded, audited reveal action.
- Android push code is implemented; no Firebase project/credential acceptance
  is established. In-app updates work independently.
- Support contains published Makerere contacts. Institutional content ownership,
  availability/hours and formal operational endorsement are still to confirm.
- HERVOICE does not automatically send reports to MakSafeSpace or complete
  Makerere's official complaint process.

## Decisions to answer

For each item, replace the blank answer with a concrete decision, named owner,
target date and evidence/policy reference. The positions below are proposals
unless listed as agreements above. A small fictional-data demo can record
explicit deferrals; a real-report pilot needs approved handling and operation.

### D01 Who is v1 for and how will it be released

Proposed position: Start with a controlled pilot in one agreed institution or cohort. Record pilot size, Android versions, languages, distribution channel, support hours and completion criteria.

Decision owner: Product owner and institutional sponsor

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

### D02 Who may register and who verifies eligibility

Proposed position: Retain unrestricted email domains unless formally changed. Email verification proves control of an address, not university affiliation. Decide invitation, eligibility checks, duplicate accounts and treatment of former students.

Decision owner: Institutional owner and product owner

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

### D03 Who creates and removes staff access

Proposed position: Staff roles are granted through an accountable administrative process. Define approver, onboarding, conflicts of interest, deactivation, emergency access and periodic review. Decide staff MFA or institutional sign-in requirements before hosting.

Decision owner: Case handling lead and IT owner

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

### D04 How should sessions and recovery behave

Proposed position: Keep passwords out of device storage. Decide session duration, whether users sign in after each restart, device loss handling and whether persistent sessions or offline unlock are actually required for v1.

Decision owner: Product owner and security reviewer

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

### D05 What can a student submit and change

Proposed position: Specify mandatory fields, uncertain dates, unknown subjects, multiple events and permitted evidence types. Decide whether post-submission corrections are append-only amendments, and how withdrawal affects institutional records.

Decision owner: Case handling lead

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

### D06 What does confidential mean in this service

Proposed position: Describe the existing account-linked model plainly: officers do not see account email, authorised administrators may reveal it with an audited reason, and narrative or file metadata may identify the reporter. Decide whether truly anonymous intake is a separate future service. Reconcile HERVOICE access controls with Makerere’s published formal-investigation disclosure requirements; restricted officer access is not a promise of anonymity through the institutional process.

Decision owner: Institutional privacy owner

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

### D07 What access and retention rules apply

Proposed position: Approve who can see each case, attachment, identity reveal, audit record and export. Decide retention, deletion holds, account closure, backups, local drafts and incident response. Obtain applicable institutional/legal review rather than inferring policy from the implementation.

Decision owner: Institutional privacy owner and case handling lead

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

### D08 What is the evidence handling process

Proposed position: Agree size/count limits, accepted formats, scanning and quarantine, unsafe-file handling, metadata advice, download permissions and storage quotas. Decide if v1 blocks uploads until scanning is available or launches with an explicitly approved narrower evidence scope.

Decision owner: Case handling lead and IT owner

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

### D09 Who owns a case and what can they do

Proposed position: Define assignment, reassignment, escalation, private notes, referrals and conflicts of interest. Current role checks allow officers to access submitted cases broadly; assignment restrictions require implementation across list, detail, download and status routes.

Decision owner: Case handling lead

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

### D10 What do the statuses promise

Proposed position: Approve Submitted, Received, Under review, Action required and Closed definitions. Define response targets, student follow-up instructions, closure outcomes and reopening. Current Action required sends a generic update and does not deliver specific next steps.

Decision owner: Case handling lead and communications owner

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

### D11 What wording must students and staff see

Proposed position: Approve welcome, consent, identity notice, local draft/recovery notice, submit confirmation, errors, notification previews and support text. Use confidential rather than anonymous for account-linked reporting. Avoid promises of guaranteed safety, immediate response, or delivery that the system cannot demonstrate.

Decision owner: Communications and privacy owners

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

### D12 Who maintains support information

Proposed position: Confirm the published Makerere contacts, appoint their content owner, supply service hours and review dates, and approve emergency/referral boundaries. Reporting is not an emergency response channel.

Decision owner: Student support lead

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

### D13 How should recurring reports be reviewed

Proposed position: Approve or amend the present three-account and 90-day rule. Define controlled subject references, explainable matching, recurrence, alert review decisions and expiry. Alerts must never automatically determine an allegation outcome.

Decision owner: Case handling lead

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

### D14 Which notifications belong in v1

Proposed position: Include neutral in-app updates and configured Android push if accepted in testing. Define opt-in, disabled permission behaviour, stale devices, failed delivery handling and permitted wording. Do not equate provider acceptance with phone delivery.

Decision owner: Product owner and communications owner

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

### D15 Which aggregate measures are authorised

Proposed position: Start with report counts and time to acknowledgement/status progression. Define cohort, timezone, denominators, missing data, small-group suppression and access. Keep identity, narrative and attachment content outside general BI. Distinguish reporting volume from incident prevalence.

Decision owner: Institutional reporting owner

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

### D16 Who funds and operates the service

Proposed position: Name account owners for hosting, domain, database, storage, email, Firebase and Android signing. Agree budget including backups, logs, egress, email and maintenance. Record data location, outage contact, vendor access and handover arrangements. No vendor or cost is committed by this workbook.

Decision owner: Sponsor and IT owner

**Answer:** Pending. **Accountable person:** Pending. **Target date:** Pending. **Evidence:** Pending.

## Business intelligence: initial scope to agree

Use service measures to support staffing and process decisions. Reporting volume
does not measure the prevalence of harassment. Start with aggregate intake,
current backlog, backlog age, status distribution and alert-review ageing;
acknowledgement/closure turnaround needs agreed event and cohort definitions.

Before building a BI view, agree its audience, metric formula, timezone,
denominator, exclusions, treatment of missing/legacy data, refresh time, small-group
protection and export permissions. Do not send narratives, attachments or identity
data into general analytics. Distinguish distinct reports, reporting accounts and
people; joining multiple files or events must not multiply report counts.

Current officer summaries serve operational use. A governed analytics model,
approved exports, canonical subject matching and richer institutional dashboards
remain outside that implementation. The full original R1–R13 and BI comparison is
preserved in the [archive](archive/2026-11-10/REQUIREMENTS_COMPLETION_AND_BI.md).

## Agree the deployment boundary

| Stage | Required outcome |
| --- | --- |
| Fictional-data hosted demo | HTTPS API, private test database/evidence, working SMTP, test accounts, reviewed build and a repeatable phone/admin journey. Optional push exclusion is recorded. |
| Controlled real-report pilot | Above plus approved case-handling/disclosure/retention, trained staff, signed distribution, representative device/browser acceptance, monitoring and restore-tested operation. |
| Wider v1 rollout | Approved cohort/capacity targets, measured performance, supported upgrades, handover and a review of the pilot's issues and residual risk. |

Small scale lowers volume; it does not define identity permissions or provide an
operational complaint-handling team. Do not infer those from a successful build.

## Approval record

| Responsibility | Named person / decision / date |
| --- | --- |
| Product/scope and pilot population | Pending |
| Institutional sponsor and case-handling lead | Pending |
| Privacy/disclosure and retention owner | Pending |
| Support/contact-content owner | Pending |
| Technical/release and signing owner | Pending |
| Hosting, database/storage, mail and on-call owner | Pending |
| Budget and provider-account owner | Pending |
| Acceptance and post-launch review owner | Pending |

For an agreed gap, record outcome, related decision ID, affected files, acceptance
check, owner and dependency before estimating work. Do not treat this answer sheet
as an instruction to implement every proposed feature.

## Historical workbook

The original [Word workbook](archive/2026-11-10/v1-planning/HERVOICE_V1_Readiness_and_Decisions.docx)
is retained unchanged for provenance. It predates later code, deployment and UI
corrections; its claims that some implemented controls are still missing are not
the current baseline.
