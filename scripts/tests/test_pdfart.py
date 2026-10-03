"""Tests for the pure parts of the PDF art extraction: names, layouts and page pairing.

Requirements: combat-pad R2.3, R4.14
"""

from pathlib import Path

import pymupdf
import pytest

from pdfart.cards import block_pairs
from pdfart.discovery import describe_folder, discover_sources, folder_kind, layout_for_pattern
from pdfart.figures import mirrored_label_area
from pdfart.naming import card_title, clean_name, label_text, slug


def test_slug_makes_safe_file_names() -> None:
    assert slug("AEON GUARD, SIHEDRON GUARD") == "aeon-guard-sihedron-guard"


def test_clean_name_rejects_legal_notices() -> None:
    assert clean_name("  AKATA ,") == "AKATA"
    assert clean_name("Paizo, Paizo Inc., and the Paizo golem logo are registered trademarks") == ""


def test_label_text_drops_layered_duplicates_numbers_and_copyright() -> None:
    words = [
        (47, 49, "AEON"),
        (47, 49, "AEON"),
        (65, 49, "GUARD"),
        (65, 49, "GUARD"),
        (64, 33, "3"),
        (50, 60, "TROOPER"),
        (40, 70, "©"),
        (45, 70, "PAIZO"),
    ]
    assert label_text(words) == "AEON GUARD TROOPER"


@pytest.mark.parametrize(
    ("line", "title"),
    [
        ("AEON, AXIOMITE CREATURE 8", "AEON, AXIOMITE"),
        ("AHAV CR 12", "AHAV"),
        ("DROWNING PIT HAZARD 3", "DROWNING PIT"),
        ("(Aeon, akhana, continued from card 2)", ""),
        ("RIVKA, ELITE CREATURE 9", ""),
        ("SKELETON ADJUSTMENTS", ""),
    ],
)
def test_card_title(line: str, title: str) -> None:
    assert card_title(line) == title


def test_layout_for_pattern() -> None:
    assert layout_for_pattern("ITITITIT") == "cardsAlternating"
    assert layout_for_pattern("TTTTIIIITTII") == "cardsBlocks"


def test_block_pairs_match_by_position_in_each_run() -> None:
    assert block_pairs("TTIITI") == [(0, 2), (1, 3), (4, 5)]


def test_mirrored_label_area_flips_and_insets_large_tokens() -> None:
    small = mirrored_label_area(pymupdf.Rect(21, 23, 113, 106), 612)
    assert (round(small.x0), round(small.x1)) == (499, 591)
    large = mirrored_label_area(pymupdf.Rect(7, 7, 240, 240), 612)
    assert round(large.x0) == round(372 + 233 * 0.2)


def test_folder_kind() -> None:
    assert folder_kind("Starfinder Alien Core Token Box") == "token"
    assert folder_kind("Starfinder Pawns- Alien Archive 2 Pawn Box") == "pawn"
    assert folder_kind("Pathfinder Bestiary Battle Cards") == "cards"
    assert folder_kind("Starfinder Flip-Mat- Basic Terrain") == ""


def test_split_decks_are_found_without_opening_them(tmp_path: Path) -> None:
    deck = tmp_path / "Pathfinder Bestiary 2 Battle Cards"
    deck.mkdir()
    (deck / "PZO2219 Bestiary 2 Battle Cards FRONT.pdf").write_bytes(b"")
    (deck / "PZO2219 Bestiary 2 Battle Cards BACKS.pdf").write_bytes(b"")
    source = describe_folder(deck, ["Monster Core"])
    assert source is not None
    assert (source.layout, source.game, source.era) == ("cardsSplitFiles", "pf2e", "legacy")
    assert source.files[0].endswith("FRONT.pdf")


def test_discovery_applies_overrides_and_skips(tmp_path: Path) -> None:
    for name in ("Starfinder Alien Core Token Box", "Pathfinder Monster Core Pawn Box", "Unrelated"):
        (tmp_path / name).mkdir()
        (tmp_path / name / "file.pdf").write_bytes(b"")
    config = {
        "remasterPdfKeywords": ["Alien Core"],
        "pdfOverrides": {"Pathfinder Monster Core Pawn Box": {"skip": True}},
    }
    sources = discover_sources(tmp_path, config)
    assert [(source.collection, source.era) for source in sources] == [("starfinder-alien-core-token-box", "remaster")]
