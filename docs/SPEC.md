# Steady release 1 product specification

Version: 1.7
Date: 2026-10-18
Status: Approved scope; Phase 7 source prepared and static/syntax checks passed (D48); Phase 1/2/3/4/5/6/7 Mac verification pending

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
- Phase 4 adds optional Apple Foundation Models ranking on supported iOS 26+ devices. It may only reorder allowlisted alternative IDs; canonical wording and outcome facts remain unchanged (D38).
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

Ignore cancelled events, all-day events, and events in the Steady-owned calendar when calculating availability. Recheck uncancelled timed conflicts immediately before a confirmed write; ignore only the tracked event being rescheduled, not unrelated events in Steady's calendar.

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

Phase 2's typed production catalog is `plan-alternatives.json`, mirrored in app resources and core test fixtures. The original `alternatives.json` remains a legacy fixture for history; its old price and outcome claims are not promoted into production choices. If the typed catalog is missing or fails validation, use the deterministic built-in fallback. Food evidence and a claim of nourishment belong to Phase 5; a preparation, pause, or movement option must state that it does not preserve nourishment.

The two-to-three invariant applies to a successful option set. If current safety rules block recommendations, or fewer than two suitable choices fit the user's explicit time/movement restrictions, return a typed blocked/unavailable result rather than adding unsuitable filler. Later and Rest remain separate actions; time below two minutes is an unavailable option set, not an invented pair of useful actions.

Choose, Later, and Rest on purpose are separate user actions. They are not padded into the primary option count. Deferring creates an inert calendar proposal and opens the confirmation flow in section 10.

### Phase 2 action and persistence rules

- The barrier is an explicit user selection, not an inferred emotion, injury, or diagnosis.
- **Choose** replaces the active app-owned plan. It does not imply that the action was completed and does not write to Calendar.
- **Rest on purpose** records an intentional-rest choice separately from a completed workout. It does not create a calendar event.
- **Later** prepares a proposed time. Cancelling or dismissing its confirmation writes nothing and preserves the prior plan.
- Calendar denial must not block choosing an alternative or resting. A denied write leaves the plan usable in the app and never claims it was scheduled.
- An accepted choice, intentional-rest state, or confirmed deferred plan survives a relaunch for its local day. Transient sheets and unconfirmed proposals do not silently resume as writes.
- An action from an open sheet must still belong to the current profile, active plan, and local day. Reject or refresh a captured source after a day rollover, profile change, or priority replacement rather than mutating the newly active plan.
- A confirmed tomorrow plan may carry into its scheduled local day when no separate plan exists for that day. Preserve its scheduled-day association after Start, completion, or another status change so a relaunch still finds the same chosen plan. If carryover creates a current-day row, atomically supersede the prior active row and transfer event/retry ownership rather than leaving two active owners. A future deferred plan cannot be started or completed before its saved time; when due, Start makes it active and completion remains a separate explicit action.
- A stored calendar event identifier tracks only a Steady-owned event. If the event is missing after an external deletion, mark the plan unscheduled and do not offer to recreate that deleted event in the current plan's Later flow. A separate new-plan scheduling action may be added in a later phase.
- SafetyGate is evaluated again before accepting an alternative or confirming a deferral. A newly reported symptom invalidates a performance proposal; restarting the app must not restore it over an active safety state.
- The Alternatives sheet has an explicit standing/seated/wheelchair mode selector and typed avoided-movement choices. These are request-local in Phase 2, not new persisted profile fields. A saved free-text movement note is shown to the user for explicit selection rather than interpreted as an injury. Phase 2 does not add advanced training progression.

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

### Phase 3 state, timing, and notification boundaries

