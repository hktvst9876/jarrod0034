# Milestones

Build them **in order**, **one per session**. Tick the boxes as you go.
Each milestone ends with the Definition of Done in `AGENTS.md` §5, plus the **Test on device** steps below.

| # | Milestone | You'll be able to… |
|---|---|---|
| M0 | Project skeleton | Open the app and see empty tabs on your iPhone |
| M1 | Health context | See last night's sleep, steps and recovery from your watch |
| M2 | Onboarding + daily priority | Get one daily priority with a reason every morning |
| M3 | Calendar + bedtime | See free slots and tonight's bedtime based on tomorrow's first class |
| M4 | Plan A + alternatives + cravings | Swap a plan in two taps, reschedule, handle a craving |
| M5 | Move | Run a strength session, log sets, get progression hints |
| M6 | Eat | Get 3 cheap food picks with price, protein and an ordering tip |
| M7 | Foundations + notifications | Get ≤ 3 useful, quiet notifications a day |
| M8 | Apple Watch | Use priority, alternatives, urge and set logging on your wrist |
| M9 | Weekly review | Review the week, pick one experiment, plan gym slots, export a summary |
| M10 | Polish (+ optional on-device AI) | Accessibility, empty states, icon, optional rewording |

---

## M0 — Project skeleton
**Assistant**
- [ ] Create `Packages/SteadyCore` (Package.swift with platforms iOS 18 / watchOS 11 / macOS 15; Swift 6). Add `Support/Clock.swift` (`Clock` protocol, `SystemClock`, `FixedClock`) and `Support/SteadyCalendar.swift` (Calendar in Asia/Singapore).
- [ ] Add `Models/` with the §15 structs as plain `Codable`, `Sendable` value types (no persistence yet).
- [ ] Add seed loaders that decode `foods.json` and `alternatives.json` (bundle them as package test resources too). Tests prove both files decode.
- [ ] Copy `docs/seed/*.json` into `Steady/Resources/`.
- [ ] iOS app: `App/SteadyApp.swift`, `RootTabView` with tabs **Today · Move · Sleep · Eat · Week**, and Settings opened from Today. Placeholder views. `AppEnvironment` holding providers.
- [ ] Settings → Debug → **Use sample data** toggle (stored in `@AppStorage`).
- [ ] Watch app: one placeholder view "Steady".

**You (Xcode clicks)**
- [ ] **File → Add Package Dependencies… → Add Local… →** select `Packages/SteadyCore` → add the **SteadyCore** library to target **Steady**.
- [ ] Target **SteadyWatch Watch App → General → Frameworks, Libraries, and Embedded Content → + → SteadyCore**.

**Test on device:** Run on iPhone → 5 tabs appear → Settings shows the Debug toggle. Run the watch app → "Steady" appears.

---

## M1 — Health context
- [ ] `HealthDataProviding` protocol (async): sleep samples, resting HR, HRV, respiratory rate, wrist temp, steps, exercise minutes, workouts, body mass, time in daylight.
- [ ] `HealthKitProvider` (requests read authorization only for the types in SPEC §16) + `SampleHealthProvider` (30 days of plausible data, including some short nights and one missing night).
- [ ] SteadyCore `Sleep/`: night attribution, overlap merge, naps, sleep debt with coverage, wake consistency (SPEC §6). Tests: midnight crossing, two overlapping sources, nap excluded, missing nights.
- [ ] SteadyCore `Recovery/`: baselines, points, label, reasons, "learning (n/7)" state, sick-flag message (SPEC §10). Tests for each rule and for missing metrics.
- [ ] Today screen (temporary layout): last night's sleep + wake time, steps today, recovery label + "why" sheet, or "No sleep data" message.

**Test on device:** Run on iPhone → allow Health access → Today shows last night's sleep that matches the Health app (± a few minutes). Turn on **Use sample data** → numbers change to sample values.

---

