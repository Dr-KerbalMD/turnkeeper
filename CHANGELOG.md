# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.2] - 2026-10-23

### Fixed
- Let the iPad choose a device to sync with

[1.2.2]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.2.2

## [1.2.1] - 2026-10-23

### Fixed
- Show party members' names again, one row per character

### Changed
- Describe the v1.2.0 changes in the CHANGELOG

[1.2.1]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.2.1

## [1.2.0] - 2026-10-23

### Added
- Party members have a player's name and notes
- "Show Player Names" in the board's Fight menu shows "Character (Player)" on PC tiles (GM view only)

### Changed
- Knocking out a strip now applies unconscious and prone alongside dying
- Swiping right to left (or the context menu) on a dying strip stabilizes it: dying ends, unconscious stays, and wounded goes up by 1
- Stabilized and unconscious enemies show as down on the players' screen

[1.2.0]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.2.0

## [1.1.1] - 2026-10-20

### Added
- Import shared Demiplane characters without signing in
- Run Turnkeeper in the App Sandbox

### Fixed
- Let the whole party member row answer a right-click
- Swipe battle strips with two fingers on a Mac trackpad
- Lay out a creature's row for the Mac, with a trash button
- Bundle the universal binary from where SwiftPM built it

### Changed
- Specify importing shared characters without signing in
- Run the weekly pf2e update off the hour
- Take Tabletop Kit 0.15.1
- Specify running in the App Sandbox
- Watch every pf2e file the import reads
- Gate releases on the coverage check, as CI does

[1.1.1]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.1.1

## [1.1.0] - 2026-10-15

### Added
- List the bundled licenses on the About screen
- Bundle the license texts the app's content requires
- Show and use the picked difficulty for either scheme
- Pick Starfinder's Easier, Base or Harder from the party's points

### Fixed
- Resolve SonarCloud medium and high findings
- Decide sign-in navigation with a completion handler
- Limit the Demiplane sign-in to its own sites
- Write converted fonts only inside the repository
- Keep the Demiplane sign-in on secure pages

### Changed
- Add CI, SonarCloud, release and platform badges
- Exclude asset catalogs from SonarCloud analysis
- Share read-only bindings and alert cancel buttons
- Grant write access per job in the pf2e update
- Add CI with SonarCloud analysis
- Say the toolkit is Mac apps, two also on the iPad
- Credit the Roboto fonts
- Specify the license texts on Turnkeeper's About screen
- Tap the card where no link is, and find a PC card by its trait
- Rename the suite the Tableside Toolkit
- Specify Starfinder's Easier, Base and Harder by party points
- Sell the linked battle cards, live conditions and reusable encounters

[1.1.0]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.1.0

## [1.0.0] - 2026-10-14

### Added
- Initial release

[1.0.0]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.0.0
