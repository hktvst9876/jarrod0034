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

Confirm that the prior phase is accepted. Then build the first phase marked Not started,
and build only that phase. If the prior phase is not accepted, stop and report the exact gate.

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

To request a specific phase, replace "the first phase marked Not started" with, for example, `Phase 3 - Daily Foundations`.

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
