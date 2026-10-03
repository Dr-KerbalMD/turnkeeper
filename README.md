# Combat Pad

A private iPad and Mac encounter builder and initiative tracker for Pathfinder 2e and Starfinder 2e,
in the style of the Paizo Combat Pad. See `docs/specs/combat-pad/` for the requirements and design.

## Build
- `make bestiary` imports creatures, conditions and art into `Generated/` (needed before the first app
  build). Sources: `~/git/pf2e`, the Foundry modules folder, and the Paizo PDFs that Scrollkeeper
  downloaded.
  The PDF step runs in a project venv (`.venv`, from `requirements.txt`), created on first use.
  `art-sources.json` sets Foundry module priority and PDF overrides; `art-overrides.json` (optional)
  maps a creature name to the name its art has in a PDF. Check `Generated/import-report.md` afterwards.
- `make run` builds and opens the Mac app; `make install` copies it to /Applications.
- `make ipad-simulator` runs the iPad app in a simulator.
- `make ipad-install` installs on a connected iPad. Put your team in `ios/Local.xcconfig`
  (`DEVELOPMENT_TEAM = …`). A free team's signature lasts 7 days, so reinstall weekly.

## Test
`make test` and `make lint` (Swift); `.venv/bin/python -m pytest` and `.venv/bin/ruff check .` (Python).

## Layout
- `Sources/CombatPadKit`: models and rules
- `Sources/CombatPadUI`: SwiftUI shared by iPad and Mac
- `Sources/CombatPad`: Mac entry point; `ios/`: iPad project
- `Sources/BestiaryImport`, `scripts/extract_pdf_art.py`: the bestiary import
