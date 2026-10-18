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
        check(not re.search(r"\bURLSession\b", source), f"Unexpected network client in the local planner: {name}")
        check(not re.search(r"\b(?:class|struct|actor)\s+CloudAdvisor\b", source), f"Cloud advisor is outside release 1: {name}")
        if re.search(r"\bimport\s+FoundationModels\b", source):
            check(bool(re.search(r"#if\s+canImport\s*\(\s*FoundationModels\s*\)", source)),
                  f"Foundation Models requires an older-SDK compile guard: {name}")
            check(bool(re.search(r"(?:@available|#available)\s*\(\s*iOS\s+26(?:\.0)?\b", source)),
                  f"Foundation Models requires an iOS 26 availability guard: {name}")
        check(not re.search(r"\b(?:try|as)!(?:\s|\b)", source), f"Force operation: {name}")
    check("\ufffd" not in source, f"Replacement character in source: {name}")
    is_food = "/Food/" in "/" + name or "/Eat/" in "/" + name
    if is_food and not is_test:
        check(not re.search(r"\bLegacyFoodSeed\b|foods\.json", source),
              f"Legacy food fixtures must not enter production food help: {name}")
        check(not re.search(r"\brequestAlwaysAuthorization\b|\brequestTemporaryFullAccuracyAuthorization\b|\bstartMonitoringSignificantLocationChanges\b", source),
              f"Food discovery must not request always/precise/background location: {name}")
        if re.search(r"\bimport\s+CoreLocation\b", source):
            check("kCLLocationAccuracyReduced" in source, f"Food location must request reduced accuracy: {name}")
    is_watch_boundary = "/WatchSync/" in "/" + name or "/CompanionConnectivity/" in "/" + name
    if is_watch_boundary and not is_test:
        check(not re.search(r"\bimport\s+(?:HealthKit|EventKit|FoundationModels)\b", source),
              f"Watch sync must not access raw Health/Calendar or model frameworks: {name}")
        check(not re.search(r"\b(?:URLSession|transferFile|transferCurrentComplicationUserInfo)\b", source),
              f"Watch sync uses bounded typed context/userInfo, not arbitrary files or network clients: {name}")

# Keep the explicit Phase 7 schema exhaustive when another app-owned model is added.
# These are source guards, not execution of migration, deletion, or serialization.
model_names: set[str] = set()
for path in (ROOT / "Steady/Persistence").glob("*.swift"):
    model_names.update(re.findall(r"@Model\s+final\s+class\s+(\w+)", path.read_text(encoding="utf-8-sig")))
archive_tables = (ROOT / "Steady/Services/Privacy/SteadyArchiveTables.swift").read_text(encoding="utf-8-sig")
archive_builder = (ROOT / "Steady/Services/Privacy/SteadyArchiveBuilder.swift").read_text(encoding="utf-8-sig")
deletion_source = (ROOT / "Steady/Services/Privacy/DataLifecycle.swift").read_text(encoding="utf-8-sig")
container_source = (ROOT / "Steady/App/SteadyApp.swift").read_text(encoding="utf-8-sig")
check(bool(model_names), "No app-owned models found for data-control schema audit")
for model in model_names:
    check(model + ".self" in container_source, f"Model absent from app container: {model}")
    check(f"FetchDescriptor<{model}>" in archive_builder, f"Model absent from export capacity audit: {model}")
    check(model in archive_tables or (model == "ProfileRecord" and "profiles.map(profileRow)" in archive_tables),
          f"Model absent from explicit export schema: {model}")
    check(f"remove({model}.self, context)" in deletion_source, f"Model absent from confirmed deletion: {model}")
for path in (ROOT / "Steady/Services/Privacy").glob("*.swift"):
    source = path.read_text(encoding="utf-8-sig")
    check(not re.search(r"\bimport\s+(?:HealthKit|EventKit|CoreLocation|MapKit)\b", source),
          f"Data controls must not query raw external records: {relative(path)}")

for filename in ("foods.json", "alternatives.json", "plan-alternatives.json"):
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
        test_target = ROOT / "Packages/SteadyCore/Tests/SteadyCoreTests/Resources" / filename
        check(test_target.is_file(), f"Missing package test resource: {filename}")
        if test_target.is_file():
            check(json.loads(test_target.read_text(encoding="utf-8-sig")) == fixture_data,
                  f"Test resource differs from fixture: {filename}")

catalog_path = ROOT / "docs/seed/plan-alternatives.json"
if catalog_path.is_file():
    catalog = json.loads(catalog_path.read_text(encoding="utf-8-sig"))
    check(catalog.get("version") == 1, "Unsupported production alternative catalog version")
    templates = catalog.get("templates", [])
    check(bool(templates), "Production alternative catalog is empty")
    check(len({item.get("id") for item in templates}) == len(templates), "Duplicate template IDs")
    for template in templates:
        label = template.get("id", "unnamed template")
        options = template.get("options", [])
        check(2 <= len(options) <= 3, f"Alternative count outside 2-3: {label}")
        check(len({option.get("effort") for option in options}) == len(options), f"Repeated effort: {label}")
        expected_parts = None
        for option in options:
            option_id = option.get("id", "unnamed option")
            kept = set(option.get("preserves", []))
            lost = set(option.get("doesNotPreserve", []))
            check(not kept.intersection(lost), f"Overlapping outcome claims: {option_id}")
            if expected_parts is None:
                expected_parts = kept.union(lost)
            check(kept.union(lost) == expected_parts, f"Inconsistent outcome partition: {option_id}")
            check(option.get("minutes", 0) > 0, f"Rest/defer padded into primary options: {option_id}")
            for key in ("title", "benefitKept", "tradeoff"):
                check(bool(option.get(key, "").strip()), f"Missing {key}: {option_id}")
            check(bool(option.get("steps")), f"Missing steps: {option_id}")

if errors:
    print("Static checks found issues:")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print(f"Static checks passed for {len(swift_files)} Swift files, including {len(test_files)} test files.")
print("Compiler, simulator, and physical-device verification remain separate gates.")
