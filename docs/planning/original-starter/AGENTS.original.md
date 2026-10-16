# AGENTS.md — instructions for the coding assistant

You are helping one person build **Steady**, a personal wellness app for their own iPhone and Apple Watch.
They are a college student in Singapore on a tight budget. They are not an experienced iOS developer, so explain anything they must do by hand in Xcode click by click.

**Read before every session:**
1. `docs/SPEC.md`: what the app does, the rules, the formulas and the data model.
2. `docs/MILESTONES.md`: what to build next, and what counts as done.
3. `docs/DECISIONS.md`: decisions already made. Don't undo them without asking.

---

## 1. Hard constraints (never break these)

- **Native Swift 6 + SwiftUI.** iOS app + watchOS app. Deployment targets: **iOS 18 / watchOS 11** unless `docs/DECISIONS.md` says otherwise.
- **Apple frameworks only:** HealthKit, EventKit, SwiftData, UserNotifications, MapKit, CoreLocation, WatchConnectivity, WidgetKit, App Intents, Swift Charts. **No third-party packages. No backend. No paid APIs. No API keys.**
- **Free Apple account (Personal Team).** So: **no CloudKit/iCloud sync, no Family Controls / Screen Time API, no push notifications, no MapKit routing directions.** HealthKit, local notifications, MapKit local search and App Groups are fine.
- **All data stays on the device.** No analytics, no accounts, no network calls except MapKit local search (Phase M6, user-triggered).
- **Calendar:** read any calendar; **write only to a calendar named "Steady"**, and **only after the user taps Confirm.**
- **Never edit `Steady.xcodeproj/project.pbxproj` by hand.** The app folders are Xcode *synchronized folders*, so a new `.swift` file saved inside `Steady/` or `SteadyWatch Watch App/` is added to that target automatically. If something needs a new target, capability, Info.plist key, or package link, **stop and give the user numbered Xcode click steps**, then continue after they confirm.
- **Every number shown to the user has a one-line "why"** they can tap to see. Nutrition is always a **range** labelled `estimate`, `saved`, or `verified`.
- **Tone:** no guilt, no streaks, no "failed", no red failure screens, no loss warnings. Missed is just missed.
- **Safety rules in `docs/SPEC.md` §18 are code-level requirements**, not suggestions.

---

## 2. Architecture

```
Steady/                              ← git repo root
├── AGENTS.md  CLAUDE.md  SETUP.md
├── docs/
│   ├── SPEC.md  MILESTONES.md  PROMPTS.md  DECISIONS.md
│   └── seed/foods.json  seed/alternatives.json
├── Packages/
│   └── SteadyCore/                  ← ALL decision logic lives here
│       ├── Package.swift            (platforms: iOS 18, watchOS 11, macOS 15)
│       ├── Sources/SteadyCore/
│       │   ├── Models/              value types (structs/enums), Codable, Sendable
│       │   ├── Priority/            daily priority rules (SPEC §4)
│       │   ├── Alternatives/        Plan A + alternative ladder (SPEC §5)
│       │   ├── Sleep/               bedtime planner, debt, consistency (SPEC §6)
│       │   ├── Training/            templates, progression, recovery adjustment (SPEC §7)
│       │   ├── Food/                ranking, filters, price (SPEC §8)
│       │   ├── Fuel/                BMR/TDEE/targets/adaptive TDEE (SPEC §9)
│       │   ├── Recovery/            recovery context label (SPEC §10)
│       │   ├── Nudges/              daily nudge planner, max-3 rule (SPEC §11)
│       │   ├── Calendar/            free-slot finder on plain intervals (SPEC §12)
│       │   ├── Weekly/              weekly review + experiment (SPEC §14)
│       │   └── Support/             Clock protocol, seed loaders, formatting
│       └── Tests/SteadyCoreTests/   unit tests for every rule and formula
├── Steady.xcodeproj
├── Steady/                          ← iOS app target (synchronized folder)
│   ├── App/                         SteadyApp.swift, RootTabView, AppEnvironment (dependency container)
│   ├── Features/
│   │   ├── Onboarding/  Today/  Alternatives/  Move/  Sleep/
│   │   ├── Eat/  Foundations/  Week/  Settings/
│   ├── Services/                    adapters that turn Apple APIs into SteadyCore types
│   │   ├── Health/                  HealthDataProviding + HealthKitProvider + SampleHealthProvider
│   │   ├── Calendar/                CalendarProviding + EventKitProvider + SampleCalendarProvider
│   │   ├── Notifications/           NotificationScheduler
│   │   ├── Places/                  PlaceSearching + MapKitPlaceSearch (M6)
│   │   └── WatchSync/               WatchConnectivity (M8)
│   ├── Persistence/                 SwiftData @Model classes + mappers to SteadyCore structs
│   ├── Resources/                   foods.json, alternatives.json (copied from docs/seed)
│   └── Steady.entitlements
└── SteadyWatch Watch App/           ← watchOS target (synchronized folder)
    ├── Views/                       Glance, Alternatives, Move, Foundation, QuickLog, Urge
    └── Services/                    WatchSession, HealthKit reads
```

