# Steady

Steady is a private, local-first iPhone and Apple Watch wellness app for one college student in Singapore. It turns permitted HealthKit and Calendar context into one realistic daily priority, explains why, and always keeps a manual fallback available.

## Current status

**Phase 1 - Foundation: source implementation and checks in progress.**

The repository is being prepared with a Foundation-only `SteadyCore` package, iPhone source folders, protocol-backed HealthKit and EventKit services, local persistence, and a Watch placeholder. This is not yet a completed phase: the Xcode project must be generated on a Mac, package and targets must be linked in Xcode, tests and simulator builds must pass, and the real-device checks below must be completed.

Do not mark Phase 1 complete from a Windows source review alone. The authoritative checklist is [docs/MILESTONES.md](docs/MILESTONES.md).

## Approved release-1 boundaries

- Native Swift 6 and SwiftUI; iOS 18 and watchOS 11 minimums.
- Deterministic local planning is always available. An optional on-device Foundation Models presentation layer may be added in Phase 4 on supported iOS 26+ devices. There is no cloud advisor in release 1.
- Food results must carry source, freshness, and uncertainty. Use MapKit for user-triggered discovery, cited SG FoodID data where applicable, and remembered user corrections. Do not invent menus, prices, ingredients, opening hours, or nutrition.
- A maximum price per meal is optional. There is no weekly spend ledger and no estimated "money saved" feature.
- Cravings are ordinary user-selected barriers. Release 1 has no dedicated Urge screen, treat quota, or moral scoring.
- Raw HealthKit samples, calendar event details, history, and preferences stay on the device. Every calendar write and every remembered correction requires confirmation.

## Repository map

