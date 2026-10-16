# Steady setup

The canonical beginner setup is in the root [README.md](README.md), under **Mac and Xcode setup - beginner steps**. Follow that section exactly for:

- installing Xcode and simulator platforms;
- creating `Steady.xcodeproj` without overwriting the prepared source;
- adding the iPhone and Watch targets;
- adding source folders with correct target membership;
- linking the local `SteadyCore` package;
- signing with a Personal Team;
- adding HealthKit capabilities and privacy usage descriptions; and
- running core tests, both simulator builds, and device checks.

Do not use an old M0 kickoff prompt. The authoritative workflow is the seven phases in `docs/MILESTONES.md`.

## Preflight checklist

Before opening Xcode:

- [ ] Work on a Mac with the current Xcode and iOS/watchOS simulator platforms installed.
- [ ] Keep at least 40 GB of free space for Xcode and simulators.
- [ ] Sign in under **Xcode > Settings > Accounts** and confirm a Personal Team appears.
- [ ] Back up or commit this repository before generating project metadata.
- [ ] Confirm these paths exist: `Packages/SteadyCore`, `Steady`, `SteadyWatch Watch App`, and `docs`.
- [ ] Do not hand-edit `project.pbxproj` and do not let Xcode replace the prepared source folders.

## Verification sequence

After completing the Xcode setup in README.md:

1. Run the repository static checker if present:

   ```bash
   python3 scripts/check_source.py
   ```

2. Run core tests:

   ```bash
   swift test --package-path Packages/SteadyCore
   ```

3. Run the Mac verification helper if present:

   ```bash
   bash scripts/verify-mac.sh
   ```

4. If simulator names differ, list installed destinations and use the exact names in README.md's `xcodebuild` commands:

   ```bash
   xcrun simctl list devices available
   ```

5. Record Xcode version, commands, destinations, pass/fail results, and new warnings in the Phase 1 Evidence section of `docs/MILESTONES.md`.

Static checks on Windows do not replace Swift compilation or Apple-platform builds.

## Device sequence

1. Connect and unlock the iPhone, trust the Mac, and enable Developer Mode.
2. Keep the paired Apple Watch nearby and enable Developer Mode on it.
3. Run the `Steady` scheme on the iPhone.
4. Deny Health and Calendar once and confirm onboarding remains usable with sample/manual fallback.
5. Enable **Use Sample Data** and confirm Today produces one priority, Sleep shows sample context, and all five tabs open.
6. Disable sample data, grant access, and confirm real or neutrally missing data appears without a crash.
7. Confirm opening Today and Sleep did not create or modify any calendar event.
8. Run the Watch scheme and confirm the Steady placeholder/glance launches.
9. Record the observations in `docs/MILESTONES.md`.

Phase 1 remains incomplete until the Mac and device evidence is recorded and accepted.
