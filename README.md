# Turnkeeper

Running a Pathfinder or Starfinder fight at the table means keeping a lot in your head: the initiative order,
hit points, conditions that change every round, who is delaying, the persistent damage and frightened values
that tick at the end of a turn, and the stat block of whoever is up, open in a book or a PDF somewhere.

Turnkeeper is an encounter builder and initiative tracker for the iPad and the Mac that puts all of it on one
screen. The left half is the initiative ladder: the creatures roll their own initiative, you say the players'
numbers aloud or tap them in, and Next passes the turn. The right half shows the battle card of whoever's turn
it is, with its conditions applied, and your notes. Reminders hold the turn until persistent damage and the
like are dealt with, and the players can watch the creature's art on a second screen.

Plan ahead, too: build parties and scenarios with an encounter for each difficulty (Pathfinder Society
challenge-point brackets, Starfinder Society's easier, base and harder), and watch the encounter budget as you
add creatures. See `docs/specs/turnkeeper/` for the requirements and design.

## Build
- `make bestiary` imports creatures, conditions and the glossary into `Generated/` (needed before the first app
  build) from the pf2e release named in `pf2e.release`, which it downloads into `build/pf2e`; set `PF2E_REPO` to
  read your own pf2e checkout instead. Font conversion runs in a project venv (`.venv`, from `requirements.txt`),
  created on first use. `art-overrides.json` (optional) maps a creature name to the name its art has in a PDF.
  Check `Generated/import-report.md` afterwards.
- `make run` builds and opens the Mac app; `make install` moves it to /Applications (the build copy is removed so Finder launches the installed one).
- `make update-pf2e` switches to pf2e's newest release and re-imports. GitHub does this every Monday, and
  when the new release changes the bestiary and Turnkeeper has a release, it builds the next patch version into
  a draft release. Commit `pf2e.release` and `import.sha256` after a local import.
- `make dmg` builds `build/Turnkeeper-<version>.dmg`. Pushing a `v*` tag builds the universal app on GitHub
  from the same pf2e release and the `Artwork` submodule, and attaches its disk image to the release.
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
- **Share:** export a campaign as a `.turnkeeper` file (AirDrop, Files, Finder) and open it on the other
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

## Paizo notices

Turnkeeper uses trademarks and/or copyrights owned by Paizo Inc., used under Paizo's Community Use Policy
([paizo.com/licenses/communityuse](https://paizo.com/licenses/communityuse)). We are expressly prohibited from
charging you to use or access this content. Turnkeeper is not published, endorsed, or specifically approved by
Paizo. For more information about Paizo Inc. and Paizo products, visit [paizo.com](https://paizo.com).

Pathfinder and Starfinder are registered trademarks and copyrights of Paizo Inc.

The creature and rules text comes from the [pf2e system for Foundry VTT](https://github.com/foundryvtt/pf2e) and is
used under the ORC License and the Open Game License 1.0a. The condition icons are from
[game-icons.net](https://game-icons.net), by DarkZaitzev, Delapouite, Lorc, Sbed, Skoll and Zeromancer, used under
[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/);
[Resources/ConditionIcons/CREDITS.md](Resources/ConditionIcons/CREDITS.md) credits each one. The same notices and
credits are in the app's About screen (the app menu on the Mac, the campaign sidebar's About button on the iPad).
Contact: [Turnkeeper's issues on GitHub](https://github.com/scooper4711/turnkeeper/issues).

## Test
`make test` and `make lint` (Swift); `make ipad-uitest` (iPad UI tests, against the demo fight);
`.venv/bin/python -m pytest` and `.venv/bin/ruff check .` (Python). `make cards KEYS="<creature key>[:elite]"`
renders battle cards to `tmp/cards` for comparing with the printed decks.

## Layout
- `Sources/TurnkeeperKit`: models and rules
- `Sources/TurnkeeperUI`: SwiftUI shared by iPad and Mac
- `Sources/Turnkeeper`: Mac entry point; `ios/`: iPad project
- `Sources/BestiaryImport`, `scripts/extract_pdf_art.py`: the bestiary import

## License

The code is under the [MIT License](LICENSE). The game text, art and fonts the app imports or bundles keep their
own licenses; see Paizo notices above.
