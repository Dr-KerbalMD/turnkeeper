#!/bin/sh
# Imports creatures, conditions and art into Generated/.
#
# PF2E_REPO           the pf2e system repository (default ~/git/pf2e)
# FOUNDRY_MODULES     the Foundry modules folder holding the token art modules
# SCROLLKEEPER_FILES  the folder of Paizo downloads holding token, pawn and Battle Cards PDFs
set -eu

cd "$(dirname "$0")/.."

PF2E_REPO="${PF2E_REPO:-$HOME/git/pf2e}"
FOUNDRY_MODULES="${FOUNDRY_MODULES:-$HOME/Library/Application Support/FoundryVTT/Data/modules}"
SCROLLKEEPER_FILES="${SCROLLKEEPER_FILES:-$HOME/Library/Application Support/Scrollkeeper/Files}"

if [ ! -x .venv/bin/python ]; then
    python3 -m venv .venv
    .venv/bin/pip install --quiet -r requirements.txt
fi

mkdir -p Generated
if [ -d "$SCROLLKEEPER_FILES" ]; then
    echo "Extracting art from the Paizo PDFs..."
    .venv/bin/python scripts/extract_pdf_art.py --files "$SCROLLKEEPER_FILES" --out Generated/PdfArt \
        --config art-sources.json
else
    echo "Skipping PDF art: $SCROLLKEEPER_FILES does not exist."
fi

echo "Importing the bestiary from $PF2E_REPO..."
swift build -c release --product BestiaryImport
"$(swift build -c release --show-bin-path)/BestiaryImport" --pf2e "$PF2E_REPO" --modules "$FOUNDRY_MODULES" \
    --out Generated --config .
