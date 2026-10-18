# Steady release 1 - seven-phase delivery plan

Status date: **18 October 2026**

This file replaces the starter's M0-M10 workflow. Work on one authorised phase at a time, update the evidence block, and stop for review. A phase is complete only after its core tests, iOS simulator build, Watch simulator build, and stated device checks pass on a Mac. D26, D32, D37, D41, D44, and D48 record authority for Phase 2/3/4/5/6/7 source work while earlier Apple-platform gates remain pending; none marks those gates accepted.

## Status

| Phase | State | Review gate |
|---|---|---|
| 1. Foundation | **Source present; Mac verification pending** | Mac integration, simulator builds, and physical-device verification still required |
| 2. Alternatives | **Source prepared - static/syntax checks passed; Mac verification pending** | User authorised Phase 2 source work; Apple-platform acceptance evidence still required |
| 3. Daily Foundations | **Source prepared - static/syntax checks passed; Mac verification pending** | User authorised Phase 3 source work; earlier gates remain pending |
| 4. Advisory agent | **Source prepared - static/syntax checks passed; Mac verification pending** | User authorised Phase 4 source work (D37); earlier gates remain pending |
| 5. Live food | **Source prepared - static/syntax checks passed; Mac verification pending** | User authorised Phase 5 continuation (D41); earlier gates remain pending |
| 6. Apple Watch | **Source prepared - static/syntax checks passed; Mac verification pending** | User authorised continuation (D44); earlier Mac/device gates remain pending |
| 7. Weekly learning | **Source prepared - static/syntax checks passed; Mac verification pending** | Explicit Phase 7 request (D48); all earlier Mac/device gates remain pending |

"Source complete" is not the same as "phase complete." Source can be prepared on Windows, but only a Mac with Xcode can satisfy the build and real-device gates.

Earlier phase authority/evidence blocks preserve the state at their own handoff. Later dated decisions authorise subsequent source work without rewriting those historical results; the Status table and latest phase section describe current source scope.

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

**Authority/status:** the user requested Phase 2 after the earlier progress report disclosed Phase 1's unrun Mac/device gates (D26). Phase 2 source is prepared and static/syntax checks passed on Windows; this is not acceptance of either phase. Phase 3 was separately authorised on 18 October 2026 (D32). Checked source items below mean implemented/reviewed source, not executed Apple-framework behavior.

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
- Review decision at the 17 October audit: source review found no further concrete issue after the recorded fixes; phase acceptance remains pending Apple-platform/device evidence. Phase 3 was subsequently authorised separately on 18 October (D32).

---

## Phase 3 - Daily Foundations

**Outcome:** small mobility, daylight, hydration, movement-break, reset, and wind-down actions can fit around the user's day without noisy prompting.

**Authority/status:** the user explicitly requested Phase 3 on 18 October 2026 after the earlier status report disclosed Phase 1/2's unrun Mac/device gates (D32). Phase 3 source is prepared and static/syntax checks passed on Windows. This is not acceptance of an earlier phase. Phase 4 was subsequently authorised separately (D37). Source checkboxes are implementation/review evidence only, never proof of Apple-framework behavior.

### Source scope

- [x] Add deterministic local options for mobility, daylight, hydration, movement breaks, quiet reset, and wind-down.
- [x] Respect explicit standing, seated, and wheelchair controls plus typed avoided movements; do not interpret saved free text as a diagnosis.
- [x] Use thirst-led hydration without a fixed intake or timer target; retain personal fluid-guidance boundaries.
- [x] Apply shade, no-sun-gazing, unsafe-weather/access opt-out language and a smallest-useful wind-down.
- [x] Model Done, Replace, Snooze, Disable, Enable, and Resume; keep replacement separate from completion and reject stale-day or invalid replacement/snooze actions.
- [x] Preserve daily state/idempotency IDs and cross-day preferences as Codable values with deterministic rollover and expiry.
- [x] Build a pure nudge planner with notification, silent Today, or typed drop results; hard-cap proactive reservations at three per local day.
- [x] Move or drop the entire action interval around overnight/all-day quiet periods, calendar blocks, workouts, and planned sleep.
- [x] Reduce a type after two dismissals using a two-local-day cooldown, pause after four, and support explicit resumption without resetting on ordinary refresh.
- [x] Prefer silent Today cards for automatic can-wait candidates; use allowlisted low-data notification wording.
- [x] Add/review SwiftData Foundation preferences/day/response persistence, optional real/sample notification providers, durable callback inbox, and device-wide conservative budget.
- [x] Add/review Today/Settings Foundations navigation, notification-open routing from any tab, explicit preference saving, denial fallback, permission explanation, current-day scheduling, and foreground-only reconciliation.
- [x] Run the final static/syntax/diff checks and record exact source/test counts below.
- [ ] Verify all authored Foundation/nudge tests on a Mac; written declarations are not passing executions.

### Xcode integration - required on a Mac

- [ ] Complete earlier project, local-package, Swift 6, signing, HealthKit, and Calendar setup without hand-editing `project.pbxproj`.
- [ ] Confirm synchronized iPhone membership includes the Foundations UI, persistence files, and `Services/Notifications`; app adapters must not enter the Foundation-only core or Watch target.
- [ ] Confirm the model container includes `FoundationPreferenceRecord`, `FoundationDayRecord`, and `FoundationResponseRecord`, and an existing development store still loads its profile/plan data.
- [ ] Use system `UserNotifications` for optional local alerts; add no APNs key, Push Notifications entitlement, background mode, server, or notification-specific usage-description key.
- [ ] Confirm the user sees Steady's explanation before the system notification prompt; a saved preference never substitutes for current system authorization.

Follow README section **10. Phase 3 Xcode integration** for the numbered clicks.

### Verification gates

