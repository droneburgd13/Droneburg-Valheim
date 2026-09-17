#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/mnt/storage/valheim"
REPO="$ROOT/release-repo"
AUTO="$ROOT/automation"
MANIFEST="$REPO/manifests/mods.json"
STATE="$AUTO/state.json"
PLAN="$AUTO/plan.json"

SERVER_PLUGINS="$ROOT/config/bepinex/plugins"
SERVER_CFG="$ROOT/config/bepinex"

CLIENT="$ROOT/staging/client/Droneburg-Valheim-Modpack-v1.1.0"
CLIENT_PLUGINS="$CLIENT/payload/BepInEx/plugins"
CLIENT_CFG="$CLIENT/payload/BepInEx/config"

PACKAGES="$ROOT/packages"
NOTIFY="/home/droneburgd13/scripts/discord_notify.sh"

LOCK="$AUTO/release.lock"
LOG="$AUTO/release.log"

mkdir -p "$AUTO"

exec 9>"$LOCK"

if ! flock -n 9; then
    echo "Another Droneburg Valheim release run is already active."
    exit 0
fi

exec > >(tee -a "$LOG") 2>&1

STAGE="initialization"
BACKUP=""
TMP=""
PUBLISHED=0

fail() {
    RC=$?
    set +e

    echo
    echo "FAILURE during stage: $STAGE"

    if [[ "$PUBLISHED" -eq 0 ]]; then
        if [[ -n "$BACKUP" && -d "$BACKUP" ]]; then
            echo "Restoring server plugin/config snapshot..."

            rm -rf "$SERVER_PLUGINS"
            cp -a "$BACKUP/plugins" "$SERVER_PLUGINS"

            if [[ -d "$BACKUP/config" ]]; then
                cp -a "$BACKUP/config"/. "$SERVER_CFG"/
            fi

            if [[ -s "$BACKUP/client-workspace.tar.gz" ]]; then
                echo "Restoring client workspace..."

                rm -rf "$CLIENT"

                tar -C "$(dirname "$CLIENT")" \
                    -xzf "$BACKUP/client-workspace.tar.gz"
            fi

            cd "$ROOT"
            docker compose up -d --force-recreate || true
        fi

        "$NOTIFY" \
          "❌ **Droneburg Valheim automatic release failed**
Stage: $STAGE
No installer was published.
Check: $LOG" \
          || true
    else
        echo "Release was already published; refusing rollback."

        "$NOTIFY" \
          "⚠️ **Droneburg Valheim release published, but a post-release step failed**
Stage: $STAGE
The published installer remains valid.
Check: $LOG" \
          || true
    fi

    [[ -n "$TMP" ]] && rm -rf "$TMP"

    exit "$RC"
}

trap fail ERR

STAGE="update detection"

set +e
"$REPO/scripts/plan-updates.py"
PLAN_RC=$?
set -e

case "$PLAN_RC" in
    0)
        echo "No Valheim or mod updates detected."
        exit 0
        ;;
    10)
        echo "Release-triggering update detected."
        ;;
    *)
        echo "Update planner failed with code $PLAN_RC."
        exit "$PLAN_RC"
        ;;
esac

echo
echo "===== RELEASE PLAN ====="
cat "$PLAN"

STAGE="version calculation"

OLD_RELEASE="$(jq -r '.release' "$STATE")"

IFS='.' read -r MAJOR MINOR PATCH <<< "$OLD_RELEASE"
NEW_RELEASE="${MAJOR}.${MINOR}.$((PATCH + 1))"

echo "Current release: $OLD_RELEASE"
echo "Next release:    $NEW_RELEASE"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$ROOT/archive/automation-pre-v${NEW_RELEASE}-${STAMP}"
TMP="$(mktemp -d)"

mkdir -p "$BACKUP"

STAGE="snapshot"

cp -a "$SERVER_PLUGINS" "$BACKUP/plugins"

mkdir -p "$BACKUP/config"

