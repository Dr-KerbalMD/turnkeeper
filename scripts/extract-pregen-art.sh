#!/bin/sh
# Extracts the Table Buddies' portraits into Resources/Pregens/Art/<key>.png from Paizo's Community Use
# pregen packages: the portrait is the largest image on a pregen PDF's first page, with its transparency mask.
# Characters without a pregen PDF fall back to the Community Use iconics art. Needs poppler and ImageMagick.
#
# PF_PREGENS   folders of Pathfinder pregen PDFs ("Ezren - Level 1 Wizard.pdf", "Pregens-Ezren-Lvl1.pdf")
# SF_PREGENS   the Starfinder 2e pregens folder ("Pregens-Dae-Lvl 1.pdf")
# ICONIC_ART   folders of Community Use iconic art ("Wizard - Ezren.png")
set -eu

cd "$(dirname "$0")/.."
PF_PREGENS="${PF_PREGENS:-$HOME/Documents/Pathfinder/Pregens $HOME/Documents/Pathfinder/CommunityUsePackagePathfinderRemasterIconicsPregeneratedCharacters}"
SF_PREGENS="${SF_PREGENS:-$HOME/Downloads/Starfinder 2E Pregens (CUP28E)}"
ICONIC_ART="${ICONIC_ART:-$HOME/git/community-use-artwork/Community Use Package- Iconics|$HOME/Downloads/Community Use Package- Starfinder Iconic Characters}"
OUT=Resources/Pregens/Art
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

# The portrait from a pregen PDF: the largest image on page 1, with its mask as alpha, at most 600 pixels tall.
portrait() {
    rm -f "$WORK"/img-*
    pdfimages -f 1 -l 1 -png "$1" "$WORK/img"
    largest=$(pdfimages -f 1 -l 1 -list "$1" | awk '$3 == "image" { print $2, $4 * $5 }' | sort -k2 -n -r | head -1 | cut -d ' ' -f 1)
    image=$(printf "%s/img-%03d.png" "$WORK" "$largest")
    mask=$(printf "%s/img-%03d.png" "$WORK" $((largest + 1)))
    if pdfimages -f 1 -l 1 -list "$1" | awk -v n=$((largest + 1)) '$2 == n { print $3 }' | grep -q smask; then
        magick "$image" "$mask" -alpha off -compose CopyOpacity -composite -resize 'x600>' "$2"
    else
        magick "$image" -resize 'x600>' "$2"
    fi
}

for key in $(jq -r '.pregens[] | select(.traits | index("minion") | not) | .key' Resources/Pregens/*-pregens.json | sort -u); do
    name=$(jq -r --arg key "$key" 'first(.pregens[] | select(.key == $key)) | .name' Resources/Pregens/*-pregens.json | head -1)
    compact=$(echo "$name" | tr -d ' -')
    # "Ezren - Level 1 Wizard.pdf" or "Pregens-Chk Chk-Lvl 1.pdf", compared without spaces and dashes.
    pdf=$(find $PF_PREGENS "$SF_PREGENS" -iname "*.pdf" 2>/dev/null | while read -r f; do
        if basename "$f" | tr -d ' -' | grep -qi -E "^(Pregens)?${compact}(Level1|Lvl1)"; then echo "$f"; fi
    done | head -1)
    if [ -n "$pdf" ]; then
        portrait "$pdf" "$OUT/$key.png"
        echo "$key: $(basename "$pdf")"
        continue
    fi
    art=$(echo "$ICONIC_ART" | tr '|' '\n' | while read -r dir; do find "$dir" -iname "* - $name.png" 2>/dev/null; done | head -1)
    if [ -n "$art" ]; then
        magick "$art" -resize 'x600>' "$OUT/$key.png"
        echo "$key: $(basename "$art")"
    else
        echo "$key: no art found" >&2
    fi
done