## M2 — Onboarding, profile, daily priority
- [ ] Onboarding (< 10 min, every step skippable): focus, sleep (wake times, sleep need), movement (gym access, sessions/week, preferred time, injuries to avoid as free text), food (dietary rules, allergies, dislikes, max price per meal, kitchen), fuel targets opt-in, low-data mode. Explain each permission **before** requesting it.
- [ ] SwiftData `Profile` + mapper. Settings screen edits everything.
- [ ] SteadyCore `Fuel/`: BMR/TDEE/targets, BMR floor, BMI guard (SPEC §9). Tests incl. the worked example (2,141 kcal / 112 g).
- [ ] Morning check-in sheet (one tap or skip), shown once per day on first open after wake time.
- [ ] SteadyCore `Priority/`: `DailyContext` + rules P0–P8 (SPEC §4). **One test per rule**, plus order tests (e.g. P1 beats P4).
- [ ] Today: priority card (title, reason, Plan A summary) + **Choose another priority**. Low-data mode hides kcal/weight/recovery labels.

**Test on device:** Finish onboarding → tomorrow morning, open the app → check-in appears → Today shows one priority with a reason that uses your real sleep.

---

## M3 — Calendar + bedtime
- [ ] `CalendarProviding` (EventKit full access + sample). Ignore all-day events and the "Steady" calendar when finding busy time.
- [ ] SteadyCore `Calendar/`: free-slot finder, `freeMinutesToday`, week slot proposer (non-consecutive strength days) (SPEC §12). Tests: back-to-back classes, empty day, event crossing midnight, travel padding.
- [ ] SteadyCore `Sleep/BedtimePlanner` (SPEC §6). Tests: early class, no events, 05:30 floor, weekend wake.
- [ ] "Steady" calendar created on the first confirmed write. Confirm sheet before every write. Store `eventIdentifier`. If the event was deleted by the user, mark the plan unscheduled.
- [ ] Observe `EKEventStoreChanged` → recompute today.
- [ ] Sleep tab: last night, 7-day debt (+ coverage), consistency, tonight's bedtime window + wind-down + caffeine cutoff, with "why".
- [ ] Wire `freeMinutesToday` into the daily priority.

**Test on device:** Import your timetable `.ics` into Apple Calendar → Sleep tab shows tonight's bedtime based on tomorrow's first class → schedule something via a confirm sheet → it appears in the "Steady" calendar in Apple Calendar.

---

## M4 — Plan A + alternatives + cravings
- [ ] SteadyCore `Alternatives/`: load templates, select options by plan type + barrier (fallback to `default`), sort by effort, apply learning (promote/demote/pin/hide) (SPEC §5). Tests.
- [ ] `PlanItem` generation from the daily priority (Today shows Plan A with time).
- [ ] Alternatives sheet: barrier chips → 2–3 option cards (keeps / gives up / minutes / price) → **Choose · Later · Rest on purpose**.
- [ ] Later → propose slot via free-slot finder → confirm → calendar write.
- [ ] **Urge** button on Today: pick craving → options incl. **Wait 10 min** (timer + "still want it?") and **Planned treat** (2 per week, neutral wording). `UrgeLog` with estimated $ saved.
- [ ] `ChoiceLog` for every choice; mark completed when the user taps Done (or a matching workout appears in HealthKit).

**Test on device:** Today → Plan A → "Can't do this" → *Low energy* → choose the condensed option → it shows as today's plan. Tap **Urge → Delivery** → see cheaper options and the 10-min timer.

---

## M5 — Move
- [ ] SteadyCore `Training/`: A/B rotation, condensed + bodyweight versions, double progression, recovery adjustment (never intensify) (SPEC §7). Tests.
- [ ] Move tab: this week (strength x/3, cardio, active minutes vs 150), next session, history.
- [ ] Session screen: exercise list, sets with reps/weight steppers, rest timer, "too much today" → alternatives.
- [ ] Read `HKWorkout`s and match them to planned sessions by time.
- [ ] Progression hint on the next session ("Squat: try 42.5 kg").

**Test on device:** Start session A at the gym → log sets → finish → Move tab updates. Next session B shows. Do A again later → weight suggestion appears if you hit the top of the range.

---

