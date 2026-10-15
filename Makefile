.PHONY: build test lint coverage bestiary update-pf2e dmg cards icon app run install \
	ipad-simulator ipad-install ipad-uitest clean

build:
	swift build

test:
	swift test

lint:
	swiftlint --strict --quiet

# Runs the tests and fails when TurnkeeperKit's and CharacterImport's coverage is below 80%.
coverage:
	scripts/coverage.sh

# Re-imports creatures, conditions and the glossary from the pf2e release in pf2e.release (see
# scripts/import-bestiary.sh for the sources and their overrides).
bestiary:
	scripts/import-bestiary.sh

# Switches pf2e.release to pf2e's newest release and re-imports. GitHub does this weekly too.
update-pf2e:
	scripts/latest-pf2e-release.sh > pf2e.release
	scripts/import-bestiary.sh

# Packages the built app into build/Turnkeeper-<VERSION>.dmg.
dmg: app
	scripts/make-dmg.sh

app:
	scripts/build-app.sh

run: app
	open "build/Turnkeeper.app"

# Moves the built app into /Applications, replacing an earlier copy. The build copy is unregistered and
# removed so Finder and Spotlight launch the installed one.
LSREGISTER = /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
install: app
	rm -rf "/Applications/Turnkeeper.app"
	ditto "build/Turnkeeper.app" "/Applications/Turnkeeper.app"
	-$(LSREGISTER) -u "build/Turnkeeper.app" 2>/dev/null  # Fails when it was never registered, which is fine.
	rm -rf "build/Turnkeeper.app"

# Builds the iPad app and starts it in a simulator. IPAD_SIMULATOR names the simulator.
ipad-simulator:
	scripts/run-ipad-simulator.sh

# Builds the iPad app and installs it on a connected iPad. IPAD names the iPad.
# A free developer team's signature lasts 7 days, so run this again each week.
ipad-install:
	scripts/install-ipad.sh

# Redraws the Mac and iPad icons from scripts/make-icon.swift.
icon:
	swift scripts/make-icon.swift

# Runs the iPad UI tests in a simulator, against the demo fight. ONLY="DelayUITests ..." runs just those.
ipad-uitest:
	scripts/run-ipad-uitests.sh

# Renders battle cards to tmp/cards for comparing with the printed decks: make cards KEYS="key[:elite] ..."
cards:
	swift run CardSnapshots tmp/cards $(KEYS)

clean:
	rm -rf .build build ios/build
