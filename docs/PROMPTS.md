# Prompts for continuing Steady

Use these with a coding assistant opened at the `Steady` repository root on a Mac. The approved workflow has seven phases, not the starter's M0-M10 milestones.

Rules:

- Work on one phase per session.
- Read the repository docs before changing code.
- Put decision logic and tests in `SteadyCore` first, then services, persistence, and UI.
- Never hand-edit `project.pbxproj`.
- Do not claim a phase is complete until core tests, both simulator builds, and device checks are recorded.
- Stop for review before beginning the next phase.

## 1. Finish and verify Phase 1 on the Mac

```text
You are continuing Steady Phase 1 (Foundation).

First read AGENTS.md, README.md, docs/SPEC.md, docs/MILESTONES.md, and docs/DECISIONS.md.
Treat docs/MILESTONES.md as the authoritative seven-phase plan.

1. Inspect the existing source. Do not recreate working files.
2. Follow README.md's Xcode steps for the iOS target, Watch target, synchronized folders,
   local SteadyCore package linkage, HealthKit capabilities, signing, and privacy keys.
3. Finish only unchecked Phase 1 source items.
4. Run scripts/check_source.py if present.
5. Run swift test --package-path Packages/SteadyCore.
6. Run the iOS and watchOS simulator builds using scripts/verify-mac.sh if present,
   or the documented xcodebuild commands.
7. Fix Phase 1 errors and new warnings. Do not start Phase 2.
8. Update README.md, docs/MILESTONES.md evidence, and docs/DECISIONS.md honestly.

Finish with:
- what changed;
- exact commands and results;
- numbered iPhone and Watch test steps for a beginner;
- any remaining Xcode clicks;
- a suggested commit message.

If physical-device testing has not happened, use the status
"source complete, Mac verification pending" or "Mac builds pass, device verification pending",
not "Phase 1 complete".
```

## 2. Build the next accepted phase

```text
Read AGENTS.md, README.md, docs/SPEC.md, docs/MILESTONES.md, and docs/DECISIONS.md.

Check the prior phase's evidence and the user's current authorisation. Build only the
named authorised phase. An explicit request may authorise source work before earlier
Mac gates pass; record that decision without marking those gates accepted. If no phase
is named and no such authorisation exists, continue the current phase's pending work.

Order of work:
1. SteadyCore models, deterministic rules, invariants, and unit tests.
2. Protocol-backed app services with sample/manual implementations.
3. Persistence mappings only for records that must survive a relaunch.
4. Thin SwiftUI views and accessibility labels.
5. Static checks, swift test, then both simulator builds.
6. Update README.md, MILESTONES.md, and DECISIONS.md with evidence.

Never add a cloud provider, backend, API key, paid dependency, automatic crawler,
weekly spend ledger, money-saved score, dedicated Urge flow, or treat quota.
Never edit project.pbxproj by hand.

Finish with what changed, exact test/build results, beginner device-test steps,
remaining Xcode clicks, and a commit message. Then stop for review.
```

To request a specific phase, name it explicitly. D32, D37, D41, D44, and D48 record the user's 18 October 2026 source authority for Phases 3, 4, 5, 6, and 7. D48 follows the explicit Phase 7 request after the status report disclosed that it had not started. All seven phases' Apple-platform acceptance gates remain pending; preparing Phase 7 source does not accept earlier unrun gates or establish a release ready to distribute.

### Continue and verify Phase 2

```text
Continue Steady Phase 2 - Alternatives only. D26 records the user's authorisation;
Phase 1 Mac verification remains pending and is not silently accepted.

Read AGENTS.md, README.md, docs/SPEC.md, docs/MILESTONES.md, and docs/DECISIONS.md.
Inspect the existing Phase 2 implementation before changing it. Preserve working code.
Verify outcome partitions, distinct effort, deterministic fallback, selected barriers,
basic movement substitutions, and SafetyGate before selection and confirmation.
Verify Choose and Rest on purpose survive relaunch without a calendar write.
Verify Later creates only a proposal: cancel/dismiss writes nothing, Confirm writes only
to a tracked Steady-owned event, denied access remains usable, and an externally deleted
event becomes unscheduled without being recreated after refresh or relaunch.
Check both sample behavior and real EventKit behavior; a sample event is not device evidence.
Run scripts/check_source.py and available meaningful core tests. On a Mac run
bash scripts/verify-mac.sh, then the README's Phase 2 physical-device acceptance steps.
Record exact command results, warnings, and unrun gates in README.md and MILESTONES.md.
Do not mark either phase complete without its recorded Apple-platform/device evidence.
Stop before Phase 3. Finish with changes, exact verification, pending Xcode/device steps,
and a suggested commit message.
```

