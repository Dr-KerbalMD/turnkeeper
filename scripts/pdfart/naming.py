"""Turns text printed in the PDFs into creature names and file names.

Requirements: combat-pad R2.3, R4.14
"""

import re

MAX_NAME_WORDS = 7
COPYRIGHT_WORDS = {"©", "PAIZO", "INC.", "INC"}
TITLE_SUFFIX = re.compile(r"\s+(CREATURE|HAZARD|CR|NPC)\s+[-–]?[\d/]+\s*$", re.IGNORECASE)
# Cards for template variants ("RIVKA, ELITE") and rules cards ("SKELETON ADJUSTMENTS") show no new creature.
VARIANT_TITLE = re.compile(r",\s*(ELITE|WEAK)$|\bADJUSTMENTS\b", re.IGNORECASE)


def slug(text: str) -> str:
    """Lowercase words joined by hyphens, safe as a file name."""
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def clean_name(text: str) -> str:
    """Normalizes spacing, or returns "" for text too long to be a name, such as a legal notice."""
    name = re.sub(r"\s+", " ", text).strip(" ,")
    return name if len(name.split()) <= MAX_NAME_WORDS and "©" not in name else ""


def label_text(words: list[tuple[float, float, str]]) -> str:
    """Joins label words in reading order, without page numbers, copyright words or layered duplicates.

    The PDFs print each label twice, one copy on top of the other, so a word at the same spot is kept once.

    Args:
        words: (x, y, text) for each word inside the label area.

    Returns:
        The label, with anything from a "©" onwards removed.
    """
    seen: set[tuple[int, int, str]] = set()
    kept: list[tuple[int, float, str]] = []
    for x, y, text in words:
        spot = (round(x), round(y), text)
        if text.isdigit() or text.upper() in COPYRIGHT_WORDS or spot in seen:
            continue
        seen.add(spot)
        kept.append((round(y), x, text))
    kept.sort()
    return re.sub(r"©.*$", "", " ".join(text for _, _, text in kept)).strip()


def card_title(top_line: str) -> str:
    """The creature name from a card's top line, or "" for continued, variant and rules cards.

    Args:
        top_line: The words of the stat page's first line, such as "AEON, AXIOMITE CREATURE 8".
    """
    title = clean_name(TITLE_SUFFIX.sub("", top_line))
    if title.startswith("(") or "continued" in title.lower() or VARIANT_TITLE.search(title):
        return ""
    return title
