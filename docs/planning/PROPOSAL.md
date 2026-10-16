# Steady release 1 — pre-implementation proposal

Status: **approved for Phase 1 implementation; retained as architecture rationale**  
Date: 16 October 2026

## 1. Recommendation

Build Steady as a native Swift 6 application with an iOS 18 baseline and watchOS 11 companion. Keep the deterministic planner, safety rules, Apple-framework adapters, and personal records on device. Treat an advisor as a constrained presentation/ranking layer, never as the authority for allergies, health safety, permissions, scheduling, or persistence.

The newer seven-phase product brief should control scope and order. The earlier starter remains valuable for its formulas, deterministic rules, sample data strategy, and testable `SteadyCore` design, but its milestones and several decisions need revision before implementation.

The first release should work fully through deterministic templates. Apple's Foundation Models may improve wording or selection on eligible iOS 26+ devices, but the app must not depend on them. A cloud advisor and automatic web research are separate, approval-gated additions because they conflict with the starter's no-backend/no-key promise and introduce cost, privacy, and operational work.

## 2. Product boundaries

Release 1 will:

- present one daily priority, its reason, Plan A, and realistic alternatives;
- derive context from HealthKit and EventKit when permitted, with manual fallbacks;
- support sleep, movement, food decisions, low-risk daily foundations, Watch actions, and weekly learning;
- use neutral language with no streak pressure or failure messaging;
- keep raw health samples, event details, logs, preferences, and metrics on device;
- require confirmation before every calendar write or remembered correction;
- enforce allergy and medical-safety rules in deterministic code; and
- remain useful with health, calendar, location, notifications, or advisor features disabled.

Release 1 will not:

- diagnose, treat, or infer medical or emotional conditions;
- use an opaque readiness score as an authority;
- intensify exercise because a wearable value looks good;
- ship API keys in the app;
- claim unverified opening hours, menus, prices, ingredients, or nutrition;
- automatically scrape third-party delivery sites;
- make calendar or notification changes through model output; or
- require a cloud service to complete the core daily loop.

Fuel/TDEE calculations, weight trends, advanced strength progression, and broader polish can follow the seven-phase release unless explicitly restored to scope.

## 3. Architecture

### 3.1 Layers and trust boundaries

```text
HealthKit / EventKit / location / user input
                     │
                     ▼
          Protocol-backed app services
                     │
                     ▼
        Plain SteadyCore context models
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
     SafetyGate          Deterministic planner
          │                     │
          └──────────┬──────────┘
                     ▼
       verified candidate set (IDs only)
                     │
          optional AdvisorCoordinator
       template / on-device / approved cloud
                     │
                     ▼
             ResponseValidator
                     │
                     ▼
              View model and UI
                     │
             explicit user confirm
                     │
                     ▼
 calendar write / notification / remembered preference
```

The advisor receives already-filtered candidates and may rank or explain them. It cannot create a new unsafe candidate, edit the profile, schedule an event, create a notification, or persist a preference.

### 3.2 Proposed project layout

```text
Steady/
├── AGENTS.md
├── README.md
├── docs/
│   ├── SPEC.md
│   ├── MILESTONES.md
│   ├── DECISIONS.md
│   └── seed/
├── Packages/SteadyCore/
│   ├── Package.swift
│   ├── Sources/SteadyCore/
│   │   ├── Models/
│   │   ├── Priority/
│   │   ├── Alternatives/
│   │   ├── Sleep/
│   │   ├── Calendar/
│   │   ├── Foundations/
│   │   ├── Nudges/
│   │   ├── Food/
│   │   ├── Advisor/
│   │   ├── Safety/
│   │   ├── Privacy/
│   │   ├── Metrics/
│   │   ├── Weekly/
│   │   └── Support/
│   └── Tests/SteadyCoreTests/
├── Steady/
│   ├── App/
│   ├── Features/
│   │   ├── Onboarding/
│   │   ├── Today/
│   │   ├── Alternatives/
│   │   ├── Move/
│   │   ├── Sleep/
│   │   ├── Eat/
│   │   ├── Foundations/
│   │   ├── Week/
│   │   └── Settings/
│   ├── Services/
│   │   ├── Health/
│   │   ├── Calendar/
│   │   ├── Notifications/
│   │   ├── Places/
│   │   ├── Advisor/
│   │   ├── Conditions/
│   │   └── WatchSync/
│   ├── Persistence/
│   │   ├── WellnessStore/
│   │   ├── AdvisorStore/
│   │   └── Mappers/
│   └── Resources/
└── SteadyWatch Watch App/
    ├── App/
    ├── Views/
    └── Services/
```

`SteadyCore` imports Foundation only. Apple frameworks and SwiftData remain in the app layer. Every Apple service has a protocol plus real and sample implementations. UI state is `@MainActor`; service calls use structured concurrency.