### Continue and verify Phase 3

```text
Continue Steady Phase 3 - Daily Foundations only. D32 records explicit source authority;
Phase 1/2 Mac tests, builds, integration, and device acceptance remain pending.

Read AGENTS.md, README.md, docs/SPEC.md, docs/MILESTONES.md, and docs/DECISIONS.md.
Inspect existing Foundation/Nudge core, FoundationStore/SwiftData records, notification
providers, durable response inbox, device-wide budget, and Foundations UI before editing.
Preserve working code and existing user records. Do not synthesize project.pbxproj.
Verify all six families, standing/seated/wheelchair variants, explicit avoids, safety,
done/replace/snooze/disable/enable, local-day rollover, stale action rejection, and ID replay.
Verify thirst-led hydration, safe shade/no-sun-gazing language, and small wind-down.
Check quiet overnight/all-day periods, sleep, calendar/workout blocks, <=3 daily proactive
reservations, cancellation/failed-save no-refund, every-other-local-day reduced frequency
after two dismissals, pause after four, explicit resume, low-data text, and silent cards.
Real reminders require optional system authorization; sample mode must never schedule real
notifications. Use ordinary active/no-sound delivery, not time-sensitive or critical levels.
Callback responses must be queued durably and applied idempotently on foreground load.
Do not promise background freshness or multi-day scheduling; Calendar unavailable is silent.
Run scripts/check_source.py. On a Mac run swift test and bash scripts/verify-mac.sh, complete
README sections 10/11, then record exact results and all unrun gates in MILESTONES.md.
Stop before Phase 4. Finish with changes, checks, remaining Xcode/device steps, and a
suggested commit message. Do not claim phase completion from Windows static checks.
```

### Continue and verify Phase 4

```text
Continue Steady Phase 4 - Advisory agent only. D37 records explicit source authority;
Phase 1/2/3 Mac integration, tests, simulator builds, and device gates remain pending.

Read AGENTS.md, README.md, docs/SPEC.md, docs/MILESTONES.md, and docs/DECISIONS.md.
Inspect existing Advisory core, TemplateAdvisor, validator/coordinator, optional Apple
adapter, AdvisorStore/Settings, and Alternatives integration before editing. Preserve
the uncommitted Phase 3 implementation and user records. Never synthesize project.pbxproj.
Keep deterministic alternatives immediate. Optional on-device ordering is default-off,
explicit opt-in and an explicit Try on-device order request, never a background shuffle.
Keep Foundation-only core; SDK-gate FoundationModels and runtime-gate iOS 26/model readiness
without raising the iOS 18/watchOS 11 minima or changing the Watch placeholder.
The provider may return ONLY an exact permutation of opaque allowlisted choice aliases.
Reject extra/duplicate/missing/foreign IDs and unknown prose/claim/action fields. Rebuild
the result from unchanged canonical title/duration/effort/steps/benefit/tradeoff/outcomes.
Send only typed candidate attributes and coarse time budget/optional explicit selected barrier.
Normal-mode barriers may describe soreness/stress/low energy as user statements, not inferences.
Never send HealthKit-derived measurements, recovery labels, SafetyGate symptom/alert records,
calendar details, original profile/plan IDs, notes, or arbitrary free text. Low-data mode removes
the selected barrier. Sample stays Template.
Recheck current safety and request identity after awaiting; cancel/ignore stale day/profile/
plan/sample/restriction/context/preferences or action transitions. No model action authority.
Keep diagnostic activity bounded, in-memory, separately clearable, and without IDs/prompts/
outputs/context/raw errors. Clear invalidates pending results without changing wellness or
reminder records. Fresh sessions retain no app transcript; don't promise wiping Apple state.
Run scripts/check_source.py. On a Mac run swift test and both simulator builds, including
older-SDK fallback and modern SDK integration; execute README sections 12/13 on supported
and unsupported/unready devices. Record exact commands/results and all unrun gates.
Stop before Phase 5. Finish with changes, checks, pending Xcode/device work, and a suggested
commit message. Do not claim phase completion from Windows static/syntax audits.
```

