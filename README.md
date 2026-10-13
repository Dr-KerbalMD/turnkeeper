# Combat Pad

A private iPad and Mac encounter builder and initiative tracker for Pathfinder 2e and Starfinder 2e,
in the style of the Paizo Combat Pad. See `docs/specs/combat-pad/` for the requirements and design.

## Build
- `make bestiary` imports creatures, conditions and the glossary from `~/git/pf2e` into `Generated/` (needed
  before the first app build). Font conversion runs in a project venv (`.venv`, from `requirements.txt`),
  created on first use. `art-overrides.json` (optional) maps a creature name to the name its art has in a
  PDF. Check `Generated/import-report.md` afterwards.
- `make run` builds and opens the Mac app; `make install` moves it to /Applications (the build copy is removed so Finder launches the installed one).
- `make ipad-simulator` runs the iPad app in a simulator.
- `make ipad-install` installs on a connected iPad. Put your team in `ios/Local.xcconfig`
  (`DEVELOPMENT_TEAM = …`). A free team's signature lasts 7 days, so reinstall weekly.

## Use
- **Creature art** comes from your own Paizo pawn, token and Battle Cards PDFs, read on the device with
  [Tabletop Kit](https://github.com/scooper4711/tabletop-kit): Creature Art (in the sidebar's toolbar) ▸ Import
  from Scrollkeeper watches Scrollkeeper's download folder and uses its PDFs where they are, picking up new
  downloads; Add PDFs… keeps copies of others. PDFs deleted from Scrollkeeper are listed as missing.
- **Plan:** add a campaign (Pathfinder or Starfinder), a party, and scenarios. Each scenario has
  difficulty variants (PFS challenge-point brackets, SFS easier/base/harder). Plan each encounter per
  variant, with creatures, a bench and events, and watch the budget bar. The scenario page shows every
  encounter at every difficulty.
- **Run:** press Run (or a cell in the scenario grid). In setup, creatures roll initiative. Hold a PC's
  strip and say the number, tap it to type, or use Listen for All. Then Begin Combat. During the fight,
  drag strips to reorder, tap one to pin its card, long-press for actions, and press Next (or space).
  Reminders block Next until dismissed.
- **Show players:** the eye button shows the creature's card back, with its art, on an external display or
  AirPlay screen (iPad), in the Players window (Mac), or full screen.
- **Share:** export a campaign as a `.combatpad` file (AirDrop, Files, Finder) and open it on the other
  device, or use Sync with Nearby Device on both. Edits made on both sides are kept as conflict copies.
- **Demo:** launch with `--demo planner`, `--demo setup`, `--demo board` or `--demo starfinder` for an
  in-memory sample that leaves the saved library alone.

## Artwork

The `Artwork/` folder is a private Git submodule ([toolkit-artwork](https://github.com/scooper4711/toolkit-artwork)).
Clone with `git clone --recursive`, or run `git submodule update --init` after cloning. Its contents are
licensed and not redistributable. Without access to it, the build still works and falls back to built-in
artwork. `make bestiary` copies Paizo's Pathfinder-Icons font from it, unaltered, for the cards' action icons
(the [Paizo Compatibility License](https://paizo.com/licenses/compatibility)); without it they show stand-in
symbols.

Pathfinder and Starfinder are registered trademarks and copyrights of Paizo Inc.

## Test
`make test` and `make lint` (Swift); `make ipad-uitest` (iPad UI tests, against the demo fight);
`.venv/bin/python -m pytest` and `.venv/bin/ruff check .` (Python). `make cards KEYS="<creature key>[:elite]"`
renders battle cards to `tmp/cards` for comparing with the printed decks.

## Layout
- `Sources/CombatPadKit`: models and rules
- `Sources/CombatPadUI`: SwiftUI shared by iPad and Mac
- `Sources/CombatPad`: Mac entry point; `ios/`: iPad project
- `Sources/BestiaryImport`, `scripts/extract_pdf_art.py`: the bestiary import
