#!/usr/bin/env python3
"""Fail when SDK logic line coverage drops below 70%.

UI, flow coordinators and the real Amplify bootstrap stay outside this gate.
Keychain adapters stay outside too: the suite replaces them with in-memory fakes,
same as the Android suite measuring network and domain rather than storage.
"""

import json
import subprocess
import sys
from pathlib import Path

MINIMUM = 0.70
EXCLUDED_PARTS = ("/UI/", "/FlowCoordinators/")
EXCLUDED_SUFFIXES = (
    "AmplifyInitializer.swift",
    "DeviceAssociationStoring.swift",
    "PinDataStoreManaging.swift",
    "DeviceIdentifierProvider.swift",
)


def included(path: str) -> bool:
    if any(part in path for part in EXCLUDED_PARTS):
        return False
    return not path.endswith(EXCLUDED_SUFFIXES)


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: check-sdk-coverage.py TestResults.xcresult", file=sys.stderr)
        sys.exit(2)

    bundle = Path(sys.argv[1])
    report = subprocess.check_output(
        ["xcrun", "xccov", "view", "--report", "--json", str(bundle)]
    )
    data = json.loads(report)
    targets = data.get("targets", [])
    covered = 0
    executable = 0
    files = []
    matched = False

    for target in targets:
        name = target.get("name", "")
        if "IDDigitalSDK" not in name or "Tests" in name:
            continue
        matched = True
        for file in target.get("files", []):
            path = file.get("path") or file.get("name") or ""
            if not included(path):
                continue
            file_executable = file.get("executableLines") or 0
            file_covered = file.get("coveredLines") or 0
            if file_executable == 0:
                continue
            covered += file_covered
            executable += file_executable
            files.append((file_covered / file_executable, path))

    if not matched or executable == 0:
        names = [target.get("name", "") for target in targets]
        print(f"No SDK coverage in {bundle}. Targets: {names}", file=sys.stderr)
        sys.exit(1)

    ratio = covered / executable
    print(f"SDK logic line coverage: {ratio:.1%} ({covered}/{executable})")
    if ratio < MINIMUM:
        print(f"Coverage {ratio:.1%} is below {MINIMUM:.0%}", file=sys.stderr)
        for file_ratio, path in sorted(files)[:20]:
            print(f"  {file_ratio:.1%} {path}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