for ITEM in \
    kwilson.TillValhalla.cfg \
    muindor.TidyChests.cfg \
    Azumatt.HaulersHelper.cfg \
    dev.crystal.comfortable.cfg \
    blacks7ar.FoodDurationMultiplier.cfg \
    drummercraig.one_map_to_rule_them_all.cfg \
    neobotics.valheim_mod.hudcompass.cfg \
    randyknapp.mods.equipmentandquickslots.cfg \
    TastyChickenLegs.TreesReborn.cfg \
    tommy.valheim.shipspeed.cfg \
    valesthor.hsemanager.cfg \
    shudnal.ConditionalConfigSync
do
    [[ -e "$SERVER_CFG/$ITEM" ]] &&
        cp -a "$SERVER_CFG/$ITEM" "$BACKUP/config/"
done

tar -C "$(dirname "$CLIENT")" \
    -czf "$BACKUP/client-workspace.tar.gz" \
    "$(basename "$CLIENT")"

echo "Snapshot: $BACKUP"

download_and_extract() {
    local ID="$1"
    local URL="$2"
    local VERSION="$3"

    local ZIP="$TMP/${ID}-${VERSION}.zip"
    local OUT="$TMP/${ID}-${VERSION}"

    mkdir -p "$OUT"

    curl -fL \
      --retry 5 \
      --retry-delay 3 \
      --retry-all-errors \
      "$URL" \
      -o "$ZIP"

    unzip -t "$ZIP" >/dev/null
    unzip -q "$ZIP" -d "$OUT"

    printf '%s\n' "$OUT"
}

install_package_tree() {
    local SRC="$1"
    local DST="$2"

    rm -rf "$DST"
    mkdir -p "$DST"

    cp -a "$SRC"/. "$DST"/
}

STAGE="mod downloads and installation"

mapfile -t MOD_CHANGES < <(
    jq -c '.changes[] | select(.type == "mod")' "$PLAN"
)

for CHANGE in "${MOD_CHANGES[@]}"; do
    ID="$(jq -r '.id' <<<"$CHANGE")"
    NEW="$(jq -r '.new' <<<"$CHANGE")"
    URL="$(jq -r '.download_url' <<<"$CHANGE")"
    MODE="$(jq -r '.mode // "normal"' <<<"$CHANGE")"

    echo
    echo "Updating $ID -> $NEW"

    if [[ "$URL" == "null" || -z "$URL" ]]; then
        echo "Missing download URL for $ID"
        exit 1
    fi

    if [[ "$MODE" == "custom_90m" ]]; then
        echo "TidyChests requires custom rebuild; deferring."
        continue
    fi

    SRC="$(download_and_extract "$ID" "$URL" "$NEW")"

    if jq -e --arg id "$ID" \
        '.mods[] | select(.id==$id) | .scope | index("server")' \
        "$MANIFEST" >/dev/null
    then
        SDIR="$(
          jq -r --arg id "$ID" \
          '.mods[] | select(.id==$id) | .server_dir // empty' \
          "$MANIFEST"
        )"

        [[ -n "$SDIR" ]] || {
            echo "Missing server_dir for $ID"
            exit 1
        }

        install_package_tree "$SRC" "$SERVER_PLUGINS/$SDIR"
    fi

    if jq -e --arg id "$ID" \
        '.mods[] | select(.id==$id) | .scope | index("client")' \
        "$MANIFEST" >/dev/null
    then
        MODE="$(
          jq -r --arg id "$ID" \
          '.mods[] | select(.id==$id) | .mode // "normal"' \
          "$MANIFEST"
        )"

        if [[ "$MODE" == "framework" ]]; then
            BASE="$(
                find "$SRC" \
                  -type f \
                  -path '*/BepInEx/core/BepInEx.dll' \
                  -printf '%h\n' \
                  -quit
            )"

            [[ -n "$BASE" ]] || {
                echo "Unable to locate BepInEx framework root"
                exit 1
            }

            BASE="$(dirname "$(dirname "$BASE")")"

            cp -a "$BASE"/. "$CLIENT/payload/"
        else
            CDIR="$(
              jq -r --arg id "$ID" \
              '.mods[] | select(.id==$id) | .client_dir // empty' \
              "$MANIFEST"
            )"

            [[ -n "$CDIR" ]] || {
                echo "Missing client_dir for $ID"
                exit 1
            }

            install_package_tree "$SRC" "$CLIENT_PLUGINS/$CDIR"
        fi
    fi
