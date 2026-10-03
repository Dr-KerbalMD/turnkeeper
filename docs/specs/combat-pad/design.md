# Combat Pad: design

## Layout
A SwiftPM package with a thin iPad Xcode project, following the Scrollkeeper pattern.

| Path | Contents |
|---|---|
| `Sources/CombatPadKit` | Models and rules, with no UI: Bestiary, Rules, Library, Combat, Sharing, Text. |
| `Sources/CombatPadUI` | SwiftUI shared by iPad and Mac: themes, board, battle cards, planning, bestiary browser. |
| `Sources/CombatPad` | Mac app entry point. |
| `Sources/FoundryImport` | Library that parses Foundry documents, converts rules text and matches art. |
| `Sources/BestiaryImport` | CLI around FoundryImport that writes `Generated/`. |
| `ios/CombatPad.xcodeproj` | iPad app. It references the package as `..` and bundles `Generated/` as a folder reference. |
| `scripts/extract_pdf_art.py`, `scripts/pdfart/` | PyMuPDF extractor for token, pawn and card art from the Paizo PDFs, run in the project `.venv`. |
| `Generated/` | Import output, gitignored and bundled into both apps. |

## Bestiary import pipeline
1. **Pack discovery.** Read `system.pf2e.json` and `system.sf2e.json` for the Actor packs. Scan
   `packs/<system>/<pack>/**/*.json`, keeping `type == "npc"` and complex `hazard` documents.
2. **Normalization.** Each document becomes a `Creature` with the key `<game>.<pack>.<_id>`. Strikes
   come from `melee` items, abilities from `action` items, spells are grouped by `spellcastingEntry`,
   and lore comes from `lore` items.
3. **Rules text.** HTML and Foundry enrichers become `RulesText` runs. `@Check` and `@Damage` stay
   structured so templates and conditions can adjust them. `@UUID` becomes its label, `@Localize` is
   resolved from the lang JSON, and `@Template` becomes prose.
4. **Conditions.** The condition packs go to `conditions.json`. sf2e gets the pf2e conditions plus its
   own.
5. **Foundry art.** Every module's `flags.compendiumArtMappings.{pf2e,sf2e}` file maps
   `<system>.<pack>` → `_id` → portrait and token. Only IDs that exist are used. Module priority comes
   from `art-sources.json`.
6. **PDF art.** `extract_pdf_art.py` finds every folder in Scrollkeeper's downloads whose name contains
   "Battle Cards", "Pawn" or "Token Box", and pairs embedded images with their printed labels. For token
   fronts and backs, the label is the text at the same position on the next page. For pawns, it is the
   text below the image. Names are matched to creatures after normalization, including "X, Y" → "Y X".
   `art-overrides.json` holds manual fixes.
7. **Battle card backs.** These make the player view, the "what you're fighting" screen. Each art
   page of a Battle Cards PDF is rendered whole, frame included, at about 200 dpi to
   `Generated/CardBacks/<set>/<slug>.webp`. It is named by the title on its stat page; "continued
   from card N" pages are skipped. `art-sources.json` gives each PDF's layout:
   - `cardsAlternating`: art page, then stat page (Pathfinder Bestiary).
   - `cardsBlocks`: a run of stat pages, then a run of art pages in the same order (Monster Core).
   - `cardsSplitFiles`: a FRONTS PDF and a BACKS PDF matched by page number (Abomination Vaults,
     Alien Archive).
   
   Card titles such as "AEON, AXIOMITE" are matched by token set against the creature name, with the
   family prefix optional. Remastered creatures prefer remaster sets such as Monster Core, and legacy
   creatures prefer legacy sets. Creatures without a card get a card back drawn in the same style:
   a parchment frame around a red field with the portrait for Pathfinder, and a neon frame with a
   name plate for Starfinder.
8. **Output.** `Generated/Bestiary/index.json` holds a summary of every creature. There is one
   `packs/<game>.<pack>.json` per pack, plus `conditions.json`, the art files, and
   `Generated/import-report.md`. Keys and arrays are sorted, so the output is deterministic.

## Rules
Ported from the pf2e system, with tests.
- **`TemplateAdjuster`.** Elite and weak: level ±1, with the special cases elite on -1 or 0 = +2 and
  weak on 1 = -2. Statistics, AC, DCs and attacks get ±2, and damage gets ±2, or ±4 for
  limited-frequency inline damage. HP changes by bracket on the base level.
- **`EncounterBudget`.** XP by level difference, clamped to -4…+4: 10, 15, 20, 30, 40, 60, 80, 120,
  160. For 4 PCs the tiers are 40, 60, 80, 120 and 160, and each extra or missing PC adds or removes
  10, 15, 20, 30 or 40 for those tiers.
- **`ConditionEffects`.** A table that mirrors the FlatModifier selectors, with statistic domains: `all`,
  str-based, dex-based, con-based, int/wis/cha-based, ac, attack, perception and saves. Granted
  conditions and overrides are applied. Only the worst status penalty and the worst circumstance
  penalty count.
- **`TurnAdvancer`.** A pure function from session state and Next to the new state plus a reminder
  queue. The order is end-of-turn, end-of-round, start-of-round, initiative-count events, expiring
  durations, then start-of-turn.
- **`ReminderRules`.** Condition reminders by timing, with their actions.
- **`SpokenNumberParser`.** Turns a transcript into an initiative number. Number words, digits and
  ties are supported, and the last number heard wins.

## Library (SwiftData)
- **Records.** Campaign, Party, PartyMember, Scenario, Encounter, EncounterVariant, EncounterSlot,
  EncounterEvent, CombatSession and Combatant. Each carries `uuid`, `modifiedAt` and `deletedAt`.
- **Sharing.** `LibraryPackage` is the Codable snapshot used both for `.combatpad` files and for
  nearby sync.
- **Merging.** `LibraryMerger` keeps the newest record per uuid, honors tombstones, and keeps conflict
  copies.
- **Nearby sync.** `NearbySync` uses Network.framework with Bonjour `_combatpad._tcp` and a 4-digit
  pairing code.

## UI
- **Themes.** `PadTheme` defines a Pathfinder look (parchment and red) and a Starfinder look (teal,
  neon cyan and a starfield). Magnet colors are shared by both.
- **Board.** The left half holds the ladder, the delay and dying gutters, the bench and event tiles.
  The right half holds the battle card and notes.
- **Battle cards.** `StatBlockPresenter` produces adjusted values with breakdowns.
  `PathfinderBattleCard`, `StarfinderBattleCard` and `HazardBattleCard` render them.
- **Fonts.** Roboto Condensed and Roboto, plus the pf2e action glyph font, converted from the pf2e
  system's woff2 files.

## Known limits
- The iPad build uses a free personal team, so it must be reinstalled every 7 days.
- PDF art is 192–330 px, so it looks soft when shown full screen.
- Creatures in a `.combatpad` file are referenced by bestiary key, so both devices should run the same
  bestiary import.
