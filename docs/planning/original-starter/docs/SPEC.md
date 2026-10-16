# Steady — product spec (v1.0, October 2026)

Steady is a personal wellness advisor for one person: a college student in Singapore with an iPhone, an Apple Watch and a tight budget.
It helps them **choose a realistic action right now**, and recover gracefully when the original plan stops fitting.

This spec merges the *Steady App Workflow* product direction (Plan A + alternatives, quiet and non-judgmental, privacy-first) with concrete rules, formulas, prices and a data model.

---

## 0. Profile (set in onboarding, editable in Settings)

```yaml
name: ""
age: null
sex: prefer_not                  # female | male | prefer_not  (only used for the BMR formula)
height_cm: null
weight_kg: null
primary_focus: sleep             # sleep | movement | strength | energy | stress | general
fuel_targets_enabled: false      # calorie/protein numbers are OPT-IN (§9)
fuel_goal: maintain              # lose_fat | maintain | build_muscle
dietary_rules: []                # halal | no_pork | no_beef | vegetarian | vegan
allergies: []                    # HARD filters: egg | fish | shellfish | peanut | tree_nut | soy | dairy | gluten | sesame
disliked_foods: []
max_price_per_meal_sgd: 6.00
show_food_spend_in_weekly_review: true
kitchen_access: microwave_kettle # full | microwave_kettle | none
gym_access: campus               # campus | activesg | none
strength_sessions_per_week: 3
preferred_workout_time: afternoon  # morning | afternoon | evening
wake_time_weekday: "07:30"
wake_time_weekend: "08:30"
sleep_need_hours: 8.0
morning_routine_minutes: 45
default_travel_minutes: 30
caffeine_cutoff_hours_before_bed: 8
quiet_periods: []                # e.g. { days: [mon, wed], start: "09:00", end: "12:00" }
low_data_mode: false             # hides calorie numbers, weight trend and recovery labels
exam_mode: false
nudges_enabled: [wind_down, workout_soon, caffeine_cutoff, daylight]
```

---

## 1. Product direction

**Promise.** For any meaningful choice, Steady answers four questions: *What matters today? What's the best realistic plan? What are the alternatives that still get most of the benefit? Why does each one fit right now?*

**Principles**
1. **One priority a day.** Not a dashboard of 20 numbers.
2. **Plan A always has a Plan B.** Missing the plan is normal, so the app's job is to offer the next best option.
3. **Health data is context, not authority.** The user can always say "that's wrong" or "not today".
4. **Quiet by default.** At most 3 proactive notifications a day. Prefer updating the Today screen silently.
5. **No guilt.** No streaks, no failure language, no loss warnings.
6. **Cheap by design.** Every food suggestion shows a price and respects a max price per meal. No paid APIs.
7. **On-device.** Health data, calendar and history never leave the phone.

---

## 2. Wellness areas

| Area | Steady supports | Steady avoids |
|---|---|---|
| Sleep & recovery | Consistent wake time, protected sleep window, wind-down, recovery context | Claiming a sensor score knows how you feel |
| Movement & training | Strength 3×/week, easy cardio, walking, mobility, shorter versions, deliberate rest | Treating a missed workout as failure; pushing harder because a score is high |
| Nourishment | Cheap practical dishes, protein, price, dietary rules, meal timing | False precision; obsessive logging by default |
| Cravings & habits | Late supper, delivery apps, sugary drinks, scrolling in bed → alternatives + "planned treat" | Shame, restriction, blocking apps |
| Mental wellbeing | Lighter days, downtime, short resets, pointing to real support when needed | Diagnosis; replacing professional care |
| Daily foundations | Morning daylight, gentle movement, water, movement breaks | Supplements, fasting, cold plunges, biohacking claims |

---

## 3. The daily loop

| When | What happens | Time it takes |
|---|---|---|
| **Morning** (first open after waking) | Sleep context (duration, timing, "missing data" if none) → optional check-in: *What feels hard today?* (low energy / short on time / stressed / sore / nothing / skip) → **Daily priority** with its reason → **Plan A** with best time → one foundation nudge. Then the nudge planner (§11) schedules today's notifications. | < 1 min |
| **Day** | Quiet. Today screen updates. Notifications only from the nudge planner. User opens **Alternatives** or **What should I eat?** when they need it. | — |
| **Evening** | Wind-down reminder with the *smallest useful routine first*. Bedtime window for tonight, based on tomorrow's first commitment. | 30 s |
| **Sunday** | Weekly review (§14): what worked, which alternatives helped, one experiment for next week, gym slots, grocery list. | 5–10 min |

