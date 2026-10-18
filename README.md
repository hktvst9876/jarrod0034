# Steady

Steady is a private, local-first iPhone and Apple Watch wellness app for one college student in Singapore. It turns permitted HealthKit and Calendar context into one realistic daily priority, explains why, and always keeps a manual fallback available.

## Current status

**Phase 7 - Weekly learning: source prepared; static and syntax checks passed; Mac verification pending.**

Phase 1 Foundation source is present: a Foundation-only `SteadyCore` package, onboarding, Today/Sleep/Settings, protocol-backed HealthKit and Calendar services, local profile persistence, and a Watch placeholder. Phase 1 Mac integration, simulator builds, and physical-device acceptance are still pending.

The user expressly requested Phase 2 on 17 October 2026, then Phase 3 and Phase 4 on 18 October 2026 after the outstanding gates were disclosed. Following the Phase 4 source handoff, the user requested continuation and Phase 5 Live-food scope was announced (D41). These requests authorise source work, without accepting earlier unrun gates. Phase 2 adds explicit outcomes, user-selected barriers, distinct alternatives, Choose/Later/Rest actions, local plan persistence, and an explicit calendar confirmation boundary.

Phase 3 adds six local Foundation families, saved Done/Replace/Snooze/Disable choices, explicit movement preferences, optional quiet reminders, a pure nudge planner, and a conservative device-wide daily reminder budget. Cards work without notification permission; sample mode never schedules real notifications.

Phase 4 adds a required deterministic TemplateAdvisor and one validating coordinator, with optional, default-off Apple on-device ordering of existing Alternatives. The model may return only a permutation of opaque candidate IDs: it cannot change canonical text/facts, choose a plan, schedule a reminder, write Calendar, or infer a diagnosis. A minimal typed packet omits HealthKit-derived measurements, recovery labels, SafetyGate symptom/alert records, calendar details, and free text. Normal mode may include the explicit user-selected barrier enum, which can describe soreness, stress, or low energy; low-data mode omits that barrier. This is a stated selection, never a model inference. Diagnostic activity stays bounded in memory and can be cleared independently of wellness records. Sample mode always stays deterministic.

Phase 5 adds user-triggered Eat discovery, evidence-labelled places/saved dishes, deterministic dietary/allergen handling, and explicit Remember confirmation. MapKit discovers venues, not verified menus: price, opening status, ingredients, and nutrition stay unknown without matching evidence. No reviewed SG FoodID dish/portion dataset or official-menu/ingredient catalog is bundled. Current live venues and manual observations therefore remain places/records to check, not primary meal recommendations; nutrition stays unavailable without a defensible match. Saved corrections are dated prior-visit evidence, not a guarantee of current ingredients or allergy safety.

Following that handoff, the user requested continuation on 18 October 2026 and Phase 6 Apple Watch scope was announced (D44). The implementation adds a cached priority/next-action glance, quick alternatives, explicit manual movement logging, Foundation Done, and saved-meal handoff. Latest phone snapshots use `updateApplicationContext`; durable explicit actions and typed receipts use `transferUserInfo`. Queueing is not acceptance. Phone-side current-state/safety validation and atomic apply-once persistence protect against stale or repeated actions. Captured Watch buttons remain bound to their displayed snapshot rather than retargeting a newer profile/day. These are implemented/reviewed source paths, not observed WatchConnectivity or tap-count evidence.

The user explicitly requested Phase 7 on 18 October 2026 after the status report explained that it had not started (D48). Weekly-learning source covers a Singapore Monday-start review with honest coverage, a narrow evidence-labelled Exam-mode proposal applied only after approval, one explicitly selected bounded experiment, local-only evaluation/helpfulness, JSON sharing, and confirmed app-local data deletion. Sample evidence cannot change the real profile's Exam-mode default. Missing observations do not become zero activity, remembered dishes do not become meals eaten, and new evaluation does not invent older interaction history. A disconnected Watch cannot be erased immediately; old companion actions must not resurrect deleted records. This is source authority, not acceptance of earlier tests/builds or an approved release.

No phase is accepted from a Windows source review alone. On 18 October 2026, `scripts/check_source.py` passed for 227 Swift files/43 test files. Tree-sitter 0.26.0 with Swift grammar 0.7.4 parsed all 227 without error/missing nodes. Source audits found no production force unwraps, unexpected control/replacement characters, or multi-statement missing-return candidates. The explicit initializer-label audit covered 667 calls across 132 local types without a finding; `git diff --check` passed. These audits are not Swift compilation or type checking.

There are 362 authored `@Test` declarations: 299 previously present plus 63 Phase 7/review declarations across five suites and a helper file. All earlier local work is preserved. Written declarations are not passing test executions. Repeated saved dish/place labels are collapsed for display so they cannot fill the results with duplicates; matching labels never prove venue identity or factual provenance.

The user separately authorised final review, commit, and GitHub push (D51). That review fixed a delayed deletion-retry authority edge case, preserved the prior autosave policy on refusal, fenced asynchronous Sleep loads, and removed hidden sleep/recovery details from low-data Sleep/Today displays and their explanations. Four new pure reset-authority regressions were authored. A source/filename scan found no private-key or common credential-token patterns; this is not a guarantee that every possible secret format is detectable. Mac tests/builds and device acceptance remain pending, including the new Sleep race/privacy and delayed-retry cases.

No Swift tests were executed: Swift and `xcodebuild` are unavailable on this Windows host. The Apple-framework adapter branches remain uncompiled. No Xcode project, simulator build, or physical-device verification is claimed. Phase 3, Phase 4, Phase 5, Phase 6, and current Phase 7 changes remain local and uncommitted; this continuation includes no commit or push. No actual user-data deletion was performed. The authoritative evidence and pending gates are in [docs/MILESTONES.md](docs/MILESTONES.md).

## Approved release-1 boundaries

- Native Swift 6 and SwiftUI; iOS 18 and watchOS 11 minimums.
- Deterministic local planning is always available. Phase 4's optional on-device Foundation Models ordering requires a supported iOS 26+ Apple Intelligence device, current model availability, explicit opt-in, and a user request. There is no cloud advisor in release 1.
- Food results must carry source, freshness, and uncertainty. Use MapKit for user-triggered discovery, cited SG FoodID data where applicable, and remembered user corrections. Do not invent menus, prices, ingredients, opening hours, or nutrition.
- A maximum price per meal is optional. There is no weekly spend ledger and no estimated "money saved" feature.
- Cravings are ordinary user-selected barriers. Release 1 has no dedicated Urge screen, treat quota, or moral scoring.
- Raw HealthKit samples, calendar event details, history, and preferences stay on the device. Every calendar write and every remembered correction requires confirmation.

## Repository map