- [x] `python scripts/check_source.py` passes for final source; Windows, 18 October 2026, 138 Swift files/22 test files.
- [ ] `swift test --package-path Packages/SteadyCore` passes on a Mac; record exact result.
- [ ] The iOS simulator build succeeds with no new warnings.
- [ ] The Watch simulator build succeeds with no new warnings; full Watch sync remains Phase 6.
- [ ] Device: all six families show appropriate language and tappable explanations, without a streak/completion target.
- [ ] Device: Done/Replace/Snooze/Disable/Enable survive same-day refresh/relaunch, rollover resets daily progress but retains preferences, and stale/duplicate actions cannot mutate new state.
- [ ] Device: mode/avoid controls are explicit, saved free-text notes require review, unavailable variants do not add unsuitable filler, and safety supersedes stale suggestions/actions.
- [ ] Device: denied/cancelled notification permission leaves in-app Foundations usable; turning reminders off cancels pending Steady requests.
- [ ] Device: overnight/all-day quiet periods, planned sleep, known workouts, and timed Calendar blocks move/drop whole candidate intervals; unavailable Calendar context stays silent.
- [ ] Device: at most three distinct proactive reservations per Singapore day survive relaunch, repeated refresh, profile changes, snooze, cancellation, and failed saves without automatic refund.
- [ ] Device: two dismissals reduce to every-other-local-day consideration, four pause that type, and explicit resume restores consideration; unrelated kinds remain unaffected.
- [ ] Device: ordinary active/no-sound notifications use no time-sensitive/critical interruption; foreground presentation stays silent.
- [ ] Device: minimal callback inbox applies actions idempotently on foreground state load; notification open routes to Foundations from Move/Sleep as well as Today without resetting dismissal history, and stale day/option Done or Snooze is ignored with an honest message.
- [ ] Device: low-data notification text includes no sensitive measurement; sample mode never sends a real notification and remains separate from real preferences/history.
- [ ] Device: foreground refresh reconciles changed context/access; no background freshness, guaranteed timing, or multi-day schedule is claimed.
- [ ] Regression: existing Today/Move/Sleep, alternatives, confirmed Calendar behavior, denied-data fallbacks, and Watch placeholder remain usable.

Use README section **11. Phase 3 physical-device acceptance** for the numbered procedure. Record passes, failures, and unrun cases separately.

### Evidence

- Source implementation/review: prepared on Windows, 18 October 2026. The repository contains 138 Swift files, including 22 test files and 163 `@Test` declarations: 95 previously present plus 29 Foundation and 39 nudge declarations (68 added). Declarations are not test executions.
- Final static source command/result: `scripts/check_source.py` run with the configured Python interpreter **PASSED** for 138 Swift files, including 22 test files. Portable rerun: `python scripts/check_source.py`.
- Final syntax/source audit: tree-sitter parsed all 138 Swift files with no error or missing nodes. No production force unwraps, unusual control characters, or multi-statement missing-return candidates were found. An explicit initializer-label audit covered 365 calls across 70 local types without a finding. These are static audits, not Swift compilation or type checking.
- Final diff whitespace check: `git diff --check` **PASSED**, including the final documentation update.
- Core Swift test command/result: **NOT RUN**. Swift is unavailable on this Windows host; run `swift test --package-path Packages/SteadyCore` on the Mac.
- iOS simulator build: **NOT RUN**; requires macOS/Xcode and the integrated project.
- watchOS simulator build: **NOT RUN**; requires macOS/Xcode and the integrated project.
- Xcode project: not created; use the numbered README steps, never synthesize `project.pbxproj`.
- New Xcode warning count: unknown; builds not run.
- Real iPhone/Watch checks: **NOT RUN**.
- Review decision at the Phase 3 audit: source review completed after reconciling global/local reservation ledgers, rechecking fresh bedtime/profile/safety state before scheduling, rounding snoozes to whole seconds, routing notification opens from any tab, foreground-only response handling, and synchronous stored-safety seeding. Static checks passed; phase acceptance remains pending the unrun Apple-platform/device evidence. Phase 4 was subsequently authorised separately (D37). No commit or push was part of the Phase 3 request.

---

## Phase 4 - Advisory agent

**Outcome:** a single validating coordinator may reorder existing alternatives without owning safety, wording, facts, persistence, or consequential actions.

**Authority/status:** the user explicitly requested Phase 4 on 18 October 2026 (D37). Source is prepared and static/syntax checks passed on Windows; earlier Phase 1/2/3 Mac tests/builds/device gates remain pending, as do Phase 4's Apple-platform gates. This instruction does not accept those gates or authorise Phase 5. D38 narrows the optional model capability to ID-only ranking; generative rewording is not implemented. Checked source items mean implementation/review only, never executed Apple-framework evidence.

### Source scope

- [x] Define one `AdvisorProviding` interface and one coordinator with typed request/result contracts.
- [x] Required `TemplateAdvisor` is deterministic, offline, immediate, and always available.
- [x] Guard the optional Apple `FoundationModels` adapter by SDK import and iOS 26/model availability, without raising the iOS 18 baseline or importing it into the core/Watch.
- [x] Keep on-device ordering default-off, explicit opt-in, and explicitly requested in Alternatives; sample mode always uses TemplateAdvisor.
- [x] Send only opaque candidate IDs, approved typed attributes, and a coarse time budget/optional explicit user-selected barrier enum. In normal mode the barrier may describe soreness/stress/low energy; low-data mode omits it. Exclude HealthKit-derived measurements, recovery labels, SafetyGate symptom/alert records, calendar details, original profile/plan identifiers, timestamps, and free text.
- [x] Validate the deterministic canonical set before inference and require an exact two-or-three-ID permutation afterward: no unknown fields, extra prose, foreign/duplicate/missing IDs, or partial acceptance.
- [x] Rebuild the result from unchanged canonical options, preserving benefit/tradeoff/outcome facts and any approved evidence. No generated factual claim or action/tool authority.
- [x] Recheck safety/current request identity after awaiting; cancel or ignore stale results after day/profile/plan/sample/preference/restriction/context changes and user actions.
- [x] Fall back deterministically for absent/unready/blocked models, errors, cancellation, and invalid responses without delaying or disabling manual choices.
- [x] Keep separately clearable bounded in-memory diagnostic status history only; persist no prompt, model output, candidate text, transcript, or context packet. Clearing cannot erase wellness/reminder records.
- [x] Add meaningful core tests for deterministic identity, malformed/rejected output, fallback, privacy/low-data packet shape, no-inference/no-action boundaries, and unchanged canonical content. Test declarations are not executed tests.
- [x] Run final static/syntax/diff checks and record exact counts/results below.