---

## 4. Daily priority (deterministic rules)

**Inputs (`DailyContext`)**: `sleepLastNightHours?`, `sleepNeedHours`, `sleepDebt7dHours`, `recovery` (§10), `daysSinceExercise`, `strengthDoneThisWeek`, `strengthTarget`, `daysLeftInWeekIncludingToday` (week = Mon–Sun), `strengthYesterday: Bool`, `freeMinutesToday` (§12), `checkIn?`, `healthFlag` (user reported pain/illness or a watch health alert today), `plannedItemToday?`, `examMode`.

**Rules: first match wins.** Each rule returns `{kind, title, reason, planA}`. The `reason` uses real numbers.

| # | Condition | Priority (kind) | Plan A | Example reason |
|---|---|---|---|---|
| P0 | `healthFlag` | `look_after_yourself` | Rest; show safety message (§18) | "You mentioned feeling unwell. Rest is the plan today." |
| P1 | sleep < need − 1.5 h **or** sleepDebt7d ≥ 5 h | `protect_bedtime` | Wind-down on time; any movement is a walk | "You slept 5 h 40 m. Tonight's bedtime matters most." |
| P2 | recovery = `go_easier` **or** checkIn = `sore` | `recover` | 20–30 min easy walk + 10 min mobility | "Your resting heart rate is higher than usual and you slept less." |
| P3 | checkIn = `short_on_time` **or** freeMinutesToday < 45 | `keep_it_small` | 10-min brisk walk + protect bedtime | "Only 35 free minutes today. A short walk still counts." |
| P4 | remaining = target − done > 0 **and** not strengthYesterday **and** (today is a planned strength day **or** daysLeft ≤ 2 × remaining) | `strength` | Next strength session (A/B, §7) in the best free slot | "2 of 3 sessions left and 4 days to go." |
| P5 | daysSinceExercise ≥ 2 | `get_moving` | 30-min walk or cardio | "No exercise logged for 2 days." |
| P6 | checkIn = `stressed` | `lighter_day` | Walk outside + planned downtime | "Busy head today. A walk helps and the plan stays light." |
| P7 | plannedItemToday exists | `follow_plan` | That item. If checkIn = `low_energy`, show the condensed version first | "Cardio was planned for today." |
| P8 | otherwise | `steady_day` | Hit steps naturally + protein at meals + bedtime | "Nothing urgent. A normal steady day." |

The user can always tap **Choose another priority**.
`examMode`: P4 strength sessions use the condensed version; P1's threshold relaxes to need − 1 h.

---

## 5. Plan A and the alternative ladder

Every Plan A has an **intended outcome**. Alternatives don't need to be equivalent. Each one states **what it keeps** and **what it gives up**.

**Barriers the user can pick** (or "Just show me another option"):

| Group | Barriers |
|---|---|
| Energy & body | `low_energy`, `sore`, `stressed` |
| Time & place | `no_time`, `bad_weather` (rain/heat), `home_late`, `no_kitchen`, `social_plans` |
| Money | `low_budget` |
| **Cravings** | `craving_supper`, `craving_delivery`, `craving_sweet_drink`, `scrolling_in_bed` |

**Flow**
1. Identify the outcome behind Plan A.
2. User picks a barrier (one tap) or asks for another option.
3. Show **2–3 options** (craving ladders: up to 4), highest effort first, each with: title, minutes, effort (1–3), *keeps*, *gives up*, steps, and price if relevant.
4. User chooses one, **defers** ("later today / tomorrow"), or **rests on purpose**. Resting is a valid choice, logged neutrally.
5. If deferred: propose a new slot (§12) → user confirms → calendar write.
6. Log a `ChoiceLog` (Plan A, barrier, option, completed?).