```text
Steady/
|-- Packages/SteadyCore/       Foundation-only rules, alternatives, Foundations, nudges, advisor, food, Watch sync, weekly learning, and tests
|-- Shared/CompanionConnectivity/ Apple transport/inbox sources shared by both app targets
|-- Steady/                    iPhone target sources
|   |-- App/
|   |-- Features/
|   |-- Services/
|   |-- Persistence/
|   `-- Resources/
|-- SteadyWatch Watch App/     watchOS target sources
|-- docs/                      product spec, phases, decisions, prompts, seed data
|   `-- planning/              approved proposal, data model, audit notes, handoff, original starter
|-- AGENTS.md                  coding rules
`-- SETUP.md                   original starter setup; use the steps below for this source-first repo
```

The planning rationale and proposed model are in [docs/planning](docs/planning): [PROPOSAL.md](docs/planning/PROPOSAL.md), [DATA_MODEL.md](docs/planning/DATA_MODEL.md), and [AUDIT_NOTES.md](docs/planning/AUDIT_NOTES.md). The untouched original starter kit is archived in [docs/planning/original-starter](docs/planning/original-starter) for history only.

## Mac and Xcode setup - beginner steps

These steps intentionally use Xcode for project membership, capabilities, signing, and package linkage. Never edit `project.pbxproj` by hand.

Earlier phase procedures retain their original source-scope boundaries and placeholder expectations as historical gates. For the current Watch source use sections 16-17, and for weekly learning/data controls use sections 18-19; neither marks earlier unrun gates accepted.

### 1. Install and prepare Xcode

1. On the Mac, install the current Xcode from the Mac App Store.
2. Open Xcode once, accept the licence, and let it install components.
3. Choose **Xcode > Settings > Components** and install an iOS 18-or-later simulator and a watchOS 11-or-later simulator.
4. Choose **Xcode > Settings > Accounts > +**, sign in with the Apple ID, and confirm a **Personal Team** appears.
5. Copy this entire `Steady` repository to the Mac, for example to `~/Developer/Steady`.

### 2. Create the iPhone project without overwriting source

1. In Finder, confirm `~/Developer/Steady` contains `AGENTS.md`, `docs`, and the source folders. Back it up or commit it before continuing.
2. In Xcode choose **File > New > Project... > iOS > App > Next**.
3. Enter:
   - **Product Name:** `Steady`
   - **Team:** your Personal Team
   - **Organization Identifier:** a permanent reverse-domain value such as `com.yourname`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Testing System:** Swift Testing
   - **Storage:** None
4. Save the temporary scaffold beside the repository, for example as `~/Developer/Steady-Xcode-Scaffold`. Leave **Create Git repository** off.
5. Quit Xcode. In Finder, move `Steady.xcodeproj` from the temporary scaffold into `~/Developer/Steady`. Do not move the generated `Steady` source folder and do not replace any repository file.
6. Reopen `~/Developer/Steady/Steady.xcodeproj`.
7. In the Project navigator, select the generated yellow/blue `Steady` source entry and press Delete. Choose **Remove Reference**, never **Move to Trash**.
8. Drag the repository's `~/Developer/Steady/Steady` source folder from Finder into the Project navigator directly under the project.
9. In the sheet, choose **Create folder references** or **Synchronize groups with folder** (wording depends on Xcode), tick target **Steady**, and click **Finish**. The folder must remain synchronized so new Swift files are discovered automatically.
10. Select the blue project icon, select target **Steady**, then **General**. Set **Minimum Deployments > iOS 18.0** and confirm the bundle identifier begins with the organization identifier.
11. With target **Steady** selected, open **Build Settings**, search for **Swift Language Version**, and choose **Swift 6**.
12. Still in **Build Settings**, search for **Default Actor Isolation**. If that setting is present, choose **Nonisolated**. The source marks UI state `@MainActor` and services as actors explicitly; it does not assume a target-wide MainActor default.

If Xcode offers to replace files at any point, cancel and check that you selected **Remove Reference** rather than deleting files on disk.

### 3. Add the Watch app target

1. Choose **File > New > Target... > watchOS > App > Next**.
2. Set **Product Name** to `SteadyWatch`.
3. Choose **Watch App for Existing iOS App** and select **Steady** as the companion app. Use SwiftUI and Swift. Click **Finish**.
4. If Xcode asks to activate the new scheme, click **Activate**.
5. Remove only the newly generated Watch source reference from the Project navigator using **Remove Reference**.
6. Drag the repository folder `SteadyWatch Watch App` into the navigator, choose a synchronized folder/group, tick only the Watch app target, and click **Finish**.
7. Select the Watch app target > **General** > set **Minimum Deployments > watchOS 11.0**.
8. Select **Build Settings**, set **Swift Language Version** to **Swift 6**, and set **Default Actor Isolation** to **Nonisolated** if that setting is present.

### 4. Link the local SteadyCore package

1. In Xcode choose **File > Add Package Dependencies...**.
2. Click **Add Local...**.
3. Select `~/Developer/Steady/Packages/SteadyCore` and click **Add Package**.
4. In the product sheet, select library **SteadyCore**, choose target **Steady**, and click **Add Package**.
5. Select the blue project icon > Watch app target > **General > Frameworks, Libraries, and Embedded Content > +**.
6. Select **SteadyCore** and click **Add**. Leave it set to **Do Not Embed** when Xcode presents an embed choice.
7. For both targets, open **Build Phases > Link Binary With Libraries** and verify `SteadyCore` appears once.

The package declares Swift tools 6.0. The two app targets must also compile in Swift 6 mode so concurrency checks are consistent.

### 5. Signing and capabilities

For target **Steady**:

1. Open **Signing & Capabilities**.
2. Tick **Automatically manage signing** and select the Personal Team.
3. Click **+ Capability > HealthKit**.

For the Watch app target:

1. Open **Signing & Capabilities**.
2. Tick **Automatically manage signing** and select the same Personal Team.
3. Click **+ Capability > HealthKit**.

Do not add iCloud, CloudKit, push notifications, Family Controls, or a third-party entitlement.

### 6. Privacy keys

Select the iPhone target > **Info** > add these rows:

| Xcode key | Value |
|---|---|
| Privacy - Health Share Usage Description | Steady reads your sleep and activity data to suggest a realistic plan. |
| Privacy - Health Update Usage Description | Steady saves only health entries you explicitly log. |
| Privacy - Calendars Full Access Usage Description | Steady checks your availability and adds plans to its own calendar only when you confirm. |

Also add these Phase 5 iPhone rows for optional nearby food:

| Xcode key | Value |
|---|---|
| Privacy - Location When In Use Usage Description | Steady uses your approximate location to find food nearby when you ask. |
| Location Default Accuracy Reduced | YES (Boolean) |

The second key's raw name is `NSLocationDefaultAccuracyReduced`; create a Boolean row, not a text value. Do not add Always location usage, temporary full-accuracy purposes, or background location. See section 14 for the numbered Phase 5 checks.

Select the Watch target > **Info** and add:

| Xcode key | Value |
|---|---|
| Privacy - Health Share Usage Description | Steady reads sleep and activity data for your watch glance. |
| Privacy - Health Update Usage Description | Steady saves only health entries you explicitly log. |

The source names behind the Xcode labels are `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`, `NSCalendarsFullAccessUsageDescription`, `NSLocationWhenInUseUsageDescription`, and `NSLocationDefaultAccuracyReduced`.

### 7. Verify the shared core and both apps on the Mac

In Terminal, from `~/Developer/Steady`, run:

```bash
swift test --package-path Packages/SteadyCore
xcrun simctl list devices available
xcodebuild -project Steady.xcodeproj -scheme Steady \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -project Steady.xcodeproj -scheme 'SteadyWatch Watch App' \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

If your installed simulator names differ, copy exact names from the `simctl` output into the two destination strings. A phase gate passes only when the core tests and both builds succeed with no new warnings.

### 8. Verify on a real iPhone and Watch

1. Connect and unlock the iPhone, trust the Mac, and enable Developer Mode on the iPhone. Keep the paired Watch nearby and enable its Developer Mode.
2. In Xcode select scheme **Steady**, select the iPhone, and press Run.
3. Complete or skip onboarding. Deny Health and Calendar once: the app must remain usable with sample/manual fallback and no crash.
4. In Settings turn **Use Sample Data** on. Confirm Today shows one priority with a plain-language reason, Sleep shows sample context, and the five tabs are **Today, Move, Sleep, Eat, Week**.
5. Turn sample data off. Grant Health read access and Calendar full access when the app explains why. Confirm Today and Sleep handle real or missing data neutrally.
6. Confirm no calendar event is created merely by viewing Today or Sleep.
7. Select the Watch scheme, choose the paired Watch, and press Run. Confirm the Steady placeholder/glance launches.

