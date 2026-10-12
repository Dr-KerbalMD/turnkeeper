# Combat Pad: requirements

Combat Pad is a private iPad and Mac app for running Pathfinder 2e and Starfinder 2e encounters at an
in-person table. It replaces the paper Paizo Combat Pad. The left half of the screen is the initiative
ladder, and the right half is the notes side, which shows the battle card of the active creature.

## R1 Platforms and sharing
- R1.1 The same app runs on iPad and Mac, with every feature available on both.
- R1.2 Planning data moves between devices in both directions as `.combatpad` files, through AirDrop,
  Files or Finder.
- R1.3 "Sync with nearby device" merges the libraries of two devices over the local network.
- R1.4 Merging never loses edits silently. When both sides changed the same record, the newer one wins
  and the other is kept as a conflict copy.
- R1.5 Nothing requires a paid Apple developer account. There is no iCloud or CloudKit.

## R2 Bestiary
- R2.1 The bundled bestiary contains every NPC and every complex hazard from the pf2e and sf2e packs in
  `~/git/pf2e`. Simple hazards are excluded.
- R2.2 `make bestiary` re-imports the bestiary. Running it twice on the same input produces identical
  output.
- R2.3 Creature art comes only from the user's own Paizo pawn, token and Battle Cards PDFs, read on the
  device by Tabletop Kit's art library; none is bundled. Creature Art (in the sidebar's toolbar) offers
  Import from Scrollkeeper, which watches the folder Scrollkeeper downloads to and adds its PDFs by reference
  (no copies; new downloads are added on request and at launch), and Add PDFs…, which keeps copies of other
  PDFs. Art is matched to creatures by name and game, remastered creatures preferring remastered products'
  art; a Battle Card's creature or a pawn gives the portrait, a token the token (else the portrait).
- R2.3a A referenced PDF that was deleted or moved is listed as missing in Creature Art, with the art it
  took away, and a creature whose art came only from missing PDFs says on its card which PDF it needs. Art
  returns when the PDF does (Check Again).
- R2.4 The import writes a report covering counts per pack and enrichers it couldn't parse.
- R2.5 The browser searches by name and trait, and filters by level, game, source, rarity, size and
  kind, and by source book. With a party chosen, the level filter starts at party level −4 to +4. The
  "Name or trait" field sits below the filters, directly above the results.
- R2.6 A creature's battle card can be opened from the browser and from its row in an encounter, with the
  slot's template applied.

## R3 Planning
- R3.1 A campaign has a game (Pathfinder or Starfinder), which sets the look and the default bestiary.
- R3.2 Parties are built separately from encounters. A quick PC has only a name and level; a PC can also
  be linked to a Demiplane character for a battle card (R6).
- R3.2a Campaigns can be renamed and switched between Pathfinder and Starfinder; a new one needs a name.
- R3.2a1 Each PC can have their own level, used for challenge points: the lowest allowed level of the
  scenario's level range gives 2 points, then 3, 4 and 6. The present players' total picks the matching
  difficulty label (such as 16–18 CP), which becomes the encounter's default difficulty. Without a match,
  a new encounter (nothing planned yet) opens at Base when the scheme has one, and others open at the
  difficulty last run.
- R3.2b Name fields capitalize each word and skip autocorrect, so fantasy names stay as typed.
- R3.3 A scenario holds ordered encounters and editable difficulty labels, filled from presets:
  Challenge Points low tier (10–11 … 16–18 CP), high tier (19–22 … 33+ CP), Easier/Base/Harder, or one
  version. Scenarios can be collapsed in the list; the choice is remembered on each device.
- R3.4 Each encounter has one variant per scheme label. Each variant has its own creatures, bench and
  events. A variant can be copied from another one.
- R3.5 A slot has a creature, count, template (elite, normal or weak), side, whether it starts on
  the bench, and the conditions and temporary HP its creatures start the fight with.
  Slots, events and party members each have a remove button (and a context menu item), since
  swipe-to-delete exists only on the iPad. Adding a creature that is already in the encounter adds a new
  slot, so one stack can be made weak or elite. Combatants of the same creature are numbered together across
  slots (Wolf 1, Wolf 2, even when one is weak), and on the board weak and elite strips have a colored border,
  a different color for each.