**Cravings ("Urge" button on phone and watch).** Picking a craving opens the same ladder. Every `craving_*` barrier always includes:
- a **"wait 10 minutes"** option (starts a timer, then asks "still want it?"), and
- **"Have it — planned treat"**. Two planned treats a week are part of the plan, not a failure.

Estimated money saved = typical price of the craving − price of the chosen option (if positive). This is shown only in the weekly review.

**Learning (weekly).** Options chosen *and completed* ≥ 2 times in the last 4 weeks move up the list. Options skipped 3 times move down. The user can pin or hide any option.

**Templates** live in `docs/seed/alternatives.json` and are the product. They work offline with no AI. An optional AI layer (§20) may only reword or re-rank options that already passed the rules.
- Plan types: `strength`, `cardio`, `walk`, `wind_down`, `meal`, `afternoon_break`, `study_block`, `morning_daylight`. Unlisted barrier → that plan's `default` options.
- Option flags: `is_rest` (deliberate rest), `is_wait` (starts the 10-min timer), `is_planned_treat` (counts toward the 2/week), optional `price_sgd`.
- **Urge → plan mapping:** `craving_supper` and `scrolling_in_bed` → `wind_down`; `craving_delivery` → `meal`; `craving_sweet_drink` → `afternoon_break`.
- If the planned-treat allowance is used up, the treat option still shows, labelled "Extra treat this week". It's never hidden and never shamed.

---

## 6. Sleep

**Targets:** sleep need (default 8 h) · wake time within ±30 min daily (weekend ≤ 60 min later) · caffeine cutoff = bedtime − 8 h · morning daylight · naps ≤ 30 min before 16:00.

**Bedtime planner (each evening, and after calendar changes)**
```
first      = earliest timed event tomorrow (ignore all-day events and the "Steady" calendar)
wake       = usual wake time for tomorrow
if first exists: wake = min(wake, first − travel − morning_routine)
wake       = max(wake, 05:30)            # earlier than 05:30 → show a heads-up instead
bedtime    = wake − sleep_need − 15 min  # 15 min to fall asleep
window     = bedtime ± 30 min
wind_down  = bedtime − 45 min
caffeine_cutoff = bedtime − caffeine_cutoff_hours_before_bed
```
If tomorrow's wake is > 60 min earlier than usual, say so in the evening: "Early class tomorrow (08:00). Aim for bed by 23:15."

**Night attribution.** A night belongs to the date you woke up. Include HealthKit `sleepAnalysis` samples with values asleepCore, asleepDeep, asleepREM or asleepUnspecified whose end falls in (D−1 18:00, D 18:00]. Merge overlapping samples from different sources so time is counted once. Samples that start and end between 12:00 and 18:00 are naps.

**Derived metrics**
- **Sleep debt (7 d)** = Σ max(0, need − actual) over nights with data. Always show coverage: "(5 of 7 nights tracked)".
- **Wake consistency** = mean absolute deviation of wake time over 7 days: ≤ 30 min *steady*, 31–60 *a bit irregular*, > 60 *irregular*.

**Wind-down (smallest version first):** phone on the desk charger → prepare tomorrow's bag/first task → lights low → bed. Full routine optional. If the user can't sleep, give one neutral, low-stimulation suggestion. No repeated alerts.

---

## 7. Movement & training

**Weekly targets:** 150+ min moderate activity (brisk walking counts) · 3 strength sessions · 1–2 easy cardio sessions (20–30 min, conversational pace) · steps: no hard target, but the Today screen shows them.

**Strength: alternate A and B, never on consecutive days**

| Session A | Sets × reps | Session B | Sets × reps |
|---|---|---|---|
| Goblet or barbell squat | 3 × 6–10 | Split squat or leg press | 3 × 8–12 |
| Bench press or push-ups | 3 × 6–12 | Overhead press | 3 × 6–10 |
| Seated cable or dumbbell row | 3 × 8–12 | Lat pulldown or pull-ups | 3 × 6–10 |
| Romanian deadlift | 2 × 8–10 | Hip thrust | 2 × 10–12 |
| Plank | 3 × 30–45 s | Dead bug | 3 × 10/side |

