> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../README.md).

# Dashboard UI audit and corrections

3 November 2026. Applied `audit-ai-design-slop` using the installed SKILL.md and the user-provided `/home/emmaa/Downloads/ARTICLE.md`. Implementation was explicitly requested by the user. Scope: browser officer/admin dashboard and Flutter student home dashboard. Existing palette, type families, workflow and access controls remain the design constraints.

## Verdict

Repeated introductory copy and containers were competing with the actual work. The largest correction is bringing the student’s report action and records forward by removing the oversized promotional panel and repeated reassurance blocks. Admin changes reduce nested card framing and clarify labels; they do not redesign case handling.

## Checked scope

- Flutter home, theme, shared components and shell source; admin HTML, CSS and JavaScript.
- Relevant article sections: composition (2), containers (3), typography (4), states (7), copy (9), quality (10).
- Flutter renders with fictional demo content at 390 and 1440 pixels wide. Loaded Lora, Manrope and MaterialIcons for visual inspection. These are widget renders, not live phone screenshots.
- Existing automated layout coverage at 390/1440 pixels and 320 pixels with enlarged text; home state/navigation tests and admin confirmation/session tests.

## Findings and changes

| Priority | Class | Pattern / evidence before correction | Harm | Correction |
| --- | --- | --- | --- | --- |
| P1 | Quality defect | `home_screen.dart`: draft footer said “Not submitted · this app session” for every device, including durable Android drafts and pending submissions. | Misstates retention and may imply a report never reached the server. | Show durable/session retention according to the store; pending operations instead ask the student to check/retry the saved submission. |
| P1 | Slop pattern | Home stacked “A little space for you”, “Welcome to your space”, “WHEN YOU FEEL READY”, “Your experience matters”, a large petal panel, three reassurance labels, and “Before you begin”. | Repeats the same reassurance and pushes actionable records down the page. | Replace with a direct dashboard heading, one report action and one explanation of save/review/confirm. Remove the decorative petal layer and repeated labels. |
| P1 | Quality defect | Home rendered the records heading but no explanation when both cases and drafts were empty. | New students cannot distinguish an empty account from missing UI. | Explain where drafts/reports will appear. Existing connected loading/errors remain in the shell. |
| P2 | Slop pattern | Admin `.summary>div`, `.panel`, `.case` and `.alert` each framed adjacent content as independent rounded cards. Home likewise framed every report/support paragraph. | Repeated surfaces flatten grouping and selected-state emphasis. | Summary becomes a divided strip; queue becomes rows within its panel; alerts and student reports use separators; support uses ordinary heading/text/link. Keep a draft card as a distinct resumable action, and keep selected-case fill/rail and status pills. |
| P2 | Quality defect | Admin total label “Submitted reports” included received, under-review, action-required and closed cases. | Label can be mistaken for the submitted status count. | Rename it “All reports”; keep “Awaiting receipt” as the submitted-status metric. Counts still derive from API data. |
| P2 | Quality defect | Admin details referenced `detail-heading`, which is absent during loading/error states. Queue focus could be clipped at a scrolling edge; download labels had no long-name wrapping constraint. | Unstable accessible section name and possible loss of focus/long-file readability. | Use stable “Case details” section label, reserve queue focus space, constrain/wrap long download labels and detail titles. Browser acceptance is still required. |

## Article observations and unknowns

Observed: repeated container framing, decorative/duplicated introductory copy, tiny functional home text and missing/misleading home states. Corrected within the inspected dashboards. Existing serif headings, plum accents and status pills communicate identity/hierarchy/state and were retained. No fabricated metric, animation cluster, gradient/glass stack or fake activity was identified in these dashboard sources; live counts come from loaded API data.

Unknown: live browser rendering, keyboard/screen-reader behaviour in the admin portal, provider/device behaviour and real Android appearance. No enabled browser surface was available. The widget screenshots do not verify those behaviours. The application shell and other Flutter screens were inspected for context but were not redesigned. Pending administrative decisions remain outside this visual pass.

## Validation

63 Flutter tests passed, including four new home-state/navigation checks; one optional live-server test was skipped. Static analysis is clean. Six admin confirmation/session tests passed, JavaScript syntax validation passed, and whitespace checks passed. The admin tests use a stubbed DOM and do not establish browser layout/accessibility acceptance. The desktop APK is not rebuilt by this UI pass; run/rebuild Flutter to view the home changes. Reload the admin portal to fetch the updated static assets.

