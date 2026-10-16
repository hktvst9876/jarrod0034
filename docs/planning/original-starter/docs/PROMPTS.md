# Prompts to paste into your coding assistant

Use these in **Codex or Claude Code, opened in your `Steady` project folder on the Mac**.
Rules of thumb:
- **One milestone per session.** Start a fresh session for each milestone so the assistant re-reads the docs.
- **Test on your phone before moving on.** Then commit (Xcode → Integrate → Commit).
- If the assistant asks you to click something in Xcode, do it, then reply **"done"**.

---

## 1. Kickoff (first session only)

```
You're helping me build Steady, a personal wellness app for my own iPhone and Apple Watch.
I'm a college student in Singapore and not an experienced iOS developer.

First read AGENTS.md, then docs/SPEC.md, docs/MILESTONES.md and docs/DECISIONS.md.

Then do milestone M0 only:
1. Give me a short plan (files you'll create, and anything I must click in Xcode).
2. Build it, following every rule in AGENTS.md.
3. Run `swift test --package-path Packages/SteadyCore` and build both schemes for the simulator. Fix any errors.
4. Update MILESTONES.md and DECISIONS.md.
5. Finish with: what changed, numbered steps for me to test on my iPhone and Watch,
   any Xcode clicks I still need to do, and a commit message.

Don't start M1. If something in the spec is unclear, choose the simplest option that respects
AGENTS.md, write it in DECISIONS.md and tell me.
```

---

## 2. Next milestone (every new session)

```
Read AGENTS.md, docs/SPEC.md, docs/MILESTONES.md and docs/DECISIONS.md.
Build the next unchecked milestone in MILESTONES.md (only that one).

Order of work: SteadyCore logic + unit tests first, then services, then UI.
Run the tests and both simulator builds until they pass with no new warnings.
Update MILESTONES.md and DECISIONS.md.

Finish with: what changed, numbered steps for me to test it on my iPhone/Watch,
any Xcode clicks I need to do, and a commit message. Then stop.
```

*To do a specific one instead:* replace the second line with `Build milestone M5 (only that one).`

---

## 3. Something's broken

```
Something's wrong. Here's what happened:

- What I did: <steps, e.g. "opened Eat, tapped What should I eat?">
- What I expected: <…>
- What happened instead: <…>
- Error text from Xcode (if any): <paste it>
- Screenshot: <attach if you can>

Find the cause before changing code. Explain it in 2–3 sentences, then fix it with the smallest change.
Add a test that would have caught it if it's in SteadyCore logic. Run tests + builds.
Tell me how to check the fix on my phone.
```

---

## 4. Change how something works

```
I want to change how Steady behaves:
<describe the change in plain words, e.g. "Bedtime should allow 20 minutes to fall asleep, not 15",
or "Add yong tau foo dry version to the food list at $5.50">

First update docs/SPEC.md (and docs/seed/*.json if it's data) so the spec stays the source of truth.
Then change the code and tests to match. Log the change in DECISIONS.md.
Keep the change small. Tell me how to see it on my phone.
```

---

## 5. Review before I commit (use a fresh session)

```
Review the uncommitted changes in this repo against AGENTS.md and docs/SPEC.md. Check:
1. Any rule in AGENTS.md §1 broken (third-party packages, network calls, pbxproj edits,
   calendar writes without confirmation, logic outside SteadyCore)?
2. Safety rules in SPEC §18, especially the allergy filters, BMR floor and low-data mode.
3. Guilt or failure wording in any user-facing string.
4. Missing tests for new SteadyCore logic, and edge cases (no data, midnight, permission denied).
5. Anything that would crash on a real device (force unwraps, main-thread HealthKit calls).

List problems by severity with file:line. Don't change code unless I say "fix them".
```

---

## 6. Teach me what you built

```
Explain the code you added for <milestone or feature> as if I'm a beginner:
which files matter, how data flows from HealthKit/Calendar → SteadyCore → the screen,
and one small change I could try myself to learn. Keep it under 300 words.
```

---

## 7. Add my real data (after M6)

```
Here are dishes I actually eat, with the prices I paid:
<e.g. "Fish soup + rice, Block 123 hawker, $5.50; Chicken rice stall at campus canteen, $3.80 (steamed)">

Add them to docs/seed/foods.json in the existing format (estimate kcal/protein ranges, mark
provenance "saved", contains_confidence "unknown" unless obvious), and make sure the app imports
new seed items without overwriting dishes I've already edited.
```

---

## 8. Weekly coach (paste into a normal chat with Claude, not the coding assistant)

```
Here's my week from my wellness app Steady. My main focus is <sleep / strength / energy …>.
Tell me: the one change most likely to help next week, what's going well,
and any patterns between my sleep, cravings, food spend and training. Keep it short and practical.

<paste the "Copy coach summary" text here>
```