- **Condensed version** (low energy, exam mode, short slot): the first 3 exercises × 2 sets, ~25 min.
- **No-gym version:** push-ups (feet raised when easy) · Bulgarian split squats on a chair · backpack Romanian deadlifts · backpack rows · glute bridges · plank.
- **Progression (double progression):** all sets reach the top of the rep range → next time add weight (+2.5 kg upper, +5 kg lower) and restart at the bottom of the range. Never suggest a weight increase on a `go_easier` day.
- **Recovery adjustment:** `go_easier` → condensed or walk + mobility. `recovered` → as planned (**never intensify because of a score**).

**Where to train cheaply (Singapore)**
- **Campus gym:** check first; usually the cheapest.
- **ActiveSG gym:** $2.50 per entry (adult). Peak monthly pass $30, off-peak $15. The pass only beats per-entry above **12 visits a month**.
- **Park connectors:** free, for walks and easy runs. Outdoor walks also give the watch VO2 max readings.

**Data:** sets/reps/weight logged in Steady (`SetLog`). Duration, heart rate and calories come from the watch's Workout app (`HKWorkout`).

---

## 8. Eat — cheap, practical, local-first

**Local-first.** The food library = `docs/seed/foods.json` (hawker dishes + home staples, estimates) + the user's **saved dishes** (their stall, their price, their corrections). Live search is an optional extra (M6), not the foundation. Most hawker stalls have no online menu.

**"What should I eat?"**

*Inputs:* meal slot (from time of day: breakfast < 10:30, lunch < 15:00, dinner < 21:30, else supper) · where (campus / hawker / home / nearby) · max price per meal · dietary rules · allergies · dislikes · kitchen access · context (post-workout within 2 h? before bed within 3 h?) · kcal/protein remaining (only if fuel targets on).

*Hard filters (in code, before any ranking):*
- **Allergies:** exclude any dish whose `contains` includes the allergen. If the user has allergies and a dish's `contains_confidence` is `unknown`, show it only with the label **"Ingredients unknown — ask the stall"**, and never as the top pick.
- **Dietary rules:** `no_pork` / `halal` exclude dishes with `pork` or `lard` in `contains`. `halal` also shows "Check the stall is halal-certified." `vegetarian` / `vegan` use the `diet` field.
- **Kitchen:** home dishes need `kitchen_access` ≥ the dish's `needs_kitchen`.
- **Price:** exclude dishes priced above `max_price_per_meal × 1.25`. Dishes above the max show "$X over your usual".

*Score (0–1):*
```
protein_target_meal = fuel_on ? protein_target / 3 : 25 g
protein_fit = min(1, protein_mid / protein_target_meal)
price_fit   = 1 if price ≤ 0.75 × max; falls linearly to 0 at 1.25 × max
kcal_fit    = fuel_on ? 1 − min(1, |kcal_mid − kcal_slot_target| / kcal_slot_target) : 0.5
              (kcal_slot_target = kcal_remaining / meals_remaining_today)
context_fit = post_workout ? protein_fit : before_bed ? (kcal_max ≤ 500 ? 1 : 0.3) : 0.5
liking      = rating != nil ? (rating − 1) / 4 : 0.5

score = 0.35 protein_fit + 0.25 price_fit + 0.20 kcal_fit + 0.10 context_fit + 0.10 liking
```
*Output: 3 picks*: **Best fit** · **Cheapest good option** (lowest price with protein_fit ≥ 0.5) · **Familiar** (most-chosen in the last 30 days). Deduplicate. Each card shows:
- price
- protein range and kcal range (kcal hidden in low-data mode)
- a provenance label: **estimate** (seed data), **saved** (from your own logs, with the date), or **verified** (you confirmed it at the stall or from a menu)
- a one-line *why*
- an **ordering tip** (e.g. "steamed, not roasted; less rice; add an egg")

**Logging.** One tap on a pick or preset logs it at the range midpoint. "Adjust" lets the user change portion (½×, 1×, 1.5×) and price. Corrections are saved to that dish **only if the user says "remember this"**.

**Nearby (M6, optional, user-triggered).** `MKLocalSearch` near the approximate location (or a typed area/campus), radius ~1.5 km, queries like "hawker centre", "food court", "fish soup". Show name, distance, "Open in Maps". Never claim a menu, price or opening hours that MapKit didn't return. Suggested dishes for a place are labelled "typical dishes — menu not verified".