Reviewed widget previews: [phone](ui-audit/home-phone.png) and [desktop](ui-audit/home-desktop.png). The fictional preview displays session-only storage intentionally; the durable-device and pending-submission wording is covered separately by tests.

The highest-impact correction is removing the repeated promotional home introduction so the report action and actual records are reached sooner.

---

## Officer web flow — Impeccable audit, 10 November 2026

This section records the pre-correction officer-web assessment; see the correction pass at the end for its latest implementation and verification status. The earlier section records the 3 November implementation pass. Used `.github/skills/impeccable/SKILL.md`, its web `audit` playbook, `PRODUCT.md` and the complete `DESIGN.md`. The surface is **web / Operate**, despite the product-level Android platform label. No UI, workflow, design-token or permission changes were made during this audit.

### Scope and evidence

Inspected `backend/app/static/admin/{index.html,styles.css,app.js}`, officer routes/schemas and existing admin tests. Ran Impeccable's source detector, calculated contrast from declared opaque colours, and ran four isolated JavaScript/DOM-stub reproductions. No real accounts or case records were used. Browser access host was unavailable; there are no fresh rendered officer screenshots, viewport/touch checks, screen-reader checks or browser focus observations. Student widget renders are not officer-web evidence.

### Implementation-integrity verdict

**Pass for product-specific visual coherence; incomplete for interaction resilience.** The web's Georgia/system typography, documented web palette, divided queue and explicit status words fit The Open Notebook. The design system mostly records the incumbent implementation; being documented does not make an existing usability defect acceptable. No new palette, font or layout direction is needed to address these findings.

The detector returned **17 colour advisories and zero primary findings**. All 17 were checked: the reported hex/RGB colours are explicitly present in DESIGN.md, including expanded `#fff` = `#FFFFFF`. They are false positives for “outside palette”, not reasons to recolour the site. Many CSS literals are documented but not yet exposed as reusable CSS variables; that is a maintenance opportunity, not demonstrated visual drift. The context loader separately reports the design sidecar stale; it was not repaired as part of this audit.

### Audit health — evidence-limited

| Dimension | Source assessment (0–4) | Evidence / limit |
| --- | --- | --- |
| Accessibility | 2, provisional | Labelled native controls, visible focus styles and live messages exist; field boundary contrast and queue focus lifecycle need correction. Browser acceptance untested. |
| Performance | 2, provisional | Small plain JS/CSS surface; all pages are accumulated and the whole queue rebuilt on selection. No runtime latency/frame benchmark. |
| Theming | 3, provisional | Values match the documented web family. Partial CSS-variable coverage; light scheme is the documented scope, so absence of dark mode is not scored as a defect. |
| Responsive design | Not rated | 900/700px breakpoints and wrapping exist in source. No browser viewport or touch evidence; no claim that mobile/zoom passes. |
| Implementation integrity | 2, provisional | Coherent visual language; reproduced inconsistent filter/selection state, ambiguous case labels and stalled saving behaviour. |
| Total | Withheld | A complete /20 acceptance score would imply evidence not available here. |

### Prioritised findings

**3 P1, 5 P2; no P0 established.** Locations refer to the source inspected on this date.

