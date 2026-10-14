# HERVOICE Flutter UI — first design implementation

12 October 2026. Source: `flutter_app/`. This document records the implemented UI preview, separately from the backend foundation and full delivery roadmap.

## Design direction

A calm editorial interface: warm paper, white surfaces, plum actions, lavender reporting panels, sage support panels, and peach draft/preview accents. Lora headings give the experience a human voice; Manrope body text keeps forms and records legible. Typography is bundled locally rather than loaded from the network.

| Token | Value | Use |
|---|---|---|
| Paper | `#F8F6F2` | Main background |
| Ink | `#302B35` | Primary text |
| Muted | `#696271` | Secondary copy |
| Plum | `#654A69` | Primary actions and navigation |
| Lavender | `#EDE6EF` | Reporting and active navigation |
| Sage | `#E6EDE5` | Support panels |
| Green | `#45674E` | Support icons and received/submitted labels |
| Peach | `#F3E5D8` | Draft and preview accents |
| Line | `#E5DFE5` | Borders/dividers |

Cards use 20-pixel corners; inputs/buttons use 12-pixel corners. Headings and secondary copy establish hierarchy without excessive badges. Statuses use words as well as colour. The home illustration is a subtle code-drawn petal motif.

## Implemented journey

```text
Home → New incident → Incident details → Optional evidence → Review
          ↓                    ↑                              ↓
      Save & leave → My records → Continue draft       Acknowledge preview
                                                              ↓
                                                    Demo confirmation
                                                              ↓
                                                       Case detail

Home / My records / Updates / Support are always available in the navigation shell.
Welcome → Simulated sign-in → Home is available from the account menu.
```

All data and actions are clearly marked as preview. There is no live report confirmation, API fallback, protected storage claim, or invented university contact information. In-memory editing remains available through navigation; reload/restart discards session changes.

## Responsive behaviour and UI states

- Bottom navigation on phones; sidebar at 980 pixels; two-column home at 1180 pixels.
- Narrow layouts wrap headings, case labels, controls, and review details.
- Editor supports partially completed session drafts, required-field/date validation, optional evidence, picker failure messages, file-size/count checks, removal, and return to editing.
- Review submission is disabled until the preview acknowledgement is checked; a short loading state demonstrates finalisation.
- Draft deletion requires confirmation; empty-draft and missing-case states offer recovery actions.
- Case details retain submitted preview narrative, person, incident time, optional course/location, and selected-file metadata.
- Notifications remain neutral and can be marked read.
- Support guidance expands in place; confirmed institutional contacts remain a future content handoff.
- Branding is consistent across the in-app wordmark, web favicon, and native vector launcher.

## Verification evidence

`flutter analyze` reports no issues. Thirty Flutter widget tests pass, including the complete no-file preview journey, system-picker metadata interaction through a platform fake, and layouts at 390/1440 pixels plus 320-pixel screens with 1.8× text. A 600-pixel-high desktop with enlarged text is checked. These are layout and interaction checks, not a substitute for TalkBack or native device testing.

The release web build succeeds. Screenshots of the actual browser-rendered app are in [ui-preview/](ui-preview/):

- [Desktop home](ui-preview/home-desktop.png)
- [Phone home](ui-preview/home-phone.png)
- [Phone incident editor](ui-preview/editor-phone.png)
- [Phone review](ui-preview/review-phone.png)

## Follow-on UI work

1. Review colours, typography, wording, and navigation with the project owners using this running preview.
2. Resolve unknown-subject entry and approximate incident dates before connecting required backend fields.
3. Extend the incident editor to multiple timeline events using the same components.
4. Introduce encrypted durable drafts and account isolation, replacing session-only storage labels only after verification.
5. Connect authentication, the real no-file draft/finalisation flow, case history, and explicit retry/session-expiry states.
6. Add actual upload progress/verification and recovery once the backend evidence lifecycle is complete.
7. Populate institution-approved support contacts and test on Android devices with keyboard, TalkBack, large fonts, and slow networks.

No APK or native-device test has been completed in this UI milestone. Web support exists for reviewing the Flutter design; Android remains the first delivery target.