**Rules**
- **SteadyCore is pure Swift.** Only `Foundation` is allowed there. **No HealthKit, EventKit, SwiftUI or SwiftData imports in SteadyCore.** Logic takes plain inputs and returns plain outputs, so it can be unit-tested with `swift test` without a phone.
- **Inject time.** Use `protocol Clock { var now: Date { get } }` plus a `Calendar` with `TimeZone(identifier: "Asia/Singapore")` by default. Never call `Date()` inside SteadyCore logic.
- **Every Apple service sits behind a protocol with a sample implementation.** The app must run in the simulator and in SwiftUI previews using `Sample…Provider` data. A Debug toggle in Settings switches between real and sample data.
- **UI is thin.** Views call `@Observable` view models; view models call SteadyCore; persistence maps to and from SteadyCore structs.
- Swift concurrency (`async/await`, `@MainActor` for UI state). No force unwraps (`!`) outside tests. No `print` in shipped code; use `Logger` (os).
- Small files (~200 lines max). One type per file where reasonable.
- User-facing strings are short, plain English. No jargon (say "how recovered you are", not "HRV z-score").

---

## 3. How to work (every session)

1. Read the three docs above. Find the **first unchecked milestone** in `docs/MILESTONES.md` (unless the user names one).
2. Post a **short plan** (5–10 bullets): files you'll add or change, tests you'll write, anything the user must click in Xcode.
3. Build **SteadyCore logic + tests first**, then services, then UI.
4. Run the checks (§4). Fix until they pass.
5. Update `docs/MILESTONES.md` (tick boxes) and add one line per decision to `docs/DECISIONS.md`.
6. Finish with:
   - **What changed** (3–6 bullets)
   - **Test it on your iPhone/Watch:** numbered steps a non-developer can follow
   - **Anything you need to click in Xcode**
   - **Suggested commit message**
7. **Stop. Do not start the next milestone** until the user asks.

If the spec is unclear or contradicts itself, pick the simplest option that respects §1, write it in `docs/DECISIONS.md`, and mention it in your summary. Ask the user only when a choice is hard to undo.

---

## 4. Commands

```bash
# Core logic tests (fast, no simulator needed)
swift test --package-path Packages/SteadyCore

# Find an installed simulator name
xcrun simctl list devices available | grep -E "iPhone|Watch"

# Build iOS app for the simulator (replace the device name with one from the list)
xcodebuild -project Steady.xcodeproj -scheme Steady \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Build the watch app for the simulator
xcodebuild -project Steady.xcodeproj -scheme "SteadyWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```
Installing on the real iPhone and Watch is done by the user in Xcode (▶ Run). Don't try to sign or install from the command line.

---

## 5. Definition of done (every milestone)

- [ ] `swift test` passes; new logic has tests, including edge cases (missing data, midnight crossover, empty calendar).
- [ ] iOS and watch builds succeed for the simulator with **zero warnings in new code**.
- [ ] The feature works with **sample data** (simulator) and degrades gracefully when **permission is denied or data is missing** (SPEC §19).
- [ ] No guilt language; every number has a "why"; nutrition shown as a range with a label.
- [ ] `docs/MILESTONES.md` and `docs/DECISIONS.md` updated.
