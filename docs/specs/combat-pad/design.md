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
| `Sources/CharacterImport` | Demiplane character import: links and QR codes, the sheet PDF reader, the client and the token. |
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
   A `@UUID` to an Item in a compendium pack becomes a `{{link:<id>|<label>}}` run instead, where the glossary
   ID is `<system>.<pack>.<_id>` (links by name are resolved to the `_id`). Links into effect packs stay labels.
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
   a parchment frame around a red field with the portrait for Pathfinder; for Starfinder, the Alien
   Archive look (teal scanline field, glowing frame, edge ticks, token hexagon, silver name plate and a
   STARFINDER logo line). Art is scaled smoothly, since tokens are small.
   A creature with no art of a kind borrows it from a same-named creature of the same game in another
   pack (`ArtFallback`), preferring the one with the most art, then remastered; the report lists them.
8. **Glossary.** `CompendiumIndex` reads the Item packs of both systems (an Item pack is indexed on first
   use) and records every glossary ID the import links to. Each creature gets a `LinkTable` from
   `<kind>:<shown text>` to a glossary ID: spells and items by their compendium source (or, without one, their
   embedded copy, `<creature key>.<item _id>`), Strike effects by the creature's own action or the ability
   glossary, and traits as `trait.<game>.<slug>`. `GlossaryBuilder` then turns the linked documents into
   `GlossaryEntry` values (name, category such as "Spell 3", traits and their links, rules text, with spell
   cast, range, area, targets, defense and duration lines first), follows their links one more level, and
   stops: everything a card links to, and everything those entries link to, is in the glossary. Trait text
   comes from `traitDescriptions` in the system's `src/scripts/config/traits.ts`, else
   `PF2E.TraitDescription<Slug>`, dropping a trailing `-value` (reach-10, deadly-d10); Starfinder prefers
   `sf2e-overrides-en.json`.
   **Player compendium.** For PC cards, `PlayerCompendium` also links every document in the player-facing
   Item packs of both systems (spells, feats, class features, actions, ancestry features, heritages and
   equipment), so they and the traits they link to are in the glossary. It writes `glossary-index.json`:
   `GlossaryIndex` keys `<game>:<kind>:<normalized name>` (kinds spell, ability, item and trait) to glossary
   IDs. Names are normalized by `GlossaryIndex.normalize` (lowercase, apostrophes dropped, other punctuation
   as spaces), so "Healing Potion, Moderate" and "Healing Potion (Moderate)" meet; on a clash the remastered
   document wins.
9. **Output.** `Generated/Bestiary/index.json` holds a summary of every creature. There is one
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
- **Voice entry.** `CombatState.initiativeTarget(chosen:)` picks whose initiative is next.
  `HoldToTalkButton` tracks the hold with a zero-distance drag gesture; a zero-duration long press ends as
  soon as it begins, which made the old per-strip buttons stop listening at once. `--fake-voice a,b,c`
  scripts what each hold hears, for UI tests.
- **`SpokenNumberParser`.** Turns a transcript into an initiative number. Number words, digits and
  ties are supported, and the last number heard wins.

## Library
- **Storage.** A Codable `Library` value holds campaigns, parties, scenarios, encounters and saved combat
  sessions. It is saved as `library.json` in Application Support on each device. Value records make undo,
  merging and testing simple, and avoid SwiftData's limits with enums that carry values.
- **Change stamps.** `ChangeClock.now()` never repeats or goes back within a run, so two quick edits never
  share a `modifiedAt` and the merger always sees that both sides changed.
- **Records.** Every record has `id`, `modifiedAt`, `deletedAt` (a tombstone; records are never removed)
  and `sharedVersion`, the `modifiedAt` of the version last shared with the other device.
- **Custom creatures.** `CustomCreature` records hold a full `Creature` under the key `custom.<id>`;
  `AppModel.entry`/`creature` look them up before the bestiary. `CreatureDraft` is the editor's text form
  of a creature, and `StatBlockText` reads and writes the printed forms (skills, speeds, resistances,
  damage, spell ranks, rules text with check and damage tokens).
- **Stat blocks from Pluck.** `PluckStatBlock` mirrors Pluck's pasteboard JSON
  (`io.github.scooper4711.pluck.statblock`, `{ "format": 1, "blocks": [...] }`) and also reads Pluck's plain
  text. `StatBlockConverter` reads each labeled entry with the `StatBlockText` parsers into a `Creature`;
  anything it can't read is kept as ability text and reported. `StatBlockImport` plans the import: one
  custom creature per block, placed in the variant whose label names the block's subtier.
- **Pasted artwork.** A `CustomArt` record points a creature key at an image file in the `ArtStore`
  (`Application Support/Combat Pad/Art/`); `library.json` never holds image bytes. Images are downscaled to
  2048 px (`PreparedImage`) and saved as JPEG, or PNG with transparency. A new image gets a new file; files
  no live record points to are swept at launch. `LibraryPackage.images` carries the bytes of the packaged
  records' files, written to the store before the library is merged. `AppModel.entry` swaps pasted art in as
  `Pasted/<file>` paths, which `AppModel.artURL` resolves to the store, so every view and the player view
  show it; the card back is cleared so the drawn back frames it.
- **Handouts.** `Handout` records (scenario, name, image file) store their image in the same `ArtStore`
  and travel in packages the same way. `PlayerDisplay` shows either a creature or a handout.
- **System paste buttons.** Pasting uses SwiftUI's `PasteButton`, which reads the pasteboard without iOS's
  Allow Paste prompt. Where a toolbar may be crowded, it sits in the page instead: iOS ignores a paste
  button it can't see in full.
- **Notes.** `CreatureNote` records (scenario, creature key, text) merge one note at a time, so editing
  one mid-fight never makes a conflict copy of a scenario. Encounter notes are `Encounter.notes`, edited in
  both places; the old per-session scratch notes are gone (old sessions still load).
- **Lenient loading.** `Library` decodes each kind of record as a lossy array, so older libraries and
  unreadable records don't stop the rest from loading. Record fields added later decode with defaults.
- **Variants.** An encounter keeps one `EncounterVariant` (slots and events) per scenario variant label.
  `CombatSetup` turns a variant and a party into the opening `CombatState`.
- **Merging.** `LibraryMerger` compares each record with the other device's copy. If one side is unchanged
  since the shared version, the other side's change wins. If both changed, the newer one wins, and for
  scenarios and encounters the other is kept as a "(conflict copy)". Deletions merge like any change.
- **Sharing.** `LibraryPackage` is the `.combatpad` file (UTType
  `io.github.scooper4711.combatpad.library`) and the nearby-sync payload. `NearbySync` uses
  Network.framework with Bonjour `_combatpad._tcp` and a 4-digit pairing code.

## UI
- **Themes.** `PadTheme` defines a Pathfinder look (parchment and red) and a Starfinder look (teal,
  neon cyan and a starfield). Magnet colors are shared by both.
- **Board.** The left half holds the ladder, the delay and dying gutters, the bench and event tiles.
  The right half holds the battle card and notes.
- **Battle cards.** `StatBlockPresenter` (in the Kit) produces adjusted values with breakdowns: the
  template adds an untyped ±2, conditions add their typed penalties, and the first damage instance of a
  Strike or ability takes the template's damage change.
  `PathfinderBattleCard`, `StarfinderBattleCard` and `HazardBattleCard` render them.
- **Glossary links.** `BestiaryStore.glossaryEntry(_:)` loads `glossary.json` on first use. Linked words are
  `CardSegment.link` runs, drawn as `Text` links (`combatpad-glossary:<id>`) with a dotted underline in the
  card's ink. `CardLineView` handles the link with an `OpenURLAction` and shows a `GlossaryPopover`
  anchored to the line; the popover's own lines do the same one level deeper. The `glossaryDepth`
  environment value stops links at two levels, and without a glossary in the environment (snapshots) links
  are plain text. Text of the creature's own embedded entries (Strike effects) is adjusted for the template
  and conditions; other entries are shown as written.
- **Card and notes split.** `SplitLayout` (in the Kit, tested) keeps the three panes as fractions of the
  height, with minimums, collapsing and a hidden creature-notes pane whose share is kept. `PaneStack` draws
  it with drag grips; the layout is saved per device in user defaults, not synced.
- **Fonts.** Roboto Condensed and Roboto, plus the pf2e action glyph font, converted from the pf2e
  system's woff2 files.

## Character import
- **Sheet.** A PC's sheet is a `Creature` of kind `character`, with `PlayerDetails` (ancestry, heritage,
  background, class, class DC, feats and class features), stored on its `PartyMember` with a
  `CharacterLink` (source, character ID, game, revision) and an optional GM-typed max HP. On the board it
  has the key `pc.<member id>`; `AppModel` resolves those keys from the party. Tiles still treat it as a PC.
- **Demiplane.** The GraphQL API (`apiv4.demiplane.com/v1/graphql`, bearer token) gives the name, level,
  avatar and game, but no computed statistics. Those come from the sheet PDF, a fillable form read field by
  field with PDFKit (`DemiplaneSheetReader`). `POST app.demiplane.com/api/magic-missile` with
  `GENERATE_CHARACTER_PDF_LAMBDA_NAME` exports it: 202 while it builds, then 200 with the PDF URL and a
  revision hash of the character. Campaigns come from `GET /api/getCampaign?campaignUuid=`. Both, and a
  fresh GraphQL token (`/api/auth/token`, then `/api/generate-graphql-token`), need the web session's
  cookies.
- **Session and token.** `DemiplaneSignInView` is a `WKWebView` on the default persistent data store; the
  app reads the session cookies from it. The GraphQL token is kept in the Keychain; its JWT expiry is
  shown, and an expired token is renewed from the session when there is one.
- **Glossary links.** `CharacterGlossaryLinker` fills the sheet's `LinkTable` by name through
  `BestiaryStore.glossaryID`; action text is replaced by the linked entry's rules text when there is one.

## Known limits
- The iPad build uses a free personal team, so it must be reinstalled every 7 days.
- PDF art is 192–330 px, so it looks soft when shown full screen.
- Pasted art is newest-wins when both devices paste art for the same creature; there are no conflict copies.
- Creatures in a `.combatpad` file are referenced by bestiary key, so both devices should run the same
  bestiary import.
- Demiplane's sheet PDF has the wrong max HP, so PCs show only a max HP the GM types.
- The Demiplane API is undocumented and may change without notice.
