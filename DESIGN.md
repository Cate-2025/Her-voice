---
name: HERVOICE — The Open Notebook
description: The existing Android and staff-web visual system.
colors: {paper: '#F8F6F2', ink: '#302B35', muted: '#696271', plum: '#654A69', lavender: '#EDE6EF', sage: '#E6EDE5',
  green: '#45674E', peach: '#F3E5D8', field-line: '#8B7C90', line: '#E5DFE5', white: '#FFFFFF', web-plum: '#65466c', web-paper: '#f8f6f3',
  web-ink: '#342b3d', web-muted: '#746c7a', web-line: '#e8e2e9', web-lavender: '#f0eaf3', web-sage: '#edf4ef',
  web-green: '#42644b', web-action-bg: '#fff0e3', web-action-ink: '#85532e', web-field-line: '#8b7c90', web-focus: '#987ba4',
  web-error: '#8b353c', web-timeline: '#d3c2da', web-backdrop: '#22182766'}
typography:
  display-small: {fontFamily: Lora, fontSize: 38px, lineHeight: 1.25}
  headline-medium: {fontFamily: Lora, fontSize: 28px, lineHeight: 1.3}
  headline-small: {fontFamily: Lora, fontSize: 23px, lineHeight: 1.35}
  body-large: {fontFamily: Manrope, fontSize: 15px, lineHeight: 1.65}
  body-medium: {fontFamily: Manrope, fontSize: 13px, lineHeight: 1.6}
  label-large: {fontFamily: Manrope, fontSize: 13px, fontWeight: 700}
  eyebrow: {fontFamily: Manrope, fontSize: 10px, fontWeight: 800, letterSpacing: 2px}
  web-headline: {fontFamily: 'Georgia, serif', fontWeight: 500, letterSpacing: -0.03em}
  web-title: {fontFamily: 'Georgia, serif', fontSize: 1.4rem, fontWeight: 500}
  web-body: {fontFamily: 'system-ui, -apple-system, "Segoe UI", sans-serif'}
  web-label: {fontFamily: 'system-ui, -apple-system, "Segoe UI", sans-serif', fontSize: 0.9rem, fontWeight: 600}
rounded: {control: 12px, card: 20px, icon-tile: 14px, status: 30px, web-button: 10px, web-field: 9px, web-panel: 18px,
  web-badge: 6px, web-status: 20px}
spacing: {'8': 8px, '10': 10px, '12': 12px, '16': 16px, '18': 18px, '20': 20px, '22': 22px, '24': 24px, '28': 28px,
  '32': 32px, '36': 36px, '40': 40px}
components:
  button-primary: {backgroundColor: '{colors.plum}', typography: '{typography.label-large}', rounded: '{rounded.control}',
    padding: 15px 24px}
  button-outlined: {typography: '{typography.label-large}', rounded: '{rounded.control}', padding: 15px 20px}
  input: {backgroundColor: '{colors.white}', rounded: '{rounded.control}', padding: 17px}
  card: {backgroundColor: '{colors.white}', rounded: '{rounded.card}', padding: '{spacing.24}'}
  status: {backgroundColor: '{colors.lavender}', textColor: '{colors.plum}', rounded: '{rounded.status}', padding: 6px
      11px}
  status-received: {backgroundColor: '{colors.sage}', textColor: '{colors.green}', rounded: '{rounded.status}',
    padding: 6px 11px}
  nav-selected: {backgroundColor: '{colors.lavender}', textColor: '{colors.plum}', rounded: '{rounded.control}'}
  web-button-primary: {backgroundColor: '{colors.web-plum}', textColor: '{colors.white}', rounded: '{rounded.web-button}',
    padding: 12px 18px}
  web-button-secondary: {backgroundColor: '{colors.white}', textColor: '{colors.web-plum}', rounded: '{rounded.web-button}',
    padding: 12px 18px}
  web-button-quiet: {backgroundColor: transparent, textColor: '{colors.web-muted}', rounded: '{rounded.web-button}',
    padding: 12px 18px}
  web-input: {backgroundColor: '{colors.white}', textColor: '{colors.web-ink}', rounded: '{rounded.web-field}',
    padding: 12px}
  web-case-selected: {backgroundColor: '{colors.web-lavender}', textColor: '{colors.web-ink}', padding: 18px
      12px}
  web-status: {backgroundColor: '{colors.web-lavender}', textColor: '{colors.web-plum}', rounded: '{rounded.web-status}',
    padding: 5px 10px}