| Priority / category | Issue and exact evidence | Officer impact | Recommended correction / command |
| --- | --- | --- | --- |
| **P1 — Integrity** | **A stalled request can lock the workspace.** `app.js:28–43` and login/download fetches have no application timeout. `:156–164` sets saving and disables Refresh/Sign out until PATCH settles. A never-settling fixture reproduced the lock. | A network stall can leave the officer waiting without a recovery action; a timed-out mutation may nevertheless have reached the server. | Add bounded requests, actionable feedback and recovery that re-reads the case after an uncertain status update. Do not claim failure or automatically resend a mutation without reconciling state. `/impeccable harden`. |
| **P1 — Accessibility** | **Selection destroys the initiating queue control.** `app.js:78–80` replaces every queue button using `innerHTML`; `:103–104` does this immediately on selection. Confirmation opening/saving/refresh also rebuilds controls (`:158–164`). There is no explicit focus restoration or detail focus destination. | The previously focused DOM node disappears. Keyboard position and dialog return focus can be lost; the resulting browser focus behaviour still needs verification. | Keep keyed/stable queue controls or restore focus deliberately; establish a predictable details destination and post-confirmation focus target. Test Tab/Enter/Escape through repeated selections and confirmation. `/impeccable harden`. |
| **P1 — Accessibility** | **Field boundaries have insufficient declared contrast.** `styles.css:67–74`: `#cfc5d2` border on white is **1.67:1**, and on paper **1.55:1**. White field fill against paper is also below 3:1. | Unfocused inputs/selects are difficult to distinguish for low-vision users. This is a source-level non-text-contrast concern (WCAG 1.4.11), subject to browser-state verification. | Strengthen the existing web field-boundary token, retain focus styling and check actual rendered controls. Update documented token and CSS together when implementing. `/impeccable harden`. |
| **P2 — Integrity** | **Different cases can look identical.** `app.js:14–17,78` displays only date, hour/minute and status in queue rows. Two distinct reports in the same minute produced identical visible title/time labels in the fixture. UUID is hidden in details (`:117`). | Hard to return to or distinguish similar cases, especially before confirming an update. | Keep date-based names; add a stable, readable non-identity discriminator to queue, detail and confirmation. Avoid exposing student identity or reinstating long UUID titles. `/impeccable clarify`. |
| **P2 — Integrity** | **Filtering can leave a hidden case open.** `app.js:74–80` filters only the queue; `selectedId` and the detail panel remain unchanged. An empty “Closed” fixture retained a submitted case in details. | “No reports in this view” can appear alongside an actionable case outside that view. | Explicitly indicate that the open case is outside the filter, or clear selection/details consistently. Apply the same rule after a status transition changes membership. `/impeccable harden`. |
| **P2 — Integrity** | **Loading/error/stale states are not distinct.** `index.html:20` initially shows real-looking zeros. `app.js:87` couples cases and alerts in one Promise.all; any failure prevents both from updating. `:98` shows a global error but leaves old counts/queue. A failed-refresh fixture retained the old total. | Officers cannot tell zero reports from not-yet-loaded data or an old snapshot. An alert outage also blocks a healthy case queue. | Show initial loading rather than zeros, retain-but-label stale data with last successful refresh, and recover queue/alerts independently. Keep confirmed mutation success distinct from a subsequent refresh failure. `/impeccable harden`. |
| **P2 — Integrity** | **Recurring alerts have no usable next step or actual date range.** `app.js:95` renders count, fixed “90-day window” wording and staff reference only. `PatternAlertResponse` includes window_start/window_end; a review endpoint exists at `routers/officer.py:124`, but the UI has no case drill-through or review action. | Officer sees a signal but cannot follow or resolve it in this workspace; “recorded window” cannot be checked from the page. | Show the actual recorded dates and plan a link/filter into relevant cases. Review/acknowledgement semantics and any new staff action require the pending administrative decision; an existing endpoint alone is not approval. `/impeccable shape`. |
| **P2 — Performance** | **Pagination still loads the entire queue.** `app.js:44–58` follows every page into memory; `:78` renders all matches. Backend `officer.py:39` orders by updated_at, which changes as work proceeds. | Work and DOM size grow with the whole dataset; changing records during offset traversal can move page membership. No measured slow-device failure is claimed. | Bound the visible queue with paging/load-more and preserve selection. Design server-side filtering and summary counts together so totals remain honest. Reconcile/deduplicate page membership as appropriate. `/impeccable optimize`. |

### What to preserve

- Real API-derived totals; no fabricated dashboard proof.
- Native buttons/selects/dialog and 44px button minimum height.
- Labelled login fields, visible focus rule, selected-row `aria-pressed` and live feedback.
- Declared muted text on white **5.04:1**, on paper **4.67:1**; focus outline on white **3.68:1**; plum status text on lavender **6.72:1**. Do not indiscriminately darken every secondary label.
- Confirmation, expected-status protection, neutral student notifications and officer identity exclusion. Keep administrative identity reveal separate from ordinary officer tasks.
- Existing typography and surface-specific web colour/status mappings; there is no evidence requiring a replacement design system.

### Verification and next pass

The six existing admin confirmation/session tests passed. Four additional temporary DOM-stub probes reproduced case-label collision, out-of-filter details, old counts after a failed refresh and lock during a non-settling PATCH. These probes establish JavaScript behaviour, not browser focus/layout/accessibility. Detector warnings were manually reconciled with DESIGN.md rather than accepted blindly. No application tests or records outside the officer-web scope were changed.

Recommended order:

