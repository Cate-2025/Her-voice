# HERVOICE

<!-- impeccable:product-schema 1 -->

## Platform

android

The primary student product is the Android Flutter app in `flutter_app/`.
This product record also covers the officer/administrator web dashboard in
`backend/app/static/admin/`; use web conventions and browser verification for
that interface. The Flutter web target is a secondary preview/testing surface,
not a separate delivery commitment. This is not an iOS or adaptive-platform
commitment.

## Users

- University students who need to document sexual harassment, decide what to
  submit, revisit their records, follow case progress, and find support guidance.
- Authorised university officers and administrators who review submitted
  reports, record progress, and coordinate case handling through the web dashboard.

The user confirmed that both active interfaces belong in this record.

## Product Purpose

HERVOICE is a mobile reporting and support-coordination platform for sexual
harassment in universities. It connects student-controlled incident recording
and explicit report submission with a staff case workspace and student updates.

Successful use means students can understand what they are sharing, preserve
their work, submit deliberately, and follow recorded progress. Staff can review
reports and communicate status through the authorised workflow. A report records
an allegation; it is not a finding of misconduct.

## Positioning

The documented mechanism connects personal incident drafts, optional evidence,
review and confirmation, submitted case history, and a university staff workspace.
No comparative superiority, guaranteed outcome, or independently validated
security claim has been established.

## Operating Context

- Student journey: access an account, start or resume an incident draft, add
  details and optional evidence, review, explicitly confirm submission, then
  revisit records and updates. Support guidance is also available.
- Staff journey: sign into the browser case workspace, filter the case queue,
  review case details and recurring-report alerts, and confirm status changes.
- The active stack is Flutter with FastAPI and PostgreSQL. The API also serves
  the web dashboard at `/admin/`. Hosted evidence uses private S3-compatible
  storage; email and optional Android push depend on external providers.
- `mobile/` and `legacy/main/` are historical references, not competing active
  implementations. Follow the current root README and deployment/project map
  before older preview documentation.
- Current demonstrations must use fictional incident details and accounts.

## Capabilities and Constraints

- Connected and disconnected-preview modes are distinct. Connected mode uses
  the API; the explicit `HERVOICE_DEMO=true` preview simulates actions with
  fictional in-memory data. Copy must describe the active mode accurately.
- Android drafts and evidence have encrypted local persistence scoped to the
  same account and API URL. Sign-in sessions are memory-only. Submitted reports
  persist on the server. Do not imply that every target has Android persistence.
- Students review and confirm before submission. Saving a local draft is not
  submitting a report; uncertain or pending submissions must retain honest
  recovery/retry messaging.
- Role/owner access checks and controlled identity access are implemented.
  Officer views exclude student account identity, but narratives may still
  identify a person. Do not describe this as truly anonymous reporting.
- Notifications must stay neutral and avoid disclosing incident details.
- Evidence transfer, email-code access/recovery, and configurable Android push
  have implementations; provider, hosting, device, and accessibility acceptance
  must be distinguished from code or automated-test completion.
- Automatic background synchronisation, truly anonymous intake, SMS, and
  policy-dependent case handling are not completed product capabilities.
- Open institutional decisions include assignment/access scope, disclosure
  policy, retention periods, status meanings, approved wording, and support
  contacts. Preserve current behaviour until those decisions are approved; do
  not resolve them through UI copy or design assumptions.
- Deployment readiness, provider acceptance, and production security must not
  be inferred from the existence of deployment files or passing local tests.

## Brand Commitments

Preserve the HERVOICE name and existing product assets. Use direct, respectful,
nonjudgmental language that supports student control. Explain sharing, access,
storage, status, and failure states accurately, without promises of guaranteed
confidentiality, anonymity, response times, or outcomes.

The user confirmed student control over submission, restricted access to
sensitive information, neutral notifications, fictional demo data, and no
invented institutional contacts or unverified security claims as constraints.
This initialization establishes no new visual direction.

## Evidence on Hand

- `docs/DESCRIPTION.md`: current product behaviour, component map and dated verification.
- `docs/DEPLOYMENT.md`: hosting, providers, signing and operations.
- `docs/DEVELOPMENT.md`: local startup, Android Studio and code/recovery responsibilities.
- `docs/RELEASE_CHECKLIST.md`: device/provider/host acceptance record.
- `docs/DECISIONS.md`: current stakeholder D01–D16 answer sheet; unapproved decisions remain open.
- `docs/reference/API_CONTRACT.md` and `docs/openapi.json`: technical contract.
- `docs/archive/2026-11-10/`: earlier comparisons, dated progress and UI audits,
  original Word workbook, widget renders and old preview notes. They do not
  establish current hosted or physical-device acceptance.
- `flutter_app/assets/fonts/`, `flutter_app/web/icon.svg`, and Android vector
  resources: existing local, licensed fonts and product marks.
- Makerere contact sources were checked online on 10 November 2026 and are listed
  in Support and Description. Published contact information does not establish
  institutional endorsement, office hours or HERVOICE integration with MakSafeSpace.
- Do not fabricate testimonials, endorsements, outcome statistics or response guarantees.
