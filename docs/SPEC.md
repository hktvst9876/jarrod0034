# Steady release 1 product specification

Version: 1.1
Date: 2026-10-16
Status: Approved scope; Phase 1 implementation in progress

This specification supersedes conflicting scope in the original starter. `docs/MILESTONES.md` controls delivery order, and `docs/DECISIONS.md` records replacements without erasing history.

## 1. Product promise

Steady is a private wellness planner for one college student in Singapore who uses an iPhone and Apple Watch. It helps answer four questions:

1. What matters most today?
2. What is the best realistic plan?
3. What alternatives keep the important part when that plan no longer fits?
4. Why does each suggestion fit the available context?

The app is wellness support, not medical care. It must remain useful without Health, Calendar, Location, Notifications, Apple Intelligence, a network connection, or an account.

### Principles

1. Show one priority, not a wall of scores.
2. Plan A always has realistic alternatives.
3. Health and calendar data are optional context, never authority.
4. The user may correct, replace, defer, rest, or do nothing.
5. Use neutral language: no streaks, failure states, shame, or loss warnings.
6. Prefer quiet in-app updates; at most three proactive notifications a day.
7. Keep personal records on device and minimise what is persisted.
8. Safety, allergy handling, factual provenance, and confirmations are deterministic code.
9. Every displayed number has a short, accessible explanation.

## 2. Approved release-1 defaults

These are fixed unless a later dated decision explicitly changes them:

- The daily planner and alternative templates are local and deterministic.
- Phase 4 may add optional Apple Foundation Models on supported iOS 26+ devices. It may rank allowlisted choices or reword approved explanations only.
- There is no cloud advisor, backend, provider API key, paid API, or automatic web crawler in release 1.
- Live food support uses user-triggered MapKit discovery, official-source links, cited SG FoodID data when a match is defensible, and remembered user corrections.
- Menus, opening hours, prices, ingredients, and nutrition are never invented. Unknown stays unknown.
- `maxPricePerMealSGD` is optional. There is no weekly spend ledger and no estimated money-saved feature.
- Cravings and phone-use friction are ordinary user-selected barriers. There is no dedicated Urge screen, planned-treat quota, or treat score in release 1.

## 3. Release phases and navigation

The release is built in this order:

1. Foundation
2. Alternatives
3. Daily Foundations
4. Advisory agent
5. Live food
6. Apple Watch
7. Weekly learning

The iPhone has five tabs:

- Today
- Move
- Sleep
- Eat
- Week

Settings opens from Today. Alternatives opens from an active plan. Foundations opens from Today and Settings. A feature can have a placeholder before its owning phase, but the placeholder must not claim the feature works.

### Daily loop

| Time | Behavior |
|---|---|
| First open after waking | Refresh permitted context, accept an optional one-tap check-in, apply `SafetyGate`, and show one priority with a reason and Plan A. |
| During the day | Update Today quietly. The user may open alternatives or food help. Notifications follow the Phase 3 budget. |
| Evening | Show a neutral bedtime opportunity and smallest useful wind-down. The user may rest, adjust tomorrow, or do nothing. |
| Weekly | Summarise patterns, propose changes, and offer one experiment. Apply no default change without approval. |

## 4. Profile and permissions

Onboarding is short, skippable, and editable later.

```yaml
primary_focus: general
other_focuses: []
sleep_need_hours: 8.0
wake_time_weekday: "07:30"
wake_time_weekend: "08:30"
morning_routine_minutes: 45
default_travel_minutes: 30
liked_activities: []
gym_access: campus
movement_mode: standing
movements_to_avoid: []
strength_sessions_per_week: 3
preferred_workout_time: afternoon
dietary_rules: []
allergies: []
other_allergies: []
disliked_foods: []
usual_areas: []
kitchen_access: microwave_kettle
max_price_per_meal_sgd: null
quiet_periods: []
low_data_mode: false
exam_mode: false
use_sample_data: false
```

