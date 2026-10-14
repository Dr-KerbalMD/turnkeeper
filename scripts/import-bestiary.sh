#!/bin/sh
# Imports creatures, conditions and the glossary into Generated/. Creature art isn't imported: the app reads it
# from the user's own PDFs on the device.
#
# PF2E_REPO           the pf2e system repository (default ~/git/pf2e)
# REXARD_PACKS        the folder holding the user's Rexard UI packs, for the cards' art (default ~/git/rexard-packs)
# ARTWORK             the toolkit-artwork checkout, for Paizo's Pathfinder-Icons font (default the Artwork submodule)
set -eu

cd "$(dirname "$0")/.."

PF2E_REPO="${PF2E_REPO:-$HOME/git/pf2e}"
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

echo "Importing the bestiary from $PF2E_REPO..."
swift build -c release --product BestiaryImport
"$(swift build -c release --show-bin-path)/BestiaryImport" --pf2e "$PF2E_REPO" --out Generated --config .