---

# Design System: HERVOICE

## Overview

**Creative North Star: "The Open Notebook"**

The Open Notebook is human, editorial, and approachable. Warm paper grounds,
serif headings, readable sans-serif text, and generous spacing give personal
records room to be read. Components are gently rounded, clear, and restrained;
decoration stays secondary to forms and records.

The Android app and staff website share this character while retaining their
implemented differences. Android uses bundled Lora and Manrope with Material 3
controls; the website uses Georgia and system fonts with its own nearby palette.
Flat surfaces, light borders, and tonal fills provide hierarchy.

**Key Characteristics:**

- Warm paper grounds and muted plum actions.
- Editorial headings with practical body text.
- Selective containers, divided record rows, and generous spacing.
- Flat surfaces with tonal layering and visible state changes.

This is an implementation record, not a redesign. Token values come from
`flutter_app/lib/app/theme.dart`, `flutter_app/lib/core/components.dart`,
`flutter_app/lib/app/shell.dart`, and `backend/app/static/admin/styles.css`.
Flutter numeric sizes are logical pixels, represented as `px` for token portability;
they are not physical device pixels. The spacing/radius entries catalogue observed
values, not a newly enforced scale. Derived Material defaults remain owned by Flutter.

Source was checked on 10 November 2026. Existing `docs/archive/2026-11-10/ui-audit/` phone and desktop
widget renders corroborate the student dashboard. Browser access was unavailable;
no fresh Android capture or browser computed-style verification was performed.

## Colors

The palette combines Muted Plum, Warm Paper, Soft Lavender, Sage, and Peach.
Unprefixed tokens belong to Flutter; `web-` tokens belong to the staff website.
The frontmatter is the value authority; similar names do not imply identical values.

### Primary

- **Muted Plum** (`plum`, `web-plum`): primary actions, brand marks, and selected navigation.
- **Soft Lavender** (`lavender`, `web-lavender`): selected or informational surfaces and ordinary status labels.

### Secondary

- **Sage** (`sage`, `web-sage`) and **Leaf Ink** (`green`, `web-green`): support and selected positive-status treatments.
  Flutter marks Received/Submitted this way; the website marks Received/Closed.

### Tertiary

- **Peach** (`peach`): the Flutter preview/prototype badge.
- **Action Amber** (`web-action-bg`, `web-action-ink`): the website's action-required status.
- **Message Red** (`web-error`): the website's ordinary error/message region.

### Neutral

- **Warm Paper** (`paper`, `web-paper`): page grounds; **White** (`white`): controls and distinct surfaces.
- **Ink** (`ink`, `web-ink`): primary text; **Muted Ink** (`muted`, `web-muted`): secondary text.
- **Fine Line** (`line`, `web-line`): dividers and container boundaries.
- **Field Line** (`field-line`, `web-field-line`): stronger input and outlined-action strokes.
- **Focus Lavender** (`web-focus`), **Timeline Lavender** (`web-timeline`), and
  **Backdrop Ink** (`web-backdrop`): focus outlines, event rails, and modal dimming.

## Typography

Android uses bundled **Lora** headings and **Manrope** body/labels. These are local
assets declared in `flutter_app/pubspec.yaml`; no additional fallback is specified
by the app theme. The website deliberately uses **Georgia, serif** headings and
the system sans-serif stack recorded in `web-body`.

The pairing is editorial at headings and practical in reading and controls.
The hierarchy follows the frontmatter roles: display-small for page headings,
headline-medium/headline-small for subordinate headings, body-large/body-medium
for reading, label-large for controls, and eyebrow for short uppercase markers.
Theme roles with no explicit weight retain their inherited Material weight.

