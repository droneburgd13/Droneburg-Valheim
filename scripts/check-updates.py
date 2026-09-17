#!/usr/bin/env python3

import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path("/mnt/storage/valheim")
REPO = ROOT / "release-repo"
MANIFEST = REPO / "manifests" / "mods.json"
STATE_DIR = ROOT / "automation"
STATE_FILE = STATE_DIR / "state.json"

PACKAGE_API = "https://thunderstore.io/c/valheim/api/v1/package/"

APP_MANIFESTS = [
    ROOT / "data/server/steamapps/appmanifest_896660.acf",
    ROOT / "data/dl/server/steamapps/appmanifest_896660.acf",
]

def semver(v):
    nums = re.findall(r"\d+", str(v))
    nums = [int(x) for x in nums[:3]]
    while len(nums) < 3:
        nums.append(0)
    return tuple(nums)

def game_build():
    for path in APP_MANIFESTS:
        if not path.exists():
            continue

        text = path.read_text(errors="replace")

        m = re.search(r'"buildid"\s+"([^"]+)"', text)
        if m:
            return m.group(1)

    raise RuntimeError("Could not locate Valheim Steam buildid")

def fetch_packages():
    request = urllib.request.Request(
        PACKAGE_API,
        headers={
            "User-Agent": "Droneburg-Valheim-Automation/1.0"
        },
    )

    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)

def latest_version(pkg):
    versions = pkg.get("versions") or []

    if not versions:
        return None

    best = max(
        versions,
        key=lambda v: semver(v.get("version_number", "0.0.0")),
    )

    return best.get("version_number")

manifest = json.loads(MANIFEST.read_text())

STATE_DIR.mkdir(parents=True, exist_ok=True)

packages = fetch_packages()

lookup = {}

for pkg in packages:
    namespace = (
        pkg.get("owner")
        or pkg.get("namespace")
        or pkg.get("namespace_name")
    )

    name = pkg.get("name")

    if namespace and name:
        lookup[(namespace.lower(), name.lower())] = pkg

current_build = game_build()

if STATE_FILE.exists():
    state = json.loads(STATE_FILE.read_text())
else:
    state = {
        "valheim_buildid": current_build,
        "mods": {
            mod["id"]: mod["current"]
            for mod in manifest["mods"]
        }
    }

changes = []
missing = []

old_build = str(state.get("valheim_buildid", ""))

if old_build != current_build:
    changes.append({
        "type": "valheim",
        "name": "Valheim",
        "old": old_build,
        "new": current_build,
    })

for mod in manifest["mods"]:
    key = (
        mod["namespace"].lower(),
        mod["package"].lower(),
    )

    pkg = lookup.get(key)

    if pkg is None:
        missing.append(
            f'{mod["namespace"]}-{mod["package"]}'
        )
        continue

    latest = latest_version(pkg)

    if not latest:
        missing.append(
            f'{mod["namespace"]}-{mod["package"]} (no versions)'
        )
        continue

    installed = str(
        state.get("mods", {}).get(
            mod["id"],
            mod["current"],
        )
    )

    if semver(latest) > semver(installed):
        changes.append({
            "type": "mod",
            "id": mod["id"],
            "namespace": mod["namespace"],
            "package": mod["package"],
            "scope": mod["scope"],
            "old": installed,
            "new": latest,
        })

print("===== VALHEIM =====")
print(f"Installed Steam build: {current_build}")
print(f"Recorded Steam build:  {old_build}")

print()
print("===== TRACKED PACKAGES =====")

for mod in manifest["mods"]:
    key = (
        mod["namespace"].lower(),
        mod["package"].lower(),
    )

    pkg = lookup.get(key)

    if pkg is None:
        print(
            f'MISSING  {mod["namespace"]}-{mod["package"]}'
        )
        continue

    latest = latest_version(pkg)

    installed = str(
        state.get("mods", {}).get(
            mod["id"],
            mod["current"],
        )
    )

    if latest is None:
        print(
            f'UNKNOWN  {mod["namespace"]}-{mod["package"]}'
        )
    elif semver(latest) > semver(installed):
        print(
            f'UPDATE   {mod["namespace"]}-{mod["package"]}: '
            f'{installed} -> {latest}'
        )
    else:
        print(
            f'OK       {mod["namespace"]}-{mod["package"]}: '
            f'{installed}'
        )

print()
print("===== RESULT =====")

if missing:
    print("Manifest/API resolution failures:")
    for item in missing:
        print(f"  - {item}")

if changes:
    print("Release-triggering changes:")
    for change in changes:
        print(
            f'  - {change["name"] if "name" in change else change["id"]}: '
            f'{change["old"]} -> {change["new"]}'
        )
else:
    print("No release-triggering updates detected.")

result = {
    "valheim_buildid": current_build,
    "changes": changes,
    "missing": missing,
}

print()
print("===== MACHINE RESULT =====")
print(json.dumps(result, indent=2))

# An unresolved package is a hard failure. We never silently stop
# tracking something just because Thunderstore did not resolve it.
if missing:
    sys.exit(2)

# Exit 10 means "updates available".
if changes:
    sys.exit(10)

sys.exit(0)
