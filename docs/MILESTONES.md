# Steady release 1 - seven-phase delivery plan

Status date: **16 October 2026**

This file replaces the starter's M0-M10 workflow. Work on one phase at a time, update the evidence block, and stop for review. A phase is complete only after its core tests, iOS simulator build, Watch simulator build, and stated device checks pass on a Mac.

## Status

| Phase | State | Review gate |
|---|---|---|
| 1. Foundation | **In progress - source implementation/checks underway** | Mac integration and verification still required |
| 2. Alternatives | Not started | Phase 1 accepted |
| 3. Daily Foundations | Not started | Phase 2 accepted |
| 4. Advisory agent | Not started | Phase 3 accepted |
| 5. Live food | Not started | Phase 4 accepted |
| 6. Apple Watch | Not started | Phase 5 accepted |
| 7. Weekly learning | Not started | Phase 6 accepted |

"Source complete" is not the same as "phase complete." Source can be prepared on Windows, but only a Mac with Xcode can satisfy the build and real-device gates.

## Legacy milestone mapping

The original milestone numbers are retained here only as history. New work uses phase numbers.

| Old starter scope | New owner |
|---|---|
| M0 skeleton, parts of M1-M3 | Phase 1 Foundation |
| M4 alternatives and basic movement substitutions | Phase 2 Alternatives |
| M7 foundations and notifications | Phase 3 Daily Foundations |
| M10 optional on-device wording | Phase 4 Advisory agent |
| M6 food | Phase 5 Live food |
| M8 Watch | Phase 6 Apple Watch |
| M9 review and learning | Phase 7 Weekly learning |
| M5 advanced training, M9 fuel adaptation, remaining M10 polish | Later unless restored by a decision |

The old dedicated Urge/treat-quota work is removed. Cravings are ordinary barriers in Phase 2. Weekly spend and estimated savings are removed.

---

## Phase 1 - Foundation

**Outcome:** the iPhone app can collect or manually substitute the minimum context, apply the safety gate, produce one deterministic daily priority, and explain it. The Watch target launches a placeholder. No network is required.

### Source scope

- [ ] `Packages/SteadyCore` declares Swift 6, iOS 18, watchOS 11, and macOS 15 platforms and imports Foundation only.
- [ ] Core support includes an injected clock and an Asia/Singapore calendar; deterministic logic does not call `Date()` directly.
- [ ] Core models cover profile, permissions/consent state, sleep/activity context, calendar availability, safety flags, plans, and priorities.
- [ ] Sleep logic handles wake-day attribution, overlapping samples, naps, missing nights, shortfall coverage, and wake consistency.
- [ ] Availability logic handles timed busy intervals, padding, free windows, missing/denied calendar data, and manual available minutes.
- [ ] `SafetyGate` suppresses performance advice for relevant user-reported symptoms or health alerts and returns neutral next steps.
- [ ] Daily-priority rules are deterministic, ordered, explainable, and produce exactly one Plan A or a safety state.
- [ ] P4 strength is implemented and tested in the core, but automatic P4 is intentionally disabled in the Phase 1 app until a trustworthy strength-completion source exists; manual Strength selection remains available.
- [ ] iPhone app folders exist for `App`, onboarding, Today, Sleep, Settings, Move/Eat/Week placeholders, services, persistence, and resources.
- [ ] `HealthDataProviding` has real HealthKit and sample/manual implementations. Permission denial and missing data are represented as data gaps, not errors that block the app.
- [ ] `CalendarProviding` has real EventKit and sample/manual implementations. Phase 1 reads availability only; no calendar write happens from Today or Sleep.
- [ ] SwiftData persistence contains the minimum profile record required in Phase 1 and maps explicitly to core values; live system permission state stays in the service layer.
- [ ] The iPhone navigation shows **Today, Move, Sleep, Eat, Week**; Settings opens from Today.
- [ ] Onboarding explains permissions before the system prompt and every step can be skipped.
- [ ] Today shows one priority, its reason, Plan A, data gaps, and a sample/manual fallback.
- [ ] Sleep shows last-night context and missing/denied states without blame.
- [ ] Settings includes **Use Sample Data**, low-data mode, profile editing, and permission status.
- [ ] The Watch source launches a Steady placeholder/glance and links only to the shared core needed in Phase 1.
- [ ] Core unit tests cover every priority rule and order, safety override, missing data, midnight crossing, overlap merge, nap exclusion, free-slot edge cases, and manual fallbacks.
- [ ] Static source checks report no forbidden framework import in `SteadyCore`, no force unwrap in shipped code, and no obvious cloud/third-party dependency.