done

if jq -e \
    '.changes[] | select(.type=="mod" and .id=="TidyChests")' \
    "$PLAN" >/dev/null
then
    STAGE="TidyChests custom rebuild"

    TIDYVER="$(
      jq -r \
      '.changes[] | select(.type=="mod" and .id=="TidyChests") | .new' \
      "$PLAN"
    )"

    SRC="$TMP/ValheimMods"

    git clone --depth 1 \
      https://github.com/egor-muindor/ValheimMods.git \
      "$SRC"

    CFGSRC="$SRC/TidyChests/ModConfig.cs"
    CSPROJ="$SRC/TidyChests/TidyChests.csproj"

    test -s "$CFGSRC"
    test -s "$CSPROJ"

    python3 - "$CFGSRC" "$CSPROJ" "$TIDYVER" <<'PY'
from pathlib import Path
import re
import sys

cfg = Path(sys.argv[1])
proj = Path(sys.argv[2])
version = sys.argv[3]

s = cfg.read_text()

pattern = r'new AcceptableValueRange<float>\(1f,\s*\d+(?:\.\d+)?f?\)'

matches = list(re.finditer(pattern, s))

if not matches:
    raise SystemExit("Could not locate TidyChests radius cap")

s = re.sub(
    pattern,
    "new AcceptableValueRange<float>(1f, 90f)",
    s,
    count=1,
)

cfg.write_text(s)

p = proj.read_text()

p, count = re.subn(
    r'<Version>[^<]+</Version>',
    f'<Version>{version}</Version>',
    p,
    count=1,
)

if count != 1:
    raise SystemExit("Could not patch TidyChests project version")

proj.write_text(p)
PY

    cd "$SRC"

    VALHEIM_MANAGED_DIR="$ROOT/data/server/valheim_server_Data/Managed/" \
      dotnet build \
      TidyChests/TidyChests.csproj \
      -c Release

    DLL="$SRC/TidyChests/bin/Release/TidyChests.dll"
    test -s "$DLL"

    rm -rf \
      "$SERVER_PLUGINS/TidyChests" \
      "$CLIENT_PLUGINS/TidyChests"

    mkdir -p \
      "$SERVER_PLUGINS/TidyChests" \
      "$CLIENT_PLUGINS/TidyChests"

    cp -a "$DLL" "$SERVER_PLUGINS/TidyChests/TidyChests.dll"
    cp -a "$DLL" "$CLIENT_PLUGINS/TidyChests/TidyChests.dll"
fi

STAGE="Droneburg policy enforcement"

TILL="$SERVER_CFG/kwilson.TillValhalla.cfg"
TIDY="$SERVER_CFG/muindor.TidyChests.cfg"
HAUL="$SERVER_CFG/Azumatt.HaulersHelper.cfg"

sed -i \
  -e 's/^needgrowspace = .*/needgrowspace = false/' \
  -e 's/^needcultivatedground = .*/needcultivatedground = false/' \
  -e 's/^craftingroofrequired = .*/craftingroofrequired = false/' \
  "$TILL"

sed -i \
  -e 's/^Radius = .*/Radius = 90/' \
  -e 's/^ScanRadius = .*/ScanRadius = 90/' \
  "$TIDY"

# Only alter the Cart section's first pair.
python3 - "$HAUL" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
lines = p.read_text().splitlines()

section = None
done_base = False
done_factor = False

out = []

for line in lines:
    if line.startswith("[") and line.endswith("]"):
        section = line

    if section == "[2 - Cart]":
        if line.startswith("Base Mass =") and not done_base:
            line = "Base Mass = 50"
            done_base = True

        if line.startswith("Item Weight Mass Factor =") and not done_factor:
            line = "Item Weight Mass Factor = 0.1"
            done_factor = True

    out.append(line)

