#!/usr/bin/env python3
"""Converts the pf2e system's web fonts to TrueType, which iOS and macOS can load.

Converts Roboto, Roboto Condensed and the Pathfinder action glyph font from <pf2e>/static/fonts into
<out> as .ttf files named after the source files.

Requirements: combat-pad R5.1, R5.2, R5.4
"""

import argparse
from pathlib import Path

from fontTools.ttLib import TTFont

FONT_PREFIXES = ("roboto-v", "roboto-condensed-", "pathfinder-2e-actions")


def main() -> None:
    """Converts every wanted font that is missing or older than its source."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fonts", required=True, help="the pf2e system's static/fonts folder")
    parser.add_argument("--out", required=True, help="output folder, such as Generated/Fonts")
    arguments = parser.parse_args()
    out = Path(arguments.out)
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