1. **P1 — `/impeccable harden`**: bounded request/recovery, stable focus, input boundary contrast, filter/selection consistency and honest loading/error/stale states.
2. **P2 — `/impeccable clarify`**: readable case disambiguation in queue/details/confirmation, preserving privacy and date-based names.
3. **P2 — `/impeccable shape`**: agree the recurring-alert handoff/review flow with stakeholders before adding staff actions.
4. **P2 — `/impeccable optimize`**: visible queue paging plus correctly scoped counts/filtering.
5. **`/impeccable polish`**: browser-check the integrated result at desktop, tablet, narrow width, zoom and keyboard-only use.

These can be run individually or together, apart from policy decisions that remain pending. Re-run `/impeccable audit` after corrections. The current highest-priority change is recoverable network operations with stable focus and clear case context, rather than further decorative cleanup.

### Officer correction pass — 10 November 2026

Implemented the recommended sequence within the existing web design:

- **Harden:** bounded request/body decoding and cancellation, no automatic PATCH resend, fresh detail reads after uncertain updates, explicit loading/stale timestamps, independent queue/summary/alert requests, filter/page selection clearing, stable queue controls on selection, and detail/dialog focus destinations. Requests that fail to reconcile replace the detail editor with a retry explanation.
- **Clarify:** date-based labels include a short existing-code/UUID suffix; full canonical UUID remains in Case reference. The suffix is a convenience label rather than a new separately allocated unique case number. Global totals are explicitly distinguished from filtered page counts.
- **Shape:** read-only alert navigation uses the exact subject reference and recorded window. Show the recorded dates and explain that reports and distinct reporting accounts can differ. No acknowledgement/resolution action was added; its semantics still await administrative feedback.
- **Optimize:** new bounded case/alert page endpoints and a server-calculated global summary replace whole-dataset client traversal. Web pages contain at most 25 records. Queue ordering uses immutable submission time; offsets remain eventually consistent under concurrent membership changes. Existing list endpoints remain available.
- **Polish:** web field boundary token updated in CSS and DESIGN.md (3.90:1 on white, 3.62:1 on paper); existing web colours exposed as CSS variables; existing botanical mark reused with the web plum; narrow header wrapping, dialog vertical overflow, keyboard skip/focus targets and wrapping retained/refined. No animation or replacement visual direction was introduced.

Verification: **69 backend tests passed** against isolated PostgreSQL, including 11 new workspace endpoint cases. **21 admin tests passed** (15 flow + six existing/adapted confirmation/session checks). Tests cover bound/timeouts, stalled body parsing, stale sessions, uncertain PATCH reconciliation without resend, persistent success feedback, filter/page changes, independent failed panels, queue-node preservation, focus calls and read-only alert drill-through. CI now runs both admin test files. OpenAPI was regenerated from development configuration; no real database was connected for generation.

Impeccable's final source detector reports zero primary findings and six colour advisories. The latter match DESIGN.md's documented opaque colour values; they are not verified palette drift. Live browser access is still unavailable. DOM-stub focus assertions do not prove browser focus restoration, screen-reader behaviour, responsive rendering or touch acceptance. These checks remain open and no fresh officer-web screenshots are claimed. The stale design sidecar was not regenerated.

To see the changes, restart the development API so it exposes the new read endpoints, then reload `/admin/`. No schema migration is needed for this pass, and the personal prototype server was not restarted by these checks. Mobile source/APK was not changed; mobile audit and corrections are the next separate pass.

### Officer motion opportunities and implementation — 10 November 2026

Used the user-requested `/home/emmaa/.agents/skills/find-animation-opportunities/SKILL.md` for discovery, then `/home/emmaa/.agents/skills/animate/SKILL.md` and its button/modal recipes for implementation. The finder stayed a read-only discovery step; the user's explicit implementation request authorised the construction step. No motion library was added.

#### Opportunities that passed the gate

| Location | Before | Purpose | Frequency and speed gate | Implemented recipe / function check |
| --- | --- | --- | --- | --- |
| `styles.css`: sign-in, review-status and confirmation action buttons | Hover feedback, no press response | Feedback | Occasional or tens/day; 100ms, subtle enough for repeated use | Fine-pointer presses scale 1→.98; `transition: transform 100ms cubic-bezier(0.23,1,0.32,1)`. Exclude keyboard-visible focus and disabled controls. Reduced motion uses opacity 1→.85 over 100ms without scale. No layout movement or delayed action. |
| `app.js`: `confirmStatus`; `styles.css`: native status dialog | Pointer opening appeared immediately | Preventing a jarring change | Occasional decision; 200ms, below 300ms budget | Pointer opening only: `@starting-style` opacity 0→1 and scale .97→1, backdrop opacity 0→1; both 200ms with the same strong ease-out. Reduced motion uses opacity .85→1 over 100ms, no transform. The dialog is immediately open, focusable and actionable; motion does not wait before input. Keyboard/programmatic entry and every dismissal stay native/instant. Older browsers without starting-style retain an immediately visible dialog. |