The website headline scales with `clamp(1.9rem, 3.2vw, 2.8rem)`; that responsive
expression stays here rather than being forced into a fixed-size token. Website
paragraphs use line-height 1.65; `.small` text is .82rem. Status text is smaller:
Flutter uses 10 logical pixels at weight 800; web status labels use .73rem at 650.
These are observed sizes, not a claim that accessibility acceptance is complete.

## Layout

Android shell content scrolls inside safe areas. At viewport width 980 logical
pixels it switches from four-destination bottom navigation to a 244-wide sidebar.
The content wrapper has maximum width 1160, with horizontal padding 22 on compact
layouts and 42 on wide layouts; top padding is 28/36 and bottom padding 40.
At width 1180, dashboard records/support form a 3:2 pair with a 40-wide gap.
Below that they stack, separated by 32. The optional sidebar message is shown
only when window height is at least 760 and scaled 14-point text is at most 19.

The website main area is at most 1320 CSS pixels wide with padding 12px 28px 40px.
Its case grid uses a 330px queue and a flexible detail column, separated by 22px.
At widths at most 900px the queue narrows to 280px and panel padding becomes 20px.
At widths at most 700px the grid stacks, summary metrics become two columns,
facts become one column, and horizontal main padding becomes 16px.
Queue scrolling is bounded to 700px height, or 360px on the compact website.
The status-description measure is limited to 65ch; there is no global prose measure.

## Elevation & Depth

Depth comes from tonal layers and light boundaries. Shared Flutter PaperCard
containers and web panels have no custom raised-card shadow. The selected web
queue row has an inset leading rail (`inset 3px 0 var(--plum)`); this communicates
selection rather than elevation. The web dialog dims its background using the
backdrop token. Native dialogs, menus, snackbars, and state layers retain Material
defaults; this record does not replace them with bespoke elevation or motion.
Officer web actions now use the limited pointer-motion vocabulary described below; native Android motion remains Material-controlled.

## Shapes

Android controls and navigation use the control radius; PaperCard uses the card
radius and an outline with line-color alpha .7. Icon tiles have their own slightly
rounder shape; status labels use capsule-like corners. The brand combines a
rounded plum tile and the existing outlined botanical icon with a Lora wordmark.

The website has separate button, field, panel, badge, and status radii. Its login
container uses the card radius, while panels/dialogs use the web-panel radius.
Queue rows are square and divided; the active row adds fill and an inset rail.
These interface-specific differences are part of the current implementation.

## Components

### Buttons

Gently rounded, clear, and restrained. Android filled and outlined controls have
minimum size 48×50 logical pixels; padding and shape are recorded in frontmatter.
The filled color comes from the Material scheme's primary/onPrimary pair; the
outlined variant uses Field Line. Text and icon buttons have a 48×48 minimum
size; interaction states continue to use Material defaults.

Web primary, white secondary, and transparent quiet buttons share a 44px minimum
height and weight 650. Hover applies `brightness(.96)`; disabled buttons use .5
opacity and a default cursor. Focus-visible uses a 3px outline in Focus Lavender,
offset 4px. The site does not define a separate custom pressed-state treatment.

### Cards / Containers

PaperCard defaults to a white surface with 24 logical pixels of padding, while
some draft cards use 20. Colors and padding can be supplied by the caller.
Web panels have white backgrounds, line-colored borders, and 26px default padding.
Both interfaces also use ordinary sections and divided records. The website's
summary is a divided strip and its recurring-report alerts are separated rows.

### Inputs / Fields

Android fields are white, padded by 17 logical pixels, and outlined with Field Line.
Sign-in and incident-entry fields retain their labels after text is entered.
Focus changes the stroke to plum at width 1.5; validation and disabled behavior
remain Material-controlled. Web fields have 46px minimum height, 12px padding,
and their own field border. Labels are grid-stacked with an 8px gap. Browser
focus uses the shared visible outline; textarea resizing is vertical.