`max_price_per_meal_sgd` is optional. It filters or labels individual choices only. It never creates a spending total.

### Permission behavior

- Explain a permission immediately before displaying the system prompt.
- A saved consent/preference record is not proof of current system authorization.
- Request only data needed by an enabled feature.
- If access is denied or data is missing, record a typed data gap and use sample data or manual available minutes.
- Phase 1 Calendar access is read-only. Later calendar writes follow section 10.
- Location is not requested until the user invokes nearby food in Phase 5.
- Notification permission is not requested until Phase 3 explains its use.

## 5. Architecture and trust boundaries

```text
HealthKit / EventKit / location / user input
                    |
                    v
          protocol-backed app services
                    |
                    v
          plain SteadyCore models
                    |
          +---------+----------+
          |                    |
      SafetyGate      deterministic rules
          |                    |
          +---------+----------+
                    |
                    v
       verified candidate IDs and reasons
                    |
          optional Phase 4 advisor
                    |
                    v
             ResponseValidator
                    |
                    v
              view model and UI
                    |
          explicit user confirmation
                    |
                    v
        calendar write / remembered change
```

### Layer rules

- `SteadyCore` imports Foundation only. It contains domain value types and pure decision logic.
- Apple frameworks and SwiftData stay in app targets behind protocols.
- Time-dependent core functions receive a `Clock` and a configured Calendar. They do not call `Date()` internally.
- Default time zone is `Asia/Singapore`; a week is Monday through Sunday.
- Views are thin and UI state is main-actor isolated.
- Every Apple service has real and sample/manual implementations.
- No third-party package is permitted in release 1.
- Never edit `Steady.xcodeproj/project.pbxproj` by hand.

## 6. Phase 1: Foundation behavior

### 6.1 Context model

`DailyContext` contains only the plain values needed to choose a priority:

- local day and current time;
- last-night sleep, seven-day shortfall coverage, and wake consistency when known;
- steps, exercise minutes, days since exercise, and last workout when known;
- free slots, free minutes today, and first commitment tomorrow when known;
- optional one-tap check-in;
- user-entered safety flags or relevant device alerts;
- an existing plan if one exists; and
- typed data gaps.

Missing data is never converted into a negative score.

### 6.2 SafetyGate

SafetyGate runs before priority selection and before any future advisor.

Relevant user-reported or device context includes pain, fainting, chest symptoms, unusual breathlessness, feeling unwell, or a heart alert. When present:

- suppress training and performance suggestions;
- show a neutral stop/rest message;
- suggest an appropriate clinician or campus health service;
- use emergency language only for an emergency symptom; and
- never diagnose the cause.

SafetyGate output is deterministic and unit-tested.

### 6.3 Sleep attribution

A night belongs to the local date on which the user woke.

- Include asleep samples whose end falls in `(D-1 18:00, D 18:00]`.
- Recognise asleep core, deep, REM, and unspecified values.
- Merge overlaps across sources so time is counted once.
- Treat a sample that both starts and ends between 12:00 and 18:00 as a nap.
- Skip missing nights rather than treating them as zero sleep.

Derived context:

```text
sleep shortfall for a tracked night = max(0, sleep need - actual sleep)
seven-day shortfall = sum of tracked-night shortfalls
coverage = tracked nights out of seven
wake consistency = mean absolute deviation of wake time for tracked nights
```

Labels:

- 30 minutes or less: steady
- 31 to 60 minutes: a bit irregular
- more than 60 minutes: irregular

Low-data mode may use sleep context internally but hides sensitive numeric detail and score-like labels in the UI.

### 6.4 Calendar availability

Ignore all-day events and events in the Steady-owned calendar when calculating availability.

```text
day window = max(wake + 60 minutes, 07:00) through bedtime - 150 minutes
busy = timed events padded by the configured travel allowance
free gaps = day window minus merged busy intervals
candidate slot = a free gap long enough for the action
ranking = preferred time of day first, then earliest
free minutes today = sum of remaining free gaps of at least 15 minutes
```