**Grocery list** (weekly review): staples from `foods.json` with `grocery: true`, filtered by kitchen access and diet, with typical FairPrice prices.

**Plate rule (HPB My Healthy Plate):** ½ vegetables/fruit, ¼ protein, ¼ carbs. At hawker: protein first, extra veg, rice is the adjustable part.

---

## 9. Fuel targets (opt-in)

Off by default. When on:
```
BMR (Mifflin–St Jeor)
  male:   10 × kg + 6.25 × cm − 5 × age + 5
  female: 10 × kg + 6.25 × cm − 5 × age − 161
  prefer_not: 10 × kg + 6.25 × cm − 5 × age − 78
TDEE start = BMR × 1.5            (user can pick 1.4 / 1.5 / 1.6 / 1.7)
target     = TDEE − 400 (lose_fat) | TDEE (maintain) | TDEE + 200 (build_muscle)
target     = max(target, BMR)     # never below BMR
protein    = 1.6 g × kg           (show "1.6–2.2 g/kg is the useful range")
```
*Example: 21 y, male, 70 kg, 175 cm → BMR 1,694 · TDEE 2,541 · lose-fat target 2,141 kcal · protein 112 g.*

**Adaptive update (weekly, only if ≥ 10 of the last 14 days have food logs and ≥ 4 weigh-ins):**
```
trend(d)     = 7-day moving average of weigh-ins
observed     = avg_intake_14d − (trend(today) − trend(today − 14)) × 7700 / 14
new_TDEE     = 0.7 × old_TDEE + 0.3 × observed, change capped at ±150 kcal/week
```
**Guards:** BMI < 18.5 → `lose_fat` is unavailable (explain kindly). Trend weight falling > 1% of body weight per week → suggest eating more and offer low-data mode. The watch's active-calorie number is shown for reference only. It's never used to "earn" food.

---

## 10. Recovery context

Needs ≥ 7 days of data; before that, show "Learning your baseline (n/7 days)". Baselines are 30-day mean and SD (or whatever is available, minimum 7 days).

```
points = 0
sleep last night < need − 1 h                 → +1
HRV (overnight avg) < mean − 1 SD             → +1
resting HR > baseline + 5 bpm                 → +1
wrist temp > baseline + 0.5 °C or resp. rate > baseline + 2/min → +1, and show
      "Your body might be fighting something. Take it easy and see a doctor if you feel unwell."

0 → recovered   1 → normal   ≥ 2 → go_easier
```
Always show the reasons in plain words. Hidden in low-data mode (it still feeds the daily priority quietly). Missing metrics are skipped, not counted as bad.

---

## 11. Daily foundations & notifications

**Foundations (each can be done, snoozed, replaced or disabled)**

| Moment | Suggestion | Boundary |
|---|---|---|
| After waking | 2–5 min of comfortable movement (standing, seated, or skip) | No "detox" or "circulation" claims |
| Morning | 10+ min outdoor daylight, e.g. walk to class | Never "look at the sun". Mention shade; UV is very high 11:00–15:00 |
| Breakfast | Water with breakfast; drink to thirst | No fixed volume target |
| Long study blocks | Stand or walk briefly every 60–90 min (if enabled) | Seated options available. The watch's Stand reminders can do this instead |
| Before demanding work | Short reset: slow breathing, a walk, or quiet prep | Stress support, not treatment |
| Before bed | Smallest wind-down that works | Sleep timing beats elaborate routines |

**Nudge planner (`SteadyCore/Nudges`)**: runs on the first app open after waking, and again whenever the app opens, the calendar changes (`EKEventStoreChanged`) or Plan A changes. It **schedules local notifications for the rest of the day**. It doesn't rely on background execution.
1. Candidates: `wind_down` (at wind_down) · `workout_soon` (30 min before a Plan A slot) · `caffeine_cutoff` (at cutoff) · `daylight` (08:00 if before 10:00 and not done).
2. Drop any candidate inside a quiet period or a calendar event (class), or already past.
3. Priority: wind_down > workout_soon > caffeine_cutoff > daylight. **Keep at most 3.**
4. Each notification has actions: **Done · Later · Another option**.
5. A type dismissed 3 times in 7 days → schedule it every other day only, and ask about it in the weekly review.
6. Wording is specific and kind: "Wind-down in 10 min: phone on the desk, bag ready, lights low." No "you missed…".