### Navigation

The Android shell exposes Home, My records, Updates, and Support. Its bottom
navigation has a white ground and lavender selection indicator. The wide sidebar
uses lavender selected rows, plum text/icons, and weight 800; idle labels use
muted ink at weight 500. Account actions use a Material popup menu.

The staff website uses a queue/detail workspace. Queue rows are button controls;
the selected row exposes `aria-pressed=true`, lavender fill, and a plum leading
rail. Focus remains visible within the scrolling queue. This is separate from
the Android app's destination navigation.

### Status Labels and Feedback

Status labels always include words. The Flutter and web mappings differ as
described in Colors; retain the mapping of the surface being extended.
The web action-required variant uses Action Amber. Native transient notices use
floating Material snackbars. Web messages use a live status region and distinguish
ordinary/error text from success. Mode badges describe connected prototype or
fictional preview state; they are not case statuses.

### Confirmation Dialog

The website uses a native HTML dialog with a web-panel radius, 28px padding,
and maximum width `min(540px, calc(100vw - 32px))`. The dim backdrop separates the
decision from the workspace. Native confirmations retain Material dialogs.

## Do's and Don'ts

These usage notes describe the implemented system; no additional visual prohibitions are established.

### Do

- Do use the matching Android or web token family for the interface being extended.
- Do reuse the existing theme and components for controls, fields, cards, and status labels.
- Do preserve visible focus, explicit status words, and layouts that accommodate enlarged text.
- Do retain the implemented mixture of selective cards, ordinary text sections, and divided rows.
- Do verify native changes on Android and web changes in a browser before claiming rendered acceptance.

## Officer web resilience update — 10 November 2026

The web field boundary is now `#8b7c90` to improve non-text contrast. The queue and alerts use 25-item server pages, independent loading/stale feedback, and visible filter scope. Queue selection updates existing row states; details provide a keyboard focus destination. All-report totals remain global, with separately scoped page counts. These are functional refinements of the existing web direction. Live browser acceptance remains pending.

## Officer web motion — 10 November 2026

Purpose: feedback on occasional pointer actions and a bridge into status confirmation.
Shared CSS vocabulary: `--ease-out: cubic-bezier(0.23,1,0.32,1)`,
`--duration-press: 100ms`, `--duration-dialog: 200ms`.
Sign-in, review-status and confirmation buttons use a `.98` press scale on fine
pointers, excluded when focus is keyboard-visible. Queue rows, filters, paging,
record content, metric values and live messages do not animate. Pointer-opened
native confirmation uses opacity 0→1 and scale .97→1 with a matching backdrop fade.
Keyboard/programmatic openings and every close remain immediate. No request waits
for motion completion. Reduced motion removes spatial changes and uses a gentle
100ms opacity change (.85→1); default/native behaviour remains when starting-style
is unsupported. Browser motion/feel and accessibility acceptance remain unverified.


## Android flow corrections — 10 November 2026

The shell keeps account/storage feedback inside the scrollable content, allowing
the report editor to remain reachable with large text and the keyboard open.
Error messages on sign-in, email access and report review use live regions.
System Back follows review → editor → records → home, saving the draft before
leaving the editor/review; a failed save retains the current screen. Pending
submissions return to records and resume directly in review with editing locked.

The current light appearance, typography, navigation destinations, status
meanings and Material motion remain the incumbent system. Widget renders with
bundled fonts and Material icons were inspected at 390×900; these are not Android
screenshots. TalkBack, predictive Back, real keyboard behavior and device rendering
still require manual acceptance.


## Quiet routine status — 10 November 2026

Supersedes the always-visible storage/status row described above. The connected
app has no Prototype badge. Routine retention information lives in Records and
Privacy; only actionable storage/API errors appear above content. Manual refresh
is an account-menu action, with separate inline retry actions for errors.
Preview mode retains its fictional-data label. Makerere support contacts use
ordinary divided reading sections and selectable text rather than extra cards.