Handle back-to-back events, overlaps, empty days, and events crossing midnight. When Calendar access is denied, accept manual available minutes in Phase 1. Manual busy blocks may be added later. A free-slot result records its source and confidence.

### 6.5 Daily priority rules

Rules are evaluated in order; first match wins. The output contains `kind`, `ruleID`, `title`, `reason`, and `planA`.

| Rule | Condition | Priority | Plan A |
|---|---|---|---|
| P0 | SafetyGate is active | Look after yourself | Stop the performance plan and show neutral safety guidance. |
| P1 | Known sleep is more than 90 minutes below need, or tracked seven-day shortfall is at least 5 hours | Protect bedtime | Protect tonight's sleep opportunity; movement may be an easy walk. |
| P2 | Check-in is sore or the user says they need an easier day | Recover | Easy movement or mobility, with intentional rest available. |
| P3 | Check-in is short on time or known free time is under 45 minutes | Keep it small | A short useful action and protected bedtime. |
| P4 | A strength session remains due, yesterday was not strength, and a suitable slot exists | Strength | The next basic strength session in the best slot. |
| P5 | Known days since exercise is at least 2 | Get moving | A 20-30 minute walk or easy cardio option. |
| P6 | Check-in is stressed | Lighter day | A short outdoor walk or quiet reset plus planned downtime. |
| P7 | A user-approved item is already planned today | Follow the plan | The planned item, with a shorter version offered when requested. |
| P8 | Otherwise | Steady day | Normal movement, practical meals, and a reasonable sleep opportunity. |

Rules only use known values. For example, missing sleep cannot trigger P1 and unknown free time cannot trigger P3. The user can always choose another priority.

The core implements and tests P4, but the Phase 1 app does not automatically trigger it. HealthKit cannot distinguish a denied workout read from no completed workouts, and Phase 1 has no app-owned strength completion log. Treating an unknown count as zero would create false catch-up pressure. The user may still choose Strength manually; automatic P4 waits for a trustworthy completion source in a later phase.

### 6.6 Bedtime opportunity

When enough inputs exist:

```text
first = earliest timed event tomorrow, excluding all-day and Steady events
wake = usual wake time for tomorrow
if first exists:
    wake = min(wake, first - travel - morning routine)
if wake would be earlier than 05:30:
    show an early-start heads-up instead of silently forcing an earlier target
bedtime = wake - sleep need - 15 minutes to fall asleep
window = bedtime plus or minus 30 minutes
wind-down = bedtime - 45 minutes
```

If inputs are missing, show a neutral manual option. Bedtime UI offers rest, adjust tomorrow, or do nothing; it does not present a missed bedtime as failure.

### 6.7 Phase 1 screens

Onboarding:

- explains value and privacy;
- captures a minimal editable profile;
- explains Health and Calendar before requesting them;
- allows skip at every step; and
- offers sample data when system data is unavailable.

Today:

- shows one priority, a short reason, Plan A, and known data gaps;
- exposes a one-line why for each number;
- links to Settings; and
- contains honest placeholders for later-phase actions.

Sleep:

- shows last-night context, available coverage, consistency, and bedtime opportunity;
- distinguishes denied, missing, learning, sample, and real-data states; and
- avoids score-authority language.

Settings:

- edits the Phase 1 profile;
- toggles sample data and low-data mode;
- shows permission status; and
- does not imply that an in-app preference grants system permission.

Move, Eat, and Week:

- appear as tabs with clear later-phase placeholders;
- do not use fake data as if a feature were complete.

Watch:

- launches a Steady placeholder or simple glance in Phase 1;
- does not claim full synchronization before Phase 6.

## 7. Phase 2: Alternatives

Every plan has an intended `Outcome` made of explicit parts. The user may select a barrier or ask for another option.

Barrier examples:

- low energy;
- sore;
- stressed;
- no time;
- bad weather;
- home late;
- no kitchen;
- social plans;
- low budget;
- late hunger;
- delivery preference;
- sweet drink preference; and
- phone use in bed.

Craving-related barriers use the same flow as every other barrier. There is no Urge button or treat allowance.

Return two or three primary options. Each option contains:

- title;
- minutes;
- effort level;
- benefit kept;
- honest tradeoff;
- preserved outcome parts;
- not-preserved outcome parts;
- steps; and
- price only when known and relevant.

Required invariants:

```text
2 <= option count <= 3
preserved union not-preserved = all outcome parts
preserved intersection not-preserved = empty
effort levels are meaningfully distinct when multiple options are shown
```

Choose, Later, and Rest on purpose are separate user actions. They are not padded into the primary option count. Deferring creates an inert calendar proposal and opens the confirmation flow in section 10.

## 8. Phase 3: Daily Foundations and notifications

Supported foundation families:

| Moment | Suggestion | Boundary |
|---|---|---|
| After waking | 2-5 minutes of comfortable mobility | Standing, seated, wheelchair-friendly, or skip; no detox claims. |
| Morning | Outdoor daylight or a shaded walk | Never tell the user to look at the sun; mention shade at high-UV times. |
| With a meal | Water, guided by thirst | No fixed daily volume target. |
| Long study block | Brief movement break | Can be disabled; seated variants available. |
| Before demanding work | Slow breathing, a short walk, or quiet preparation | Stress support, not treatment. |
| Before bed | Smallest useful wind-down | Timing matters more than an elaborate routine. |

Every foundation can be done, replaced, snoozed, or disabled.

The nudge planner is pure and returns a notification, a silent Today card, or a typed drop reason.

1. Build candidates from enabled foundations and the current plan.
2. Remove candidates inside quiet periods, calendar blocks, workouts, or the planned sleep window.
3. Remove past candidates and already-completed actions.
4. Keep at most three proactive notifications in a local day.
5. Use ordinary interruption levels, not time-sensitive delivery by default.
6. After repeated dismissal, move a type from normal to reduced frequency and then paused.
7. Prefer a silent Today update when an action can wait.

## 9. Phase 4: Advisory agent

Expose one app-facing protocol:

```swift
protocol AdvisorProviding: Sendable {
    func advise(_ request: AdvisorRequest) async throws -> AdvisorResult
}
```

Providers:

- `TemplateAdvisor`: required, deterministic, offline, and the universal fallback.
- `OnDeviceAdvisor`: optional on supported iOS 26+ Apple Intelligence devices. It may rank candidate IDs and reword explanations.
- `CloudAdvisor`: not implemented in release 1.

Narrow tool contracts may expose coarse wellness context, free windows without event details, deterministic alternatives, relevant saved preferences, sourced food evidence, and inert calendar proposals.

`ResponseValidator` rejects:

- more than three primary options;
- an option ID not returned by deterministic code;
- an uncited live claim;
- inferred allergy, injury, diagnosis, or emotion;
- a missing benefit or tradeoff;
- an instruction to write calendar, notification, or preference state; or
- anything blocked by SafetyGate or the content rules.

If on-device model availability or validation fails, return the template result. Core functionality must not degrade.

## 10. Calendar confirmation boundary

- Read permitted calendars to calculate availability.
- Ignore all-day events and the calendar named `Steady` when finding commitments.
- A plan change first creates a plain `CalendarChangeProposal`.
- Show title, date, start, end, and reason in a confirmation sheet.
- Create the `Steady` calendar on the first confirmed write only.
- Write or reschedule only after the user taps Confirm.
- Save the returned event identifier.
- If the user deletes the event, mark the plan unscheduled and do not recreate it automatically.
- Advisor/model output can never trigger the write handler.

## 11. Phase 5: Live food

Food help is user-triggered and returns up to three distinct results. It accepts meal type, typed area or approximate location, dietary rules, allergies, dislikes, kitchen access, optional per-meal price, and user-stated context.

### Evidence pipeline

1. Find places with MapKit or use a typed/saved area.
2. Apply deterministic dietary and allergen handling.
3. Attach a place-owned official menu link only when identity can be matched.
4. Match nutrition to a cited SG FoodID record only when the serving/dish match is defensible.
5. Apply a confirmed user correction when present.
6. Label each fact with source, check time, confidence, and uncertainty.

MapKit place discovery is not evidence of a menu, current price, opening status, ingredient list, or nutrition value.

### Allergen states

- `eligible`: evidence is sufficiently complete and no selected allergen conflicts.
- `requiresConfirmation`: ingredients are incomplete or uncertain. Never call the dish safe and never rank it as the primary recommendation.
- `excluded`: a known ingredient conflicts with a selected allergen.

Unknown is not safe. Other free-text allergies receive the same conservative treatment.

### Price and nutrition

- Official sourced value: show the value, source, and check time.
- Defensible SG FoodID match: show a range and portion assumptions.
- User-saved correction: show `saved from prior visit` and the date.
- No evidence: show `price not known` or `estimate unavailable`.
- Legacy seed prices and nutrition are reference estimates only and may not receive a verified label.
- Price preference is optional and per meal. Do not aggregate spending or estimate money saved.

A correction affects future ranking only after the user selects Remember this and confirms.

## 12. Phase 6: Apple Watch

Watch surfaces:

- glance with today's priority and next action;
- quick alternatives;
- basic movement logging;
- one foundation action; and
- saved-meal handoff.

No dedicated Urge surface ships in release 1.

Synchronization:

- phone to Watch latest snapshot: `updateApplicationContext`;
- durable Watch actions: `transferUserInfo`;
- optional reachable interaction: `sendMessage`;
- each Watch action has an ID and is applied once on the phone.

The Watch remains useful when disconnected and queues actions safely. Low-data mode applies to every Watch surface.

## 13. Phase 7: Weekly learning

The weekly review should take five to ten minutes and may show:

- sleep opportunity and tracked coverage;
- movement and plan completion context;
- which plans were often changed;
- which alternatives were helpful;
- foundation completion/dismissal patterns;
- commonly chosen foods and remembered corrections; and
- user-reported helpfulness.

It does not show weekly spend, estimated savings, treat quotas, or a moralised craving score.

The app may propose a default change with evidence, but applies it only after approval. The user may choose one time-bounded experiment. Local evaluation may record suggestion shown/accepted, alternative completion, time to choose, correction rate, and helpfulness. There is no remote analytics pipeline.

Export and deletion:

- Export local records as JSON through a share sheet.
- Delete all Steady data only after confirmation.
- Clear advisor history independently from wellness records.

## 14. Persistence and privacy

Release 1 stores only records needed for the experience, such as profile, any later consent-notice receipts, plans, choices, foundation settings, nudge response, saved dishes, confirmed corrections, weekly reviews, experiments, and local metrics. Phase 1 keeps system permission state in its service layer rather than duplicating it as a SwiftData consent record.

Do not persist:

- raw HealthKit samples;
- complete calendar events, titles, or notes;
- transient nearby results as personal history;
- system authorization as if it were app-owned consent; or
- hidden network payloads.

If advisor history is introduced, keep it separately clearable from wellness records. Any context packet is a typed minimal value, never a SwiftData model, HealthKit sample, EventKit event, or unrestricted dictionary.

## 15. HealthKit scope

Request read access only when needed for an active feature:

| Type | Purpose |
|---|---|
| `sleepAnalysis` | Last-night sleep and sleep coverage. |
| `stepCount`, `appleExerciseTime` | Activity context. |
| `HKWorkoutType` | Days since exercise and later movement matching. |
| `restingHeartRate`, `heartRateVariabilitySDNN` | Optional coarse context, never diagnosis or authority. |
| `respiratoryRate`, `appleSleepingWristTemperature` | Optional safety context with careful wording. |
| `timeInDaylight` | Later foundation context. |
| `bodyMass` | Only if a later user-enabled feature needs it. |

