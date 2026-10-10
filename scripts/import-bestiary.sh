#!/bin/sh
# Imports creatures, conditions and the glossary into Generated/. Creature art isn't imported: the app reads it
# from the user's own PDFs on the device.
#
# PF2E_REPO           the pf2e system repository (default ~/git/pf2e)
# REXARD_PACKS        the folder holding the user's Rexard UI packs, for the cards' art (default ~/Downloads)
set -eu

cd "$(dirname "$0")/.."

PF2E_REPO="${PF2E_REPO:-$HOME/git/pf2e}"
REXARD_PACKS="${REXARD_PACKS:-$HOME/Downloads}"

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

echo "Copying condition icons..."
mkdir -p Generated/Conditions
cp "$PF2E_REPO"/static/icons/conditions/*.webp Generated/Conditions/

echo "Importing the bestiary from $PF2E_REPO..."
swift build -c release --product BestiaryImport
"$(swift build -c release --show-bin-path)/BestiaryImport" --pf2e "$PF2E_REPO" --out Generated --config .