---

## 12. Calendar

- **Read** all calendars (classes, CCAs, part-time work; Google calendars added in iOS Settings appear too). Class timetables: import the `.ics` from your uni's timetable tool into Apple Calendar each semester.
- **Write** only to a calendar named **"Steady"** (create it on first confirmed write). Every write or reschedule needs **Confirm**. Store the `eventIdentifier`. If the user deletes the event, mark the plan unscheduled and don't recreate it.
- **Free-slot finder** (pure function on intervals):
```
day window   = [max(wake + 60 min, 07:00), bedtime − 150 min]
busy         = timed events, each padded by travel buffer (default 15 min before and after)
free gaps    = day window − busy
candidate    = gap ≥ needed minutes
rank         = matches preferred_workout_time first, then earliest
freeMinutesToday = Σ free gaps ≥ 15 min (from now)
```
- **Week planner** (weekly review): propose `strength_sessions_per_week` slots on non-consecutive days + 1–2 cardio slots. The user approves each one; approved slots are written to "Steady".
- **Exam mode:** condensed sessions (30–40 min), bedtime protected, easiest food options first.

---

## 13. Apple Watch

| View | Content | Interaction |
|---|---|---|
| Glance | Today's priority, next planned action, last night's sleep | Tap to open the action |
| Alternatives | 3 short options for the current plan | Choose, or "send to phone" |
| Move | Current exercise, set, rest timer | Log a set in 1–2 taps |
| Urge | Pick craving → options + 10-min timer | 2 taps |
| Quick log | Top 8 saved dishes/drinks | 1 tap |
| Complications | "Next" (next action) and "Urge" shortcut | — |

**Sync:** the phone sends `DailyPlanSnapshot` (priority, Plan A, options, top dishes) via `updateApplicationContext`. The watch sends logs via `transferUserInfo`. The watch reads HealthKit itself for display.

---

## 14. Weekly review (Sunday, 5–10 min)

| Section | Shows | Possible adjustment |
|---|---|---|
| Sleep | Avg sleep, nights tracked, wake consistency, debt | Move wind-down; keep as is |
| Movement | Active minutes vs 150, strength sessions, cardio | Change default duration/time |
| Plans | Which Plan A items were often swapped | Make the realistic version the default |
| Alternatives | Which options were chosen and completed | Promote / hide options |
| Cravings | Urges by type and time of day, planned treats, estimated $ saved | Plan a snack on late-study nights |
| Food | Most-chosen dishes, corrections, **food spend** (if enabled) | Grocery list, cheaper swaps |
| Fuel (if on) | Protein days hit, trend weight, TDEE update | Apply the new target |
| Foundations | Done vs dismissed | Keep / reduce / disable |
| **Next week** | Choose **one experiment** with an end date (e.g. "Bed by 23:30 on weeknights until Sun 26 Oct") | — |

Then: propose next week's gym slots (§12) → confirm. Show the grocery list. Offer **Copy coach summary** (plain text to the clipboard; nothing is sent anywhere).

**Wellbeing check:** if `stressed` was chosen as a check-in or barrier on ≥ 8 of the last 14 days, gently add: *"It's been a heavy couple of weeks. Talking to someone can help. Your campus counselling service is free for students. If you ever feel unsafe, Samaritans of Singapore (SOS) is available 24 hours at 1767."* Show it once per two weeks at most. Never diagnose.

---

## 15. Data model (SwiftData in the app; mirrored as plain structs in SteadyCore)