Phase 1 does not need HealthKit write access to produce a priority. If a later feature writes a user-entered sample, explain it and request only that type then.

## 16. Safety and trust rules

1. Steady does not diagnose or treat.
2. Known allergies are hard exclusions. Unknown ingredients are never assumed safe.
3. Do not recommend supplements, fasting protocols, cold exposure, extreme heat, or high-risk biohacks.
4. Relevant pain, fainting, chest symptoms, unusual breathlessness, or a heart alert suppress performance advice.
5. Never intensify exercise because a wearable value looks good.
6. Do not prescribe a fixed hydration volume.
7. Daylight suggestions never instruct the user to look at the sun.
8. If fuel calculations are restored later, a calorie target may not fall below BMR and weight-loss guards require separate review.
9. Low-data mode applies to phone, Watch, notifications, advisor packets, exports, and any future widgets.
10. No guilt, streak, failure, or loss-warning language.
11. No menu, price, opening-hours, ingredient, nutrition, or medical claim without the required evidence.
12. A model never owns a safety filter or consequential action.

## 17. Failures and fallbacks

| Condition | Required fallback |
|---|---|
| No sleep data | Say that sleep data is unavailable and use check-in/manual context. |
| Health access denied | Manual check-in and sample/manual activity context. |
| Calendar access denied | Ask for manual available minutes. |
| Location denied | Typed area, campus, or saved place. |
| Nearby search fails or device is offline | Saved dishes and evidence-labelled local references. |
| Food evidence is incomplete | Show unknown/unavailable; require ingredient confirmation where relevant. |
| On-device model unavailable or rejected | Deterministic template response. |
| Watch unreachable | Phone works alone; Watch action queues for later delivery. |
| User repeatedly dismisses a nudge | Reduce, then pause that nudge type. |
| Calendar event removed by the user | Mark the plan unscheduled; do not recreate it. |

## 18. Test invariants

At minimum, automated tests cover:

- P0-P8 selection, priority order, missing inputs, and SafetyGate override;
- sleep crossing midnight, overlapping sources, naps, and partial coverage;
- busy-interval merge, empty calendar, travel padding, midnight crossing, denied access, and manual fallback;
- alternative count, distinct effort, outcome partition, template fallback, and separate defer/rest actions;
- known-allergen exclusion and incomplete-ingredient confirmation state;
- nudge daily cap, blocking windows, repeated dismissal, and silent updates;
- low-data mode on every introduced surface;
- advisor candidate allowlisting, citation validation, no-inference, and no action authority;
- idempotent Watch actions; and
- confirmation before every calendar write, default change, and remembered correction.

Every phase also requires:

- `swift test --package-path Packages/SteadyCore` on a Mac;
- successful iOS and watchOS simulator builds with no new warnings;
- sample/manual behavior with permissions denied or data missing; and
- the real-device checks in `docs/MILESTONES.md`.

## 19. Explicitly later or out of scope

- Cloud advisor or proxy infrastructure.
- Paid places, nutrition, or model APIs.
- Automatic menu crawling or delivery-site scraping.
- Accounts, social features, remote analytics, or remote push.
- Dedicated Urge flow, treat quota, savings score, or weekly spend ledger.
- Advanced strength progression, adaptive TDEE, and weight-loss planning unless restored by a later decision and safety review.
- Publication or App Store distribution as part of Phase 1.

## 20. Reference sources

- Apple Foundation Models: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- Apple HealthKit setup: https://developer.apple.com/documentation/healthkit/setting-up-healthkit
- Apple EventKit access: https://developer.apple.com/documentation/eventkit/accessing-the-event-store
- Apple MapKit `MKMapItem`: https://developer.apple.com/documentation/mapkit/mkmapitem
- Apple WatchConnectivity: https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity
- Apple capability availability: https://developer.apple.com/help/account/reference/supported-capabilities-ios
- Singapore HPB SG FoodID: https://www.hpb.gov.sg/healthy-living/food-and-beverage/sgfoodid/