Shared curve/duration tokens are documented in DESIGN.md. Closing animation was deliberately rejected: delaying native close/return-focus would hinder a confirmed/cancelled action. No display/overlay transition or animation-end callback gates the dialog lifecycle.

#### Rejected candidates

- Queue row selection, page changes and focus jumps: frequent working navigation; keyboard activation is a disqualifier. Retain instant selection and focus.
- Counts, statuses, narrative/evidence content and alert rows: data officers must read or act on. Count-up, stagger or panel movement would add distraction rather than information.
- Loading/refresh feedback and a perpetual spinner: existing busy/disabled labels communicate the state; continuous motion adds no necessary explanation here.
- Success celebrations: a case-status update records workflow progress, not a positive case outcome. No confetti, bounce or celebratory treatment.

#### Verdict and verification

This task-focused interface needs very little motion. The highest-leverage addition is the restrained pointer entrance into confirmation; press feedback supplies a smaller tactile cue. Mobile Flutter was not changed.

24 admin tests passed (18 flow/motion routing, six confirmation/session). Added cases check pointer opt-in, keyboard reset after pointer use, programmatic instant opening and cancellation focus. JavaScript syntax and whitespace checks passed. The source detector found no primary issues and the same six known documented-colour advisories. A standalone CSS parser was unavailable; these are source checks rather than proof of rendering/interpolation.

Browser host remains unavailable. Still check the actual entrance, quick open/cancel/reopen, keyboard activation after a mouse opening, OS reduced-motion setting, touch and unsupported-starting-style fallback in a browser. Use the browser animation inspector to slow/step the 200ms entry; confirm text and focus remain readable and that close is immediate. No fresh motion capture or rendered acceptance is claimed.


## Mobile flow review and corrections — 10 November 2026

Scope: Android student flow from sign-in/registration/recovery through Home,
draft editing, review, records, evidence details and updates. This pass preserves
the existing Open Notebook design and permissions; it adds no product features.
Evidence is Flutter source, regression tests and inspected 390×900 widget renders
with bundled fonts and Material icons. No Android device was connected.

### Platform verdict and audit limits

The source uses Material 3 controls, SafeArea, keyboard-resizing Scaffold and a
four-destination NavigationBar, with a sidebar on wider windows. It reads as an
Android app rather than a website port. Hardware acceptance is pending: widget
tests cannot establish TalkBack traversal, predictive Back animation, notification
delivery, actual IME behavior or device performance. A release health score is
therefore not assigned from source alone.

### Findings addressed

| Priority | Location | Finding and impact | Correction |
| --- | --- | --- | --- |
| P1 | Shell, report editor/review | Root routes did not provide a reliable reporting-flow Back path. | Back now follows review → editor → records → home. Editor/review save first; a save failure retains the screen and explains recovery. |
| P1 | Review, Home, records | Pending submissions offered Edit or resumed through the editor despite immutable recovery details. | Edit is disabled while pending or submitting. Pending shortcuts open review directly; Back returns to records. |
| P1 | Records | Durable drafts were described as session-only, and all drafts were labelled unsubmitted even during uncertain submission recovery. | Retention text follows durable storage capability; pending records avoid an unsubmitted claim. |
| P2 | Case evidence | Connected reports displayed preview-only/no-upload wording. | Connected evidence is described as files listed on the submitted report; preview copy remains limited to preview mode. |
| P2 | Email access | Reset success claimed email verification and returned to the request form. | Password reset has an accurate terminal success message and sign-in action; code/password are cleared. |
| P2 | Sign-in, editor, email access | Hints disappeared after entry; recovery lacked password visibility and code input constraints. | Persistent labels, autofill hints, password visibility and eight-digit input formatting. Error/status messages announce via live regions. |
| P2 | Theme | Input boundaries were too faint and text/icon button sizing relied on defaults. | Shared Field Line token strengthens boundaries; text/icon button minimums are 48×48 logical pixels. |
| P2 | Shell | Fixed storage/error feedback consumed scarce height with large text and keyboard insets. | Feedback scrolls with content; its text increases from 11 to 13 logical pixels. |

