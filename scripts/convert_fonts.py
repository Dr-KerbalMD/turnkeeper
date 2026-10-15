#!/usr/bin/env python3
"""Converts the pf2e system's web fonts to TrueType, which iOS and macOS can load.

Converts Roboto and Roboto Condensed from <pf2e>/static/fonts into <out>, a folder inside the repository, as
.ttf files named after the source files. The action icons' Pathfinder-Icons font is already TrueType, and its
license forbids altering it, so import-bestiary.sh copies it as it is.

Requirements: turnkeeper R5.1, R5.2, R5.4
"""

import argparse
from pathlib import Path

from fontTools.ttLib import TTFont

FONT_PREFIXES = ("roboto-v", "roboto-condensed-")
REPOSITORY = Path(__file__).resolve().parent.parent


def main() -> None:
    """Converts every wanted font that is missing or older than its source."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fonts", required=True, help="the pf2e system's static/fonts folder")
    parser.add_argument("--out", required=True, help="output folder, such as Generated/Fonts")
    arguments = parser.parse_args()
    out = Path(arguments.out).resolve()
    if not out.is_relative_to(REPOSITORY):
        parser.error(f"--out must be inside the repository ({REPOSITORY}), not {out}")
    out.mkdir(parents=True, exist_ok=True)
    converted = [convert(source, out) for source in wanted_fonts(Path(arguments.fonts))]
    print(f"Fonts ready: {len(converted)}.")


def wanted_fonts(folder: Path) -> list[Path]:
    """The woff2 files for the fonts the battle cards use."""
    return sorted(path for path in folder.glob("*.woff2") if path.name.startswith(FONT_PREFIXES))


def convert(source: Path, out: Path) -> Path:
    """Writes source as TrueType into out, unless an up-to-date copy is already there."""
    target = out / f"{source.stem}.ttf"
    if not target.exists() or target.stat().st_mtime < source.stat().st_mtime:
        font = TTFont(source)
        font.flavor = None
        font.save(target)
    return target


if __name__ == "__main__":
    main()
