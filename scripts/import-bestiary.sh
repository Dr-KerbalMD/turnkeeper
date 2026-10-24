#!/bin/sh
# Imports creatures, conditions and the glossary into Generated/. Creature art isn't imported: the app reads it
# from the user's own PDFs on the device.
#
# PF2E_REPO           a pf2e system repository to read instead of the release in pf2e.release, which is
#                     fetched into build/pf2e (scripts/fetch-pf2e.sh); release builds always use that release
# REXARD_PACKS        the folder holding the user's Rexard UI packs, for the cards' art (default ~/git/rexard-packs)
# ARTWORK             the toolkit-artwork checkout, for Paizo's Pathfinder-Icons font (default the Artwork submodule)
set -eu

cd "$(dirname "$0")/.."

if [ -z "${PF2E_REPO:-}" ]; then
    scripts/fetch-pf2e.sh build/pf2e
    PF2E_REPO=build/pf2e
else
    echo "Reading $PF2E_REPO; release builds read $(cut -d ' ' -f 2- pf2e.release) instead." >&2
fi
REXARD_PACKS="${REXARD_PACKS:-$HOME/git/rexard-packs}"
ARTWORK="${ARTWORK:-Artwork}"

if [ ! -x .venv/bin/python ] || ! .venv/bin/python -c "import fontTools, brotli" 2>/dev/null; then
    python3 -m venv .venv
    .venv/bin/pip install --quiet -r requirements.txt
fi

mkdir -p Generated
# Art from earlier imports, which the app no longer bundles.
rm -rf Generated/Art Generated/PdfArt Generated/CardBacks

echo "Copying the cards' art from $REXARD_PACKS..."
swift run -c release CardArtImport "$REXARD_PACKS" Generated/CardArt

echo "Converting fonts..."
.venv/bin/python scripts/convert_fonts.py --fonts "$PF2E_REPO/static/fonts" --out Generated/Fonts
# The action icons, copied unaltered as the Paizo Compatibility License requires; the pf2e font they replace goes.
rm -f Generated/Fonts/pathfinder-2e-actions.ttf
if [ -f "$ARTWORK/pathfinder-icons/Pathfinder-Icons.ttf" ]; then
    cp "$ARTWORK/pathfinder-icons/Pathfinder-Icons.ttf" Generated/Fonts/
else
    echo "Warning: $ARTWORK has no Pathfinder-Icons font (git submodule update --init); cards show stand-in symbols." >&2
fi

echo "Rendering condition icons..."
# The game-icons.net SVGs in Resources/ConditionIcons; the pf2e icons from earlier imports go.
rm -rf Generated/Conditions
mkdir -p Generated/Conditions
for icon in Resources/ConditionIcons/*.svg; do
    sips --setProperty format png --resampleHeightWidthMax 128 "$icon" \
        --out "Generated/Conditions/$(basename "$icon" .svg).png" >/dev/null
done

echo "Copying the licenses the bundled content requires..."
# The About screen lists every file here (Tabletop Kit's LicenseText.all(in:)), titled by its name.
rm -rf Generated/Licenses
mkdir -p Generated/Licenses
cp Resources/Licenses/* Generated/Licenses/
cp "$PF2E_REPO/static/licenses/OpenGameLicense.md" "Generated/Licenses/Open Game License.md"
cp "$PF2E_REPO/static/licenses/ORCLicense.md" "Generated/Licenses/ORC License.md"
cp Resources/ConditionIcons/CREDITS.md "Generated/Licenses/Condition Icons.md"

echo "Copying the Table Buddies' pregens..."
# Exported from Foundry by scripts/foundry/export-pregens.js, since only a running world works out their numbers.
rm -rf Generated/Pregens
mkdir -p Generated/Pregens
cp Resources/Pregens/*-pregens.json Generated/Pregens/
# Their portraits, from Paizo's Community Use Package (scripts/extract-pregen-art.sh).
cp -R Resources/Pregens/Art Generated/Pregens/Art

echo "Importing the bestiary from $PF2E_REPO..."
swift build -c release --product BestiaryImport
"$(swift build -c release --show-bin-path)/BestiaryImport" --pf2e "$PF2E_REPO" --out Generated --config .
# The weekly pf2e update compares this to decide whether a new pf2e release changes anything Turnkeeper shows.
scripts/fingerprint.sh > import.sha256