### Xcode integration - required on a Mac

- [ ] Create `Steady.xcodeproj` with an iOS SwiftUI app target using the steps in the root README.
- [ ] Add a `SteadyWatch` watchOS app target for the existing iOS app.
- [ ] Add the repository iPhone and Watch folders as synchronized folders with correct target membership.
- [ ] Add local package `Packages/SteadyCore` and link product `SteadyCore` to both targets.
- [ ] Set minimum versions to iOS 18.0 and watchOS 11.0.
- [ ] Set **Swift Language Version** to Swift 6 for both targets and **Default Actor Isolation** to Nonisolated when that setting is available.
- [ ] Choose the same Personal Team for both targets with automatic signing.
- [ ] Add HealthKit to both targets.
- [ ] Add Health read/update usage descriptions to both targets and Calendar full-access usage description to the iPhone target.

### Verification gates

- [ ] `swift test --package-path Packages/SteadyCore` passes.
- [ ] The `Steady` scheme builds for an installed iOS simulator with no new warnings.
- [ ] The Watch app scheme builds for an installed watchOS simulator with no new warnings.
- [ ] With Health and Calendar denied, the iPhone app launches and produces a priority from sample/manual context.
- [ ] With sample data enabled, Today and Sleep show plausible values and a one-line reason for every number.
- [ ] With permissions granted on a real iPhone, real data or a neutral missing-data state appears.
- [ ] Merely viewing Today/Sleep does not create or modify a calendar event.
- [ ] The paired Watch launches the Steady placeholder/glance.

### Evidence

- Source audit: pending final implementation report.
- Core test command: not run on this Windows host.
- iOS simulator build: not run; requires macOS/Xcode.
- watchOS simulator build: not run; requires macOS/Xcode.
- Real iPhone/Watch check: not run.
- Review decision: pending.

---

## Phase 2 - Alternatives

**Outcome:** when Plan A no longer fits, the user can choose, defer, or intentionally rest without replanning from scratch.

- [ ] Model outcomes as explicit parts and barriers as user-selected context; do not infer injury, allergy, diagnosis, or emotion.
- [ ] Repair seed alternatives so each set has two or three primary options with meaningfully different effort.
- [ ] Every option states minutes, effort, benefit kept, honest tradeoff, steps, and any known price.
- [ ] Validate that preserved and not-preserved outcome parts are complete and non-overlapping.
- [ ] Provide deterministic template fallback for every supported plan/barrier pair.
- [ ] Treat late hunger, delivery preference, sweet drinks, and phone use as ordinary barriers; no Urge screen, treat quota, or savings score.
- [ ] Implement **Choose**, **Later**, and **Rest on purpose** as separate actions.
- [ ] A deferred plan creates only an inert calendar proposal. Write to a calendar named `Steady` only after an explicit confirmation sheet.
- [ ] Add basic movement substitutions; advanced progression remains later scope.
- [ ] Test set size, distinct effort, outcome invariants, fallback, denied calendar access, and confirmation boundaries.
- [ ] Device test: replace and reschedule a plan in a few taps; cancel confirmation and verify no event is written.

---

## Phase 3 - Daily Foundations

**Outcome:** small mobility, daylight, hydration, movement-break, reset, and wind-down actions can fit around the user's day without noisy prompting.

- [ ] Each foundation can be done, replaced, snoozed, or disabled.
- [ ] Respect standing, seated, and wheelchair movement preferences.
- [ ] Use hydration cues without a fixed intake target.
- [ ] Apply safe daylight language; never tell the user to look at the sun.
- [ ] Build a pure nudge planner with a default budget of at most three proactive notifications per day.
- [ ] Drop or move candidates in quiet periods, calendar blocks, workouts, and the planned sleep window.
- [ ] Repeated dismissal moves a nudge type from normal to reduced frequency and then paused.
- [ ] Prefer a silent Today update when the action can wait.
- [ ] Test cap, blocked windows, repeated dismissal, disabled types, and low-data wording.
- [ ] Device test notification actions and confirm ordinary interruption levels are used.

---

