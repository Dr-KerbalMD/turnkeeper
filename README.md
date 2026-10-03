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

## Use
- **Plan:** add a campaign (Pathfinder or Starfinder), a party, and scenarios. Each scenario has
  difficulty variants (PFS challenge-point brackets, SFS easier/base/harder). Plan each encounter per
  variant, with creatures, a bench and events, and watch the budget bar. The scenario page shows every
  encounter at every difficulty.
- **Run:** press Run (or a cell in the scenario grid). In setup, creatures roll initiative. Hold a PC's
  strip and say the number, tap it to type, or use Listen for All. Then Begin Combat. During the fight,
  drag strips to reorder, tap one to pin its card, long-press for actions, and press Next (or space).
  Reminders block Next until dismissed.
- **Show players:** the eye button shows the creature's Battle Card back on an external display or
  AirPlay screen (iPad), in the Players window (Mac), or full screen.
- **Share:** export a campaign as a `.combatpad` file (AirDrop, Files, Finder) and open it on the other
  device, or use Sync with Nearby Device on both. Edits made on both sides are kept as conflict copies.
- **Demo:** launch with `--demo planner`, `--demo setup`, `--demo board` or `--demo starfinder` for an
  in-memory sample that leaves the saved library alone.

## Test
`make test` and `make lint` (Swift); `make ipad-uitest` (iPad UI tests, against the demo fight);
`.venv/bin/python -m pytest` and `.venv/bin/ruff check .` (Python). `make cards KEYS="<creature key>[:elite]"`
renders battle cards to `tmp/cards` for comparing with the printed decks.

## Layout
- `Sources/CombatPadKit`: models and rules
- `Sources/CombatPadUI`: SwiftUI shared by iPad and Mac
- `Sources/CombatPad`: Mac entry point; `ios/`: iPad project
- `Sources/BestiaryImport`, `scripts/extract_pdf_art.py`: the bestiary import