### Continue and verify Phase 5

```text
Continue Steady Phase 5 - Live food only. D41 records source authority following the
Phase 4 handoff; Phase 1/2/3/4 Mac integration, tests, builds, and device gates remain pending.

Read AGENTS.md, README.md, docs/SPEC.md, docs/MILESTONES.md, and docs/DECISIONS.md.
Inspect existing Food core/tests, Eat UI, protocol-backed discovery/location services,
SwiftData saved-food records, and confirmation flow before editing. Preserve all local
Phase 3/4 work and user records. Never synthesize or hand-edit project.pbxproj.
Keep discovery user-triggered. Opening Eat must not request location or run MapKit.
Typed area/manual/saved options remain useful offline or with location denied. Approximate
foreground location is optional; sample mode never invokes real MapKit or location.
MapKit is venue discovery, not menu, price, hours, ingredients, or nutrition evidence.
Only attach official-menu evidence bound to the same venue identity. A website/Maps link
alone cannot substantiate a food fact. Keep unknown/unavailable explicit with source,
checkedAt, confidence, uncertainty, and freshness for each fact; never promote fixtures.
There is no bundled reviewed official-menu or SG FoodID dish/portion dataset. A typed
matcher may accept defensible reviewed cited records, but do not invent nutrition values
or pretend the HPB reference link is itself a match. Show estimate unavailable otherwise.
Deterministic dietary/allergen filtering precedes ranking: known conflicts excluded;
incomplete/uncertain ingredients, cross-contact, unresolved dietary rules, and free-text
other allergies require confirmation, never a safe label or primary recommendation.
Respect dislikes/kitchen access and optional per-meal max price; unknown price is not zero
or verified affordable. Return up to 3 distinct useful choices, fewer/none when necessary.
Remember this creates a review only. Cancel/dismiss writes nothing; only fresh explicit
Confirm persists the exact prior-visit record. Recheck current profile/sample/day/inputs/
saved-state revision. Reject late searches/confirmations; separate sample and real records.
Save failures must not claim success or silently affect future ranking. Never persist
transient MapKit search/location history or infer current allergy safety from a saved visit.
Keep food evidence and action authority outside the advisor; no automatic crawler, paid
API, key, cloud service, spending ledger, money-saved score, or eating-completion claim.
Low-data food surfaces hide calorie/nutrition detail; every displayed number has a Why.
Run scripts/check_source.py. On a Mac run swift test and both simulator builds, verify
SwiftData compatibility and optional location setup, then complete README sections 14/15.
Record exact counts, commands, results, warnings, catalog limitations, and all unrun gates.
Stop before Phase 6. Finish with changes, checks, remaining Xcode/device steps, and a
suggested commit message. Windows static/syntax checks do not establish phase acceptance.
```

### Continue and verify Phase 6