```swift
Profile        { all §0 fields, tdee: Double?, kcalTarget: Int?, proteinTargetG: Int?, createdAt }
FoodItem       { id, name, place: hawker|canteen|home|grocery|cafe, priceSGD, kcalMin, kcalMax,
                 proteinMin, proteinMax, contains: [String], containsConfidence: likely|verified|unknown,
                 diet: omnivore|vegetarian|vegan, needsKitchen: none|microwave_kettle|full,
                 caffeineMg: Int?, tags: [String], orderTip: String?, provenance: estimate|saved|verified,
                 priceSource: String?, isUserCreated, rating: Int?, timesChosen, lastChosenAt?,
                 seedId: String? }        // seedId lets re-imports update seed rows without touching user edits
GroceryItem    { id, name, store, priceSGD, priceConfidence: verified|approx, validUntil: Date?, note?,
                 forKitchen, diet }
MealLog        { id, date, slot, foodItemId?, name, portion: Double, kcalEst, proteinEst, priceSGD,
                 isPlannedTreat, note? }
PlanItem       { id, date, type: strength|cardio|walk|wind_down|meal|afternoon_break|study_block|
                       morning_daylight|rest,
                 templateId?, start?, end?, status: planned|done|swapped|deferred|rested|skipped,
                 calendarEventId?, outcome: String }
ChoiceLog      { id, date, planItemId, barrier?, optionId, accepted: Bool, completed: Bool? }
UrgeLog        { id, date, kind: supper|delivery|sweet_drink|scrolling|other, intensity: 1...5,
                 optionId?, outcome: waited|swapped|planned_treat|other, estSavedSGD: Double? }
SetLog         { id, date, sessionTemplate: A|B|condensed|bodyweight, exercise, setNumber, reps, weightKg? }
WeightEntry    { id, date, kg }
NudgeLog       { id, type, scheduledAt, action: done|later|another|dismissed|none }
CheckIn        { id, date, value: low_energy|short_on_time|stressed|sore|nothing|skipped }
DailySnapshot  { date, sleepHours?, wakeTime?, steps?, exerciseMin?, restingHR?, hrv?, recovery?,
                 priorityKind, kcalIn?, proteinIn?, spentSGD }
WeeklyReview   { weekStart, experiment: String?, experimentEnds: Date?, tdeeBefore?, tdeeAfter?, notes? }
SavedPlace     { id, name, area, latitude?, longitude?, isFavourite }
```

---

## 16. HealthKit

| Read | Use |
|---|---|
| `sleepAnalysis` | Sleep, nights, naps (§6) |
| `restingHeartRate`, `heartRateVariabilitySDNN` | Recovery (§10) |
| `respiratoryRate`, `appleSleepingWristTemperature` | "Might be fighting something" flag |
| `stepCount`, `appleExerciseTime` | Movement |
| `HKWorkoutType` | Training log |
| `activeEnergyBurned` | Reference only |
| `vo2Max`, `timeInDaylight` | Monthly trend; daylight foundation |
| `bodyMass` | Fuel targets (if on) |

| Write (only what the user logs) |
|---|
| `dietaryEnergyConsumed`, `dietaryProtein`, `dietaryCaffeine`, `dietaryWater`, `bodyMass` |

Request only the types needed for features the user turned on. If a type is denied, that feature shows "not available" and the rest keeps working.

---

## 17. Privacy & confirmation boundaries

- Raw HealthKit samples, calendar details, location, logs and history stay **on device**. No network except MapKit search (user-triggered).
- The user confirms **every** calendar write or reschedule.
- The user decides whether a correction becomes a remembered preference.
- Settings → **Export my data** (JSON) and **Delete all Steady data**.
- If an optional AI layer is ever added (§20), it receives only a minimal, coarse context packet (e.g. "slept less than usual", free windows, dietary rules), never raw health data. It never gets authority to act.

---

## 18. Safety & trust rules (enforced in code)

1. Steady gives wellness guidance; it doesn't diagnose or treat. About screen says so.
2. **Allergies are hard filters.** Unknown ingredients are labelled unknown, never assumed safe.
3. No supplements, fasting protocols, cold exposure, extreme heat or other high-risk "biohacks".
4. Pain, fainting, chest symptoms, unusual breathlessness, or a watch heart alert → a safety message ("Please stop and get checked. Campus health centre or a GP; 995 in an emergency") instead of any training suggestion.
5. Never intensify exercise because a score is high.
6. No fixed hydration target.
7. Daylight suggestions never say to look at the sun, and mention shade/UV at midday.
8. Calorie target never below BMR. `lose_fat` unavailable at BMI < 18.5. Rapid loss flagged (§9).
9. **Low-data mode** hides calorie numbers, weight trend and recovery labels everywhere, including on the watch and in notifications.
10. No guilt language anywhere (see AGENTS.md).
11. Wellbeing check in the weekly review (§14).

