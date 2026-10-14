.PHONY: build test lint bestiary cards icon app run install ipad-simulator ipad-install ipad-uitest clean

build:
	swift build

test:
	swift test

lint:
	swiftlint --strict --quiet

# Re-imports creatures, conditions and art from ~/git/pf2e, the Foundry modules and the Paizo PDFs.
# PF2E_REPO, FOUNDRY_MODULES and SCROLLKEEPER_FILES override the source locations.
bestiary:
	scripts/import-bestiary.sh

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