```text
Continue Steady Phase 6 - Apple Watch only. D44 records source authority following the
Phase 5 handoff; Phase 1/2/3/4/5 Mac integration, tests, builds, and device gates remain pending.

Read AGENTS.md, README.md, docs/SPEC.md, docs/MILESTONES.md, and docs/DECISIONS.md.
Inspect existing Watch core/tests, transport, durable outbox/inbox/receipts, phone store,
snapshot builder, Watch UI, and saved-meal routing before editing. Preserve all local
Phase 3/4/5 work and existing user records. Never synthesize or edit project.pbxproj.
Keep SteadyCore Foundation-only. Use updateApplicationContext for replaceable latest
phone snapshots and transferUserInfo for durable explicit Watch actions. sendMessage is
optional and not required. Do not gate durable transfer on counterpart reachability.
Persist an action before submission; retain its ID through retry until a typed phone
receipt. Show queued versus accepted/rejected honestly. Bounded queues must refuse new
work rather than silently evict pending actions. Disconnect/relaunch cannot imply success.
Validate schema, bounds, current profile/sample/Singapore day/snapshot, plan, Foundation,
and saved-record identity. Recheck fresh safety before accepting performance actions.
Commit each accepted local mutation and its apply-once phone receipt atomically. Same-ID
replay returns the prior outcome. Failed/uncertain persistence cannot emit a false success.
Quick alternatives choose the app plan only, not completion or a Calendar write. Manual
movement logging is explicit local user report, not a HealthKit sample/workout or inferred
strength history. Foundation Done follows current local-day/option/safety guards. Saved-meal
handoff opens the confirmed phone record for evidence-labelled review, never a search,
eating/completion claim, allergy-safe label, or automatic Remember confirmation.
The glance and common actions target at most two taps. Preserve offline cached use and
phone-only operation. Minimise typed packets, redact low-data fields before transport,
explain each displayed number, and show stale/unavailable/queue/storage states honestly.
No raw Health samples, full calendar details, location history, advisor transcript, arbitrary
notes, notification scheduling, default change, cloud service, key, APNs, or new background
mode. WatchConnectivity is system-scheduled; promise neither latency nor continuous freshness.
Run scripts/check_source.py. On a Mac run swift test and both simulator builds, follow
README section 16 for companion association/target membership/store compatibility, then
section 17 on a real paired Watch/iPhone: offline queue/reconnect, duplicates, relaunch,
save failures, stale scopes, safety, low-data, common-action tap count, and phone-alone use.
Record exact counts, commands/results, warnings, and all unrun gates in MILESTONES.md.
Stop before Phase 7. Finish with changes, checks, remaining Xcode/device steps, and a
suggested commit message. Windows static/syntax checks do not establish phase acceptance.
```

### Continue and verify Phase 7

```text
Continue Steady Phase 7 - Weekly learning only. D48 records explicit source authority;
earlier Mac tests/builds/device gates remain pending and are not silently accepted.

Read AGENTS.md, README.md, docs/SPEC.md, docs/MILESTONES.md, and docs/DECISIONS.md.
Inspect existing weekly rules, UI, persistence, data controls, and companion cleanup.
Preserve all earlier local source and user records. Never synthesize project.pbxproj.

1. Keep Singapore Monday-start weekly windows, explicit observation coverage, and
   unknown values. Distinguish actual sleep from the in-bed opportunity proxy,
   saved plans from completion, user-reported movement from HealthKit, and remembered
   dishes from consumption. Do not invent past interaction telemetry or helpfulness.
2. Retain deterministic evidence-labelled Exam-mode-only default proposals with
   explicit approval, no exercise intensification, and profile/sample/week/revision/
   current-value/expiry checks. Cancel, dismiss, refresh, relaunch, and stale sheets
   must not change defaults. SafetyGate retains authority independently.
3. Keep one explicitly confirmed two-to-fourteen-day experiment with named dates
   and a simple self-report measure; starting it changes no default or reminder.
   Verify overlap/stale rejection, status, relaunch, and explicit helpfulness.
4. Persist only minimal review/experiment/typed local evaluation records; runtime
   Health aggregates stay transient. Unknown historical denominators remain unknown.
   No remote analytics, money ledger, savings score, treat quota, or moral scoring.
5. Verify explicitly invoked typed JSON export of all app-owned record categories,
   schema/redaction manifest, and low-data payload redaction. Do not export raw
   Health samples, full Calendar details, advisor content, searches, or location.
6. On a disposable backed-up development store, verify delete confirmation/cancel,
   invalidation of in-flight work, every app-local record/preference/opt-in/reminder/
   transport/cache category, partial failure/journal recovery, and no Apple Health
   or Apple Calendar deletion. Retry only a readable pending confirmed operation;
   an unreadable privacy journal is unavailable/recheck-only, never authority to guess
   a lower cutoff or accept fresh destructive confirmation over unknown state. Do not
   claim forensic secure erase. Never test deletion on the user's only important copy.
7. Verify connected/offline Watch clearing behavior and stale queued action rejection
   after deletion, restart, and new onboarding. No immediate disconnected remote erase
   or resurrection into a new profile may be claimed. Keep independent advisor clear.
8. Follow README sections 18-19 for Xcode membership/model integration and physical
   device checks. Run scripts/check_source.py, swift test --package-path
   Packages/SteadyCore, and both simulator builds or scripts/verify-mac.sh on a Mac.
9. Record exact commands, Xcode/SDK/destination, pass/fail/unrun results, warnings,
   migration/failure outcomes, and paired-device checks in README/MILESTONES.

Stop after Phase 7 review; do not invent Phase 8, publish, commit, push, or claim release
readiness without explicit authority and accepted gates. Finish with changes, checks,
remaining Xcode/device steps, and a suggested commit message. Windows source audits
are not Swift compilation, executed tests, deletion execution, or paired-device proof.
```

## 3. Diagnose a problem

```text
Something is wrong in Steady.

What I did: <steps>
What I expected: <expected behavior>
What happened: <actual behavior>
Xcode or console error: <paste exact text>
Screenshot: <attach if useful>

Read the relevant repository docs, then reproduce or trace the problem before editing.
Explain the cause in two or three sentences. Make the smallest scoped fix.
If deterministic behavior changed, add a SteadyCore test that would have caught it.
Run the relevant static checks, swift test, and affected simulator builds.
Do not broaden phase scope. Tell me exactly how to verify the fix on my device.
```

## 4. Change product behavior

```text
I want Steady to behave differently:
<describe the change>

First identify the controlling rule in docs/SPEC.md and any decision in docs/DECISIONS.md.
If this reverses an approved decision, stop and explain the tradeoff before coding.
Otherwise update the spec, add a dated decision when needed, then change code and tests.
Keep the change inside the current phase. Run the relevant checks and builds.
Finish with a short summary and device verification steps.
```

## 5. Review before a commit

```text
Review all uncommitted Steady changes against AGENTS.md, docs/SPEC.md,
docs/MILESTONES.md, and docs/DECISIONS.md. Do not modify files.

Check for:
1. framework imports or decision logic leaking into SteadyCore;
2. third-party packages, cloud calls, API keys, or hidden egress;
3. project.pbxproj edits;
4. a calendar write, remembered correction, or default change without confirmation;
5. allergy, SafetyGate, low-data, or no-inference violations;
6. invented menu, price, hours, ingredient, or nutrition claims;
7. guilt or failure wording;
8. force unwraps, unsafe concurrency, and permission-denied crashes;
9. missing edge-case tests;
10. status claims not supported by Mac/build/device evidence.

List findings by severity with file and line. Say explicitly when there are no findings.
Do not fix anything until I ask.
```

## 6. Teach me what was built

```text
Explain Steady <phase or feature> for a beginner in under 400 words.
Show the path from Apple service or manual input, through plain SteadyCore values,
through deterministic rules and SafetyGate, to the view. Explain what is persisted
and what is not. End with one safe, small code change I can try myself.
```

## 7. Add a real food correction in Phase 5 or later

```text
I confirmed this food information myself:
<dish, place, date checked, exact source or what I observed, price, portion, ingredients if known>

Add it using the Phase 5 evidence model. Preserve source, checkedAt, serving assumptions,
and uncertainty. Do not infer an ingredient list or nutrition value I did not provide.
Do not label it verified unless the evidence satisfies docs/SPEC.md.
Ensure the user still must choose Remember this before it affects future ranking.
Add or update tests without overwriting existing user corrections.
```

## 8. Record Mac verification evidence

```text
Record these exact results in the current phase Evidence section of docs/MILESTONES.md:

- Xcode version: <xcodebuild -version>
- Swift test command and result: <paste summary>
- iOS simulator destination and build result: <paste summary>
- watchOS simulator destination and build result: <paste summary>
- new warning count: <number>
- iPhone checks: <pass/fail/not run, with notes>
- Watch checks: <pass/fail/not run, with notes>

Do not change a checkbox to complete unless the pasted evidence proves it.
Do not infer physical-device success from a simulator build.
```