- Six deterministic local families are available without Health, Calendar, or notification permission. Done, replacement, and snooze are local-day states; disabled kinds and explicit standing/seated/wheelchair/avoided-movement preferences persist across days. Foundation preferences are separate from the request-local Phase 2 Alternatives controls (D30).
- A replacement is not completion. Actions have stable IDs and a captured local day; duplicate delivery applies once. A new Singapore day resets daily progress and expired snoozes without re-enabling disabled kinds. Snoozes must be finite, future, within the same local day, and no more than twelve hours away. Safety is checked again at action time; a stored choice cannot override it.
- A saved free-text movement note is never interpreted as an injury or automatically converted into typed exclusions. The user explicitly reviews and saves preferences. If no suitable physical option remains, show unavailable rather than filler.
- Hydration is thirst-led, with no fixed intake volume or timer, and respects personal clinician-provided fluid guidance. Daylight options offer accessible shade, normal sun protection, no sun gazing, and an indoor/skip choice when outdoor conditions are unsuitable. No UV, treatment, detox, or dose claim is inferred. The smallest wind-down is a brief optional starting point, not an elaborate checklist.
- Reminders start off. An explanation precedes Apple's permission prompt. Current system authorization is checked at scheduling time; denial leaves the quiet in-app experience intact. Sample mode uses a separate sample provider and never schedules real notifications.
- The pure planner returns a proactive notification, silent Today card, or typed drop reason. Automatic can-wait candidates remain silent. User-requested snoozes may be considered proactively, but still use the same budget and blocking rules. Calendar-unavailable context is silent rather than treated as a known free window; optional workout samples remain uncertain when unavailable.
- Recurring quiet periods use Singapore wall-clock minutes, may cross midnight, and equal start/end means quiet all day. Protect the entire proposed action interval against quiet periods, planned sleep, timed Calendar blocks, and known workouts. Move within the same local day and expiry if possible; otherwise drop. Never invent a future free window.
- Keep a device-wide persistent ceiling of three distinct proactive reservations per Singapore local day, including user-requested snoozes. Refresh, relaunch, profile change, cancellation, and uncertain/failed scheduling cannot refund reservations automatically. This conservative count can exceed actual deliveries but cannot expand the ceiling. Sample reservations do not create real notifications.
- Two dismissals reduce that type to consideration every other Singapore local day (a two-local-day cooldown, not a guarantee of forty-eight elapsed hours). Four dismissals pause it. Explicit **Resume reminders for this Foundation**, or marking that Foundation **Done**, resets its dismissal count. Merely opening a notification, replacing/enabling an option, ordinary refresh, and day rollover do not reset that history.
- Real notifications use ordinary active interruption, no sound, and no time-sensitive/critical level. Open-app updates remain silent. Notification text uses allowlisted neutral wording and never includes raw Health values; low-data wording removes sensitive context.
- The notification delegate writes only a minimal durable response inbox. The main-actor store applies matching-profile responses idempotently on foreground load; stale day/option Done or Snooze cannot complete or defer today's different choice. Opening a reminder routes to Foundations from any selected tab without resetting dismissal history. A scheduling callback does not directly mutate SwiftData or bypass safety.
- Schedule only prospective current-day requests from the latest foreground context. Foreground refresh reconciles access, context, responses, and pending requests. No continuous background context refresh, guaranteed delivery time, APNs/server, or multi-day scheduling is promised in Phase 3.

## 9. Phase 4: Advisory agent

Expose one app-facing protocol:

```swift
protocol AdvisorProviding: Sendable {
    func advise(_ request: AdvisorRequest) async throws -> AdvisorResult
}
```

Providers:

- `TemplateAdvisor`: required, deterministic, offline, and the universal fallback.
- `OnDeviceAdvisor`: optional on supported iOS 26+ Apple Intelligence devices, off until explicit opt-in. It may only return a permutation of the current allowlisted alternative IDs.
- `CloudAdvisor`: not implemented in release 1.

Phase 4 implements ranking of existing Phase 2 alternative sets, not a conversational assistant or autonomous tool runner. One coordinator first obtains the deterministic result and applies SafetyGate, then optionally requests ranking. The model receives a minimal typed packet of opaque choice aliases, approved candidate attributes, a coarse time budget, and optionally the explicit user-selected barrier enum. In normal mode that enum can describe soreness, stress, or low energy; it is a user-stated selection, never an inferred condition. The packet receives no HealthKit-derived measurements, recovery labels, SafetyGate symptom/alert records, full EventKit events, original plan/profile identifiers, precise calendar times, diagnoses, free-text movement notes, or unrestricted persisted models. Low-data mode removes the selected barrier rather than merely hiding it on screen. Unknown data stays unknown. Deterministic cards appear immediately; only an explicit **Try on-device order** action after opt-in invokes inference, never automatic background shuffling.

Model output contains IDs only. After validation, the coordinator reconstructs the result from the original canonical options, preserving title, minutes, effort, steps, benefit, tradeoff, outcome partition, and any approved source facts exactly. Phase 4 produces no new medical or food facts, reworded explanations, citation text, calendar proposals, or tool calls. Food provenance and allergy filtering remain Phase 5 work. ID-only output cannot add an uncited claim, infer an injury/emotion/allergy, or grant action authority.

`ResponseValidator` rejects:

- more than three primary options;
- an option ID not returned by deterministic code;
- an uncited live claim;
- inferred allergy, injury, diagnosis, or emotion;
- a missing benefit or tradeoff;
- an instruction to write calendar, notification, or preference state; or
- anything blocked by SafetyGate or the content rules.

If on-device model availability or validation fails, return the template result. Core functionality must not degrade.

The response must contain each candidate ID exactly once, with no additions, duplicates, omissions, or more than three options. Bind it to the same active plan, candidate set, profile-local-day/sample mode, request, and current safety/context snapshot. A cancelled or stale response cannot reorder a newer set. Recheck safety before display and before a later action; choosing a ranked option still passes the existing action checks and explicit Calendar confirmation boundary. The advisor cannot choose, complete, rest, save a preference, schedule a notification, or write Calendar.

Use `#if canImport(FoundationModels)` to preserve compilation with an older SDK, and runtime availability checks for iOS 26 and model readiness. The deployment target stays iOS 18; the Watch stays on its existing placeholder and Foundation-only shared package. Devices or builds without Foundation Models always use TemplateAdvisor. Availability is checked for each request; Steady does not promise that a device is supported, trigger a model download, or fall back to a cloud service. Sample mode always uses TemplateAdvisor even after opt-in.

An advisor setting may store only the explicit opt-in. Diagnostic history is separate, bounded, in-memory state with coarse source/status entries: no prompts, model output, option content, raw context, or user free text. Clear it independently without changing plans, Foundation responses, reminder preferences, or other wellness records, and invalidate in-flight requests. App termination clears the in-memory history. Each request creates a fresh model session with no retained app transcript. No persisted advisor transcript or prompt/output logging is introduced; clearing Steady's activity does not promise to erase Apple's system-managed model state or diagnostics.

## 10. Calendar confirmation boundary

- Read permitted calendars to calculate availability.
- Ignore all-day events and the calendar named `Steady` when finding commitments.
- A plan change first creates a plain `CalendarChangeProposal`.
- Show title, date, start, end, and reason in a confirmation sheet.
- Create the `Steady` calendar on the first confirmed write only.
- Write or reschedule only after the user taps Confirm.
- Save the returned event identifier.
- If the user deletes the event, mark the plan unscheduled and do not recreate it automatically.
- On rescheduling, update only the event whose stored identifier still resolves to the Steady-owned calendar. Do not modify an unrelated event merely because its title matches.
- Cancellation, dismissal, app refresh, and app relaunch never invoke the confirmed-write handler.
- Recheck proposal validity, current access, and current safety state at the confirmation boundary. Display a failure or denied state honestly rather than persisting an unconfirmed schedule.
- If a confirmed write may have reached Calendar before local persistence failed, retain only the exact minimal retry proposal. Relaunch does not retry automatically: show that same title/time for review and require another Confirm. A definitive access denial must not strand Choose/Rest behind a pending write. Clearing an uncertain retry requires an explicit explanation that an event may already exist and does not delete that event.
- A newly reviewed change receives a new operation identifier, even when revisiting a previously used time. Retrying the exact uncertain change keeps its existing identifier. This permits confirmed A-to-B-to-A rescheduling while making retries idempotent.
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

### Phase 5 implementation boundaries

- Nearby food is explicitly requested from Eat. Opening the tab must not start a search or request location. A typed area remains available without location permission; approximate location is optional, foreground-only, and never requires precise/Always access. Sample mode must not invoke live location or place discovery.
- Treat discovered venues as places to check, not discovered menu items. A MapKit website or Maps link may be shown with that limited label, never as an identity-verified official menu. Without adequate ingredient/dietary evidence there may be fewer than three eligible choices, or none. Do not pad the result with uncertain primary recommendations.
- Keep official evidence venue-bound and fact-specific. A source URL alone does not substantiate a price, complete ingredient list, current hours, or nutrition. A checked timestamp records when the evidence was checked, not a promise that it remains current.
- No reviewed official-menu/ingredient catalog or defensible SG FoodID record/portion dataset is bundled in this source handoff. Current live venues and manual observations therefore stay confirmation-required rather than primary meal recommendations. Keep a typed cited-record matcher for reviewed records, link to HPB's food-search reference, and show `estimate unavailable` when no defensible match exists. The link itself is not a nutrition match. Legacy `foods.json` values stay fixtures, not verified fallback facts.
- Saved prior-visit records remain dated user evidence. Ingredients may still be incomplete and cross-contact uncertain; an explicit confirmation is not an allergy-safety guarantee. Free-text allergies and dietary rules are not guessed from venue/dish names. Unresolved restrictions require confirmation rather than a primary recommendation.
- Bind searches, open correction drafts, and confirmations to current profile, sample mode, local day, request inputs, and saved-record revision. Changing context must invalidate stale results/proposals. Cancelling or dismissing Remember writes nothing; a failed save must not claim success. Sample and real saved records stay separate.
- Persist only confirmed corrections/saved dishes needed for future use. Keep transient searches and approximate location out of personal history. No automatic menu crawler, paid service, cloud advisor, hidden network request, spending total, or meal-completion claim is introduced.
- Low-data mode hides calorie/nutrition detail on introduced food surfaces and does not send food/profile free text to the Phase 4 advisor. Each displayed price, portion, date, or other numeric fact has a tappable one-line explanation.

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

### Phase 6 action and privacy boundaries

- A phone snapshot is cached context, not a guarantee of live Health, Calendar, safety, or delivery state. Show its age and a neutral refresh/unavailable state when stale. The iPhone works without a paired or reachable Watch.
- The Watch glance labels completed, intentionally rested, and deferred plans honestly rather than presenting them as a new action to start. Every action button is bound to the exact displayed snapshot; repeated option IDs cannot retarget it to a newer profile/day/plan.
- A bounded durable Watch outbox retains explicit action IDs until a typed phone receipt confirms acceptance or rejection. Transport submission alone is not completion. Do not silently evict unacknowledged actions to make space; show queue-full/storage/unavailable states honestly.
- The phone validates supported schema, payload bounds, scope, profile, sample mode, Singapore local day, snapshot/action identity, allowlisted content, and current state before any mutation. Recheck current safety for performance actions. A stale/replaced/disabled/completed option cannot mutate its replacement.
- Commit the accepted action's local mutation and apply-once receipt atomically. An uncertain or failed save must remain retryable with the same action ID rather than claiming success. Duplicate delivery returns the existing outcome, never a second mutation. Bound ingress and new-receipt processing rather than silently pruning replay protection: retain the phone's apply-once receipt-ID ledger and consumed handoff records until a later explicit data-deletion flow. No Phase 6 delete/export UI is introduced.
- Choosing a quick alternative changes the app-owned plan only. It is not completion and never calls EventKit. Basic movement logging is explicitly user-reported local information, not a HealthKit workout/sample, automatic strength count, or proof of an unobserved activity.
- Foundation Done uses the same deterministic local-day/option/safety rules as the phone. It cannot enable reminders, reset another kind, or bypass a new safety state.
- Saved-meal handoff refers only to an already confirmed saved record. It opens the phone's evidence-labelled review; it does not save a correction, start a search, record eating, infer current ingredients/allergy safety, or bypass Remember confirmation. Missing/replaced/stale records are unavailable, not reconstructed from a name.
- Transmit the minimum typed values needed for the glance/actions. No raw Health samples, complete Calendar details, advisor transcript, location history, full food search, or unrestricted user notes. Low-data mode removes sensitive fields from the packet, not just the display; changing mode invalidates the prior scope.
- Use `updateApplicationContext` for replaceable latest state and `transferUserInfo` for durable actions. This implementation does not need `sendMessage`, a backend, APNs, a new permission prompt, iCloud entitlement, or background mode. WatchConnectivity scheduling is system-managed; no delivery deadline or continuous background refresh is promised.
- Apply phone actions only when current foreground context is loaded. Watch background connectivity handling may save incoming transport data/receipts locally, not execute phone wellness mutations. Sample wellness packets/actions never cross the live link; entering sample mode may send one empty low-data control snapshot to clear cached real content on the Watch.
- The Watch SwiftUI scene handles `.backgroundTask(.watchConnectivity)` by waiting for pending transport delivery and receiving local data/receipts; task completion/cancellation is system-managed. It schedules no periodic background refresh. Validate durable outbox integrity and revision-watermark consistency before enabling actions; report a corrupt store instead of resetting it.
- The phone issues snapshots with a fifteen-minute lifetime, bounded by Singapore midnight; shared validation also enforces a four-hour absolute maximum. A disconnected Watch cannot immediately learn a phone low-data/sample/profile change. Its prior received cache remains only until expiry or a newer valid frame arrives; no immediate remote erase is promised. Pending actions carry the old scope and the phone rejects them when that scope is no longer current.
- Bound the Watch outbox at fifty pending actions and its displayed receipt history at one hundred. Bound each local raw transport inbox at one hundred combined action/receipt packets, and enforce typed packet byte limits. The phone processes at most 256 new receipts per Singapore day; replay of an already persisted action ID remains available after that cap. A cap/storage error leaves work pending instead of dropping it or claiming a mutation succeeded. Manual movement remains a retained local user record, not an aggregate activity score.
- Common actions target at most two taps from the glance. Verify this and VoiceOver usability on a real paired Watch; a source layout does not satisfy the device gate. Stop before Phase 7 weekly learning.

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

### Phase 7 evidence and action boundaries

