# Decisions log

Add a dated entry instead of silently changing an earlier decision. A later entry may explicitly supersede all or part of an earlier one; the historical entry remains visible.

## Historical starter decisions

| # | Date | Decision | Why / status |
|---|---|---|---|
| D1 | 2026-10-16 | Native Swift/SwiftUI iOS and watchOS app, built in Xcode and signed with a free Personal Team. | Required for HealthKit and Apple Watch; retained. |
| D2 | 2026-10-16 | Deployment targets iOS 18 and watchOS 11; newer APIs are availability-gated. | Retained. |
| D3 | 2026-10-16 | Decision logic lives in a local, Foundation-only `SteadyCore` package and is unit-tested with `swift test`. | Retained. |
| D4 | 2026-10-16 | No cloud AI, paid APIs, API keys, backend, or third-party packages in v1; alternative templates are the product. | Clarified by D14. |
| D5 | 2026-10-16 | Food is local-first: seed library and saved dishes, with MapKit nearby search; do not claim menus, prices, or hours not supplied by evidence. | Superseded by D15 because the evidence contract is stricter. |
| D6 | 2026-10-16 | Show price on each food suggestion, use a max price per meal, show food spend only in the weekly review, and do not build a separate budget tracker. | Superseded by D16. |
| D7 | 2026-10-16 | Calorie/protein targets are opt-in; low-data mode hides calories, weight trend, and recovery labels. | Retained where those later-scope features exist. |
| D8 | 2026-10-16 | Handle cravings through the alternative ladder with a ten-minute wait and two planned treats per week. | Superseded by D17. |
| D9 | 2026-10-16 | Compute nudges in-app and schedule local notifications, at most three per day. | Retained and assigned to Phase 3. |
| D10 | 2026-10-16 | Write only to a calendar named `Steady`, and only after Confirm. | Retained. |
| D11 | 2026-10-16 | Default time zone is Asia/Singapore; a week runs Monday-Sunday. | Retained. |
| D12 | 2026-10-16 | Use Xcode synchronized folders; never edit `project.pbxproj` by hand. | Retained and clarified by D20. |

## Approved release-1 decisions

| # | Date | Decision | Why / replacement |
|---|---|---|---|
| D13 | 2026-10-16 | Replace M0-M10 with seven phases: Foundation, Alternatives, Daily Foundations, Advisory agent, Live food, Apple Watch, Weekly learning. | The approved product brief controls scope and order. `MILESTONES.md` is the authoritative plan. |
| D14 | 2026-10-16 | **Clarifies D4:** deterministic `TemplateAdvisor` behavior is required everywhere. Phase 4 may add an optional on-device Foundation Models adapter on supported iOS 26+ devices, but release 1 has no cloud advisor, backend, provider key, or paid API. | The app remains private, free, offline-capable, and deterministic while allowing availability-gated wording/ranking later. |
| D15 | 2026-10-16 | **Supersedes D5:** food help uses user-triggered MapKit discovery, official-source links, cited SG FoodID data where a match is defensible, and confirmed user corrections. Every live fact needs provenance and check time. Unknown menus, hours, prices, ingredients, and nutrition remain unknown. No automatic crawling. | Legacy seed values are rough and cannot be presented as verified facts. |
| D16 | 2026-10-16 | **Supersedes D6:** keep an optional `maxPricePerMealSGD` preference and display sourced or saved per-item prices when available. Do not build a weekly spend ledger or estimated-money-saved feature. | Affordability affects feasibility, but money tracking must not become the centre of the product. |
| D17 | 2026-10-16 | **Supersedes D8:** cravings and phone-use friction are ordinary user-selected barriers in the alternatives flow. Release 1 has no dedicated Urge screen, planned-treat quota, or treat/savings score. | A single neutral barrier model is simpler and avoids accidental moral pressure. |
| D18 | 2026-10-16 | `SafetyGate` and deterministic filtering run before any advisor. A model may only select allowlisted candidate IDs or reword approved explanations; it cannot infer allergies, injuries, diagnoses, or emotions, and cannot write calendar, notification, or preference state. | Safety and consequential actions must remain testable code and explicit user choices. |
| D19 | 2026-10-16 | Raw HealthKit samples and complete EventKit events are queried at runtime rather than copied into app history. Persist only minimum derived context and user-created records. | Data minimisation and simpler deletion/export behavior. |
| D20 | 2026-10-16 | **Clarifies D12:** because this source was prepared without macOS/Xcode, generate the `.xcodeproj`, add targets, link the local package, set capabilities, and add privacy keys through Xcode on a Mac. A Windows source audit cannot mark a phase complete. | Xcode owns signing and project metadata; build verification requires Apple tooling. |
| D21 | 2026-10-16 | Phase 1 requests Health and Calendar access only after an in-app explanation and remains useful when either is denied or missing. Calendar use is read-only in Phase 1. | Permission is optional context, not a gate to using Steady. |
| D22 | 2026-10-16 | Use five iPhone tabs - Today, Move, Sleep, Eat, Week. Open Settings from Today; open Alternatives and Foundations contextually rather than adding tabs. | Keeps navigation usable while retaining all required screens. |
| D23 | 2026-10-16 | Phase 1 status may be "source complete, Mac verification pending," but never "complete," until `swift test`, both simulator builds, and real iPhone/Watch checks are recorded. | Prevents source preparation on Windows from being mistaken for a tested Apple-platform release. |
| D24 | 2026-10-16 | Compile both Xcode app targets in Swift 6 mode and use Nonisolated as the target's Default Actor Isolation when that build setting is available. UI state and Apple services declare their isolation explicitly. | A newer template's target-wide MainActor default would otherwise change protocol and value-type isolation assumptions in the prepared source. |
| D25 | 2026-10-16 | Keep P4 strength implemented and tested in `SteadyCore`, but do not trigger it automatically from the Phase 1 app. Manual Strength selection remains available. | Phase 1 has no trustworthy strength-completion count: HealthKit read denial is indistinguishable from zero workouts, and treating unknown as zero could create false catch-up pressure. |

## Decision rules still in force

- User-facing language is neutral: no streak pressure, failure language, or loss warnings.
- Every displayed number has a short explanation.
- Known allergies are hard exclusions. Incomplete ingredients require confirmation and are never presented as safe.
- The app never intensifies exercise because a wearable value looks good.
- Every calendar write/reschedule and remembered food correction requires explicit confirmation.
- Phase boundaries are review gates; do not start the next phase before acceptance.
