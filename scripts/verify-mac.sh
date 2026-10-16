#!/usr/bin/env bash
# Run from any directory after following README.md's Xcode integration steps.
set -euo pipefail
task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$task_root"

if ! command -v swift >/dev/null || ! command -v xcodebuild >/dev/null; then
  printf '%s\n' 'Install Xcode and select it with xcode-select before verification.' >&2
  exit 1
fi

swift test --package-path Packages/SteadyCore

if [[ ! -d Steady.xcodeproj ]]; then
  printf '%s\n' 'Core tests finished. Integrate these sources into an Xcode-created Steady project using README.md.' >&2
  exit 1
fi

xcodebuild -project Steady.xcodeproj -scheme Steady \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Steady.xcodeproj -scheme 'SteadyWatch Watch App' \
  -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO build
printf '%s\n' 'Core tests and both simulator builds passed. Complete the device checks in README.md.'
