"""Static handoff checks; these do not compile Swift or run Swift tests."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def check(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


check((ROOT / "Packages/SteadyCore/Package.swift").is_file(), "Package.swift is missing")
swift_files = list(ROOT.rglob("*.swift"))
check(bool(swift_files), "No Swift source files exist")
test_files = [path for path in swift_files if "Tests" in path.parts]
check(bool(test_files), "No Swift tests were supplied")

for path in swift_files:
    source = path.read_text(encoding="utf-8-sig")
    name = relative(path)
    is_test = "Tests" in path.parts
    is_core = "/Sources/SteadyCore/" in "/" + name
    if is_core:
        imports = re.findall(r"^\s*(?:@\w+\s+)?import\s+(\w+)", source, re.MULTILINE)
        check(all(module == "Foundation" for module in imports), f"Non-Foundation core import: {name}")
        if path.name != "Clock.swift":
            check(not re.search(r"\bDate\s*\(\s*\)", source), f"Uninjected current time: {name}")
    if not is_test:
        check(not re.search(r"\b(?:print|fatalError)\s*\(", source), f"Debug/crash call: {name}")
        check(not re.search(r"\bimport\s+(?:Firebase|Alamofire|OpenAI|Anthropic)\b", source), f"Third-party app dependency: {name}")
        check(not re.search(r"\bURLSession\b", source), f"Unexpected Phase 1 network client: {name}")
        check(not re.search(r"\b(?:try|as)!(?:\s|\b)", source), f"Force operation: {name}")
    check("\ufffd" not in source, f"Replacement character in source: {name}")

for filename in ("foods.json", "alternatives.json"):
    fixture = ROOT / "docs/seed" / filename
    check(fixture.is_file(), f"Missing seed fixture: {filename}")
    if fixture.is_file():
        try:
            fixture_data = json.loads(fixture.read_text(encoding="utf-8-sig"))
        except (ValueError, UnicodeError) as error:
            errors.append(f"Invalid fixture {filename}: {error}")
            continue
        target = ROOT / "Steady/Resources" / filename
        check(target.is_file(), f"Missing app resource: {filename}")
        if target.is_file():
            try:
                check(json.loads(target.read_text(encoding="utf-8-sig")) == fixture_data, f"Resource differs from fixture: {filename}")
            except (ValueError, UnicodeError) as error:
                errors.append(f"Invalid app resource {filename}: {error}")

if errors:
    print("Static checks found issues:")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print(f"Static checks passed for {len(swift_files)} Swift files, including {len(test_files)} test files.")
print("Compiler, simulator, and physical-device verification remain separate gates.")