### 3.3 Navigation

Use five top-level iPhone tabs: **Today, Move, Sleep, Eat, Week**. The eight required screens still exist:

- Alternatives opens from any active plan.
- Foundations opens from Today and Settings.
- Settings opens from Today.

This keeps the tab bar usable while preserving every screen named in the brief.

## 4. Persistence and privacy

Use two SwiftData containers:

1. `WellnessStore` for profile, plans, choices, saved dishes, foundation preferences, weekly reviews, and local metrics.
2. `AdvisorStore` for advisor sessions, tool-call summaries, egress records, and expiring live-source cache entries.

“Clear advisor history” deletes only `AdvisorStore`. “Delete all Steady data” clears both after confirmation. Raw HealthKit samples and full calendar events are not copied into either store; the app saves only the minimum derived context needed for its own history.

Network clients accept only explicit `OutboundPayload` value types. They cannot accept a SwiftData model, HealthKit sample, EventKit event, or an unrestricted dictionary. Every network request records its scope and destination locally and is preceded by feature-specific consent.

For the simplest privacy posture, a future cloud food request should contain only local time, approximate typed area, meal type, dietary filters, and the user's stated goal. HealthKit-derived labels should remain off the cloud path unless a later legal/product review explicitly approves them.

## 5. Advisor design

Expose one app-facing protocol:

```swift
protocol AdvisorProviding: Sendable {
    func advise(_ request: AdvisorRequest) async throws -> AdvisorResult
}
```

`AdvisorCoordinator` owns the eight narrow tool contracts from the brief and enforces a maximum of three options:

- `getWellnessContext` — returns coarse status only;
- `getFreeCalendarSlots` — returns windows without event titles or notes;
- `findNearbyFood` — returns source-owned place identities;
- `searchOfficialMenu` — returns cited evidence and explicit gaps;
- `estimateLocalDish` — returns a cited range or no estimate;
- `getSavedPreferences` — returns only request-relevant, user-approved memory;
- `proposeAlternatives` — returns deterministic candidate IDs; and
- `proposeCalendarChange` — prepares inert proposal data and never commits it.

Provider implementations are:

- `TemplateAdvisor`: required, deterministic, offline, and the fallback everywhere.
- `OnDeviceAdvisor`: optional on eligible iOS 26+ Apple Intelligence devices. It may select from candidate IDs and reword reasons/tradeoffs; it may not invent live facts or execute consequential actions.
- `CloudAdvisor`: not part of the approved build unless separately authorized. It would require a minimal proxy, explicit consent, a budget, operational ownership, and a privacy review. No provider key may ship in the app.

All provider output passes `ResponseValidator`, which rejects:

- more than three primary options;
- an option ID that no deterministic tool returned;
- uncited live claims;
- inferred allergies, injuries, diagnoses, or emotions;
- missing benefit/tradeoff fields;
- direct calendar, notification, or persistence instructions; and
- content blocked by `SafetyGate` or `ContentGuard`.

## 6. Live food evidence

Food help is user-triggered. The pipeline is:

1. Obtain an area or approximate location with permission.
2. Find places through MapKit.
3. Apply deterministic dietary and allergen handling.
4. Attach official menu evidence only when it can be tied to the place's own source.
5. Match a dish to a cited SG FoodID record or a saved user estimate.
6. Return up to three labeled results with source, check time, and uncertainty.

MapKit place results provide useful identity, address, phone, URL, and map data, but not a dependable machine-readable “open now” contract for this design. Therefore opening status defaults to **not verified** unless a cited source actually supplies it. The app may open the Apple Maps place card or the official website for the user to confirm.

Prices and nutrition follow these rules:

- sourced official value → show the value and check time;
- cited SG FoodID match → show a range and portion assumptions;
- user-saved correction → show “saved from prior visit” and its date;
- no evidence → show “price not known” or “estimate unavailable”; and
- never convert a typical, inferred, or stale value into a verified claim.

Allergen handling uses three states: `eligible`, `requiresConfirmation`, and `excluded`. A known conflict is excluded. An incomplete or unknown ingredient list can never be presented as safe or as the primary recommendation; it is shown only as a clearly separated confirmation-needed result when useful.

## 7. Notifications and Watch

The nudge planner is a pure function with a default daily budget of three. It removes candidates inside quiet periods, calendar blocks, workouts, and the planned sleep window. A repeatedly dismissed type moves from normal to reduced frequency and then paused. When a suggestion can wait, it updates Today silently.

Local notifications use ordinary interruption levels, never time-sensitive delivery by default. The app does not attempt to read private Focus state; it avoids the user's configured sleep/wind-down window and lets system Focus filtering operate normally.

Watch sync uses:

- `updateApplicationContext` for the latest phone-to-Watch snapshot;
- `transferUserInfo` for durable, idempotent Watch actions; and
- `sendMessage` only for optional interactions when the counterpart is reachable.

The Watch shows a glance, quick alternatives, movement logging, a foundation action, and saved-meal handoff. Common actions are designed for no more than two taps.

## 8. Seven-phase delivery plan

| Phase | Scope | Required completion evidence |
|---|---|---|
| 1. Foundation | Project skeleton, profile, consent screens, HealthKit sleep/activity context, EventKit availability, safety gate, daily priority, Today/Sleep/Settings | `swift test`; iOS and Watch simulator builds; on a real iPhone, one priority is produced from permitted device data and manual fallbacks work |
| 2. Alternatives | Outcomes, barriers, 2–3 validated options, choose/defer/rest, confirmation-bound rescheduling, basic movement substitutions | A missed plan can be replaced or rescheduled without manual replanning; invariant and calendar-confirmation tests pass |
| 3. Daily Foundations | Mobility, daylight, hydration guard, movement breaks, reset, wind-down, quiet periods, adaptive notification budget | Every foundation can be completed, replaced, snoozed, or disabled; at most three proactive notifications; repeated dismissal pauses a type |
| 4. Advisory agent | One coordinator, narrow tools, minimal packets, provider fallback, response validation, egress disclosure/history clearing | Useful options are returned without action authority; deterministic behavior remains available when the model is absent or rejected |
| 5. Live food | Nearby places, evidence/provenance, SG FoodID ranges, uncertainty, saved corrections | Every shown fact has the correct provenance/freshness label; allergy and unknown-ingredient tests pass |
| 6. Apple Watch | Glance, alternatives, movement log, foundation actions, saved-food handoff | Common actions take at most two taps; queued actions arrive once on the phone after reconnection |
| 7. Weekly learning | Pattern review, proposed default changes, one experiment, local metrics, export/delete | Preferences change only after approval; the review completes in 5–10 minutes and all local data can be exported/deleted |

Each phase ends with updated `README.md`, `MILESTONES.md`, and `DECISIONS.md`, device-test instructions, and a review stop. No phase begins until the prior one is accepted.

## 9. Test strategy and non-negotiable invariants

`SteadyCoreTests` will cover at minimum:

- daily-priority order, missing data, and the health-safety override;
- sleep samples crossing midnight, overlapping sources, naps, and partial coverage;
- free-slot calculation, empty calendars, travel padding, and denied access;
- alternative-set size, distinct effort levels, explicit preserved/lost outcome parts, and template fallback;
- known-allergen exclusion and unknown-ingredient confirmation behavior;
- notification daily cap, blocking windows, repeated dismissals, and silent updates;
- low-data mode across phone, Watch, advisor packets, exports, and notifications;
- advisor candidate-ID allowlisting, live-citation validation, and action-authority rejection;
- idempotent Watch actions; and
- preference, correction, and calendar changes requiring confirmation.

Service contract tests use sample providers. Phase completion additionally requires both simulator builds with no new warnings and the phase's physical-device test. Because the current machine is Windows without Swift/Xcode, those build gates must run on a Mac.

## 10. Starter-kit changes after approval

Before writing Phase 1 code:

- rewrite `MILESTONES.md` into the seven approved phases;
- add replacement decisions instead of silently erasing D4–D12 history;
- update `SPEC.md` with the advisor, evidence, privacy, metrics, and screen decisions;
- add a root README to the actual Xcode repository;
- quarantine the current food seed values from production recommendations;
- repair alternative templates before Phase 2; and
- preserve the ban on hand-editing `project.pbxproj`.

## 11. Approval gate

Please approve or change these three decisions before Phase 1 begins:

1. **Advisor:** recommended — deterministic templates everywhere, plus optional on-device Foundation Models where available; no cloud advisor in release 1.
2. **Live food:** recommended — MapKit discovery, cited SG FoodID data, saved corrections, and links to official sources; no automatic web crawling or paid places API in release 1.
3. **Price:** recommended — retain an optional per-meal price preference and display only sourced/saved prices; remove weekly spend tracking and estimated money-saved features.

Approval authorizes documentation reconciliation and Phase 1 implementation only. It does not authorize cloud infrastructure, paid APIs, publishing, or distribution.

## 12. Current platform references

- Apple Foundation Models `SystemLanguageModel`: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- Apple `MKMapItem`: https://developer.apple.com/documentation/mapkit/mkmapitem
- Apple capability availability by membership: https://developer.apple.com/help/account/reference/supported-capabilities-ios
- Health Promotion Board Singapore Food Insights Database: https://www.hpb.gov.sg/healthy-living/food-and-beverage/sgfoodid/
