.PHONY: build test lint bestiary cards app run install ipad-simulator ipad-install ipad-uitest clean

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
	open "build/Combat Pad.app"

# Copies the built app into /Applications, replacing an earlier copy.
install: app
	rm -rf "/Applications/Combat Pad.app"
	ditto "build/Combat Pad.app" "/Applications/Combat Pad.app"

# Builds the iPad app and starts it in a simulator. IPAD_SIMULATOR names the simulator.
ipad-simulator:
	scripts/run-ipad-simulator.sh

# Builds the iPad app and installs it on a connected iPad. IPAD names the iPad.
# A free developer team's signature lasts 7 days, so run this again each week.
ipad-install:
	scripts/install-ipad.sh

# Runs the iPad UI tests in a simulator, against the demo fight.
ipad-uitest:
	scripts/run-ipad-uitests.sh

# Renders battle cards to tmp/cards for comparing with the printed decks: make cards KEYS="key[:elite] ..."
cards:
	swift run CardSnapshots tmp/cards $(KEYS)

clean:
	rm -rf .build build ios/build
