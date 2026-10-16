# Steady contributor instructions

Read `docs/SPEC.md`, `docs/MILESTONES.md`, and `docs/DECISIONS.md` before working.
Implement only the phase requested by the user. The seven-phase plan supersedes
the original M0–M10 starter plan.

## Architecture

- Swift 6, SwiftUI, iOS 18, watchOS 11; no third-party app dependencies.
- `Packages/SteadyCore` contains deterministic logic and plain `Codable`,
  `Sendable` values. It imports Foundation only.
- Inject `Clock` and `Calendar`. Use Asia/Singapore and a Monday-start week.
  Only `SystemClock` may construct the current time inside SteadyCore.
- Apple-framework services live in the app behind protocols with sample providers.
- Views use observable view models. UI and SwiftData access belong on the main actor.
- No force unwraps outside tests, shipped `print`, API keys, backend, cloud sync,
  remote analytics, or cloud advisor. Newer on-device AI remains optional and
  availability-gated in a later phase.
- Keep files small and responsibilities explicit.

## Project and source integration

- Never hand-edit or synthesize `Steady.xcodeproj/project.pbxproj`.
- The source handoff is integrated into an Xcode-created project using synchronized
  folders; new capabilities, targets, and package links are configured in Xcode.
- Give numbered, beginner-friendly Xcode steps for integration changes.
- Source may be prepared on Windows. Do not declare an iOS/watchOS feature verified
  until the Swift tests, both simulator builds, and relevant device checks pass.

## Product and privacy

- Show one daily priority with a reason and an appropriate plan.
- Every displayed number has a tappable one-line explanation.
- Health context is uncertain: missing samples are not zero, read-permission
  request success is not proof that Health data was shared, and user check-ins
  can correct or override the context.
- Safety rules override performance plans, including manual priority changes.
- Pain, fainting, chest symptoms, unusual breathlessness, or a relevant Health
  alert show a stop-and-get-checked message instead of exercise advice.
- Never increase exercise because a recovery label looks favorable.
- No guilt, streak pressure, failure language, diagnosis, or unsupported claims.
- Low-data mode hides calories, weight trends, and recovery/readiness labels.
- Personal records stay on the device. Keep raw HealthKit data in HealthKit and
  full calendar event details in EventKit.
- Calendar reads are optional. Writes require an explicit confirmation and may
  target only a Steady-owned event/calendar. Never recreate a user-deleted event.
- Never invent prices, menus, nutrition, opening hours, or ingredient completeness.
  Historical seed files are fixtures until evidence is added in Phase 5.
- No money ledger, money-saved score, treat quota, or dedicated Urge feature in v1.
- Notify only through the later-phase deterministic nudge planner, maximum three
  proactive notifications per day; respect quiet and sleep periods.

## Workflow and verification

1. Explain the scope briefly.
2. Build deterministic core and meaningful tests, then adapters and UI.
3. Run `python scripts/check_source.py` for static source checks.
4. On a Mac with the integrated Xcode project, run `bash scripts/verify-mac.sh`.
5. Record exact verification outcomes and pending device gates in the README and
   milestone checklist. Do not check off unrun tests or builds.
6. Update decisions when behavior changes; preserve superseded decision history.
7. Finish with what changed, device testing steps, outstanding Xcode steps, and a
   suggested commit message. Stop before the next phase.
