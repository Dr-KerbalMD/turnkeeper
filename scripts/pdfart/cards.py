"""Renders Battle Card backs (the art side) and names them from their stat pages.

Requirements: combat-pad R4.14
"""

import io
import re
from pathlib import Path

import pymupdf
from PIL import Image

from pdfart.discovery import page_pattern
from pdfart.figures import Found
from pdfart.naming import card_title, slug

CARD_DPI = 160
TITLE_LINE_TOLERANCE = 4


def extract_alternating_cards(pdf: str, folder: Path) -> Found:
    """Decks where each card's art page comes just before its stat page."""
    with pymupdf.open(pdf) as document:
        pairs = []
        for number in range(len(document) - 1):
            art, stats = document[number], document[number + 1]
            if not art.get_text("words") and stats.get_text("words"):
                pairs.append((art, stats))
        return save_cards(pairs, folder, Path(pdf))


def extract_block_cards(pdf: str, folder: Path) -> Found:
    """Decks with runs of stat pages, each followed by a run of the matching art pages."""
    with pymupdf.open(pdf) as document:
        pairs = []
        for texts, images in block_pairs(page_pattern(document)):
            pairs.append((document[images], document[texts]))
        return save_cards(pairs, folder, Path(pdf))


def block_pairs(pattern: str) -> list[tuple[int, int]]:
    """(stat page, art page) index pairs for a pattern like "TTTIII", matched by position in each run."""
    pairs = []
    for match in re.finditer(r"(T+)(I+)", pattern):
        texts, images = match.span(1), match.span(2)
        count = min(texts[1] - texts[0], images[1] - images[0])
        pairs += [(texts[0] + offset, images[0] + offset) for offset in range(count)]
    return pairs


def extract_split_cards(fronts_pdf: str, backs_pdf: str, folder: Path) -> Found:
    """Decks printed as a FRONTS PDF of stat pages and a BACKS PDF of art pages, matched page by page."""
    with pymupdf.open(fronts_pdf) as fronts, pymupdf.open(backs_pdf) as backs:
        pairs = [(backs[number], fronts[number]) for number in range(min(len(fronts), len(backs)))]
        return save_cards(pairs, folder, Path(backs_pdf))


def save_cards(pairs: list[tuple[pymupdf.Page, pymupdf.Page]], folder: Path, art_pdf: Path) -> Found:
    """Renders each (art page, stat page) pair's art page, named by the stat page's title.

    Cards rendered by an earlier run from an unchanged PDF are reused, since rendering is slow.
    """
    found: Found = []
    used: set[str] = set()
    for art, stats in pairs:
        name = card_title(top_line(stats))
        if not name or name in used:
            continue
        used.add(name)
        output = folder / f"{slug(name)}.webp"
        if not is_current(output, art_pdf):
            pixmap = art.get_pixmap(dpi=CARD_DPI)
            Image.open(io.BytesIO(pixmap.tobytes("png"))).save(output, "WEBP", quality=82)
        found.append((name, "cardBack", output.name))
    return found


def top_line(page: pymupdf.Page) -> str:
    """The words of a page's first line of text, left to right."""
    words = page.get_text("words")
    if not words:
        return ""
    top = min(word[1] for word in words)
    line = sorted((word for word in words if abs(word[1] - top) < TITLE_LINE_TOLERANCE), key=lambda word: word[0])
    return " ".join(word[4] for word in line)


def is_current(output: Path, pdf: Path) -> bool:
    """Whether output was written after the PDF last changed."""
    return output.exists() and output.stat().st_mtime >= pdf.stat().st_mtime
