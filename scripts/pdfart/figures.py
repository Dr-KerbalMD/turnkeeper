"""Extracts token and pawn art, naming each image from the label printed beside it.

Requirements: combat-pad R2.3
"""

import io
from pathlib import Path

import pymupdf
from PIL import Image

from pdfart.naming import clean_name, label_text, slug

LARGE_TOKEN = 150
MIN_ART_WIDTH = 40
# (name, kind, file name) for each saved image.
Found = list[tuple[str, str, str]]


def extract_tokens(pdf: str, folder: Path) -> Found:
    """Token art from even pages, named from the following page, which is mirrored for duplex printing."""
    found: Found = []
    with pymupdf.open(pdf) as document:
        saved: set[int] = set()
        for front_number in range(1, len(document) - 1, 2):
            front, back = document[front_number], document[front_number + 1]
            for image in art_images(front):
                area = mirrored_label_area(pymupdf.Rect(image["bbox"]), front.rect.width)
                name = clean_name(label_text(words_inside(back, area)))
                found += save_image(document, image["xref"], (name, "token"), folder, saved)
    return found


def mirrored_label_area(bbox: pymupdf.Rect, page_width: float) -> pymupdf.Rect:
    """Where a token's name sits on the back page.

    Big circles' bounding squares overlap the labels of their small neighbors, so only their middle is used.
    """
    area = pymupdf.Rect(page_width - bbox.x1, bbox.y0, page_width - bbox.x0, bbox.y1)
    if area.width > LARGE_TOKEN:
        inset = area.width * 0.2
        area = pymupdf.Rect(area.x0 + inset, area.y0 + inset, area.x1 - inset, area.y1 - inset)
    return area


def extract_pawns(pdfs: list[str], folder: Path) -> Found:
    """Pawn figures, named from the label printed under each one."""
    found: Found = []
    for pdf in pdfs:
        with pymupdf.open(pdf) as document:
            saved: set[int] = set()
            for page in document:
                for image in art_images(page):
                    x0, y0, x1, y1 = image["bbox"]
                    area = pymupdf.Rect(x0, y1 - (y1 - y0) * 0.12, x1, y1 + 14)
                    name = clean_name(label_text(words_inside(page, area)))
                    found += save_image(document, image["xref"], (name, "pawn"), folder, saved)
    return found


def art_images(page: pymupdf.Page) -> list[dict]:
    """Images that are art: not page backgrounds, decorations or thumbnails."""
    images = []
    for image in page.get_image_info(xrefs=True):
        x0, _, x1, _ = image["bbox"]
        if image["xref"] and MIN_ART_WIDTH < (x1 - x0) < page.rect.width * 0.6 and image["width"] >= 100:
            images.append(image)
    return images


def words_inside(page: pymupdf.Page, area: pymupdf.Rect) -> list[tuple[float, float, str]]:
    """(x, y, text) of the words whose centers fall inside area."""
    words = []
    for x0, y0, x1, y1, text, *_ in page.get_text("words"):
        if pymupdf.Point((x0 + x1) / 2, (y0 + y1) / 2) in area:
            words.append((x0, y0, text))
    return words


def save_image(document: pymupdf.Document, xref: int, label: tuple[str, str], folder: Path, saved: set[int]) -> Found:
    """Saves an embedded image once, with its transparency, as webp.

    Args:
        document: The PDF holding the image.
        xref: The image's object number; the same art reused on a page is saved once.
        label: (name, kind) of the image. Unnamed images are skipped.
        folder: Where to write the file.
        saved: Object numbers already saved from this document.

    Returns:
        A one-item list with (name, kind, file name), or an empty list.
    """
    name, kind = label
    if not name or xref in saved:
        return []
    saved.add(xref)
    picture = pillow_image(document, xref)
    if picture is None:
        return []
    file_name = f"{slug(name)}-{xref}.webp"
    picture.save(folder / file_name, "WEBP", quality=85)
    return [(name, kind, file_name)]


def pillow_image(document: pymupdf.Document, xref: int) -> Image.Image | None:
    """The image in RGB with its soft mask applied as alpha, or None when it can't be decoded."""
    try:
        pixmap = pymupdf.Pixmap(document, xref)
        if pixmap.colorspace and pixmap.colorspace.n not in (1, 3):
            pixmap = pymupdf.Pixmap(pymupdf.csRGB, pixmap)
        mask_xref = document.extract_image(xref).get("smask", 0)
        if mask_xref:
            pixmap = pymupdf.Pixmap(pixmap, pymupdf.Pixmap(document, mask_xref))
        return Image.open(io.BytesIO(pixmap.tobytes("png")))
    except (RuntimeError, ValueError):
        return None
