#!/usr/bin/env python3

import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path("/mnt/storage/valheim")
REPO = ROOT / "release-repo"
MANIFEST = REPO / "manifests" / "mods.json"
STATE = ROOT / "automation" / "state.json"
PLAN = ROOT / "automation" / "plan.json"

API = "https://thunderstore.io/c/valheim/api/v1/package/"

APP_MANIFESTS = [
    ROOT / "data/server/steamapps/appmanifest_896660.acf",
    ROOT / "data/dl/server/steamapps/appmanifest_896660.acf",
]

def semver(v):
    nums = [int(x) for x in re.findall(r"\d+", str(v))[:3]]
    while len(nums) < 3:
        nums.append(0)
    return tuple(nums)

def buildid():
    for path in APP_MANIFESTS:
        if not path.exists():
            continue

        text = path.read_text(errors="replace")
        m = re.search(r'"buildid"\s+"([^"]+)"', text)

        if m:
            return m.group(1)

    raise RuntimeError("Could not determine Valheim buildid")

def fetch():
    req = urllib.request.Request(
        API,
        headers={"User-Agent": "Droneburg-Valheim-Automation/1.0"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

manifest = json.loads(MANIFEST.read_text())
state = json.loads(STATE.read_text())
packages = fetch()

lookup = {}

for pkg in packages:
    ns = (
        pkg.get("owner")
        or pkg.get("namespace")
        or pkg.get("namespace_name")
    )
    name = pkg.get("name")

    if ns and name:
        lookup[(ns.lower(), name.lower())] = pkg

changes = []
missing = []

current_build = buildid()
recorded_build = str(state["valheim_buildid"])

if current_build != recorded_build:
    changes.append({
        "type": "valheim",
        "id": "Valheim",
        "old": recorded_build,
        "new": current_build,
    })

for mod in manifest["mods"]:
    key = (mod["namespace"].lower(), mod["package"].lower())
    pkg = lookup.get(key)

    if not pkg:
        missing.append(f'{mod["namespace"]}-{mod["package"]}')
        continue

    versions = pkg.get("versions") or []

    if not versions:
        missing.append(f'{mod["namespace"]}-{mod["package"]} (no versions)')
        continue

    latest_obj = max(
        versions,
        key=lambda x: semver(x.get("version_number", "0")),
    )

    latest = latest_obj["version_number"]
    old = state["mods"].get(mod["id"], mod["current"])

    if semver(latest) > semver(old):
        changes.append({
            "type": "mod",
            "id": mod["id"],
            "namespace": mod["namespace"],
            "package": mod["package"],
            "old": old,
            "new": latest,
            "scope": mod["scope"],
            "mode": mod.get("mode", "normal"),
            "server_dir": mod.get("server_dir"),
            "client_dir": mod.get("client_dir"),
            "download_url": latest_obj.get("download_url"),
        })

result = {
    "valheim_buildid": current_build,
    "previous_release": state["release"],
    "changes": changes,
    "missing": missing,
}

PLAN.write_text(json.dumps(result, indent=2) + "\n")

print(json.dumps(result, indent=2))

if missing:
    sys.exit(2)

if changes:
    sys.exit(10)

sys.exit(0)