Record the exact Xcode version, simulator destinations, test output, and device observations in `docs/MILESTONES.md`. Only then may Phase 1 be marked complete.

### 9. Phase 2 physical-device acceptance

Complete the Xcode setup above first. Keep a separate record of each result in the Phase 2 Evidence section of `docs/MILESTONES.md`. Sample-mode results do not prove that real EventKit access or writes work.

For independent cases after intentional rest/completion, use **Choose another priority** to select a fresh movement plan. Keep the same plan throughout the confirmed creation, reschedule, and external-deletion checks so event identity can be verified.

1. **Options and explanations:** enable **Use Sample Data**, open Today, select a movement priority when no safety flag is active, then tap **Find another option**. The Move tab also opens the flow with **Shorter or different**. Select barriers such as no time, low energy, or bad weather. Expect two or three primary choices with different effort levels. Each shows duration and its explanation, benefit kept, tradeoff, steps, and the outcome parts kept or omitted. **Choose this**, **Later**, and **Rest on purpose** remain separate actions.
2. **Choose without Calendar:** choose a smaller alternative. Return to Today, refresh, force-quit, and reopen during the same Singapore local day. Expect the chosen app plan to remain, without being marked completed and without a calendar event. Repeat with low-data mode enabled; the alternatives must remain usable without exposing hidden recovery or calorie details.
3. **Rest on purpose:** select **Rest on purpose** and repeat the same-day refresh/relaunch. Expect intentional rest to remain an explicit choice, with no workout completion and no calendar write.
4. **Cancel or dismiss Later:** select **Later**, pick a valid future time, and inspect the proposal sheet. Check the title, date, start, end, and reason. Tap **Cancel**, then repeat by dismissing the sheet. Inspect Apple Calendar and reopen Steady: no event was created or moved, and the prior active plan remains.
5. **Confirmed creation:** turn sample data off, grant Calendar full access when explained, and choose **Later** again. Before confirming, verify there is no new event. Tap **Confirm** once. Expect exactly one event in Steady's own calendar and a scheduled plan in Today. Refresh and reopen: no duplicate event appears.
6. **Confirmed reschedule and ownership:** propose a different future time for that scheduled plan. Cancel once and verify the event is unchanged; confirm a new proposal and verify the same tracked Steady-owned event moves rather than creating a duplicate. Then move from time A to B and back to A: each separately reviewed confirmation must work, without being mistaken for an old retry. An unrelated event with a matching title must remain untouched.
7. **Denied Calendar:** in iPhone **Settings > Apps > Steady > Calendars** (or **Settings > Privacy & Security > Calendars**), deny access. Reopen Steady and try **Later**. Expect the **Keep for later without Calendar** manual action, no claimed successful schedule, and no calendar write. **Choose this** and **Rest on purpose** must remain available. Save for later manually and relaunch: its app-only deferred state remains. Restoring access must not replay a cancelled or denied proposal automatically.
8. **Externally deleted event:** with a confirmed event present, delete it in Apple Calendar. Return to Steady, refresh, force-quit, and reopen. Expect the plan to become unscheduled; refresh and relaunch must never recreate the event. Its Later flow must explain that the event was removed and leave it unscheduled. Creating a separate new plan after deletion is later scope.
9. **Safety changes:** prepare an exercise alternative or an unconfirmed Later proposal, cancel/dismiss it, then return to Today and tap **Report pain or a concerning symptom**. Choose a symptom you are explicitly testing in this development build. Expect safety guidance to take priority and movement alternatives to be disabled; no cancelled proposal may write. Reopen on the same local day and verify the stored symptom still prevents an old movement plan from replacing safety guidance. Automated tests separately cover a safety change at the confirmation boundary.
10. **Movement preferences and other barriers:** in Alternatives, select seated or wheelchair mode. To test avoids, first save a movement-to-avoid note in Settings, reopen Alternatives, explicitly select the typed movements to omit, and tap **Use these preferences**. Verify basic substitutions follow those choices without inferring an injury. Mode/avoid choices are local to this Alternatives request in Phase 2; the note is not automatically interpreted. Check late hunger, delivery preference, sweet drink preference, and phone use in bed through the ordinary barrier flow, without a separate Urge screen or any quota/score. Food suggestions must not claim unknown prices, ingredients, nutrition, or allergy safety.
11. **Watch regression:** run the Watch scheme on the paired Watch. Its existing placeholder/glance still launches; full Watch alternatives and sync remain Phase 6.
12. **Future plan:** when a suitable tomorrow window is available, confirm it, then verify Start is unavailable before its saved time. Reopen on the scheduled local day: the deferred plan should carry forward if there is no separate plan for that day. Once due, starting makes it active; completion requires a separate explicit completion action. After starting and after completion, relaunch again and verify that the same chosen plan remains on that scheduled day without duplicate active plans or calendar events. A deferred future plan must not be marked complete early.

The precise system Settings path may vary with iOS version. A missing calendar account, denied access, failed save, or deleted event must leave Steady usable and display the resulting state honestly. Phase 2 remains unaccepted until core tests, both simulator builds, and these physical-device checks have recorded results.

If testing an interrupted Calendar save, stop the development process after EventKit returns but before the local success is saved, then reopen Steady. Expect **Review an unfinished Calendar save**, never an automatic retry. **Review previous time** must show the exact earlier proposal; only another **Confirm** may retry it, without creating a duplicate. **Clear Calendar retry** requires the **Clear retry** confirmation and explains that an earlier event may exist; it must not delete or modify Calendar data. After a definitive denied-access failure, Choose/Rest must work without requiring this recovery step.

Today also exposes **Unfinished Calendar save > Clear Calendar retry** when the plan is completed, intentionally rested, or blocked by safety. That recovery must remain reachable without reopening exercise alternatives; clearing it must not write or delete an event.

For a controlled-clock regression in a development build, capture an alternatives/proposal sheet, advance the injected time across local midnight, then attempt its action. It must refresh or refuse the stale day rather than mutate the new day's plan. Repeat against a replaced priority or switched profile. Do not change the device's system time merely to run this check.

### 10. Phase 3 Xcode integration

Complete the earlier project setup first. Phase 3 uses local notifications, not remote push.

1. In Xcode, confirm the synchronized iPhone source folder includes `Features/Foundations`, the Foundation persistence files, and `Services/Notifications`. Keep these app files out of the Watch target. The shared package discovers its new `Foundations` and `Nudges` sources/tests automatically.
2. Confirm `SteadyApp`'s `ModelContainer` includes `FoundationPreferenceRecord`, `FoundationDayRecord`, and `FoundationResponseRecord`, alongside the existing profile/plan/choice models. Run once with an existing development store and verify saved profiles/plans remain available. Do not erase a user's store to hide a migration error.
3. Keep the existing HealthKit and Calendar configuration. `UserNotifications` is an Apple system framework. Local notifications need no APNs key, Push Notifications entitlement, background mode, server, or notification-specific Info.plist usage-description key. Do not add remote-push capabilities.
4. Run the app and open Today > **Foundations**, or Settings > **Foundation preferences and reminders**. **Review and enable reminders** explains optional use before Apple's prompt. **Not now** must leave the in-app cards usable without requesting permission. A saved reminder preference is not proof of current system authorization.
5. Run the core tests and both simulator builds from section 7. Record exact commands/results in the Phase 3 evidence block, then run the physical-device cases below. The Watch remains a Phase 1 placeholder/glance; no Phase 6 sync is claimed.

### 11. Phase 3 physical-device acceptance

Use a development build, record each pass/failure/not-run separately, and do not treat a sample reminder as real notification evidence. Use injected time/context for clock-boundary tests rather than changing the device clock.