## M6 — Eat
- [ ] On first launch, import `foods.json` dishes into SwiftData `FoodItem` (provenance `estimate`). Never overwrite user edits on later imports.
- [ ] SteadyCore `Food/`: hard filters (allergies, unknown-ingredient labelling, diet, kitchen, price) then scoring and 3 picks (SPEC §8). **Tests: allergy never leaks; unknown-ingredient dish never ranks first for a user with allergies; price cap; low-data mode hides kcal.**
- [ ] Eat tab: **What should I eat?** (slot auto-detected, where: campus/hawker/home) → 3 cards with price, protein range, kcal range, label, why, ordering tip → **Log it**.
- [ ] Quick log presets + **Adjust** (portion ½/1/1.5×, price) + "remember this" for corrections.
- [ ] Add my own dish (name, place, price, rough kcal/protein or "not sure").
- [ ] Write `dietaryEnergyConsumed`, `dietaryProtein`, `dietaryCaffeine` to HealthKit if the user allowed it (request write permission here, explained first).
- [ ] *(Optional sub-step)* Nearby: `MKLocalSearch` with approximate location or a typed area → list places with distance + "Open in Maps"; dishes labelled "typical — menu not verified". **You:** add the Location usage key if you haven't (SETUP §4).
- [ ] Grocery list builder (used in M9).

**Test on device:** At lunch → Eat → What should I eat? → 3 hawker picks under your max price, with ordering tips → log one → Today's protein/price updates. Set an allergy to *fish* → no fish dishes appear.

---

## M7 — Foundations + notifications
- [ ] SteadyCore `Nudges/`: candidate builder, quiet periods + class filtering, priority, **max 3**, dismissal adaptation (SPEC §11). Tests.
- [ ] `NotificationScheduler`: request permission (explained first), schedule today's nudges, categories with **Done · Later · Another option** actions, handle the responses.
- [ ] Recompute on: first open after wake, any app open, `EKEventStoreChanged`, Plan A change.
- [ ] Foundation card on Today (one at a time, can be replaced or disabled). Caffeine quick-log (kopi, teh, coffee, energy drink).
- [ ] Settings → Notifications: toggle each type, quiet periods.

**Test on device:** Open the app in the morning → check iOS Settings → Notifications for Steady is on → during the day you get at most 3 notifications, none during classes, and the wind-down one arrives 45 min before bedtime.

---

## M8 — Apple Watch
- [ ] `WatchConnectivity` on both sides: phone → `DailyPlanSnapshot` via application context; watch → logs via `transferUserInfo`; phone applies logs to SwiftData.
- [ ] Watch views: Glance, Alternatives, Move (set logging + rest timer), Urge (+ 10-min timer), Quick log.
- [ ] Watch reads HealthKit for display (sleep, steps).
- [ ] **You (Xcode clicks):** **File → New → Target → watchOS → Widget Extension** → name `SteadyWatchWidgets` → embed in *SteadyWatch Watch App*. Then the assistant adds complications: **Next** and **Urge**.
- [ ] Low-data mode respected on the watch.

**Test on device:** Run the watch app → Glance shows today's priority → tap Urge → choose *Sweet drink* → options appear → choose one → it shows in the phone's log within a minute (phone nearby). Add the **Next** complication to a watch face.

---

## M9 — Weekly review
- [ ] SteadyCore `Weekly/`: aggregates (sleep, movement, plans swapped, alternatives completed, cravings + $ saved, food spend, foundations), adaptive TDEE (SPEC §9), option learning, wellbeing check rule (SPEC §14). Tests.
- [ ] Week tab: the review sections → choose **one experiment** with an end date → propose next week's gym slots → confirm → grocery list → **Copy coach summary**.
- [ ] Sunday 18:00 notification "Weekly review ready" (counts toward the daily 3).
- [ ] Settings → **Export my data** (JSON via share sheet) and **Delete all Steady data** (with confirmation).

**Test on device:** On Sunday open Week → review shows real numbers → pick an experiment → approve 3 gym slots → they appear in the Steady calendar → Copy coach summary → paste into Notes.

---

## M10 — Polish (+ optional on-device AI)
- [ ] Dynamic Type, VoiceOver labels, dark mode, empty states for every screen, app icon.
- [ ] Remove any guilt wording (search the codebase for "fail", "missed", "streak", "should have").
- [ ] Performance: Today loads in < 1 s with 90 days of data.
- [ ] *(Optional)* If `SystemLanguageModel.default.availability == .available` (iOS 26+, Apple Intelligence on): reword option explanations in a friendlier tone. Only for options that already passed the rules; templates are always the fallback (SPEC §20).

**Test on device:** Set the largest text size in iOS Settings → every screen is still usable. Turn on VoiceOver → Today reads sensibly.