- A review covers a named Monday-start Singapore week, not an inferred rolling score. Query permitted sleep context when requested; saved reviews retain the review date and optional user-stated helpfulness, not the runtime Health aggregate. Raw HealthKit samples and full EventKit details remain in Apple's stores. Show tracked-day/night coverage alongside observed values; no observation is not zero activity, missed sleep, or a failed action. Actual sleep and an in-bed sleep-opportunity proxy are separate, uncertain observations.
- Separate plans saved, plans explicitly completed, changed plans, intentional rest, alternatives chosen, Foundation responses, user-reported movement, remembered food records, and helpfulness. A plan's current status cannot prove the historical timing of an unrecorded completion. A saved dish/correction is not evidence that it was eaten, and Watch handoff is not consumption. Do not show food frequency as "commonly eaten" without an explicit meal record.
- Local evaluation begins when the introduced surface records it. Do not invent past suggestion views, accepts, time-to-choose, alternative completion, correction denominators, or helpfulness from unrelated retained rows. Unsupported measures remain unavailable. No hidden background analytics or remote delivery is introduced.
- The initial supported default proposal is Exam mode off to on after evidence of changed plans on three distinct days of the reviewed week; it cannot increase movement. Sample mode cannot propose or apply this shared real-profile default. Approval binds to the displayed profile, sample mode, week, revision, and current preference value, with a thirty-minute same-local-day freshness boundary. Cancel/dismiss/refresh/relaunch cannot apply a change; stale or replaced state requires a fresh review. A weekly pattern or favorable wearable context cannot increase training load or override SafetyGate.
- Starting an experiment is an explicit choice, not an automatic default change. Keep one active time-bounded experiment from small plan, wind-down, or quiet Foundation, with its simple self-report measure and explicit two-to-fourteen-day dates. Completion or ending it must be honest about its status. An experiment is not a prescription, streak, score, or permission to enable reminders.
- Low-data mode applies to the review, approval, experiment, evaluation, and exported JSON. If any saved profile uses low-data mode, the entire multi-profile JSON archive is metadata-only: salted opaque record keys/IDs, profile UUIDs, dates, and sample/real markers, without content, measurements, settings, or opaque payloads. Exports distinguish omission from zero, include a schema version and limitations manifest, and contain app-owned records only. No import/restore workflow is implemented; a redacted archive is not a complete backup.
- Export starts only after the user invokes it, previews its scope, and opens the system share sheet. Do not upload automatically or export raw HealthKit samples, complete Calendar events, advisor prompts/output/transcripts, temporary place searches, or approximate-location history.
- Delete all Steady data requires an explicit destructive confirmation describing what will be removed and what will remain. Cancel/dismiss writes nothing. Stop or invalidate in-flight actions and callbacks so they cannot recreate the old profile's data. Clear app-owned persisted records, app preferences/opt-ins, local reminder reservations/response inboxes, companion receipts/transports/caches, and separately clearable advisor activity. Deletion never calls HealthKit or EventKit to remove Apple's records or revokes system permission.
- Deletion has a recoverable, honest failure state rather than claiming success after a partial clear. Retain only a non-personal deletion journal/generation cutoff, not the deleted wellness history. Keep proactive reminders quiet until the next Singapore day, so resetting/recreating a profile cannot refund the daily ceiling. If cleanup is interrupted, show that condition and finish only the previously confirmed operation; it is not authority to delete newly created data. A disconnected Watch may retain its expiring prior cache until a valid clearing control frame is received. A readable Watch store is cleared selectively through that generation; an unreadable store remains an honest incomplete-privacy-clear failure, never an automatic wipe of unknown newer records. No immediate remote erase is promised, and old actions must not resurrect deleted wellness data or mutate a new profile.
- A readable pending privacy journal permits retrying its confirmed operation. An unreadable journal instead blocks normal data access in a separate unavailable/recheck-only state: do not claim prior confirmation, guess a lower generation, or accept fresh destructive confirmation over an unknown cutoff. App-accessible record deletion is not a forensic secure-erase guarantee for storage, exported copies, system backups, or Apple-owned stores.

Phase 7 source authority (D48) does not establish an accepted release. Run the core tests, both simulator builds, source migration/failure checks, and physical-device procedure before accepting the phase or distributing the app.

## 14. Persistence and privacy

Release 1 stores only records needed for the experience, such as profile, any later consent-notice receipts, plans, choices, foundation settings, nudge response, saved dishes, confirmed corrections, weekly reviews, experiments, and local metrics. Phase 1 keeps system permission state in its service layer rather than duplicating it as a SwiftData consent record.

Do not persist:

- raw HealthKit samples;
- complete calendar events, titles, or notes;
- transient nearby results as personal history;
- system authorization as if it were app-owned consent; or
- hidden network payloads.

Phase 4 advisor diagnostics are separately clearable, bounded in-memory status history, not a persisted transcript. Do not persist prompts, model outputs, context packets, or candidate text. Any context packet is a typed minimal value, never a SwiftData model, HealthKit sample, EventKit event, or unrestricted dictionary.

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
- Apple MapKit `MKLocalSearch`: https://developer.apple.com/documentation/mapkit/mklocalsearch
- Apple reduced location accuracy default: https://developer.apple.com/documentation/bundleresources/information-property-list/nslocationdefaultaccuracyreduced
- Apple WatchConnectivity: https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity
- Apple capability availability: https://developer.apple.com/help/account/reference/supported-capabilities-ios
- Singapore HPB SG FoodID: https://www.hpb.gov.sg/healthy-living/food-and-beverage/sgfoodid/
- Singapore HPB SG FoodID food search: https://pphtpc.hpb.gov.sg/web/sgfoodid/tools/food-search