- R3.5a Custom creatures and complex hazards belong to a campaign and work everywhere bestiary creatures do
  (cards, templates, conditions, budget, initiative). They are made or edited in a form with a live battle
  card; lists are typed as printed ("Acrobatics +5", "2d8+11 bludgeoning plus 1d6 fire", "DC 22 basic
  Reflex"), and DCs and damage in ability text still adjust with templates and conditions.
  The bestiary browser lists the campaign's custom creatures first, with a Custom Creatures source filter.
  A custom creature's slot offers Edit Creature… and Delete Custom Creature… (which removes it from every
  encounter), and the editor's Paste button replaces it with a stat block copied from Pluck.
- R3.5b Stat blocks copied or dragged from Pluck (or pasted as plain text) become custom creatures in the
  encounter. A block for a subtier goes into the variant with that subtier; a summary lists what was added
  and anything kept as text, with Review… to open the editor.
- R3.5c Any creature can be given pasted artwork: Paste (an image copied from Pluck or anywhere), Choose
  Image…, or a drop onto its card or encounter row, plus ⌘V on the Mac. It replaces the bundled art
  everywhere, including the player view, travels with exports and nearby sync, and can be removed to go back
  to the bundled art.
- R3.5d Each scenario can have handouts: a name and one image (pasted, chosen or dropped), listed under its
  encounters. Show Players shows the image full screen with its name as a caption, on the second screen
  when there is one.