1. **Six useful families:** open Foundations from Today and Settings. Verify after-waking mobility, morning daylight, water with a meal, study breaks, quiet preparation, and wind-down. Each duration has a tappable explanation. Hydration has no volume target or timer; daylight says never to look at the sun and offers shade/weather opt-out; wind-down starts small. No streak or completion target appears.
2. **Saved actions:** independently test **Done**, **Replace**, **Snooze**, **Disable this Foundation**, and **Enable this Foundation**. Refresh, force-quit, and reopen on the same Singapore day: state must remain. Replacement is not completion. Snooze expires or can be shown now; a new local day resets daily progress but retains disabled kinds and preferences. Invalid past/cross-midnight snoozes must be refused, not silently scheduled.
3. **Movement and safety:** save standing, seated, and wheelchair preferences with explicit avoided-movement controls. Confirm incompatible options disappear without guessing from the saved free-text note. If none fit, expect a neutral unavailable message. Report a safety symptom through Today, then reopen Foundations: safety guidance supersedes stored movement suggestions, and old actions/reminders cannot bypass it. Disabling remains available.
4. **Permission boundaries:** with real mode selected, tap **Review and enable reminders**, cancel the explanation, then repeat and deny Apple's prompt. Cards and all manual choices must still work. Grant access through system Settings, reopen, and explicitly enable reminders. Turning reminders off cancels Steady's pending requests. Health/Calendar permission must remain separate.
5. **Quiet and blocked windows:** add an overnight quiet period and an all-day period (equal start/end); save explicitly. With controlled development context, also provide planned sleep, timed Calendar blocks, and workout blocks. Candidates must move to a valid same-day gap or drop with a reason; none may fire inside a blocked interval. Calendar denial/unavailable context yields silent Today cards, not a claimed free slot. Unknown workouts are not treated as a known empty history.
6. **Conservative daily ceiling:** in a controlled development scenario request more than the daily allowance, repeat refresh/relaunch, snooze, disable a type, cancel pending requests, and simulate a failed scheduling call. At most three distinct proactive reservations may be made for a Singapore day across real profiles. Cancelled/failed reservations are not automatically refunded; receiving fewer notifications than the ceiling is expected. A snooze never bypasses the ceiling.
7. **Dismissal learning:** use controlled persisted responses to dismiss the same type twice: subsequent proactive consideration uses a two-local-day cooldown (every other Singapore local day). Four dismissals pause that type. **Resume reminders for this Foundation** explicitly restores consideration; marking it **Done** also resets that type's dismissal count. Merely opening a notification, replacing/enabling an option, or foreground refresh must not reset it. Other kinds remain unaffected.
8. **Notification delivery and actions:** test a due real reminder outside blocked windows. Expect ordinary active delivery, no sound, and no time-sensitive/critical interruption. In the foreground expect a quiet in-app update rather than a second banner. Test Done, Snooze, Disable, notification open, and dismissal: callbacks are durably queued and applied once when the matching app state is loaded on the foreground. Open a reminder while Move or Sleep is selected: it must route to Foundations from that tab, not depend on Today being visible. Merely opening it must not reset dismissal history. Replaying a response must not duplicate history or completion. Done/Snooze from an old day or replaced option must be ignored with an honest stale-action message.
9. **Low-data and samples:** enable low-data mode and inspect cards plus notification text: no recovery/readiness label, calorie count, weight trend, or raw Health measurement appears. Enable **Use Sample Data**, select **Try simulated reminders**, and test actions: no request may reach the device's real notification center. Sample preferences/history remain separate from real mode.
10. **Freshness and storage:** add/change a Calendar block or workout after scheduling, then foreground the app: pending current-day requests must be reconciled against fresh permitted context. Inject a storage failure: do not claim the action was saved or the request scheduled; retry must remain idempotent. Background delivery uses the last foreground snapshot; Phase 3 makes no continuous background refresh guarantee or multi-day scheduling promise.
11. **Regression:** existing Today/Move/Sleep, alternatives, confirmed Calendar writes, denied-data fallbacks, and the Watch placeholder must still work. New Foundation actions must never create Calendar events, Health samples, remote analytics, or network traffic.

The operating system may delay delivery or suppress banners according to its settings; reservation counts are a conservative planning ceiling, not evidence of actual delivery. Keep Mac tests/builds and physical-device checks pending until observed results are recorded.

### 12. Phase 4 Xcode integration

Complete the earlier setup first. Phase 4 does not raise the iOS 18 or watchOS 11 deployment targets and does not add a backend, model key, cloud entitlement, or network dependency.

1. To build the optional adapter, install an Xcode release whose iOS SDK includes Apple's `FoundationModels` framework (iOS 26 SDK or later). Open **Xcode > Settings > Components** and install an appropriate simulator. Keep the iPhone target minimum at **iOS 18.0**, the Watch minimum at **watchOS 11.0**, Swift 6, and the explicit actor-isolation settings from the earlier steps.
2. In the synchronized iPhone folder, confirm the new advisor services and Settings section are members of **Steady** only. `FoundationModels` must never be imported into `SteadyCore` or the Watch target. The local package discovers its Foundation-only advisor sources/tests automatically. Do not synthesize or edit `project.pbxproj`.
3. Keep `#if canImport(FoundationModels)` SDK guards and iOS 26 runtime checks intact. With an older SDK or on an older/unsupported/unready system, the app must compile/use the deterministic fallback rather than require Foundation Models. A simulator result is not proof that physical-device Apple Intelligence is available.
4. Keep existing HealthKit, Calendar, and local-notification configuration unchanged. Phase 4 requests no new Health, Calendar, location, notification, network, or cloud permission. No API key or model-download workflow is part of Steady.
5. On a supported iPhone, enable Apple Intelligence using Apple's system settings if desired and allow its system-managed availability process to finish. Steady checks current model availability; it does not promise support or download a model itself. In Steady Settings, **On-device alternative ordering > Use on-device ordering** is off until explicitly enabled.
6. Run `swift test --package-path Packages/SteadyCore`, then both simulator builds from section 7. Record exact Xcode/SDK versions, commands, destinations, warnings, and results in Phase 4's Evidence block. Build/check the fallback path as well as the modern-SDK path. Complete the physical-device cases below before marking the phase accepted.

### 13. Phase 4 physical-device acceptance

These cases require the integrated development app. Keep a separate pass/fail/not-run record; authoring source or parsing Swift syntax is not execution evidence. Use injected development providers/clocks for controlled error, malformed-output, and staleness cases rather than changing the device clock or weakening production validation.

