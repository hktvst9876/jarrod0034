# Decisions log

One line per decision: **date · decision · why**. The coding assistant adds to this; don't undo a decision without writing a new line that replaces it.

| # | Date | Decision | Why |
|---|---|---|---|
| D1 | 2026-10-16 | Native Swift/SwiftUI iOS + watchOS app, built in Xcode on the Mac, signed with a free Personal Team | Only way to read Apple Watch data via HealthKit; free |
| D2 | 2026-10-16 | Deployment targets iOS 18 / watchOS 11 | Covers SwiftData and current HealthKit types; newer APIs behind `#available` |
| D3 | 2026-10-16 | All decision logic in local package `SteadyCore` (Foundation only), unit-tested with `swift test` | Testable without a phone; keeps UI thin |
| D4 | 2026-10-16 | No cloud AI, paid APIs, API keys, backend or third-party packages in v1. Alternative templates are the product | Free, private, works offline |
| D5 | 2026-10-16 | Food is local-first (seed library + saved dishes); MapKit local search for "nearby"; never claim menus, prices or hours we didn't get | Hawker stalls rarely have online menus; MapKit search works on a free account |
| D6 | 2026-10-16 | Money = price on every food suggestion + max price per meal; food spend shown only in the weekly review. No budget tracker | User is on a tight budget but money shouldn't be the centre of the app |
| D7 | 2026-10-16 | Calorie/protein targets are opt-in; low-data mode hides calories, weight trend and recovery labels | Avoid obsessive tracking by default |
| D8 | 2026-10-16 | Cravings handled as barriers in the alternative ladder (+ 10-min wait + 2 planned treats/week) | Reuses one system; no shame |
| D9 | 2026-10-16 | Notifications are computed in-app and scheduled as local notifications (on wake/open/calendar change), max 3/day | iOS background execution is unreliable; push needs a paid account |
| D10 | 2026-10-16 | Calendar writes only to a calendar named "Steady", only after Confirm | User stays in control of their schedule |
| D11 | 2026-10-16 | Default time zone Asia/Singapore; week = Monday–Sunday | User is in Singapore |
| D12 | 2026-10-16 | Xcode synchronized folders; assistant never edits project.pbxproj by hand | Hand edits to the project file break easily |