These corrections implement the audit's harden/adapt/clarify recommendations.
Colors, typography, tab destinations and status vocabulary remain consistent
with DESIGN.md. Existing strengths to preserve include local bundled fonts,
encrypted same-account Android draft recovery, explicit submission confirmation,
native file selection and separate fictional-preview wording.

### Remaining manual and scale checks

- **P1 acceptance:** on a physical Android phone, test TalkBack labels/order and
  announcements; keyboard opening/dismissal; system/predictive Back; draft save
  failures; sign-out/re-entry; uncertain submission retry; file selection and
  notification permission/opening. These behaviors are not certified by renders.
- **P2 scale:** records and updates build their fetched items in Columns inside
  the shell scroll view. Large histories need bounded paging/lazy construction
  together with API pagination; profile with realistic data before choosing limits.
- **P2 appearance:** the product currently provides a light theme only. Decide
  whether dark appearance is a v1 requirement before adding and validating a
  second palette. Do not invert the existing palette automatically.
- **P2 adaptivity:** test landscape, split-screen and foldable window changes on
  actual Android surfaces. Current tests cover compact/wide layouts, text scaling,
  and a 320×640 editor with 1.8× text and a simulated 280-pixel keyboard inset.

Recommended follow-up order: Android manual acceptance, then
`/impeccable optimize` if large histories show measurable cost, and
`/impeccable polish` after device findings are corrected.

### Verification

- `flutter analyze --no-pub`: no issues found.
- `flutter test --no-pub`: 72 passed; one optional live-API test skipped.
- Eight mobile-flow regression checks cover Back/save failures, pending review,
  Home recovery routing, retention/evidence wording, persistent labels and
  large-text/keyboard-inset layout. Both email access tests pass.
- Five phone widget renders (Home, editor, records, review, registration) were
  inspected with local fonts/icons; no device screenshots are claimed.
- `git diff --check`: passed.
- Android debug APK compiled successfully:
  `flutter_app/build/app/outputs/flutter-apk/app-debug.apk`.
  Built with `HERVOICE_API_BASE_URL=http://127.0.0.1:8000/api/v1` for the
  documented adb-reverse local workflow. It is not a cloud/demo-release build.
  Gradle reported non-blocking Firebase Core Kotlin-plugin migration and Android
  SDK XML-version warnings; dependency upgrades were outside this UI pass.

The optional live-API test requires a separately configured running test service;
mocked widget tests do not certify backend, SMTP or Firebase delivery.


## Makerere support copy and quiet shell — 10 November 2026

Replaced the unavailable-contacts placeholder with published Makerere counselling,
safeguarding, student-support, hospital-location and police contacts. Phone
numbers, email and reporting URLs are selectable. Support includes a brief
explanation of formal reporting and confidentiality, with an explicit statement
that HERVOICE does not automatically forward reports to MakSafeSpace.

Source checks (web verification, not confirmation by telephone):
- [Makerere contact directory](https://mak.ac.ug/get-touch)
- [School of Medicine safeguarding guidance](https://som.mak.ac.ug/makerere-university-school-of-medicine-safeguarding/)
- [Published sexual-harassment policy](https://policies.mak.ac.ug/policy/policy-regulations-sexual-harassment-prevention),
  sections 5, 11, 15, 17 and 20. This remains the published 2018 amendment;
  do not invent a newer procedure, automatic university referral or response SLA.

Removed the connected-app Prototype badge and sidebar label. Fictional preview
mode retains its Preview disclosure. Normal draft-storage status no longer occupies
the top of every page; retention details remain in Records and the account Privacy
dialog. Storage errors and API errors remain visible with their respective retry
actions. Refresh records and updates is available through the account menu.
Draft encryption/retention is independent of Firebase push notifications.

Validation: 74 Flutter tests passed, one optional live-API test skipped; static
analysis clean. Inspected widget renders of the quiet Home screen and support
contacts at 320 logical pixels with 1.8× text. Phone acceptance of contact copy and
menu placement remains a manual check.

Android debug build completed successfully with the existing local API URL.
Installed with `adb install -r` on the connected TECNO CK6 (app data retained),
reapplied port reversal and launched the updated app. Local API readiness returned
200/ready. No account sign-in or report submission was performed.
