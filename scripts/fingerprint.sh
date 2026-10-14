#!/bin/sh
# Prints a SHA-256 fingerprint of the imported bestiary (Generated/Bestiary), which "make bestiary" keeps in
# import.sha256. The weekly pf2e update releases only when a new pf2e release changes it. Fonts and pictures
# are left out: their bytes can differ with the tools' versions while showing the same.
set -eu

cd "$(dirname "$0")/../Generated"
find Bestiary -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 | shasum -a 256 | cut -d ' ' -f 1