if not done_base or not done_factor:
    raise SystemExit("Could not enforce Cart mass settings")

p.write_text("\n".join(out) + "\n")
PY

find "$SERVER_PLUGINS/TillValhalla" \
  -type f \
  -iname 'Splash_WaterEmerge01.wav' \
  -delete

STAGE="server restart"

cd "$ROOT"
docker compose up -d --force-recreate

sleep 60

STAGE="server validation"

LOGS="$TMP/server-startup.log"

docker logs --since 3m valheim >"$LOGS" 2>&1

grep -q 'Chainloader startup complete' "$LOGS"
grep -q '13 plugins to load' "$LOGS"

if grep -Ei \
    '\[Error[[:space:]]*:|Unhandled exception|Chainloader.*failed|Could not load.*plugin' \
    "$LOGS"
then
    echo "Server startup contains fatal-looking errors."
    exit 1
fi

REQUIRED_SERVER=(
  Comfortable/Comfortable.dll
  ConditionalConfigSync/ConditionalConfigSync.dll
  ConditionalConfigSync/ConditionalConfigSync.Plugin.dll
  EquipmentAndQuickSlots/EquipmentAndQuickSlots.dll
  FoodDurationMultiplier/FoodDurationMultiplier.dll
  HaulersHelper/HaulersHelper.dll
  HealthStaminaEitrManager/HSEManager.dll
  HUDCompass/HUDCompass.dll
  Jotunn/Jotunn.dll
  OneMapToRuleThemAll/OneMapToRuleThemAll.dll
  TidyChests/TidyChests.dll
  TillValhalla/TillValhalla.dll
  TommysShipSpeed/TommysShipSpeed.dll
  TreesReborn/TreesReborn.dll
)

for F in "${REQUIRED_SERVER[@]}"; do
    test -s "$SERVER_PLUGINS/$F"
done

grep -q '^Radius = 90$' "$TIDY"
grep -q '^ScanRadius = 90$' "$TIDY"
grep -q '^needgrowspace = false$' "$TILL"
grep -q '^needcultivatedground = false$' "$TILL"

echo "Server validation passed."

STAGE="client synchronization"

for DIR in \
  Comfortable \
  ConditionalConfigSync \
  EquipmentAndQuickSlots \
  FoodDurationMultiplier \
  HaulersHelper \
  HealthStaminaEitrManager \
  HUDCompass \
  Jotunn \
  OneMapToRuleThemAll \
  TidyChests \
  TillValhalla \
  TommysShipSpeed \
  TreesReborn
do
    rm -rf "$CLIENT_PLUGINS/$DIR"
    cp -a "$SERVER_PLUGINS/$DIR" "$CLIENT_PLUGINS/$DIR"
done

for CFG in \
  dev.crystal.comfortable.cfg \
  blacks7ar.FoodDurationMultiplier.cfg \
  drummercraig.one_map_to_rule_them_all.cfg \
  kwilson.TillValhalla.cfg \
  muindor.TidyChests.cfg \
  neobotics.valheim_mod.hudcompass.cfg \
  randyknapp.mods.equipmentandquickslots.cfg \
  TastyChickenLegs.TreesReborn.cfg \
  tommy.valheim.shipspeed.cfg \
  valesthor.hsemanager.cfg \
  Azumatt.HaulersHelper.cfg
do
    [[ -e "$SERVER_CFG/$CFG" ]] &&
      cp -a "$SERVER_CFG/$CFG" "$CLIENT_CFG/$CFG"
done

rm -rf "$CLIENT_CFG/shudnal.ConditionalConfigSync"
cp -a \
  "$SERVER_CFG/shudnal.ConditionalConfigSync" \
  "$CLIENT_CFG/shudnal.ConditionalConfigSync"

find "$CLIENT_PLUGINS/TillValhalla" \
  -type f \
  -iname 'Splash_WaterEmerge01.wav' \
  -delete