### Xcode integration - required on a Mac

- [ ] Complete the earlier project/package/signing/capability setup without editing `project.pbxproj`.
- [ ] Build the optional adapter using an Xcode/iOS SDK that includes `FoundationModels` (iOS 26 SDK or later); retain iOS 18/watchOS 11 deployment minima and Swift 6 explicit isolation.
- [ ] Verify advisor app files belong only to the iPhone target. `SteadyCore` stays Foundation-only and the Watch remains its existing placeholder.
- [ ] Verify older-SDK compile fallback and older/unsupported/unready runtime fallback. No new permission, API key, cloud entitlement, backend, or model-download workflow.

Follow README section **12. Phase 4 Xcode integration** for the numbered steps.

### Verification gates

- [x] `python scripts/check_source.py` passes for final source; Windows, 18 October 2026, 153 Swift files/26 test files.
- [ ] `swift test --package-path Packages/SteadyCore` passes on a Mac.
- [ ] The iOS simulator build succeeds with no new warnings, including SDK/runtime fallback paths.
- [ ] The Watch simulator build succeeds with no new warnings; full sync remains Phase 6.
- [ ] Device: default-off deterministic alternatives are immediate and usable offline with no advisor/model support; sample mode never calls the real model.
- [ ] Device: supported ready Apple Intelligence plus explicit opt-in/request may only reorder the same canonical IDs/options; no background shuffling or generated claims.
- [ ] Device: unsupported/unready/blocked/refused/error/malformed output retains the deterministic order with honest status and no cloud fallback/download promise.
- [ ] Device: safety, cancellation, day/profile/plan/sample/barrier/mode/avoid/preference/context changes reject late responses; action boundaries still recheck current state.
- [ ] Device: typed requests omit HealthKit-derived measurements, recovery labels, SafetyGate symptom/alert records, calendar details, original profile/plan IDs, and free text. Normal-mode selected barriers are explicit user statements, not inferred conditions; low-data packets omit the barrier.
- [ ] Device: Clear advisor activity clears only in-memory diagnostics, invalidates in-flight work, survives no transcript relaunch, and leaves wellness/reminder/Calendar records unchanged.
- [ ] Regression: earlier Today/Move/Sleep, alternatives, Foundation/reminder, Calendar confirmation, denied-data, and Watch placeholder behavior remains usable; model output alone has no side effects.

Use README section **13. Phase 4 physical-device acceptance** for the numbered cases. Record passes, failures, and unrun checks separately.

### Evidence

- Source implementation/review: prepared on Windows, 18 October 2026. The repository contains 153 Swift files, including 26 test files and 197 `@Test` declarations: 163 previously present plus 34 Phase 4 declarations. Declarations are not test executions.
- Final static source command/result: `scripts/check_source.py` run with the configured Python interpreter **PASSED** for 153 Swift files/26 test files, including Foundation Models compile/runtime-guard and no-cloud checks. Portable rerun: `python scripts/check_source.py`.
- Final syntax/source audit: tree-sitter parsed all 153 Swift files with no error or missing nodes. No production force unwraps, unexpected control characters, or multi-statement missing-return candidates were found. The explicit initializer-label audit covered 445 calls across 79 local types without a finding. These are static audits, not Swift compilation or type checking; the modern-SDK `FoundationModels` branch remains uncompiled on this Windows host.
- Final diff whitespace check: `git diff --check` **PASSED**.
- Core Swift test command/result: **NOT RUN**. Swift is unavailable on this Windows host; run `swift test --package-path Packages/SteadyCore` on the Mac.
- iOS simulator build: **NOT RUN**; requires macOS/Xcode and the integrated project.
- watchOS simulator build: **NOT RUN**; requires macOS/Xcode and the integrated project.
- Xcode project: not created; use the numbered README setup, never synthesize `project.pbxproj`.
- New Xcode warning count: unknown; builds not run.
- Real iPhone/Watch checks: **NOT RUN**.
- Review decision: source review and static checks completed. The reviewed boundary uses ID-only output with canonical reconstruction, no HealthKit-derived measurements/recovery labels/SafetyGate symptom records/free text in packets, fresh safety/request checks, independent timeout/cancellation, interaction freeze, and separate memory-only diagnostic clearing. The explicit selected barrier enum may describe soreness/stress/low energy in normal mode and is omitted in low-data mode. Optional Apple API references were reviewed, but actual SDK compilation, fallback builds, and supported-device behavior remain unverified. Phase acceptance remains pending Apple-platform/device evidence. Phase 5 is not started. Phase 3's local uncommitted work is preserved; no commit or push is part of this request.

---

## Phase 5 - Live food

**Outcome:** user-triggered food help returns up to three useful choices whose price, nutrition, ingredients, and freshness are never overstated.

**Authority/status:** after the Phase 4 source handoff, the user requested continuation on 18 October 2026. Phase 5 Live-food scope was announced before implementation (D41). Source is prepared and static/syntax checks passed on Windows. This authorises source work, not acceptance of Phase 1/2/3/4, whose Mac/device gates remain pending. Phase 6 remains unauthorised. Source checkboxes describe implementation/review only, never executed Swift or Apple-framework behavior.

The Phase 4 Evidence block above records that earlier handoff's state; D41 subsequently authorises the Phase 5 work below without changing that historical evidence.

### Source scope

