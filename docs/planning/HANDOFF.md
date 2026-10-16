# Steady release 1 handoff

Status: **Phase 1 implementation in progress; Mac verification pending**  
Prepared: 16 October 2026

This folder continues the interrupted Steady planning session. That session completed a detailed requirements and platform audit, but stopped before writing its promised proposal and README.

## Review package

- `PROPOSAL.md` — recommended architecture, project layout, phase plan, safety boundaries, and decisions requiring approval.
- `DATA_MODEL.md` — proposed pure-Swift domain models and SwiftData persistence boundaries.
- `AUDIT_NOTES.md` — the important conflicts and defects found when comparing the newer product brief with the earlier starter kit.

Source material remains unchanged (an archived copy of the starter is in [original-starter](original-starter)):

- `C:\Users\hello\Desktop\jarrodsgreekgod\steady-starter`
- `C:\Users\hello\Documents\Codex\2026-10-15\do\outputs\steady-starter`
- `C:\Users\hello\Documents\Codex\2026-10-15\do\outputs\Steady_App_Workflow.docx`

The two starter-kit copies were checked and are byte-for-byte identical. Neither contains Swift source, an Xcode project, a Git repository, or completed milestones.

## Approved implementation defaults

The implementation follows the proposed defaults:

1. Keep release 1 native, local-first, and usable without an account or server.
2. Use one `AdvisorCoordinator` interface with deterministic templates as the universal fallback.
3. Allow Apple's on-device Foundation Models only on supported iOS 26+ devices; do not require it.
4. Do not build a cloud advisor or automatic menu crawler until its backend, cost, privacy policy, and HealthKit constraints are explicitly approved.
5. Retain an optional per-meal price preference, but remove aggregate money tracking and estimated “money saved.”
6. Show only sourced prices and nutrition. Unknown values remain unknown.
7. Build in the seven phases from the newer brief, stopping for review after every phase.

## Implementation

Before Phase 1 can be integrated and verified, create the iOS and Watch targets in Xcode on a Mac by following the existing `SETUP.md`. The project rules prohibit hand-writing `project.pbxproj`.

The source implementation is this repository. Phase 1 includes:

- the `SteadyCore` Swift package and tests;
- profile, permission, sleep, calendar, safety, and priority models;
- real and sample HealthKit/EventKit providers;
- onboarding, Today, Sleep, and Settings foundations;
- one daily priority derived from real device data; and
- updated progress and decision documentation.

This Windows machine does not currently have Swift or Xcode. Source files can be authored here, but Phase 1 cannot be declared complete until `swift test`, both simulator builds, and the real-device completion test pass on macOS.

## Current handoff

Open the repository [README.md](../../README.md) for setup, source status, verification, and the device checklist. Phases 2-7 remain outside this implementation pass.