STAGE="installer versioning"

NSI="$CLIENT/Droneburg-Valheim-Modpack.nsi"

python3 - "$NSI" "$NEW_RELEASE" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
version = sys.argv[2]
s = p.read_text()

s, n = re.subn(
    r'OutFile\s+"[^"]*Droneburg-Valheim-Modpack-v[0-9.]+\.exe"',
    f'OutFile "../../../packages/Droneburg-Valheim-Modpack-v{version}.exe"',
    s,
    count=1,
)

if n != 1:
    raise SystemExit("Could not update NSIS OutFile")

s = re.sub(
    r'Droneburg Valheim Modpack v[0-9.]+ installed\.',
    f'Droneburg Valheim Modpack v{version} installed.',
    s,
)

p.write_text(s)
PY

CURRENT_BUILD="$(jq -r '.valheim_buildid' "$PLAN")"

cat > "$CLIENT/payload/DRONEBURG-MODPACK.txt" <<INFO
Droneburg Valheim Modpack
Version: $NEW_RELEASE
Built: $(date +%F)

Valheim Steam Build: $CURRENT_BUILD

TidyChests stash/find radius: 90m
TidyChests browser scan radius: 90m
Cart cargo weight factor: 0.1
Plant grow-space restriction: disabled
Cultivated-ground requirement: disabled
Splash_WaterEmerge01.wav: removed
INFO

{
    echo "Droneburg Valheim Modpack v$NEW_RELEASE"
    echo "$(date +%F)"
    echo
    echo "Automated update:"
    jq -r '
      .changes[] |
      if .type=="valheim"
      then "- Valheim build: \(.old) -> \(.new)"
      else "- \(.id): \(.old) -> \(.new)"
      end
    ' "$PLAN"
} > "$CLIENT/payload/changelog.txt"

STAGE="installer build"

INSTALLER="$PACKAGES/Droneburg-Valheim-Modpack-v${NEW_RELEASE}.exe"

rm -f "$INSTALLER" "$INSTALLER.sha256"

cd "$CLIENT"
makensis Droneburg-Valheim-Modpack.nsi

test -s "$INSTALLER"

sha256sum "$INSTALLER" >"$INSTALLER.sha256"

if find "$CLIENT_PLUGINS/TillValhalla" \
    -type f \
    -iname 'Splash_WaterEmerge01*' |
    grep -q .
then
    echo "Client payload contains forbidden water audio."
    exit 1
fi

STAGE="state preparation"

python3 - "$STATE" "$PLAN" "$NEW_RELEASE" "$MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

state_path = Path(sys.argv[1])
plan_path = Path(sys.argv[2])
release = sys.argv[3]
manifest_path = Path(sys.argv[4])

state = json.loads(state_path.read_text())
plan = json.loads(plan_path.read_text())
manifest = json.loads(manifest_path.read_text())

state["release"] = release
state["valheim_buildid"] = plan["valheim_buildid"]

for change in plan["changes"]:
    if change["type"] == "mod":
        state["mods"][change["id"]] = change["new"]

for mod in manifest["mods"]:
    if mod["id"] in state["mods"]:
        mod["current"] = state["mods"][mod["id"]]

Path(str(state_path) + ".next").write_text(
    json.dumps(state, indent=2) + "\n"
)

Path(str(manifest_path) + ".next").write_text(
    json.dumps(manifest, indent=2) + "\n"
)
PY

STAGE="GitHub source commit"

cp -a "$NSI" \
  "$REPO/installer/Droneburg-Valheim-Modpack.nsi"

cp -a "$CLIENT/payload/DRONEBURG-MODPACK.txt" \
  "$REPO/docs/DRONEBURG-MODPACK.txt"

cp -a "$CLIENT/payload/changelog.txt" \
  "$REPO/docs/CHANGELOG-v${NEW_RELEASE}.txt"

cp -a "$MANIFEST.next" "$MANIFEST"