- R3.5e Notes come in two kinds, the same text in planning and on the board: creature notes, one per
  creature per scenario (on each encounter row, and under the card on that creature's turn), and the
  encounter's notes. On the board the card, creature notes and encounter notes are a split resized by
  dragging grips; a notes pane dragged small collapses to its header, a tap reopens it, a double-tap on a
  grip resets the split, and the split is remembered on each device.
- R3.5f A battle card, in planning and on the board, has a flip button (the circling-arrows symbol) that
  turns it over to show the GM the creature's art privately. On the board it turns back when the card
  changes to another combatant.
- R3.6 The encounter budget shows the XP total and threat for the party's level and size.
- R3.7 The scenario page shows every encounter against every variant, with each cell's XP and threat.
- R3.8 Planned events trigger at an initiative count, at the start or end of a round, or at the start or
  end of a combatant's turn. An event can recur every round, happen only in round N, or every N rounds
  starting at round M. An event can instead come at the end of combat: ending the fight (from the top bar
  or Victory!) first shows those events, then End Combat closes it.

## R4 Combat
- R4.1 Starting combat asks for the party and the variant. The scenario's last-used variant is the
  default.
- R4.2 Combat begins with a Setup phase. Nobody's initiative is rolled for them: the GM enters every total,
  creatures included, by keypad or by voice. Creatures show their initiative modifiers (Perception,
  Stealth and other skills, template and conditions applied) to do the math with. Benched creatures that
  join later get their number entered the same way.
- R4.2a Begin Combat warns, naming them, when anyone on the ladder has no initiative; Go Back outlines
  them, Begin Anyway puts them last.
- R4.3 In Setup only, one large Hold to Say Initiative button sits below the ladder (and on the Mac,
  holding I does the same). It sets the highlighted strip: the first without an initiative, or the one
  the GM tapped. Letting go sets the spoken total and moves the highlight to the next strip without one.
  A missed number shows a short message to try again; it never opens the keypad. Only numbers are
  recognized, never names, on the device where it can (else Apple's recognizer). While listening, the
  creature's modifiers are shown large. After Begin combat, nothing listens and strips are dragged to
  reorder.
- R4.4 Tiles show the name, initiative, HP and conditions, and a creature's or hazard's AC with its template
  and conditions applied (in yellow when they change it). Tiles are colored like magnets: red for
  enemies, blue for PCs, green for NPCs, gray for hazards.
- R4.5 Creature HP tracks damage, healing and temporary HP. PCs track no HP.
- R4.6 The template can be changed during combat. It recalculates the stats without changing the damage
  already taken.
- R4.7 Conditions are applied from a palette, shown as chips, and change the battle card's numbers.
  Changed numbers are tinted and show their breakdown on long-press or hover.
- R4.8 Benched creatures can be brought into combat at any time.
- R4.9 Durations and events count down and fire in rules order.
- R4.10 Turn reminders are modal and must be dismissed: slowed, stunned, quickened and dying at the
  start of a turn; persistent damage and frightened at the end of a turn; custom notes at either. Next
  is blocked until every reminder has been dismissed.
- R4.11 Every turn advance can be undone.
- R4.11a Closing the board never loses a fight: Run resumes the unfinished fight for that encounter and
  difficulty (shown as Resume, with Start Over behind a confirmation).
- R4.11b Reset Combat returns the fight to setup from the current plan; it can be undone.
- R4.11c When every enemy that joined the fight is at 0 HP, the app offers to end combat. Benched enemies,
  hazards and allies don't count. Finished fights can be reopened.
- R4.11d Changing an in-progress difficulty's creatures or events in the planner warns that the fight will
  be reset, and ends it if the GM goes ahead.
- R4.12 The battle card follows the current turn. Tapping a tile pins that card.
- R4.13 Art can be shown full screen; on the iPad the player view covers the whole screen. If an external display is connected, the art goes there.
- R4.14 The player view shows the creature's card back (R5.5) around its portrait from the user's PDFs.

## R5 Battle cards
- R5.1 The cards are Tabletop Kit's battle cards (shared with Field Guide), in a look of their own rather than
  Paizo's Battle Cards': Pathfinder on parchment in a stone frame, the level on a shield; Starfinder on a dark
  panel in steel brackets, the level in a hexagon; elites in a gold frame.
- R5.2 Their UI art comes from the user's own Rexard packs: `make bestiary` copies it into `Generated/CardArt`
  (`REXARD_PACKS`, default `~/Downloads`). Without it the cards are drawn in plain colors.
- R5.3 Complex hazards get a hazard card in the same style.
- R5.3a Every card shows its source book in small text at the bottom.
- R5.3b Words on a card that the Foundry data links to another entry are tappable: spells, items, strike
  effects, traits (on the trait line, Strikes and abilities), and links inside rules text, such as conditions,
  actions and spells. A tap (or click) shows a popover with the entry's name, category, traits and text. Links
  inside that popover open a second popover; links go two deep, and deeper ones read as plain text.
- R5.3c A card lists the immunities a creature's traits grant even when the Foundry data leaves them out:
  construct, mindless and swarm (Tabletop Kit's `TraitImmunities`). Hardness can't be derived, so a creature
  whose hardness is missing upstream has none on its card.
- R5.4 The card fronts are drawn in code, with free fonts. Paizo art comes only from the user's own purchased
  PDFs, read on the device, and is never bundled or committed.
- R5.5 Card backs show the creature in a landscape picked by its traits (Pathfinder) or glowing on a dark texture
  with its name on a terminal plate (Starfinder).

## R6 Player characters
- R6.1 A PC can be added from Demiplane by scanning the QR code on its character sheet (iPad), by pasting
  the sheet's link, its ID or an image of the QR code, or by importing a Demiplane campaign and choosing
  from its characters. A quick PC (name and level only) can be linked later, and a linked one unlinked.
- R6.2 Importing asks Demiplane to export the character sheet PDF and reads the computed numbers from it:
  AC, saves, Perception, skills, speeds, Strikes, spells, actions and reactions, feats, class features,
  items, languages and senses. Refreshing re-imports; a character that hasn't changed comes back at once.
  A refresh always says what happened: what changed ("Updated Eagan Norr: AC 18 → 19."), that nothing did
  (perhaps the player hasn't saved the rebuild), that the member isn't linked, and, when signed out, that
  Demiplane's last export was read. It never shows an old copy of the sheet from a cache.
  Importing again matches by the Demiplane character, so it never duplicates a PC.
  When an import fails, the reason shows in the import sheet at once, not after it closes.
- R6.3 A linked PC's tile pins a PC battle card in the same style as creature cards, with conditions
  applied to its numbers.
- R6.3a A linked member's battle card opens from its row in the party, without the Weak and Elite templates.
- R6.4 The PC card links spells, actions, reactions, feats, class features, items and traits to the
  Foundry glossary (R5.3b), matched by name for the character's game; a name without a match stays plain.
  Actions with a glossary entry show its rules text, else Demiplane's text.
- R6.5 Players track their own HP: PC tiles don't change (R4.4, R4.5). The GM may type a max HP, shown only
  on the card; imports never overwrite it.
- R6.6 Show Players for a PC shows only the card back, drawn around the Demiplane portrait.
- R6.7 Demiplane access is set up in the app: sign in through a Demiplane web page (needed for campaigns
  and sheet export, and to renew the token), or paste a token. The token stays in the device's Keychain;
  it is never synced or exported. Linked PCs and their sheets travel with the party like any other data.