## Phase 4 - Advisory agent

**Outcome:** a single coordinator may improve selection or wording without owning safety, facts, persistence, or consequential actions.

- [ ] Define one `AdvisorProviding` interface and narrow typed tool contracts.
- [ ] `TemplateAdvisor` is required, deterministic, offline, and always available.
- [ ] On supported iOS 26+ Apple Intelligence devices, an optional `OnDeviceAdvisor` may rank allowlisted candidate IDs or reword explanations.
- [ ] No cloud provider, API key, proxy, paid API, or automatic web crawler ships in release 1.
- [ ] Build minimal context packets; never send raw HealthKit samples, full calendar events, or unrestricted persisted models.
- [ ] Validate maximum option count, allowlisted IDs, benefit/tradeoff fields, citation requirements, no-inference rules, and no action authority.
- [ ] If model availability or validation fails, return the deterministic result without losing functionality.
- [ ] Keep any advisor history separately clearable from wellness history.
- [ ] Test absence, rejection, malformed output, privacy packet shape, and low-data mode.

---

## Phase 5 - Live food

**Outcome:** user-triggered food help returns up to three useful choices whose price, nutrition, ingredients, and freshness are never overstated.

- [ ] Use MapKit for nearby place discovery with approximate location or typed-area fallback.
- [ ] Add the location usage key only when this phase is integrated.
- [ ] Use official-source links and cited SG FoodID records where an evidence match is defensible.
- [ ] Every live fact has source and check time; every estimate has basis and uncertainty reasons.
- [ ] Unknown opening hours, menu items, price, nutrition, and ingredients remain explicitly unknown.
- [ ] Known allergen conflict is excluded. Incomplete ingredients require confirmation and never rank as the primary recommendation.
- [ ] Remember a correction only after the user confirms **Remember this**.
- [ ] Keep optional `maxPricePerMealSGD`; do not add weekly spend or estimated savings.
- [ ] Quarantine legacy seed prices/nutrition from "verified" presentation.
- [ ] Test allergen exclusion, unknown-ingredient handling, provenance, staleness, offline fallback, and denied location.

---

## Phase 6 - Apple Watch

**Outcome:** the Watch provides a glance and the most common actions in no more than two taps, then synchronizes safely.

- [ ] Phone sends the latest snapshot with `updateApplicationContext`.
- [ ] Watch queues durable actions with `transferUserInfo`; apply each action ID once on the phone.
- [ ] Use `sendMessage` only for optional interactions when the counterpart is reachable.
- [ ] Add glance, quick alternatives, movement log, foundation action, and saved-meal handoff.
- [ ] Respect low-data mode everywhere on the Watch.
- [ ] Test disconnected queueing, duplicate delivery, stale snapshots, and phone-only operation.
- [ ] Device test: common actions take at most two taps and arrive exactly once after reconnection.

---

## Phase 7 - Weekly learning

**Outcome:** a five-to-ten-minute review identifies patterns, proposes one experiment, and changes defaults only with approval.

- [ ] Summarize sleep opportunity, movement, plan changes, alternatives, foundation response, food corrections, and stated helpfulness.
- [ ] Do not show a weekly spend total or estimated money saved.
- [ ] Propose default changes with evidence; never apply them automatically.
- [ ] Let the user select one experiment with start/end dates and a simple measure.
- [ ] Record local-only evaluation metrics such as shown/accepted, alternative completion, time to choose, correction rate, and helpfulness.
- [ ] Export the user's local records as JSON and delete all Steady data after confirmation.
- [ ] Clear advisor history independently from wellness records.
- [ ] Test approval boundaries, aggregation with missing data, export, deletion, and low-data redaction.
- [ ] Device test: complete the review in five to ten minutes and reject a proposed default without side effects.

---

## Definition of done for every phase

- [ ] New decision logic lives in `SteadyCore` and has edge-case tests.
- [ ] `swift test` and both simulator builds pass on a Mac with no new warnings.
- [ ] Sample/manual fallback works when permission is denied or data is missing.
- [ ] No guilt language, diagnosis, unsafe intensification, invented fact, or unconfirmed consequential action.
- [ ] Low-data mode is respected by every surface introduced in the phase.
- [ ] `README.md`, this file, and `DECISIONS.md` contain accurate status and evidence.
- [ ] The user accepts the phase before work begins on the next one.