```text
Steady/
|-- Packages/SteadyCore/       Foundation-only rules and tests
|-- Steady/                    iPhone target sources
|   |-- App/
|   |-- Features/
|   |-- Services/
|   |-- Persistence/
|   `-- Resources/
|-- SteadyWatch Watch App/     watchOS target sources
|-- docs/                      product spec, phases, decisions, prompts, seed data
|   `-- planning/              approved proposal, data model, audit notes, handoff, original starter
|-- AGENTS.md                  coding rules
`-- SETUP.md                   original starter setup; use the steps below for this source-first repo
```

The planning rationale and proposed model are in [docs/planning](docs/planning): [PROPOSAL.md](docs/planning/PROPOSAL.md), [DATA_MODEL.md](docs/planning/DATA_MODEL.md), and [AUDIT_NOTES.md](docs/planning/AUDIT_NOTES.md). The untouched original starter kit is archived in [docs/planning/original-starter](docs/planning/original-starter) for history only.

## Mac and Xcode setup - beginner steps

These steps intentionally use Xcode for project membership, capabilities, signing, and package linkage. Never edit `project.pbxproj` by hand.

### 1. Install and prepare Xcode

1. On the Mac, install the current Xcode from the Mac App Store.
2. Open Xcode once, accept the licence, and let it install components.
3. Choose **Xcode > Settings > Components** and install an iOS 18-or-later simulator and a watchOS 11-or-later simulator.
4. Choose **Xcode > Settings > Accounts > +**, sign in with the Apple ID, and confirm a **Personal Team** appears.
5. Copy this entire `Steady` repository to the Mac, for example to `~/Developer/Steady`.

### 2. Create the iPhone project without overwriting source

1. In Finder, confirm `~/Developer/Steady` contains `AGENTS.md`, `docs`, and the source folders. Back it up or commit it before continuing.
2. In Xcode choose **File > New > Project... > iOS > App > Next**.
3. Enter:
   - **Product Name:** `Steady`
   - **Team:** your Personal Team
   - **Organization Identifier:** a permanent reverse-domain value such as `com.yourname`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Testing System:** Swift Testing
   - **Storage:** None
4. Save the temporary scaffold beside the repository, for example as `~/Developer/Steady-Xcode-Scaffold`. Leave **Create Git repository** off.
5. Quit Xcode. In Finder, move `Steady.xcodeproj` from the temporary scaffold into `~/Developer/Steady`. Do not move the generated `Steady` source folder and do not replace any repository file.
6. Reopen `~/Developer/Steady/Steady.xcodeproj`.
7. In the Project navigator, select the generated yellow/blue `Steady` source entry and press Delete. Choose **Remove Reference**, never **Move to Trash**.
8. Drag the repository's `~/Developer/Steady/Steady` source folder from Finder into the Project navigator directly under the project.
9. In the sheet, choose **Create folder references** or **Synchronize groups with folder** (wording depends on Xcode), tick target **Steady**, and click **Finish**. The folder must remain synchronized so new Swift files are discovered automatically.
10. Select the blue project icon, select target **Steady**, then **General**. Set **Minimum Deployments > iOS 18.0** and confirm the bundle identifier begins with the organization identifier.
11. With target **Steady** selected, open **Build Settings**, search for **Swift Language Version**, and choose **Swift 6**.
12. Still in **Build Settings**, search for **Default Actor Isolation**. If that setting is present, choose **Nonisolated**. The source marks UI state `@MainActor` and services as actors explicitly; it does not assume a target-wide MainActor default.

If Xcode offers to replace files at any point, cancel and check that you selected **Remove Reference** rather than deleting files on disk.

### 3. Add the Watch app target

1. Choose **File > New > Target... > watchOS > App > Next**.
2. Set **Product Name** to `SteadyWatch`.
3. Choose **Watch App for Existing iOS App** and select **Steady** as the companion app. Use SwiftUI and Swift. Click **Finish**.
4. If Xcode asks to activate the new scheme, click **Activate**.
5. Remove only the newly generated Watch source reference from the Project navigator using **Remove Reference**.
6. Drag the repository folder `SteadyWatch Watch App` into the navigator, choose a synchronized folder/group, tick only the Watch app target, and click **Finish**.
7. Select the Watch app target > **General** > set **Minimum Deployments > watchOS 11.0**.
8. Select **Build Settings**, set **Swift Language Version** to **Swift 6**, and set **Default Actor Isolation** to **Nonisolated** if that setting is present.

### 4. Link the local SteadyCore package

1. In Xcode choose **File > Add Package Dependencies...**.
2. Click **Add Local...**.
3. Select `~/Developer/Steady/Packages/SteadyCore` and click **Add Package**.
4. In the product sheet, select library **SteadyCore**, choose target **Steady**, and click **Add Package**.
5. Select the blue project icon > Watch app target > **General > Frameworks, Libraries, and Embedded Content > +**.
6. Select **SteadyCore** and click **Add**. Leave it set to **Do Not Embed** when Xcode presents an embed choice.
7. For both targets, open **Build Phases > Link Binary With Libraries** and verify `SteadyCore` appears once.

The package declares Swift tools 6.0. The two app targets must also compile in Swift 6 mode so concurrency checks are consistent.

### 5. Signing and capabilities

For target **Steady**:

1. Open **Signing & Capabilities**.
2. Tick **Automatically manage signing** and select the Personal Team.
3. Click **+ Capability > HealthKit**.

For the Watch app target:

1. Open **Signing & Capabilities**.
2. Tick **Automatically manage signing** and select the same Personal Team.
3. Click **+ Capability > HealthKit**.

Do not add iCloud, CloudKit, push notifications, Family Controls, or a third-party entitlement.

### 6. Privacy keys

Select the iPhone target > **Info** > add these rows:

| Xcode key | Value |
|---|---|
| Privacy - Health Share Usage Description | Steady reads your sleep and activity data to suggest a realistic plan. |
| Privacy - Health Update Usage Description | Steady saves only health entries you explicitly log. |
| Privacy - Calendars Full Access Usage Description | Steady checks your availability and adds plans to its own calendar only when you confirm. |

Add this later in Phase 5, when nearby food is enabled:

| Xcode key | Value |
|---|---|
| Privacy - Location When In Use Usage Description | Steady uses your approximate location to find food nearby when you ask. |

Select the Watch target > **Info** and add:

| Xcode key | Value |
|---|---|
| Privacy - Health Share Usage Description | Steady reads sleep and activity data for your watch glance. |
| Privacy - Health Update Usage Description | Steady saves only health entries you explicitly log. |

The source names behind the Xcode labels are `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`, `NSCalendarsFullAccessUsageDescription`, and later `NSLocationWhenInUseUsageDescription`.

### 7. Verify Phase 1 on the Mac

In Terminal, from `~/Developer/Steady`, run:

```bash
swift test --package-path Packages/SteadyCore
xcrun simctl list devices available
xcodebuild -project Steady.xcodeproj -scheme Steady \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -project Steady.xcodeproj -scheme 'SteadyWatch Watch App' \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

If your installed simulator names differ, copy exact names from the `simctl` output into the two destination strings. A phase gate passes only when the core tests and both builds succeed with no new warnings.

### 8. Verify on a real iPhone and Watch

1. Connect and unlock the iPhone, trust the Mac, and enable Developer Mode on the iPhone. Keep the paired Watch nearby and enable its Developer Mode.
2. In Xcode select scheme **Steady**, select the iPhone, and press Run.
3. Complete or skip onboarding. Deny Health and Calendar once: the app must remain usable with sample/manual fallback and no crash.
4. In Settings turn **Use Sample Data** on. Confirm Today shows one priority with a plain-language reason, Sleep shows sample context, and the five tabs are **Today, Move, Sleep, Eat, Week**.
5. Turn sample data off. Grant Health read access and Calendar full access when the app explains why. Confirm Today and Sleep handle real or missing data neutrally.
6. Confirm no calendar event is created merely by viewing Today or Sleep.
7. Select the Watch scheme, choose the paired Watch, and press Run. Confirm the Steady placeholder/glance launches.

Record the exact Xcode version, simulator destinations, test output, and device observations in `docs/MILESTONES.md`. Only then may Phase 1 be marked complete.

## Continue development

Read these files in order before changing code:

1. `AGENTS.md`
2. `docs/SPEC.md`
3. `docs/MILESTONES.md`
4. `docs/DECISIONS.md`

Use the phase prompts in `docs/PROMPTS.md`. Implement one phase at a time and stop for review after each phase.
