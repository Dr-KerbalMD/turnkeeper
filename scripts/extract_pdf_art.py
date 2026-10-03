#!/usr/bin/env python3
"""Extracts creature art from Paizo token, pawn and Battle Cards PDFs.

Sources are discovered in the Scrollkeeper downloads folder: any folder whose name contains "Battle Cards",
"Pawn" or "Token Box". Each image is paired with the name printed beside it, saved as webp under
<out>/<collection>/, and listed in <out>/pdf-art-index.json for the Swift importer to match against creatures.

Layouts:
  tokenFrontsBacks  token art on one page, names on the next page, mirrored for duplex printing
  pawnLabelBelow    pawn figures with their name printed under each one
  cardsAlternating  a card's art page followed by its stat page
  cardsBlocks       a run of stat pages followed by the matching run of art pages
  cardsSplitFiles   a FRONT(S) PDF of stat pages and a BACKS PDF of art pages, page by page

Requirements: combat-pad R2.2, R2.3, R2.4, R4.14
"""

import argparse
import json
from pathlib import Path

from pdfart.cards import extract_alternating_cards, extract_block_cards, extract_split_cards
from pdfart.discovery import Source, discover_sources
from pdfart.figures import Found, extract_pawns, extract_tokens


def main() -> None:
    """Extracts every discovered source and writes the index."""
    arguments = parse_arguments()
    config = json.loads(Path(arguments.config).read_text())
    out = Path(arguments.out)
    out.mkdir(parents=True, exist_ok=True)
    entries: list[dict[str, str]] = []
    for source in discover_sources(Path(arguments.files), config):
        print(f"  {source.collection} ({source.layout})", flush=True)
        entries += extract(source, out / source.collection)
    entries.sort(key=lambda entry: (entry["collection"], entry["path"]))
    (out / "pdf-art-index.json").write_text(json.dumps({"entries": entries}, indent=1, sort_keys=True) + "\n")
    print(f"Extracted {len(entries)} images from PDFs.")


def parse_arguments() -> argparse.Namespace:
    """The --files, --out and --config options."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--files", required=True, help="the Scrollkeeper Files folder")
    parser.add_argument("--out", required=True, help="output folder, such as Generated/PdfArt")
    parser.add_argument("--config", required=True, help="art-sources.json")
    return parser.parse_args()


def extract(source: Source, folder: Path) -> list[dict[str, str]]:
    """Extracts one source into folder, removes files earlier runs left behind, and returns index entries."""
    folder.mkdir(parents=True, exist_ok=True)
    found = run_layout(source, folder)
    remove_stale_files(folder, {file_name for _, _, file_name in found})
    return [
        {
            "name": name,
            "collection": source.collection,
            "game": source.game,
            "era": source.era,
            "kind": kind,
            "path": f"PdfArt/{source.collection}/{file_name}",
        }
        for name, kind, file_name in found
    ]


def run_layout(source: Source, folder: Path) -> Found:
    """Calls the extractor for the source's layout."""
    if source.layout == "tokenFrontsBacks":
        return extract_tokens(source.files[0], folder)
    if source.layout == "pawnLabelBelow":
        return extract_pawns(source.files, folder)
    if source.layout == "cardsAlternating":
        return extract_alternating_cards(source.files[0], folder)
    if source.layout == "cardsBlocks":
        return extract_block_cards(source.files[0], folder)
    if source.layout == "cardsSplitFiles":
        return extract_split_cards(source.files[0], source.files[1], folder)
    raise ValueError(f"Extracting {source.collection} failed: unknown layout {source.layout!r}")


def remove_stale_files(folder: Path, current: set[str]) -> None:
    """Deletes images an earlier run wrote that this run no longer produces."""
    for file in folder.glob("*.webp"):
        if file.name not in current:
            file.unlink()


if __name__ == "__main__":
    main()