---

## 19. Failures & fallbacks

| Failure | Fallback |
|---|---|
| No sleep data last night | "No sleep data, so going by how you feel." Priority uses check-in only |
| Health permission denied | Manual check-in + manual workout logging |
| Calendar permission denied | Ask "How many free minutes today?" and allow manual time blocks |
| Location denied | Typed area, campus or saved place |
| Nearby search fails / offline | Saved dishes + seed library |
| Dish nutrition uncertain | Show a wide range; let the user adjust portion |
| Watch not reachable | Phone works alone; logs queue and sync later |
| App expired (7-day limit) | User reinstalls from Xcode; data persists |
| User keeps rejecting suggestions | Reduce prompting; ask in the weekly review whether the goal or options should change |

---

## 20. Later (not in v1): an optional AI advisor

The template system (§5) is the product. An AI layer is optional and may only **reword, explain or re-rank options that already passed the rules**. It never makes safety, allergy or calendar decisions.

| Option | Cost | Notes |
|---|---|---|
| A. **Copy coach summary** into any chat app (M9) | Free | Already planned. No code needed beyond the export |
| B. **Apple Foundation Models** (on-device) | Free | iOS 26+ on an Apple Intelligence–capable iPhone, with Apple Intelligence turned on. Small context (~4K tokens). Check `SystemLanguageModel.default.availability`; fall back to templates. Wrap in `if #available(iOS 26, *)` |
| C. Cloud API (OpenAI, Anthropic, Google Places) | Paid, needs a key | **Not planned.** Costs money and puts a key in the app |

---

## 21. Singapore reference (checked October 2026; prices change, so the app stores what you actually pay)

- **Hawker averages (SingStat, Aug 2026):** chicken rice $4.23 · economical rice 1 meat 2 veg $3.80 · fishball noodles $4.43 · chicken chop $7.93 · kopi/teh $1.44.
- **FairPrice price hold to 31 Dec 2026:** 30 Dasoon eggs $4.95 · 1 kg Seara frozen whole chicken $2.50. FairPrice *supermarkets* only (not Finest, Xtra or Online); max 2 of each per customer.
- **Supermarkets:** Sheng Siong is usually cheapest for staples. FairPrice house brands are good value. Cold Storage is typically 25–35% more for staples; only worth it for specific deals.
- **ActiveSG:** $2.50/entry adult; peak pass $30/month, off-peak $15. Credits valid to 31 Dec 2026; make one booking in 2026 to roll the balance into 2027.
- **Healthy 365 / National Steps Challenge:** pair Apple Health and earn Healthpoints for steps and active minutes.

**Sources**
- SingStat hawker averages: https://themoneybees.co/calculators/eating-out-vs-cooking
- FairPrice price hold: https://mustsharenews.com/fairprice-lower-dec/amp/ · https://www.misslobang.com/article/fairprice-chicken-eggs-price-cut-until-dec-2026
- Supermarket comparison: https://sgfinancecalculators.com/lifestyle/grocery-price-comparison-tool/
- ActiveSG rates and credits: https://themoneybees.co/blog/best-gym-membership-singapore · https://themoneybees.co/blog/activesg-credits-workout-plans-hacks
- National Steps Challenge: https://healthhub.sg/programmes/NSC
- HPB food database (for better dish estimates): https://www.hpb.gov.sg/healthy-living/food-and-beverage/sgfoodid/
- UV index (NEA): https://www.nea.gov.sg/corporate-functions/weather/ultraviolet-index
- WHO physical activity guidelines: https://www.who.int/publications-detail-redirect/9789240015128
- Apple free-account capabilities: https://developer.apple.com/help/account/reference/supported-capabilities-ios/
- Apple free-account limits (7-day profiles): https://developer.apple.com/support/compare-memberships/
- HealthKit setup: https://developer.apple.com/documentation/healthkit/setting-up-healthkit
- EventKit: https://developer.apple.com/documentation/eventkit/accessing-the-event-store
- Watch Connectivity: https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity
