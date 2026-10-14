# Turnkeeper: design

## Layout
A SwiftPM package with a thin iPad Xcode project, following the Scrollkeeper pattern.

| Path | Contents |
|---|---|
| `Sources/TurnkeeperKit` | Models and rules, with no UI: Bestiary, Rules, Library, Combat, Sharing, Text. |
| `Sources/TurnkeeperUI` | SwiftUI shared by iPad and Mac: themes, board, battle cards, planning, bestiary browser. |
| `Sources/Turnkeeper` | Mac app entry point. |
| `Sources/FoundryImport` | Library that parses Foundry documents, converts rules text and matches art. |
| `Sources/BestiaryImport` | CLI around FoundryImport that writes `Generated/`. |
| `Sources/CharacterImport` | Demiplane character import: links and QR codes, the sheet PDF reader, the client and the token. |
| `ios/Turnkeeper.xcodeproj` | iPad app. It references the package as `..` and bundles `Generated/` as a folder reference. |
| `scripts/extract_pdf_art.py`, `scripts/pdfart/` | PyMuPDF extractor for token, pawn and card art from the Paizo PDFs, run in the project `.venv`. |
| `Generated/` | Import output, gitignored and bundled into both apps. |

## Bestiary import
The creature model, stat-block presentation, conditions and the pf2e import live in
[Tabletop Kit](https://github.com/scooper4711/tabletop-kit) (`Bestiary` and `CreatureImport`), shared with Field
Guide; its spec describes the import pipeline. `make bestiary` runs Turnkeeper's `BestiaryImport` executable on it.

## Release
`pf2e.release` holds a pf2e commit and the system release tags on it. `make bestiary` fetches that one commit
from `foundryvtt/pf2e` into `build/pf2e` (`scripts/fetch-pf2e.sh`) and imports it; `PF2E_REPO` reads another
checkout for development. `scripts/latest-pf2e-release.sh` finds the newest `pf2e-*` or `sf2e-*` release.
- **Release workflow** (on `v*` tags, or called): fetches the `Artwork` submodule with the `ARTWORK_SSH_KEY`
  deploy key, runs the import with `REXARD_PACKS=Artwork/rexard`, tests, builds the universal app and attaches
  `Turnkeeper-<version>.dmg` (`scripts/make-dmg.sh`) to the release, creating a draft if there is none. The
  app is signed ad hoc, as a local build is.
- **pf2e update workflow** (Mondays, or by hand): when pf2e has a newer release, commits `pf2e.release`
  through the API (so GitHub signs it). If the app has a `v*` tag, it tags the next patch version on that
  commit and calls the release workflow; tags made with the workflow's token don't start workflows themselves.

## Creature art
- Tabletop Kit's `CreatureArtStore` (an actor, in its `CreatureArt` product) owns the kit's `ArtLibrary`;
  Turnkeeper's `standard()` puts it in Application Support/Turnkeeper/Creature Art (apart from
  pasted art's `Art` folder, whose unused files are swept at launch). Import
  from Scrollkeeper watches the chosen folder and runs `addNewFiles`, by reference; Add PDFs… commits each file
  kept. At launch the store refreshes the PDFs' statuses and adds new files from the watched folders. Pictures
  are drawn by `ArtLibrary.picture(of:maxPixels:)` and cached by entry and size.
- After each change the store publishes a catalog: per entry its id, name, game, whether a remastered product
  (Monster Core, NPC Core, Alien Core, Howl of the Wild, Rage of Elements) prints it, whether its first print is
  a token, whether it can be drawn, the titles of the PDFs printing it, and whether it is an item's art.
  Tabletop Kit's `LibraryArtMatcher` (`Bestiary`) indexes it by game and normalized name, items apart so a
  creature never takes an item's art, with the same rules as the old PDF matcher: words compared as a set,
  a "FAMILY, MEMBER" title also under the member alone, a creature's name tried as is, without "spellcaster"
  and without parentheses, `art-overrides.json` first. Remastered creatures prefer entries a remastered product
  prints, legacy ones the others, drawable entries first.
- `AppModel.entry(_:)` fills a bestiary creature's `ArtReference` from the matcher: `library:<entry id>` paths
  for the portrait (a non-token entry, else the token) and the token (a token entry, else the portrait).
  `ArtImage` asks the store for `library:` paths and loads other paths from files as before. A creature whose
  matched art can't be drawn gets `missingArt`, the titles of the PDFs it needs, shown on its card.

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
  (`Application Support/Turnkeeper/Art/`); `library.json` never holds image bytes. Images are downscaled to
  2048 px (`PreparedImage`) and saved as JPEG, or PNG with transparency. A new image gets a new file; files
  no live record points to are swept at launch. `LibraryPackage.images` carries the bytes of the packaged
  records' files, written to the store before the library is merged. `AppModel.entry` swaps pasted art in as
  `Pasted/<file>` paths, which `AppModel.artURL` resolves to the store, so every view and the player view
  show it; the card back is cleared so the drawn back frames it.
- **Handouts.** `Handout` records (scenario, name, image file) store their image in the same `ArtStore`
  and travel in packages the same way. `PlayerDisplay` shows either a handout or, while the player screen is
  on, the fight.
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
- **Sharing.** `LibraryPackage` is the `.turnkeeper` file (UTType
  `io.github.scooper4711.turnkeeper.library`) and the nearby-sync payload. `NearbySync` uses
  Network.framework with Bonjour `_turnkeeper._tcp` and a 4-digit pairing code.

## UI
- **Themes.** `BoardTheme` defines a Pathfinder look (parchment and red) and a Starfinder look (teal,
  neon cyan and a starfield). Magnet colors are shared by both.
- **Board.** The left half holds the ladder, the bench and event tiles.
  The ladder is a scroll view, so strips use `SwipeableStrip`: a sideways `DragGesture` (ignored when the
  drag starts more vertical than sideways, so scrolling and `.draggable` still work) that slides the strip
  over a colored action and fires it past a threshold.
- **Delay.** `Combatant.isDelaying` keeps a delaying strip in `CombatState.order`. `TurnAdvancer.next`
  skips delaying strips and takes `actingNow`, the GM's answer about `delayedStripsAhead`, which
  `BoardController` asks for (an alert for one, a sheet for several) before passing the turn.
  The right half holds the battle card and notes.
- **Battle cards.** `StatBlockPresenter` (in the Kit) produces adjusted values with breakdowns: the
  template adds an untyped ±2, conditions add their typed penalties, and the first damage instance of a
  Strike or ability takes the template's damage change.
  Tabletop Kit's `BattleCard` and `CardBack` render them, with the UI art in `Generated/CardArt` passed as the
  `cardArt` environment value (the root view, the player display and card snapshots).
- **Interactive cards.** `CreatureBattleCard` wraps Tabletop Kit's `InteractiveBattleCard`, with
  `CreatureCardBack` (the kit's `CardBack` around its `ArtPicture`) as the back. `battleCardEnvironment(_:)`
  sets what cards take from the app: the glossary, the card UI art, and an `ArtPictureLoader` that calls
  `AppModel.artPicture(for:maxPixels:)`. The root view and `CreaturePreview` apply
  `battleCardFullScreenHost()`, so a Mac card fills its window or sheet. The board's card is keyed by
  combatant (`.id`), so a new turn starts it on its front. Condition tags and `ConditionLabel` are the kit's;
  the strip chips use the same `ConditionLabel`.
- **Player screen.** `CombatState.playerScreen(maxHitPoints:)` (tested) builds a `PlayerScreenFight`: the
  ladder as `PlayerScreenLine`s with a `HealthEstimate` (Tabletop Kit) for enemies, and the acting
  combatant's creature key. `BoardView` pushes `BoardController.playerScreen` to `PlayerDisplay.fight` on
  every change and clears it when the board closes. `PlayerScreenToggle` sets
  `PlayerDisplay.isPlayerScreenOn`: on the Mac it opens or dismisses the Players window (whose appearing
  and disappearing set it too); on the iPad without a second screen it presents `PlayerScreen` in a
  `fullScreenCover`. `PlayerScreen`, the root of the external-display scene and the Players window, uses
  the app's own `AppModel` and lays the order and art side by side, or stacked when taller than wide.
- **Glossary links.** `BestiaryStore.glossaryEntry(_:)` loads `glossary.json` on first use. Linked words are
  `CardSegment.link` runs, drawn as `Text` links (`tabletop-glossary:<id>`) with a dotted underline in the
  card's ink. `CardLineView` handles the link with an `OpenURLAction` and shows a `GlossaryPopover`
  anchored to the line; the popover's own lines do the same one level deeper. The `glossaryDepth`
  environment value stops links at two levels, and without a glossary in the environment (snapshots) links
  are plain text. Text of the creature's own embedded entries (Strike effects) is adjusted for the template
  and conditions; other entries are shown as written.
- **Card and notes split.** `SplitLayout` (in the Kit, tested) keeps the three panes as fractions of the
  height, with minimums, collapsing and a hidden creature-notes pane whose share is kept. `PaneStack` draws
  it with drag grips; the layout is saved per device in user defaults, not synced.
- **Fonts.** Roboto Condensed and Roboto, converted from the pf2e system's woff2 files, plus Paizo's
  Pathfinder-Icons font for the action icons, which `make bestiary` copies unaltered from the private `Artwork`
  submodule (Tabletop Kit's `ActionIcons` maps costs to its code points).
- **Condition icons.** The game-icons.net SVGs, unaltered but named by condition slug, live in
  `Resources/ConditionIcons` with `CREDITS.md` naming each icon's author. `make bestiary` renders them with
  `sips` to `Generated/Conditions/<slug>.png`, which the palette shows.
- **About.** Tabletop Kit's `AppNotices`: `AboutCommands` on the Mac, an `AboutSheet` from the campaign
  sidebar's toolbar on the iPad, both with `AboutInfo.turnkeeper` (`App/About.swift`).

## Character import
- **Sheet.** A PC's sheet is a `Creature` of kind `character`, with `PlayerDetails` (ancestry, heritage,
  background, class, class DC, feats and class features), stored on its `PartyMember` with a
  `CharacterLink` (source, character ID, game, revision) and an optional GM-typed max HP. On the board it
  has the key `pc.<member id>`; `AppModel` resolves those keys from the party. Tiles still treat it as a PC.
- **Demiplane.** The GraphQL API (`apiv4.demiplane.com/v1/graphql`, bearer token) gives the name, level,
  avatar and game, but no computed statistics. Those come from the sheet PDF, a fillable form read field by
  field with PDFKit (`DemiplaneSheetReader`), one sheet at a time since PDFKit can deadlock reading form
  fields on several threads. Starfinder sheets (`/nexus/starfinder2e/…`, against Pathfinder's
  `/nexus/pathfinder-2e/…`) add Computers, Piloting, credits and a ranged weapon's range, magazine and
  expend, and have no damage types; a sheet's game comes from the API, else from those fields. `POST app.demiplane.com/api/magic-missile` with
  `GENERATE_CHARACTER_PDF_LAMBDA_NAME` exports it: 202 (or sometimes 200 without a URL) while it builds,
  then 200 with the PDF URL and a revision hash of the character. Campaigns come from `GET /api/getCampaign?campaignUuid=`, sent with
  `Client-Pathname: /nexus/<pathfinder2e|starfinder2e>/campaigns/<id>` as Demiplane's own page does: the
  server looks the campaign up in the game that path names, and answers 403 "Campaign not found" for a
  Starfinder campaign asked without it. Both, and a fresh GraphQL token (`/api/auth/token`, then
  `/api/generate-graphql-token`), need the web session's cookies.
- **Shared characters.** `demiplane_user_character` returns only the user's own characters (Demiplane's own
  client filters it by `user_id` too), so a character shared with the GM read-only gets no row, with any
  token. Demiplane's server embeds the character in its sheet page (`/nexus/<slug>/character-sheet/<id>`)
  for anyone allowed to view it, as `characterSheetContent.character` (`name`, `level`, `avatar_url`,
  `nexus_id`: 1 Pathfinder, 100 Starfinder) inside the page's string-escaped React data; the import reads it
  from there (`DemiplaneClient.sharedCharacter`). When the page doesn't have it either, the import goes on
  with the link's game and the sheet's name and level.
- **Refresh.** Every request to Demiplane skips the URL cache (`reloadIgnoringLocalCacheData`): signed out,
  the sheet's address never changes, so a cached PDF would hide a rebuild. `Party.apply(_:link:to:)`
  (TurnkeeperKit) puts an imported sheet on its member and returns a `SheetUpdate`: `added`, `unchanged` (the
  same sheet as before) or `updated` with the changes a GM cares about (level, AC, saves, Perception, class DC,
  then skills, Strikes, spells, feats and items). The status message reports it, and says when the import was
  signed out and so read Demiplane's last export. The party row shows progress while its refresh runs.
- **Session and token.** `DemiplaneSignInView` is a `WKWebView` on the default persistent data store; the
  app reads the session cookies from it. The GraphQL token is kept in the Keychain; its JWT expiry is
  shown, and an expired token is renewed from the session when there is one.
- **Interactive cards.** `CreatureBattleCard` wraps Tabletop Kit's `InteractiveBattleCard`, with
  `CreatureCardBack` (the kit's `CardBack` around its `ArtPicture`) as the back. `battleCardEnvironment(_:)`
  sets what cards take from the app: the glossary, the card UI art, and an `ArtPictureLoader` that calls
  `AppModel.artPicture(for:maxPixels:)`. The root view and `CreaturePreview` apply
  `battleCardFullScreenHost()`, so a Mac card fills its window or sheet. The board's card is keyed by
  combatant (`.id`), so a new turn starts it on its front. Condition tags and `ConditionLabel` are the kit's;
  the strip chips use the same `ConditionLabel`.
- **Player screen.** `CombatState.playerScreen(maxHitPoints:)` (tested) builds a `PlayerScreenFight`: the
  ladder as `PlayerScreenLine`s with a `HealthEstimate` (Tabletop Kit) for enemies, and the acting
  combatant's creature key. `BoardView` pushes `BoardController.playerScreen` to `PlayerDisplay.fight` on
  every change and clears it when the board closes. `PlayerScreenToggle` sets
  `PlayerDisplay.isPlayerScreenOn`: on the Mac it opens or dismisses the Players window (whose appearing
  and disappearing set it too); on the iPad without a second screen it presents `PlayerScreen` in a
  `fullScreenCover`. `PlayerScreen`, the root of the external-display scene and the Players window, uses
  the app's own `AppModel` and lays the order and art side by side, or stacked when taller than wide.
- **Glossary links.** `CharacterGlossaryLinker` fills the sheet's `LinkTable` by name through
  `BestiaryStore.glossaryID`, falling back to Pathfinder names for Starfinder characters (Starfinder 2e
  shares the Player Core ancestries and feats); action text is replaced by the linked entry's rules text when there is one.

## Known limits
- The iPad build uses a free personal team, so it must be reinstalled every 7 days.
- PDF art is 192–330 px, so it looks soft when shown full screen.
- Pasted art is newest-wins when both devices paste art for the same creature; there are no conflict copies.
- Creatures in a `.turnkeeper` file are referenced by bestiary key, so both devices should run the same
  bestiary import.
- Demiplane's sheet PDF has the wrong max HP, so PCs show only a max HP the GM types.
- The Demiplane API is undocumented and may change without notice.