1. **Deterministic baseline:** leave **Use on-device ordering** off and open Alternatives with sample mode both on and off. Eligible options must appear immediately in deterministic template order with unchanged titles, duration explanations, steps, benefit/tradeoff, and outcome parts. Choose/Later/Rest remain usable without an account, network, Apple Intelligence, or advisor permission.
2. **SDK/system/model fallback:** run the fallback build on the iOS 18 baseline and test modern-SDK builds with an unsupported system/device, Apple Intelligence disabled, model not ready, and a provider error/refusal. Each must retain the deterministic options with an honest status, no cloud request, no download promise, and no blocked manual actions. Keep the Watch placeholder regression in scope; full Watch sync is still Phase 6.
3. **Explicit supported-device request:** on a supported, ready real iPhone, explicitly enable **Use on-device ordering**, reopen Alternatives, and tap **Try on-device order**. Merely opening or refreshing the sheet must not invoke model ordering. A valid response may reorder the same two or three canonical choices only; it may not alter wording, duration, effort, outcome partitions, or fact/citation content. Turning the setting off must stop further model use.
4. **Strict output boundary:** inject duplicate, missing, foreign, extra, malformed, or oversized IDs, extra prose/claim/action fields, and a thrown/cancelled response. Expect the validated deterministic order, never partly trusted content. No response can automatically choose/complete a plan, persist a default, schedule a reminder, or invoke Calendar. Later still opens the existing fresh explicit confirmation sheet.
5. **Safety and stale requests:** delay an advisor request, then report a safety symptom or change the active plan, profile, local day, sample mode, barrier, movement mode/avoids, or relevant context. Resolve the delayed response: it must not reorder the newer/blocked state. A subsequent card action must still recheck current safety and active-plan identity. Starting Choose/Later/Rest must cancel/freeze the old request rather than let it alter a confirmation underneath the user.
6. **Privacy and low-data mode:** inspect a controlled provider's typed request. Expect opaque candidate IDs, approved enum/numeric candidate attributes, a coarse time budget, and in normal mode the explicit user-selected barrier enum. A barrier such as sore, stressed, or low energy describes the user's selection, not an inferred condition; low-data packets omit it. Expect no original profile/plan IDs, HealthKit-derived measurements, recovery labels, SafetyGate symptom/alert records, calendar titles/times/notes, movement-note free text, prompts persisted to disk, or unrestricted dictionaries. No favorable recovery value is sent or can raise exercise effort. All displayed explanations/facts remain canonical.
7. **Sample separation and preference:** enable sample mode after real-mode opt-in. The UI must explain that sample mode uses template ordering and must not offer a real-model ordering request. Opt-in is explicit and scoped to the selected profile/mode; restarting must not create implicit consent for another profile or sample state. Changing the Settings switch applies immediately; turning it off restores template order.
8. **Clear diagnostic activity:** create deterministic/on-device/fallback activity, then tap **Clear advisor activity** in Settings. Activity must clear independently, cancel/invalidate an in-flight request, and leave plans, choices, Foundation completion/preferences, reminder budget/dismissal history, and Calendar events unchanged. Diagnostic activity is memory-only; app termination must not restore a transcript, prompt, output, or context history. No raw provider error text should be stored or shown. Each request uses a fresh model session with no retained app transcript. Clearing Steady's activity does not claim to erase Apple's system-managed model state or diagnostics.
9. **Regression:** rerun representative Today/Move/Sleep, alternatives, Foundation/reminder, Calendar cancel/confirm, denied-data, and Watch placeholder cases. Advisor use must create no network analytics, Health sample, calendar event, notification, or persisted wellness-state change on its own.

### 14. Phase 5 Xcode integration

Complete the earlier setup first. This phase adds optional foreground approximate location and MapKit discovery to the iPhone only; it does not raise the deployment minima or add Watch functionality.

1. Open the repository's Xcode-created project on a Mac. Confirm **Steady > General > Minimum Deployments** remains **iOS 18.0**, the Watch remains **watchOS 11.0**, and both targets retain Swift 6 with explicit isolation. Do not edit `project.pbxproj`.
2. In the synchronized iPhone source folder, confirm Eat UI, food persistence, and `Services/Food`/location adapters belong only to **Steady**. Apple MapKit/CoreLocation/SwiftData adapters must not enter the Foundation-only package or Watch target. The local package discovers its new food source/tests automatically.
3. Select **Steady > Info**, add **Privacy - Location When In Use Usage Description** (`NSLocationWhenInUseUsageDescription`), and set its text to: `Steady uses your approximate location to find food nearby when you ask.` Add raw key `NSLocationDefaultAccuracyReduced` as type **Boolean**, value **YES**. Add no Always-location key, temporary full-accuracy purpose dictionary, Location updates background mode, paid service, API key, or cloud entitlement.
4. Confirm the app's SwiftData model container includes **FoodCorrectionRecord** along with all existing profile, plan, choice, and Foundation records. Launch against an existing development store and check its records still load. Back up development data before testing migrations; do not delete a store to disguise a migration failure.
5. Launch Eat with **Use Sample Data** on first. Merely opening it must not request location or run MapKit. Then test real mode with a typed area. Only the explicit approximate-location action should lead through the explanation and system When-In-Use prompt; denying it must preserve typed/manual/saved options.
6. Run `python scripts/check_source.py`, then `swift test --package-path Packages/SteadyCore` and both simulator builds from section 7 or `bash scripts/verify-mac.sh`. Record exact Xcode/SDK versions, commands, simulator destinations, warnings, and results in Phase 5's Evidence block. Complete the device procedure below before marking the phase accepted.

### 15. Phase 5 physical-device acceptance

Use a development iPhone and controlled injected providers/clocks for failure/staleness cases. Keep separate pass/fail/not-run notes. Sample data does not prove live MapKit, location authorization, SwiftData migrations, or network behavior.

1. **Explicit actions only:** open Eat in sample and real mode. No location prompt or live discovery should occur on open, refresh, relaunch, or mode change alone. Enter a meal type and typed area, dietary rules, allergies (including a free-text other allergy), dislikes, kitchen access, optional per-meal max price, and user-stated context. Only an explicit search requests discovery. No food/profile free text may be sent to the optional advisor.
2. **Approximate permission:** tap the approximate-location action, cancel the explanation once, then retry and deny the system prompt. Typed area, manual entry, and saved dishes must remain usable. Grant When-In-Use with Precise Location off and retry. The app must not ask for Always/full accuracy or depend on background location; inspect Settings and confirm no ongoing location history is stored.
3. **Live discovery is not a menu:** run a real typed/nearby search. Venue results must be labelled places to check with source/check time, not menu items. MapKit names, websites, or Maps links must not imply verified prices, opening status, ingredients, menu availability, or nutrition. No unsupported factual value may appear from legacy seed data. Return fewer than three or none when appropriate rather than filler.
4. **Allergens and restrictions:** with controlled evidence, provide a known selected-allergen conflict and confirm it is excluded. Provide incomplete ingredients, uncertain cross-contact, an unresolved dietary rule, or a free-text allergy: the result must require confirmation, never be called safe, and never be the primary recommendation. Do not infer ingredients or dietary suitability from a dish/venue name. Changing restrictions must invalidate a captured older result/confirmation.
5. **Price and sources:** leave max price empty, then set it. Known over-limit prices are excluded according to the per-meal preference; unknown prices stay explicitly unknown, never assumed affordable. Source/date/uncertainty remain visible. Inspect every displayed price, portion, date, or other number: each needs a tappable one-line explanation. There must be no weekly spend total, savings score, or moral food score.
6. **Remember review and cancellation:** enter a prior-visit correction with only information actually observed. Select **Remember this**, inspect the exact dish/place, source/date, price/portion/ingredients and remaining uncertainty, then cancel. Repeat and dismiss the review. Refresh and relaunch: neither path may persist a draft or affect future ranking. Confirming is not eating/completion, a Calendar write, or consent for another action.
7. **Confirmed persistence and failure:** repeat Remember and explicitly confirm once. Expect one dated `saved from prior visit` record after same-day refresh/relaunch, without auto-saving a transient search/location. Repeated confirmation/retry must not duplicate it. Inject a save failure: do not claim success or silently apply the correction; retry remains explicit. A saved record never guarantees current price, ingredients, or cross-contact handling.
8. **Stale context and separation:** delay a search or leave a Remember review open, then change profile, sample mode, local day, search inputs, or saved-record revision. Resolve/confirm the old operation: it must not replace/save into the newer context or leave a stale search stuck working. Use injected clocks rather than changing the device clock. Check that captured location/results expire after ten minutes and confirmation after fifteen minutes; foreground expiry must not trigger a new search, permission prompt, or save. Real and sample saved records/providers remain separate; sample mode never invokes real location or MapKit. A food-save failure must not roll back an unrelated unsaved profile/plan edit.
9. **Offline and denied fallback:** disable network, deny/restrict location, and inject discovery errors/timeouts. Keep typed areas/manual and previously saved records available with honest failure/freshness labels. Empty saved data may show no choices; do not manufacture a local menu/nutrition fallback. Restoring network/permission must not automatically replay a cancelled operation.
10. **Nutrition, freshness, and fixtures:** no defensible SG FoodID record is bundled. Without a reviewed dish/portion match expect `estimate unavailable`; opening the HPB reference is not a match. With controlled reviewed records, verify source, range, serving assumptions, and expiry. Stale/future-invalid/source-mismatched evidence cannot be promoted to current verification. `foods.json` values remain fixtures, not verified prices/nutrition/menu claims.
11. **Low-data and regression:** enable low-data mode and inspect Eat, saved records, and Remember review: sensitive nutrition/calorie details remain hidden while source/allergen uncertainty stays understandable. Recheck Today/Move/Sleep, Alternatives, Foundations/reminders, confirmed Calendar behavior, denied-data fallbacks, and Watch placeholder. Food actions must not create Health samples, Calendar events, notifications, remote analytics, an advisor call, or Phase 6 Watch synchronization.