- [x] Add Foundation-only food requests, place/dish identities, fact-specific provenance, confidence, uncertainty, and freshness rules.
- [x] Apply deterministic dietary/allergen filtering, explicit free-text uncertainty, dislikes/kitchen restrictions, and optional per-meal price without a spending ledger.
- [x] Return up to three distinct useful choices, allow fewer/none, and collapse repeated normalized dish/place labels for display only, never as identity proof. Conservative exclusion precedence survives duplicate records. Keep incomplete/uncertain ingredient results outside primary recommendations. Known allergen conflicts are excluded; no result is called safe.
- [x] Add user-triggered MapKit discovery and protocol-backed typed/approximate/sample/manual paths. Merely opening Eat requests neither location nor live search.
- [x] Label MapKit results as places to check; discovery/venue website links never prove a current menu, item, price, hours, ingredients, or nutrition.
- [x] Validate venue-bound official-menu evidence and exact dish/serving cited SG FoodID matches. Do not ship invented or unreviewed menu/nutrition records.
- [x] Retain the honest no-matched-record fallback: HPB reference link plus unavailable nutrition; legacy `foods.json` stays a fixture, never verified food evidence.
- [x] Add explicit **Remember this** review/confirmation, minimal local SwiftData saved records, dated prior-visit labels, cancel/dismiss no-write behavior, and honest persistence failures.
- [x] Keep profile/sample separation and invalidate stale searches/corrections after request/profile/sample/day/saved-state changes. Do not persist transient MapKit searches or approximate location history.
- [x] Provide low-data food presentation and tappable one-line explanations for displayed numbers, sources, and uncertainty.
- [x] Author meaningful core tests for evidence validation, allergy/dietary uncertainty, known conflicts, provenance/expiry, duplicates/caps, price/serving guards, corrections, and stale identity. Declarations are not executed tests.
- [x] Run final static/syntax/diff checks and record exact counts/results below.

### Xcode integration - required on a Mac

- [ ] Complete earlier project, package, signing, capability, and explicit Swift 6 isolation setup without editing `project.pbxproj`.
- [ ] Verify Eat/Food/location services and saved-food SwiftData files belong to the iPhone target only. The Watch remains its existing placeholder; the core stays Foundation-only.
- [ ] Confirm the model container includes `FoodCorrectionRecord` and existing development stores still load their profiles, plans, and Foundations.
- [ ] Add iPhone `NSLocationWhenInUseUsageDescription` and set `NSLocationDefaultAccuracyReduced` to Boolean `YES`. Add no Always location key, full-accuracy purpose dictionary, background location mode, API key, paid entitlement, server, or crawler.
- [ ] Keep typed-area/manual/saved-dish paths usable without location or network. Permission is explained before the system prompt; current OS authorization, not a saved preference, controls access.

Follow README section **14. Phase 5 Xcode integration** for numbered steps.

### Verification gates

- [x] `python scripts/check_source.py` passes for final source; Windows, 18 October 2026, 174 Swift files/32 test files.
- [ ] `swift test --package-path Packages/SteadyCore` passes on a Mac.
- [ ] The iOS simulator build succeeds with no new warnings, including MapKit/CoreLocation and SwiftData integration.
- [ ] The Watch simulator build succeeds with no new warnings; full Watch synchronization remains Phase 6.
- [ ] Device: opening Eat makes no live request; explicit typed search/nearby actions work, permission is optional, and denied/restricted/offline/error states remain honest and useful.
- [ ] Device: live discovery exposes only venue facts; menu/item/price/hours/ingredients/nutrition stay unknown without matching evidence. Fewer/none is allowed; uncertain items are never primary or called safe.
- [ ] Device: known allergens exclude; incomplete ingredients, cross-contact uncertainty, unknown dietary rules, and free-text allergies remain confirmation-required; names/venue categories are not ingredient evidence.
- [ ] Device: max price is optional and per meal; known over-limit choices are excluded while unknown prices remain explicitly unverified, without a spending total or invented price.
- [ ] Device: Remember review shows the exact draft/source/date; cancel/dismiss writes nothing; Confirm persists only the current confirmed record. Refresh/relaunch does not auto-save/replay, and a failed save never claims success.
- [ ] Device: stale profile/sample/day/input/saved-record state rejects late searches and confirmations; sample records/providers stay separate from real ones; transient search/location data is not persisted.
- [ ] Device: saved prior visits stay dated and uncertain, stale evidence is not current verification, and missing SG FoodID records stay unavailable. Legacy fixture prices/nutrition cannot become verified results.
- [ ] Device: low-data food surfaces hide sensitive nutrition details and every displayed number has an explanation. Food search/corrections never invoke the advisor or create Health/Calendar/notification actions.
- [ ] Regression: earlier Today/Move/Sleep, alternatives, Foundations/reminders, Calendar confirmations, denied-data fallbacks, and Watch placeholder remain usable.

Use README section **15. Phase 5 physical-device acceptance**. Record each pass, failure, and not-run case separately; sample results do not prove live location/search behavior.

### Evidence

