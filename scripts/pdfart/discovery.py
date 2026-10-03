"""Finds the art PDFs in the Scrollkeeper downloads folder and works out their layout.

Requirements: combat-pad R2.2, R2.3, R4.14
"""

import re
from dataclasses import dataclass, field
from pathlib import Path

import pymupdf

from pdfart.naming import slug

LAYOUTS = ("tokenFrontsBacks", "pawnLabelBelow", "cardsAlternating", "cardsBlocks", "cardsSplitFiles")


@dataclass
class Source:
    """One collection of art PDFs, such as a Battle Cards deck or a pawn box."""

    collection: str
    game: str
    era: str
    layout: str = ""
    files: list[str] = field(default_factory=list)


def discover_sources(files: Path, config: dict) -> list[Source]:
    """Every token, pawn and Battle Cards folder, in name order, with overrides from the config applied.

    Args:
        files: The Scrollkeeper Files folder.
        config: art-sources.json, for "remasterPdfKeywords" and "pdfOverrides".
    """
    overrides = config.get("pdfOverrides", {})
    keywords = config.get("remasterPdfKeywords", [])
    sources = []
    for folder in sorted(path for path in files.iterdir() if path.is_dir()):
        override = overrides.get(folder.name, {})
        source = describe_folder(folder, keywords)
        if source and not override.get("skip"):
            for key, value in override.items():
                setattr(source, key, value)
            sources.append(source)
    return sources


def describe_folder(folder: Path, remaster_keywords: list[str]) -> Source | None:
    """The source a folder holds, or None when it holds no art PDFs."""
    pdfs = sorted(folder.rglob("*.pdf"))
    kind = folder_kind(folder.name)
    if not pdfs or not kind:
        return None
    source = Source(
        collection=slug(folder.name),
        game="sf2e" if folder.name.startswith("Starfinder") else "pf2e",
        era="remaster" if any(word in folder.name for word in remaster_keywords) else "legacy",
    )
    if kind == "token":
        source.layout, source.files = "tokenFrontsBacks", [str(pdfs[0])]
    elif kind == "pawn":
        source.layout, source.files = "pawnLabelBelow", [str(pdf) for pdf in pdfs]
    else:
        source.layout, source.files = card_layout(pdfs)
    return source


def folder_kind(name: str) -> str:
    """Classifies a folder as "token", "pawn" or "cards", or "" when it holds no art."""
    if "Token Box" in name:
        return "token"
    if "Pawn" in name:
        return "pawn"
    return "cards" if "Battle Cards" in name or "Deck" in name else ""


def card_layout(pdfs: list[Path]) -> tuple[str, list[str]]:
    """The layout of a Battle Cards deck and the files to read, fronts first for split decks."""
    fronts = [pdf for pdf in pdfs if re.search(r"FRONTS?\b", pdf.name, re.IGNORECASE)]
    backs = [pdf for pdf in pdfs if re.search(r"BACKS?\b", pdf.name, re.IGNORECASE)]
    if fronts and backs:
        return "cardsSplitFiles", [str(fronts[0]), str(backs[0])]
    with pymupdf.open(pdfs[0]) as document:
        pattern = page_pattern(document)
    return layout_for_pattern(pattern), [str(pdfs[0])]


def page_pattern(document: pymupdf.Document) -> str:
    """One letter per page: "T" for a page with text (a stat page), "I" for an art-only page."""
    return "".join("T" if page.get_text("words") else "I" for page in document)


def layout_for_pattern(pattern: str) -> str:
    """Alternating art and stat pages, or runs of stat pages followed by runs of art pages."""
    return "cardsAlternating" if pattern.count("IT") > len(pattern) / 3 else "cardsBlocks"