The source handoff includes no verified official-menu catalog or SG FoodID nutrition dataset. This is an intentional factual limitation, not evidence that a venue has no menu or a dish has no nutrients. Record actual Mac and device results before accepting Phase 5; stop before Phase 6.

Primary implementation references: Apple's [MKLocalSearch](https://developer.apple.com/documentation/mapkit/mklocalsearch) and [reduced-accuracy default](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocationdefaultaccuracyreduced), plus HPB's [SG FoodID index](https://www.hpb.gov.sg/healthy-living/food-and-beverage/sgfoodid/) and [food-search tool](https://pphtpc.hpb.gov.sg/web/sgfoodid/tools/food-search). These references do not constitute a verified menu or numeric nutrition dataset.

Suggested commit after review and requested verification: `Implement Phase 5 evidence-aware food discovery and confirmed saved dishes`. No commit or push is performed by this continuation.

### 16. Phase 6 Xcode integration

Complete the earlier setup first. Phase 6 adds companion synchronization, not a standalone Watch account, server, widget, complication, HealthKit workout, or Calendar writer.

1. Open the existing Xcode-created `Steady.xcodeproj` on the Mac. Keep **Steady > General > Minimum Deployments** at **iOS 18.0**, the Watch at **watchOS 11.0**, and both targets in Swift 6 with explicit isolation. Do not edit `project.pbxproj`, duplicate an app entry point, or create another Watch target if the companion target already exists.
2. Select **Steady > Signing & Capabilities** and note its bundle identifier, for example `com.yourname.Steady`. Select the Watch target and confirm its bundle identifier extends that value, for example `com.yourname.Steady.watchkitapp`. Use the same signing team with automatic signing. In the Watch target's **Info** tab verify raw key **WKCompanionAppBundleIdentifier** equals the iPhone bundle identifier exactly. The target must be **Watch App for Existing iOS App: Steady**, not a separate watch-only app. Keep Xcode's companion association/embedding settings; do not mark the app independent as a shortcut around a missing association.
3. In Finder drag repository folder **Shared/CompanionConnectivity** into the Project navigator as a synchronized folder. In its target membership select **both Steady and the Watch app**, once each. It contains `CompanionTransport.swift`, `CompanionDiskInbox.swift`, and `WCCompanionTransport.swift`. Do not add it as a third app target or copy it into `SteadyCore`. If Xcode created an unsynchronized reference, correct membership through Xcode's File inspector rather than editing project metadata.
4. Confirm **Steady/** files, including the phone Watch store, new persistence models, snapshot publication, and saved-meal routing, belong only to the iPhone target. Confirm **SteadyWatch Watch App/** files belong only to the Watch target and the old placeholder is no longer the app's root screen. Each target must link the local **SteadyCore** product once. Shared core source/tests are discovered by the package automatically.
5. Verify the iPhone `ModelContainer` includes `WatchIssuedSnapshotRecord`, `WatchActionReceiptRecord`, `WatchMovementRecord`, and `WatchMealHandoffRecord` alongside all existing profile/plan/choice/Foundation/food models. Back up development data, launch against an existing store, and check earlier records still load. A migration failure must be reported/fixed, not hidden by erasing a user's store. The Watch's bounded cached snapshot/outbox and each app's transport inbox are local application-support files, not iCloud sync.
6. WatchConnectivity is a system framework. Add no API key, paid service, APNs/Push Notifications capability, iCloud/App Group entitlement, new background mode, or usage-description prompt for Phase 6. This source has no widget/complication requiring a shared App Group. Earlier optional phone permissions remain unchanged; manual movement logging does not request HealthKit write access. Do not enable HealthKit writes to make this feature pass.
7. Run `python scripts/check_source.py`, then `swift test --package-path Packages/SteadyCore` and both simulator builds from section 7 or `bash scripts/verify-mac.sh`. Record Xcode/SDK versions, exact commands, destinations, warnings, and results in Phase 6's Evidence block. Review Swift 6 delegate isolation and target membership in both builds. Two separate simulator launches do not prove a working paired connection.
8. Run both schemes on the actual paired iPhone/Watch using the same development build/signing team. Open Steady on the phone to refresh/validate current state, then open the Watch app. Complete section 17 before accepting Phase 6. To test real suspension/relaunch, also launch from each device's Home Screen without Xcode holding the process active.

The Watch scene uses SwiftUI `.backgroundTask(.watchConnectivity)` only to receive/save transport data and receipts, waiting for pending delivery before returning. It does not schedule periodic background refresh or apply phone wellness actions. Local Watch storage validates outbox integrity and its monotonic revision watermark before it is considered usable; corrupt data is reported rather than silently reset.

### 17. Phase 6 physical-device acceptance

Use a development iPhone and its physically paired Watch. Keep a separate pass/fail/not-run record for every case, including tap counts and VoiceOver observations. Use injected clocks/providers and controlled persistence failures for rare conditions; do not change system time, remove validation, or fabricate a real Health/food record just to pass a test. Sample transport cannot establish real WatchConnectivity delivery.

1. **Glance and phone alone:** with real mode selected, open the phone app and then the Watch. Check today's priority, next action, cached-state age, terminal/deferred plan-status wording, and tappable number explanations. A completed/rested/deferred plan must not appear as an unqualified action to start now. Leave the Watch unavailable/uninstalled or use an unpaired development phone: all earlier phone tabs and manual/denied-data flows must remain usable. Missing or stale Watch data must say unavailable/refresh, not display fabricated current state.
2. **Common actions and accessibility:** from the Watch glance, count taps for a quick alternative, one basic user-reported movement log, captured Foundation Done, and saved-meal handoff. Each common action must need at most two taps. Check large text, VoiceOver labels, readable benefits/tradeoffs and duration explanations, and an honest queued status. A choice changes the app plan only; it is not workout completion. Manual logging must not create Health samples, Calendar entries, or inferred strength history.
3. **Disconnected durable queue:** first load a current real snapshot, then disconnect the devices using Airplane Mode/Bluetooth/network controls as appropriate. Queue a permitted explicit action. Force-quit and reopen the Watch without reconnecting: the same action ID remains queued, not accepted. Reconnect, foreground the phone to apply pending actions, then foreground the Watch to receive its receipt. Expect one accepted mutation, never an immediate delivery promise or duplicate. `transferUserInfo` must not depend on `isReachable` being true.
4. **Receipt and duplicate replay:** in a controlled development transport, deliver the same action repeatedly, delay/reorder the same receipt, and relaunch both apps before and after receipt processing. The phone must return the prior typed outcome without another mutation. An OS transfer callback is not an application receipt and must not clear the Watch action. A rejected action must be labelled rejected with a neutral reason, never completed.
5. **Save and capacity failures:** inject Watch outbox/phone inbox/phone transaction persistence failures, and reach each documented bound with controlled packets. New work must be refused or remain pending with an honest message; no pending action is silently evicted. A failed/uncertain phone save must emit no false accepted receipt and must not leave a mutation without its replay record. Retry uses the same ID; after successful persistence it applies once. Corrupt/oversized/unknown-version packets must not crash or mutate records.
6. **Stale scope/current identity:** queue from a captured snapshot, then change the phone profile, sample mode, Singapore local day, active plan, Foundation option/preferences, or confirmed saved-food revision before delivery. Foreground the phone: old actions must not mutate the replacement or another scope. Also leave an older Watch button visible during a received-frame change and tap it: it must refuse the captured snapshot rather than retargeting a repeated option ID in the new frame. Use injected time rather than changing the device clock. Expired or future-invalid snapshots/actions must refresh/refuse honestly; a rejected future-timestamp action must still be removable by its exact matching phone receipt. A completed/disabled Foundation cannot be completed again through an old packet.
7. **Safety supersedes cache:** load a movement alternative/Foundation snapshot, disconnect the Watch, and report a safety symptom through the phone's explicit development flow. Deliver the old Watch action after reconnecting. Current safety must block performance changes rather than revive the cached suggestion. Inspect the refreshed Watch: safety guidance replaces performance actions without guessing a diagnosis or increasing effort from a favorable recovery value.
8. **Saved-meal handoff only:** explicitly confirm a prior-visit saved dish on the phone using the existing Remember review. Refresh the Watch and hand it back to the phone. The phone opens that saved record with dated source/uncertainty and no allergy-safe claim. Nothing is automatically eaten, newly saved, searched, or confirmed. Delete/replace/change the saved record in a controlled case before delivery: the stale handoff must not reconstruct a dish from its title or open a different record.
9. **Low-data and sample isolation:** switch low-data mode on and inspect the actual typed transport packet plus every Watch surface/cache after relaunch. Hidden calorie/weight/recovery details must not remain in packets merely because the UI hides them; mode changes invalidate captured actions. Enter sample mode: sample wellness data/actions stay on the sample provider. The only real transport allowed on sample entry is an empty low-data privacy-clearing control snapshot so old real information is not left displayed. Returning to real mode must not replay a sample action into real history.
10. **Foreground delivery and regression:** with apps launched from Home Screens, lower the wrist/background both apps, reconnect, and then foreground them to reconcile. Queueing survives system scheduling without claiming a delivery deadline or automatic background action application. Rerun representative Today/Move/Sleep/Eat, Alternatives, Foundations/reminders, Calendar cancel/confirm, and denied-data cases. Watch action handling must never request HealthKit writes, invoke EventKit, trigger a notification/advisor, save a food correction, or apply an unapproved default. Phase 7 weekly learning remains untouched.

Application-context updates replace previous pending snapshots; they are not a command queue. Durable transfers may be delayed by the system, and transport delivery alone does not establish application acceptance. Phone-issued snapshots expire after fifteen minutes or at Singapore midnight, whichever is earlier; the shared validator also rejects a lifetime above four hours. A disconnected Watch cannot immediately learn a phone low-data/sample/profile change or be remotely wiped: the prior cache is hidden at expiry or replaced by a newer received frame. Its queued old-scope actions are still checked against current phone state. The implementation applies phone actions when its current foreground state is loaded; a disconnected action can become stale before then and be rejected safely rather than applied to a newer day/plan.

Storage bounds are fifty pending Watch actions, one hundred displayed Watch receipts, and one hundred combined raw action/receipt packets per local transport inbox. Typed snapshots/actions/receipts are limited to 64,000/8,192/20,480 bytes. The phone processes no more than 256 new receipts per Singapore day; replay of an existing ID still works after the cap. Full queues/caps/storage failures retain pending work or refuse new work, not silently evict it. The durable phone apply-once ledger and consumed handoff records are not automatically pruned; they remain until a later explicitly confirmed data-deletion flow. Phase 6 introduces no deletion/export UI, aggregate movement count, or streak.

Primary references: Apple's [WatchConnectivity data-transfer sample](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity), [`updateApplicationContext`](https://developer.apple.com/documentation/watchconnectivity/wcsession/updateapplicationcontext(_:)), and [`transferUserInfo`](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferuserinfo(_:)). Reference review is not paired-device or Swift SDK verification.

Suggested commit after review and requested verification: `Implement Phase 6 durable Watch actions and validated companion snapshots`. This continuation performs no commit or push.

### 18. Phase 7 Xcode integration

Complete the earlier setup first. Weekly learning is local and deterministic; it adds no account, cloud sync, remote analytics, permission prompt, Calendar deletion, or HealthKit write access.

1. Back up the repository and the development app's local records before migration testing. Keep a separate disposable development store for destructive acceptance tests. Do not run Delete all against the user's only copy of important records.
2. In Xcode's Project navigator, confirm synchronized iPhone membership includes `Steady/Features/Week`, `Steady/Persistence/WeeklyRecords.swift`, `Steady/Features/Settings/DataControlsView.swift`, `Steady/Features/Settings/PrivacyLaunchView.swift`, `Steady/Services/Privacy`, and the app integration changes. Keep these app-only files out of the Watch and Foundation-only package targets. `Packages/SteadyCore/Sources/SteadyCore/WeeklyLearning` belongs to the local package product already linked to both apps. Do not edit `project.pbxproj` by hand.
3. Open `SteadyApp.swift` and inspect the existing model-container declaration. It must retain all earlier models and include `WeeklyReviewRecord`, `WeeklyExperimentRecord`, and `WeeklyMetricRecord`. Launch once with a disposable copy of an older development store and verify profile, plans, choices, Foundations, saved-food corrections, and companion records still load. Do not fix migration errors by silently deleting the store.
4. Keep `Shared/CompanionConnectivity/DataDeletionGate.swift` and the existing shared transport sources in both app targets, with each platform's own phone/Watch coordination/storage source in its correct target. Phase 7 cleanup must compile on both platforms; deletion does not introduce a new App Group, iCloud entitlement, backend, background mode, or paired-device delivery guarantee.
5. Retain iOS 18/watchOS 11 minima, Swift 6, and the documented explicit actor isolation. Use the Apple system share sheet for a user-invoked JSON export. Do not add an analytics SDK, provider key, automatic upload, HealthKit write permission, or EventKit deletion call.
6. Run `python scripts/check_source.py`, `swift test --package-path Packages/SteadyCore`, and both simulator builds using section 7 or `bash scripts/verify-mac.sh`. Record exact Xcode/SDK versions, commands, destinations, warning counts, and pass/fail results in the Phase 7 Evidence block. Source parsing is not Swift type checking.
7. Run the paired iPhone/Watch procedure below, including testing from device Home Screens without Xcode keeping the processes alive. Use a disposable store to inject save/cleanup failure and interruption. A simulator build cannot prove SwiftData migration/recovery, system share-sheet behavior, or remote Watch clearing.

### 19. Phase 7 physical-device acceptance

Primary integration references: Apple's [model-context environment modifier](https://developer.apple.com/documentation/swiftui/view/modelcontext(_:)), [exporting data representation](https://developer.apple.com/documentation/coretransferable/datarepresentation/init(exportedcontenttype:exporting:)), and [suggested transfer filename](https://developer.apple.com/documentation/coretransferable/transferrepresentation/suggestedfilename(_:)-2yln2). Documentation review is not Swift SDK compilation or device verification.

None of these checks has been run in this Windows source handoff. Record each pass, failure, and not-run case separately. Keep the original important data outside the test install.

1. **Weekly window and gaps:** open Week in sample mode, then real/manual mode. Select the current and previous week and check Singapore Monday-start dates. Deny Health access and try partial/no sleep observations: coverage and unavailable values remain clear, not zero sleep/activity or a missed-action judgement. Actual sleep and the in-bed opportunity proxy must remain distinct. Every displayed date/count/duration has an accessible one-line explanation.
2. **Honest record interpretation:** create and change local plans, choose alternatives, record intentional rest, explicitly complete an action, mark a Foundation Done/dismiss a reminder, save a food correction, and record movement on Watch. Review only the observations retained in that week. A chosen plan is not completed; manual movement is user-reported, not a HealthKit workout; a saved prior visit or meal handoff is not evidence of eating. There is no weekly spend, savings, treat quota, or moral score.
3. **New evaluation and helpfulness:** scroll to an introduced offer and explicitly accept/respond. Loading Week alone must not record below-fold suggestions as shown; tracking uses the offer button's SwiftUI appearance or explicit tap, not proof of attention. Relaunch and inspect newly retained local evaluation/helpfulness. Older records must not produce invented past views, time-to-choose, completion/correction denominators, or helpfulness. Choosing Not answered removes a previously saved helpfulness metric. Unsupported measures remain unavailable. No remote analytics request or advisor inference is part of the review.
4. **Default proposal and refusal:** using disposable real-mode test records with changed plans on three distinct days, review the evidence-labelled Exam-mode proposal. Sample mode must not offer or apply this shared profile default. Cancel, dismiss, and refuse it; confirm the existing profile setting and all plans/reminders remain unchanged. Approve the exact current proposal and confirm only the supported setting changes once. No weekly pattern increases exercise or overrides a safety state.
5. **Stale approvals:** leave a proposal open, then change the profile, sample mode, selected week, source records/revision, base setting, or local day/week. Also test expiry and relaunch. A stale approval must refresh/reject rather than apply to a different context; saving or reopening the review is not approval.
6. **One experiment:** explicitly select a small-plan, wind-down, or quiet-Foundation experiment. Review its dates and simple self-report measure before confirming. Cancel/dismiss the draft and verify it writes nothing. Confirm one bounded experiment, relaunch, and verify it remains labelled correctly without auto-changing plans, defaults, or reminders. Try a second overlapping/stale experiment; it must be refused. Let a disposable trial reach its end and verify honest elapsed status and the ability to choose a new trial, without a streak or failure message. The current UI offers trial selection and elapsed status, not an early-end control.
7. **JSON export scope:** open Week > Export or delete local data (or the Settings data-controls link), tap Prepare local JSON, and review scope/counts before Share JSON. Save a disposable copy to Files, open the JSON, and verify schema/version/export date, all fourteen model-record categories, known local preferences, pending phone companion inbox, limitations, and sample/real distinctions. Cancel sharing and check that no automatic upload or record mutation occurs. The file must contain no raw HealthKit samples, complete Calendar events, advisor prompt/output/transcript, temporary nearby results, or approximate-location history. Handle the exported file as personal data: the app cannot retract a copy shared to another destination. The archive is capped at 20,000 model rows and 10 MB; failures share no partial archive. No import/restore is implemented.
8. **Low-data payload:** enable low-data mode on any saved profile and repeat review, proposal, experiment, and export. Inspect the JSON itself, not just the screen: the whole multi-profile archive is metadata-only, with salted opaque record keys/IDs, profile UUIDs, dates, and sample/real markers, but no content, measurements, settings, or opaque payload details. A redacted export is not a full restorable backup; omitted fields must not be interpreted as zero. Prepare an archive, change profile/low-data/reset scope or background/leave the screen, and verify its in-memory share lease is invalidated instead of disclosing an old fuller payload. Recheck Watch packet/display privacy and tappable explanations.
9. **Deletion cancellation:** on the disposable install only, open Delete all and read the scope warning. Cancel and dismiss in separate runs. Verify records, profile/defaults, experiments, advisor opt-in/activity, reminder preferences/reservations/inboxes, and companion queues/receipts/caches remain unchanged. Merely viewing data controls must never delete anything.
10. **Confirmed cleanup:** make one Steady-owned Calendar event and note existing Health/Calendar data before testing. Queue pending local/reminder/companion work, open Review deletion, type DELETE, and explicitly confirm Delete all Steady app data. Verify every app-owned record category and preference/opt-in, local metrics, advisor activity, pending/delivered Steady notifications/reservations/response inboxes, companion queues/receipts/cache, and in-flight work is cleared or invalidated. The app returns to honest onboarding with a fresh model context only after successful cleanup. A minimal non-personal journal/generation cutoff remains; proactive reminders stay quiet until the next Singapore day so reset/recreation cannot refund the daily ceiling. Apple Health and Apple Calendar records, including the Steady-owned event, remain; system permission is not revoked. Exported files and system backups held elsewhere are not removed. This removes app-accessible local records; it is not a forensic secure-erase guarantee for device storage.
11. **Failure and recovery:** inject a SwiftData/save/storage/transport cleanup failure and interrupt/relaunch during confirmed deletion. Do not accept a success message for a partial clear. Normal mutations must not continue against a half-cleared state; a readable pending journal permits retrying only its already confirmed operation, not later erasing newly created data. After finishing a reset and creating new data, deliver a delayed old recovery callback: it must refuse, not begin another deletion or re-enable autosave on an abandoned context. Test an unreadable privacy journal separately: the app must fail closed in an unavailable/recheck-only state, without claiming a deletion was confirmed, guessing a lower cutoff, or offering fresh destructive confirmation over unknown generation state. Restore trustworthy readability/remove the injected failure and recheck; only a readable pending operation may resume. Capture exact outcomes, not a source-inspection assumption.
12. **Connected and offline Watch:** test confirmed deletion with the paired Watch reachable, then repeat with it disconnected and an old queued action. A connected Watch should receive the minimal clearing frame, selectively clearing only the old generation. A disconnected Watch may retain only its disclosed expiring prior cache until a new valid frame arrives; no immediate remote erase is promised. Reconnect, relaunch both devices, and create a new phone profile: old actions must be rejected and must never restore deleted wellness data or mutate the new profile. A late old clearing frame must preserve newer-generation actions. Corrupt/unreadable Watch storage must fail closed with an honest incomplete-clear message, not reset unknown newer data because an old deletion fence exists. Check on-Watch pending queues/caches and honest receipt status.
13. **Independent advisor clear and regression:** clear advisor activity without Delete all. It must invalidate in-flight advisor work and leave wellness records, defaults, experiments, Foundations/reminders, Calendar, and Watch action records unchanged. Complete one review in five to ten minutes, test VoiceOver/readability, and rerun representative earlier Today/Move/Sleep/Eat, Alternatives, Foundations, denied-permission, confirmed Calendar, and paired-Watch checks.

Acceptance still requires passing core tests, both builds with no new warnings, and recorded device outcomes. No actual user-data deletion, Swift test execution, Apple-platform build, or physical-device test was performed during this source preparation. All seven phases remain pending their Apple-platform acceptance gates; Phase 7 source is not a fully verified release and does not authorise App Store distribution.

Suggested commit after review and requested verification: `Implement Phase 7 weekly learning and confirmed local data controls`. This continuation performs no commit or push.

## Continue development

Read these files in order before changing code:

1. `AGENTS.md`
2. `docs/SPEC.md`
3. `docs/MILESTONES.md`
4. `docs/DECISIONS.md`

Use the phase prompts in `docs/PROMPTS.md`. Implement one phase at a time and stop for review after each phase.