- Source implementation/review: prepared on Windows, 18 October 2026. The repository contains 174 Swift files, including 32 test files and 252 `@Test` declarations: 197 previously present plus 55 Phase 5 declarations. Declarations are not test executions. The final regression covers repeated-save display deduplication in reversed input order without promoting matching labels into venue identity evidence.
- Final static source command/result: `scripts/check_source.py` run with the configured Python interpreter **PASSED** for 174 Swift files/32 test files, including food no-legacy/no-Always/full-accuracy-location guards. Portable rerun: `python scripts/check_source.py`.
- Final syntax/source audit: tree-sitter 0.26.0 with Swift grammar 0.7.4 parsed all 174 Swift files with no error or missing nodes. No production force unwraps, unexpected control/replacement characters, or multi-statement missing-return candidates were found. The explicit initializer-label audit covered 505 calls across 96 local types without a finding. These are static audits, not Swift compilation or type checking; MapKit/CoreLocation/SwiftData integration remains uncompiled here.
- Final diff whitespace check: `git diff --check` **PASSED**, including final documentation edits.
- Food reference limitation: HPB's [SG FoodID entry point](https://www.hpb.gov.sg/healthy-living/food-and-beverage/sgfoodid/) and [food-search tool](https://pphtpc.hpb.gov.sg/web/sgfoodid/tools/food-search) were inspected. No defensible record/portion dataset was extracted. No verified nutrition values or official menu catalog are claimed; unsupported facts remain unavailable (D42).
- Core Swift test command/result: **NOT RUN**. Swift is unavailable on this Windows host; run `swift test --package-path Packages/SteadyCore` on the Mac.
- iOS simulator build: **NOT RUN**; requires macOS/Xcode and an integrated project.
- watchOS simulator build: **NOT RUN**; requires macOS/Xcode and an integrated project.
- Xcode project: not created; use numbered README setup, never synthesize `project.pbxproj`.
- New Xcode warning count: unknown; builds not run.
- Real iPhone/Watch checks: **NOT RUN**.
- Reviewed primary Apple references: [MKLocalSearch](https://developer.apple.com/documentation/mapkit/mklocalsearch) and [NSLocationDefaultAccuracyReduced](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocationdefaultaccuracyreduced). Documentation review is not SDK compilation or permission-dialog/device evidence.
- Review decision: source review and static checks completed. The reviewed source keeps empty production menu/nutrition catalogs honest, binds evidence to fact/venue/dish/serving, excludes recorded allergen conflicts conservatively, keeps user observations incomplete, and separates uncertain results from primary recommendations. Remember is a reviewed, expiring proposal; profile/sample/day/input/saved-record guards and own-revision asynchronous cleanup reject stale work. Fresh saved-record fingerprints and a food-only SwiftData transaction avoid stale overwrites/shared rollback; foreground expiry never starts network/location/save work. Location prompts survive transient inactivity, while backgrounding clears captured area; system permission and persistence behavior still require device checks. Current production venues/manual observations cannot be primary because no vetted ingredient/menu catalog ships. Phase acceptance remains pending Apple-platform/device evidence. Phase 3/4 local uncommitted changes are preserved; Phase 5 includes no commit or push. Stop before Phase 6.

---

## Phase 6 - Apple Watch

**Outcome:** the Watch provides a useful cached glance and the most common explicit actions in no more than two taps, then synchronizes safely without claiming guaranteed delivery.

**Authority/status:** after the Phase 5 source handoff, the user requested continuation on 18 October 2026. Phase 6 Apple Watch scope was announced before implementation (D44). Source is prepared and static/syntax checks passed on Windows. This authorises source work, not acceptance of Phase 1/2/3/4/5, whose Mac/device gates remain pending, as do Phase 6's Apple-platform gates. Phase 7 remains unauthorised. Source checkboxes describe implemented/reviewed source, never executed Swift, WatchConnectivity, or device behavior.

The Phase 5 Evidence block above records that earlier handoff's state; D44 subsequently authorises the work below without rewriting that historical evidence.

### Source scope

- [x] Add Foundation-only typed snapshot/action/receipt values, bounds, schema handling, durable-outbox reducer, and current-scope validation with tests.
- [x] Send replaceable latest phone state with `updateApplicationContext`; activate the protocol-backed WatchConnectivity service on both platforms without relying on reachability for durable transfer.
- [x] Queue explicit Watch actions durably before `transferUserInfo`; retain IDs for retry until typed acceptance/rejection, and reject queue/storage overflow honestly without silent eviction.
- [x] Persist minimal phone inbox/apply-once receipts; commit each accepted mutation and receipt atomically, with idempotent replay after disconnect, duplicate delivery, relaunch, and uncertain save. Bound ingress/new daily receipts while retaining replay IDs until later explicit deletion.
- [x] Add a cached glance, allowlisted quick alternatives, explicit manual movement log, captured current Foundation Done, and confirmed saved-meal phone handoff. Label completed/rested/deferred plans without implying a new action to start.
- [x] Revalidate profile/sample/day/snapshot/current-plan/current-option/saved-record/safety state before applying; bind every Watch button to its displayed snapshot so repeated IDs cannot retarget a replacement.
- [x] Keep quick choice distinct from completion, manual movement distinct from HealthKit, and saved-meal handoff distinct from eating or Remember confirmation. No Calendar, HealthKit, advisor, notification, or default-change action authority.
- [x] Minimise payloads and apply low-data redaction to transport and UI. Show stale/unavailable/queued/accepted/rejected states with tappable explanations for numbers.
- [x] Keep phone-only operation and offline cached Watch use. Optional `sendMessage` is omitted; no cloud entitlement, server, APNs, or delivery/background-freshness guarantee. SwiftUI WatchConnectivity background handling only receives local transport data/receipts.
- [x] Validate durable outbox/revision-watermark integrity before enabling actions; never reset corrupt data silently. Match phone rejection receipts even for future-dated actions without allowing false accepted timestamp ordering.
- [x] Author meaningful core tests for packet bounds/redaction, offline queues, same-ID duplicates, stale scope/day/snapshot, safety, receipts, replay, capacity, and failure boundaries. Declarations are not executed tests.
- [x] Run final static/syntax/diff checks and record exact results below.

### Xcode integration - required on a Mac

- [ ] Complete earlier project/package/signing/capability setup through Xcode without editing `project.pbxproj`.
- [ ] Verify the Watch app is associated with the existing iPhone app, bundle identifiers and companion settings match, and both targets link the local `SteadyCore` product.
- [ ] Verify shared transport source target membership plus platform-specific app/watch source membership using README section 16; no duplicate generated app entry points.
- [ ] Verify the SwiftData container includes the new Watch receipt/movement records while existing development stores retain profiles/plans/Foundations/food corrections.
- [ ] Add no new permission prompt, API key, APNs, iCloud/App Group entitlement, background mode, or HealthKit write request for Phase 6.

Follow README section **16. Phase 6 Xcode integration** for numbered steps. WatchConnectivity delivery and companion association require an actual paired-device check, not just two independent simulator launches.

### Verification gates

- [x] `python scripts/check_source.py` passes for final source; Windows, 18 October 2026, 199 Swift files/37 test files.
- [ ] `swift test --package-path Packages/SteadyCore` passes on a Mac.
- [ ] The iOS simulator build succeeds with no new warnings, including Swift 6 delegate isolation and SwiftData integration.
- [ ] The Watch simulator build succeeds with no new warnings, including WatchConnectivity and local durable storage.
- [ ] Device: paired Watch shows current priority/next action and honest cached age; unsupported/unpaired/unreachable transport leaves the iPhone usable alone.
- [ ] Device: quick choice, manual movement log, Foundation Done, and saved-meal handoff take at most two taps from the glance, with legible accessibility/VoiceOver labels.
- [ ] Device: disconnected explicit actions remain durably queued through Watch relaunch and arrive once after reconnect; transport submission is never shown as accepted completion.
- [ ] Device: duplicates/late receipts/phone and Watch relaunch do not duplicate a mutation; injected phone save failure yields no success receipt and retry remains same-ID/idempotent.
- [ ] Device: bounded queue/inbox/storage failure states do not silently discard pending actions or hide unsaved mutations.
- [ ] Device: stale day/profile/sample/snapshot/plan/Foundation/saved-record and newly active safety state reject old actions without changing the new state.
- [ ] Device: low-data mode removes sensitive transport fields and display details, including on relaunch and stale snapshots; mode changes invalidate old action scope.
- [ ] Device: saved-meal handoff opens the correct confirmed record for phone review without searching, eating/completion, allergy-safety claims, or automatic Remember confirmation.
- [ ] Regression: phone-only and denied/missing-data flows remain usable; no Watch action writes Calendar/HealthKit, schedules a notification, invokes an advisor, or applies a default change.

Use README section **17. Phase 6 physical-device acceptance**. Record each pass, failure, and not-run case separately; sample transport does not prove real WatchConnectivity delivery.

### Evidence

- Source implementation/review: prepared on Windows, 18 October 2026. The repository contains 199 Swift files, including 37 test files and 299 `@Test` declarations: 252 previously present plus 47 Phase 6 declarations across four test suites and their helper file. The prior 55 Phase 5 declarations and earlier local work are preserved. Declarations are not test executions.
- Final static source command/result: `scripts/check_source.py` run with the configured Python interpreter **PASSED** for 199 Swift files/37 test files, including Watch no-HealthKit/EventKit/FoundationModels and no arbitrary file/network action guards. Portable rerun: `python scripts/check_source.py`.
- Final syntax/source audit: tree-sitter 0.26.0 with Swift grammar 0.7.4 parsed all 199 Swift files with no error or missing nodes. No production force unwraps, unexpected control/replacement characters, or multi-statement missing-return candidates were found. The explicit initializer-label audit covered 594 calls across 111 local types without a finding. These are static audits, not Swift compilation or type checking; WatchConnectivity/SwiftData/SwiftUI background handling remain uncompiled on this Windows host.
- Final diff whitespace check: `git diff --check` **PASSED**, including the final documentation update.
- Core Swift test command/result: **NOT RUN**. Swift is unavailable on this Windows host; run `swift test --package-path Packages/SteadyCore` on the Mac.
- iOS simulator build: **NOT RUN**; requires macOS/Xcode and an integrated project.
- watchOS simulator build: **NOT RUN**; requires macOS/Xcode and an integrated project.
- Xcode project: not created; follow the numbered README integration, never synthesize `project.pbxproj`.
- New Xcode warning count: unknown; builds not run.
- Real paired iPhone/Watch checks: **NOT RUN**.
- Reviewed primary Apple references: [WatchConnectivity data-transfer sample](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity), [`updateApplicationContext`](https://developer.apple.com/documentation/watchconnectivity/wcsession/updateapplicationcontext(_:)), [`transferUserInfo`](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferuserinfo(_:)), and SwiftUI [`BackgroundTask.watchConnectivity`](https://developer.apple.com/documentation/swiftui/backgroundtask/watchconnectivity). Documentation review does not prove SDK compilation, suspension behavior, companion association, or paired-device delivery.
- Review decision: source review and static checks completed. The reviewed paths bind captured UI buttons to their displayed snapshot; retain same-ID durable actions until typed phone receipt; commit phone mutation/receipt atomically; refuse stale scope, option, safety, and save failures; validate local watermark/outbox integrity; handle rejected future-timestamp receipts; and keep saved-meal handoff separate from Remember/eating. Phone snapshots expire after fifteen minutes or Singapore midnight. Watch SwiftUI connectivity background handling receives local data/receipts only; phone mutations wait for fresh foreground context. Disconnected cached views cannot learn privacy-setting changes until expiry or a newer frame. No remaining concrete source-review finding was identified, but Apple SDK type checking, SwiftData reload/failure behavior, physical pairing/reconnect/relaunch/low-data/VoiceOver/two-tap checks remain unverified. Phase acceptance is pending those gates. No commit, push, Phase 7 implementation, or delivery guarantee is part of this continuation; earlier local Phase 3/4/5 work is preserved.

---

## Phase 7 - Weekly learning

**Outcome:** a five-to-ten-minute review identifies patterns, proposes one experiment, and changes defaults only with approval.

**Authority/status:** the user explicitly requested Phase 7 on 18 October 2026 after the status report stated that it had not started (D48). Source is prepared and static/syntax checks passed on Windows. This authorises source work, not acceptance of Phase 1/2/3/4/5/6, whose Mac/device gates remain pending, as do Phase 7's Apple-platform gates. No release-ready, publication, commit, push, or actual deletion of the developer's records is implied. Checked source boxes describe implementation/review only, never Swift or Apple-framework runtime evidence.

The Phase 6 Evidence block above preserves its historical handoff; D48 subsequently authorises this source work without rewriting those results.

### Source scope

- [x] Add deterministic Monday-start Singapore weekly windows and explicit observed-day/night coverage; preserve missing data as unknown.
- [x] Separate runtime actual sleep and in-bed opportunity proxy, app-owned plan/change/choice state, Foundation responses, explicit manual movement, confirmed saved-food corrections, and user-stated helpfulness. The in-bed proxy counts only readable nights with asleep data; no runtime Health aggregate is copied into review history.
- [x] Do not invent historical completion times, food consumption, helpfulness, telemetry denominators, spending, savings, treat quotas, or a moral score.
- [x] Offer an evidence-labelled, non-intensifying Exam-mode proposal only after three distinct changed-plan days; apply only after fresh explicit approval, never on cancel/dismiss/refresh/relaunch. Sample mode cannot propose/apply this shared real-profile default.
- [x] Validate proposal identity, profile/sample/week/revision/current default, thirty-minute/same-local-day freshness and expiry; safety remains independent authority.
- [x] Let the user explicitly select one two-to-fourteen-day experiment with start/end dates and a simple self-report measure; reject overlapping/stale state, retain ended history, and permit a later non-overlapping trial. The UI exposes selection/elapsed status, not an early-end control.
- [x] Persist minimal weekly review/helpfulness, experiment, and new local-only metric records. Never backfill unobserved suggestion history from older records.
- [x] Expose unsupported metrics as unavailable rather than guessing historical suggestion counts, alternative completion, correction rate, or time to choose. New Week-card approvals/time/helpfulness are explicit; out-of-bound decision durations remain unavailable, not clamped invented measurements.
- [x] Export typed app-owned local records as JSON through a user-invoked share sheet; all fourteen model tables, known preferences, and pending phone companion inbox have explicit normal-mode coverage. Any low-data profile makes the entire multi-profile archive metadata-only; payload details are omitted before decoding. A revocable memory lease rejects changed profile/privacy/reset scope. No import/restore is implemented.
- [x] Add explicit delete-all confirmation with app-local cleanup, in-flight invalidation, reminder/transport/advisor cleanup, honest partial-failure/recovery, and no HealthKit/EventKit deletion. Type DELETE, then confirm within fifteen minutes on the same local day/current privacy scope. A fresh model context prevents registered pre-reset models from reappearing.
- [x] Invalidate old companion scope and provide a minimal Watch clearing control frame without promising immediate erase of a disconnected Watch or accepting stale actions into a new profile. Preserve only the non-personal generation journal; readable Watch records clear selectively, while unreadable stores fail closed rather than wiping unknown newer data. Reset-day proactive reminders stay quiet until the next Singapore day to prevent budget refund.
- [x] Keep advisor activity independently clearable without deleting wellness records or changing opt-in.
- [x] Author edge-case core tests for aggregation, missing coverage, explicit telemetry, default approval/cancel/stale state, experiments, export projection/redaction, strict erase-control schema, generation-preserving outbox cleanup, and reset-day nudge blocking. SwiftData/share-sheet/delete cancellation/failure/recovery remain manual Apple-platform gates; core declarations do not execute those framework paths.
- [x] Run final static/syntax/diff checks and record exact counts/results below.

### Xcode integration - required on a Mac

- [ ] Complete earlier project/package/signing/capability setup through Xcode without editing `project.pbxproj`.
- [ ] Verify weekly review, weekly persistence, and data-controls files belong to the iPhone target; both targets retain the appropriate shared companion transport source.
- [ ] Verify the model container includes `WeeklyReviewRecord`, `WeeklyExperimentRecord`, and `WeeklyMetricRecord` alongside every earlier app model. Existing development stores must retain prior records during migration.
- [ ] Add no remote analytics SDK, backend, cloud entitlement, network service, new permission prompt, HealthKit write request, or Calendar deletion authority.
- [ ] Verify JSON sharing and local deletion on a disposable development store, including interrupted/failed cleanup and paired/offline Watch behavior.

Follow README section **18. Phase 7 Xcode integration** for numbered steps.

### Verification gates

- [x] `python scripts/check_source.py` passes for final source; Windows, 18 October 2026, 227 Swift files/43 test files after the D51 review.
- [ ] `swift test --package-path Packages/SteadyCore` passes on a Mac.
- [ ] The iOS simulator build succeeds with no new warnings, including SwiftData, share-sheet, deletion recovery, and explicit Swift 6 isolation.
- [ ] The Watch simulator build succeeds with no new warnings, including clearing-control handling and old-action rejection.
- [ ] Device: review current/previous Singapore weeks with full/partial/missing Health and app-owned observations; coverage/uncertainty stays explicit and absent data never becomes zero activity or failure.
- [ ] Device: sleep actual and in-bed opportunity proxy remain distinct; plans/changes/intentional rest, completed actions, manual movement, saved-food records, and stated helpfulness are labelled honestly.
- [ ] Device: decline/cancel/dismiss a proposed default and confirm no setting change; approve the exact current proposal once; sample mode never mutates the shared default; profile/sample/week/day/revision/current-setting changes reject stale proposals.
- [ ] Device: one explicit bounded experiment survives relaunch, does not auto-change settings/reminders, and rejects overlap or stale confirmation; elapsed status is honest and a later trial does not overwrite prior history.
- [ ] Device: newly recorded local metrics survive relaunch, unsupported historical metrics remain unavailable, and no remote analytics/network payload is introduced.
- [ ] Device: user-invoked JSON sharing includes each app-owned record category and an explicit limitations/schema manifest. Any low-data profile makes the entire archive metadata-only, without sensitive sleep/recovery/nutrition detail, raw Health samples, full Calendar records, advisor transcript, search, or location history; privacy/profile/reset changes revoke an existing in-memory share lease.
- [ ] Device: cancel/dismiss deletion leaves all records/preferences/transports unchanged. Confirm on a disposable store clears all app-local records, settings/opt-ins, pending/delivered notifications/reservations/inboxes, advisor activity, companion queues/receipts/caches, and pending in-flight work without deleting Apple Health or Calendar records. Only a non-personal reset journal/cutoff remains; reset-day proactive reminders stay quiet until the next Singapore day.
- [ ] Device: injected delete/storage/transport failure or interruption cannot falsely report success, reopen normal mutation against partial deletion, or erase newly created data during recovery. A readable pending journal permits retrying only previously confirmed cleanup; an unreadable journal is unavailable/recheck-only, never a claim of prior confirmation, guessed lower cutoff, or new destructive confirmation over unknown state. App-accessible deletion is not a forensic secure-erase guarantee.
- [ ] Paired-device: connected Watch receives the clearing frame; offline Watch retains only the disclosed expiring prior cache. Queued old-profile actions are rejected after deletion/relaunch/new onboarding and cannot resurrect data. Late clearing controls preserve newer actions; an unreadable Watch cache fails closed with an incomplete-clear message rather than using historical authority to wipe unknown newer records.
- [ ] Device: independent Clear advisor activity leaves wellness/default/reminder/experiment data unchanged; low-data mode and tappable number explanations cover each introduced surface.
- [ ] Device: finish a neutral review within five to ten minutes, verify VoiceOver/readability, and rerun representative earlier-phase phone/Watch/denied-permission/Calendar-confirmation regressions.

Use README section **19. Phase 7 physical-device acceptance**. Record passes, failures, and not-run cases separately. Never test deletion against the user's only copy of important records.

### Evidence

- Source implementation/review: prepared on Windows, 18 October 2026. After the separately authorised D51 review, the repository contains 227 Swift files, including 43 test files and 362 `@Test` declarations: 299 previously present plus 63 Phase 7/review declarations across five suites and a helper file. Four reset-authority regressions were added during that review. Earlier local work is preserved. Declarations are not executed test cases.
- Final static source command/result: `scripts/check_source.py` run with the configured Python interpreter **PASSED** for 227 Swift files/43 test files, including exhaustive fourteen-model container/export/delete coverage, pre-fetch archive capacity, and no raw external-framework imports in privacy services. Portable rerun: `python scripts/check_source.py`.
- Final syntax/source audit: tree-sitter 0.26.0 with Swift grammar 0.7.4 parsed all 227 Swift files with no error or missing nodes. No production force unwraps, unexpected control/replacement characters, or multi-statement missing-return candidates were found. The explicit initializer-label audit covered 667 calls across 132 local types without a finding. These are static audits, not Swift compilation/type checking; SwiftData/ShareLink/WatchConnectivity integration remains uncompiled here.
- Final diff whitespace check: `git diff --check` **PASSED**, including the Phase 7 documentation update.
- Core Swift test command/result: **NOT RUN**. Swift is unavailable on this Windows host; run `swift test --package-path Packages/SteadyCore` on the Mac.
- iOS simulator build: **NOT RUN**; requires macOS/Xcode and an integrated project.
- watchOS simulator build: **NOT RUN**; requires macOS/Xcode and an integrated project.
- Xcode project: not created; follow the numbered README integration, never synthesize `project.pbxproj`.
- New Xcode warning count: unknown; builds not run.
- Real iPhone/Watch checks: **NOT RUN**. No actual user-data deletion was performed during source preparation.
- Review decision: source review and static checks completed. Review fixes include sample-default suppression; same-day/week/revision/current-value approval guards; explicit-only local telemetry without duration clamping or backfill; ended-experiment history and overlap handling; privacy-mode-aware revocable export leases; all fourteen model tables; atomic pending reset journaling with fresh-context relaunch; callback/transport generation fencing; reset-day nudge suppression; and no historical-fence authority to wipe a corrupt newer Watch store. Partial cleanup, unreadable Watch storage, offline clearing, system backups/export copies, and permissions remain honestly bounded. Core declarations and source review do not verify deletion cancellation, SwiftData migration/save failures, JSON share-sheet transfer, or paired-device delivery. Phase acceptance and release readiness remain pending Apple-platform/device evidence. Earlier local Phase 3/4/5/6 work is preserved; no commit or push is part of this request. Stop after Phase 7 source review, not an invented Phase 8 or publication.

---

## Final review and repository handoff - 18 October 2026

- Authority: the user requested another code review followed by a push to the configured GitHub repository (D51). This is separate from the earlier phase handoffs; their historical statements about no commit/push remain historical evidence, not a restriction on this new request.
- Review: independent source passes covered core logic/tests, app integration, and privacy/export/Watch paths. The review fixed a delayed deletion-retry authority edge case, prior-autosave restoration on refused callbacks, stale asynchronous Sleep loads, and low-data sleep/recovery information in Sleep/Today and their Why sheets. No additional concrete source-level finding remained after these fixes. This is not proof of Apple SDK correctness.
- Regression declarations: four new Foundation-only reset-authority tests distinguish explicit fresh confirmation from a readable pending recovery and refuse late retries, invalid revisions, unreadable state, and overlapping start. Total: 362 declarations, **not executed**.
- Available verification: static source checks, all-Swift syntax/source/initializer audit, and diff whitespace checks passed with 227 Swift files/43 test files and 667 audited calls/132 local types. A source/filename scan found no common private-key/credential-token pattern. Such a scan cannot guarantee detection of every possible secret format.
- Git preflight: fetched the configured origin and confirmed `main` had no remote commits to integrate at review time. Commit/push is requested; the actual result and resulting commit are reported in the handoff, not inferred from this preflight.
- Still **NOT RUN**: Swift tests, iOS/watchOS builds, migration/failure injection, system sharing, delayed recovery callbacks, Sleep real/sample/profile/day/privacy races, and physical paired-device checks. No actual wellness record was deleted by this review. Follow README sections 18-19 plus the new Sleep cases before accepting a release.

## Definition of done for every phase

- [ ] New decision logic lives in `SteadyCore` and has edge-case tests.
- [ ] `swift test` and both simulator builds pass on a Mac with no new warnings.
- [ ] Sample/manual fallback works when permission is denied or data is missing.
- [ ] No guilt language, diagnosis, unsafe intensification, invented fact, or unconfirmed consequential action.
- [ ] Low-data mode is respected by every surface introduced in the phase.
- [ ] `README.md`, this file, and `DECISIONS.md` contain accurate status and evidence.
- [ ] The user accepts the phase before work begins on the next one, or explicitly authorises source work for a named phase with the unrun gates recorded (D26); acceptance is never inferred from that exception.
