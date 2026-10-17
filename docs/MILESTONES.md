# Steady release 1 - seven-phase delivery plan

Status date: **17 October 2026**

This file replaces the starter's M0-M10 workflow. Work on one authorised phase at a time, update the evidence block, and stop for review. A phase is complete only after its core tests, iOS simulator build, Watch simulator build, and stated device checks pass on a Mac. D26 records the user's explicit authorisation to prepare Phase 2 while Phase 1 Apple-platform gates remain pending; it does not mark those gates accepted.

## Status

| Phase | State | Review gate |
|---|---|---|
| 1. Foundation | **Source present; Mac verification pending** | Mac integration, simulator builds, and physical-device verification still required |
| 2. Alternatives | **Source prepared - static/syntax checks passed; Mac verification pending** | User authorised Phase 2 source work; Apple-platform acceptance evidence still required |
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

**Authority/status:** the user requested Phase 2 after the earlier progress report disclosed Phase 1's unrun Mac/device gates (D26). Phase 2 source is prepared and static/syntax checks passed on Windows; this is not acceptance of either phase. Phase 3 has not started. Checked source items below mean implemented/reviewed source, not executed Apple-framework behavior.

### Source scope

- [x] Model outcomes as explicit parts and barriers as user-selected context; do not infer injury, allergy, diagnosis, or emotion.
- [x] Add a repaired typed production catalog with two or three primary options per set and meaningfully different effort; quarantine the legacy fixture.
- [x] Every option states minutes, effort, benefit kept, honest tradeoff, and steps. No unsourced price is displayed.
- [x] Validate that preserved and not-preserved outcome parts are complete and non-overlapping.
- [x] Provide deterministic template fallback for every supported plan/barrier pair; return unavailable when fewer than two eligible options fit.
- [x] Treat late hunger, delivery preference, sweet drinks, and phone use as ordinary barriers; no Urge screen, treat quota, or savings score.
- [x] Implement **Choose**, **Later**, and **Rest on purpose** as separate actions.
- [x] Add local-day chosen/rested/deferred plan and confirmed event-identifier persistence, with no automatic write on refresh/relaunch.
- [x] A deferred plan creates only an inert calendar proposal. Add a confirmed-write service boundary for the Steady-owned calendar.
- [x] Recheck safety at selection and confirmation; add guards for stale or replaced performance proposals.
- [x] Reject actions captured for a previous profile/local day/active priority; preserve scheduled-day linkage through deferred-plan start/completion and atomic carryover.
- [x] Add tracked Steady-owned event rescheduling and an external-deletion tombstone that prevents recreation.
- [x] Add basic explicit standing/seated/wheelchair movement substitutions; advanced progression remains later scope.
- [x] Write core tests for option count, distinct effort/content, outcome partitions, fallback, allowed choices, safety, action idempotence, proposed times, changed conflicts, padding, terminal plans, and inert proposal round trips. These tests have not been executed.
- [ ] Verify framework-dependent Calendar denial, cancel/confirm, duplicate prevention, external deletion, SwiftData recovery/carryover, and foreground-load race behavior on the integrated app. Source review is not runtime evidence.

### Xcode integration

- [ ] Complete the pending Phase 1 project/target/package/capability/privacy setup above.
- [ ] Verify synchronized iPhone source membership includes new Alternatives, persistence, and calendar service files. No manual `project.pbxproj` edits.
- [ ] Verify the SwiftData model container includes the Phase 2 local plan record and launches with existing Phase 1 profile data.
- [ ] Keep the existing Calendar full-access usage description. Phase 2 adds no notification or location permission.

### Verification gates

- [x] `python scripts/check_source.py` passes for the final source (Windows, 17 October 2026).
- [ ] `swift test --package-path Packages/SteadyCore` passes; record host and exact result.
- [ ] The `Steady` scheme builds for an installed iOS simulator with no new warnings.
- [ ] The Watch scheme builds for an installed watchOS simulator with no new warnings.
- [ ] Device: barriers return two or three distinct primary alternatives, explicit outcome coverage, duration explanations, steps, benefit, and tradeoff.
- [ ] Device: Choose replaces the app plan without a calendar write or false completion; same-day refresh/relaunch preserves it.
- [ ] Device: Rest on purpose remains a saved intentional-rest action, without a workout completion or calendar event.
- [ ] Device: Later shows title/date/start/end/reason; cancel and dismiss preserve the previous plan and write nothing.
- [ ] Device: Confirm creates one Steady-owned event; refresh/relaunch do not duplicate it; reschedule updates only the tracked event after another confirmation, including A-to-B-to-A changes.
- [ ] Device: denied Calendar remains usable for Choose/Rest; failed/denied scheduling never claims success or replays after access is restored.
- [ ] Device: deleting the event in Apple Calendar makes the app plan unscheduled; refresh/relaunch never recreates it.
- [ ] Device: a confirmed tomorrow plan carries into its local day when no separate plan exists; future deferred plans cannot start/complete early, a due plan requires explicit Start then completion, and the chosen plan remains correctly associated with that day after relaunch at each step without duplicate active owners.
- [ ] Device: a newly reported safety symptom blocks a stale exercise alternative or deferral, including after relaunch on the same local day.
- [ ] Device: low-data mode, seated/wheelchair preferences, avoided movements, and ordinary craving/phone-use barriers behave according to the specification.
- [ ] Paired Watch regression: the existing placeholder/glance launches; no Phase 6 sync is claimed.

Use README section **9. Phase 2 physical-device acceptance** for the numbered procedure. Record passes, failures, and unrun checks separately.

### Evidence

- Source implementation: prepared/reviewed on Windows on 17 October 2026. The repository contains 103 Swift files, including 14 test files and 95 `@Test` declarations: 56 existing plus 26 alternatives and 13 rescheduling declarations (39 new). Declaration counts are not passing test executions.
- Static source command/result: `scripts/check_source.py` run with the configured Python interpreter **PASSED** for 103 Swift files, including 14 test files. Portable rerun command: `python scripts/check_source.py`.
- Syntax/source audit: tree-sitter 0.26.0 with Swift grammar 0.7.4 parsed all 103 Swift files with no error or missing nodes. No production force unwraps, unusual control characters, or multi-statement missing-return candidates were found. This is not Swift compilation or type checking.
- Diff whitespace check: `git diff --check` **PASSED**.
- Production catalog: nine templates/27 options. Seed, app-resource, and test-fixture copies are byte-identical, SHA-256 `d69bab2fd83de533c135224620b93cb277c42570a6953302baa3682fc9f82ff2`. Legacy `alternatives.json` remains quarantined.
- Core Swift test command/result: **NOT RUN**. `swift` is unavailable on this Windows host; run `swift test --package-path Packages/SteadyCore` on the Mac. No compiler/test success is claimed.
- iOS simulator build: not run; requires macOS/Xcode and the integrated project.
- watchOS simulator build: not run; requires macOS/Xcode and the integrated project.
- Xcode project: not created; follow README's numbered setup steps without editing `project.pbxproj`.
- New Xcode warning count: unknown; builds not run.
- Real iPhone/Watch checks: not run.
- Review decision: source review found no further concrete issue after the recorded fixes; phase acceptance remains pending Apple-platform/device evidence. Phase 3 remains not started.

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
- [ ] The user accepts the phase before work begins on the next one, or explicitly authorises source work for a named phase with the unrun gates recorded (D26); acceptance is never inferred from that exception.