cat > "$REPO/manifests/release.json" <<JSON
{
  "product": "Droneburg Valheim Modpack",
  "release": "$NEW_RELEASE",
  "valheim_buildid": "$CURRENT_BUILD",
  "status": "released",
  "released": "$(date +%F)",
  "tidychests_radius_m": 90,
  "tidychests_scan_radius_m": 90,
  "cart_item_weight_factor": 0.1,
  "installer": "Droneburg-Valheim-Modpack-v${NEW_RELEASE}.exe"
}
JSON

cd "$REPO"

git add \
  manifests/mods.json \
  manifests/release.json \
  installer/Droneburg-Valheim-Modpack.nsi \
  docs/DRONEBURG-MODPACK.txt \
  "docs/CHANGELOG-v${NEW_RELEASE}.txt"

if ! git diff --cached --quiet; then
    git commit -m "Release Droneburg Valheim Modpack v${NEW_RELEASE}"
    git push
else
    echo "Release source already committed; continuing."
fi

if git rev-parse "v${NEW_RELEASE}" >/dev/null 2>&1; then
    echo "Local tag v${NEW_RELEASE} already exists."
else
    git tag -a "v${NEW_RELEASE}" \
      -m "Droneburg Valheim Modpack v${NEW_RELEASE}"
fi

if git ls-remote --exit-code --tags origin \
    "refs/tags/v${NEW_RELEASE}" >/dev/null 2>&1
then
    echo "Remote tag v${NEW_RELEASE} already exists."
else
    git push origin "v${NEW_RELEASE}"
fi

STAGE="GitHub release"

RELEASE_NOTES="$TMP/release-notes.md"

{
    echo "# Droneburg Valheim Modpack v${NEW_RELEASE}"
    echo
    echo "Automated update release."
    echo
    echo "## Changes"
    echo
    jq -r '
      .changes[] |
      if .type=="valheim"
      then "- Valheim build: `\(.old)` → `\(.new)`"
      else "- \(.id): `\(.old)` → `\(.new)`"
      end
    ' "$PLAN"
    echo
    echo "TidyChests remains locked to 90 m."
    echo
    echo "Existing Droneburg gameplay policy was reapplied and validated."
} >"$RELEASE_NOTES"

if gh release view "v${NEW_RELEASE}" \
    --repo droneburgd13/Droneburg-Valheim >/dev/null 2>&1
then
    echo "GitHub release v${NEW_RELEASE} already exists; reusing it."
else
    gh release create "v${NEW_RELEASE}" \
      "$INSTALLER" \
      "$INSTALLER.sha256" \
      --repo droneburgd13/Droneburg-Valheim \
      --title "Droneburg Valheim Modpack v${NEW_RELEASE}" \
      --notes-file "$RELEASE_NOTES" \
      --latest \
      --verify-tag
fi

PUBLISHED=1

STAGE="state finalization"

mv "$STATE.next" "$STATE"
rm -f "$MANIFEST.next"

RELEASE_URL="$(
  gh release view "v${NEW_RELEASE}" \
    --repo droneburgd13/Droneburg-Valheim \
    --json url \
    --jq '.url'
)"

STAGE="Discord notification"

CHANGE_TEXT="$(
  jq -r '
    .changes[] |
    if .type=="valheim"
    then "• Valheim: \(.old) → \(.new)"
    else "• \(.id): \(.old) → \(.new)"
    end
  ' "$PLAN"
)"

set +e

"$NOTIFY" \
"🛡️ **Droneburg Valheim Modpack v${NEW_RELEASE} is live**

$CHANGE_TEXT

Server validation passed before publication.

Download:
$RELEASE_URL"

NOTIFY_RC=$?

set -e

if [[ "$NOTIFY_RC" -ne 0 ]]; then
    echo "WARNING: release succeeded but Discord notification failed."
else
    echo "Discord release notification sent."
fi

rm -rf "$TMP"
TMP=""

echo
echo "========================================"
echo "   RELEASE v${NEW_RELEASE} COMPLETE"
echo "========================================"

trap - ERR
