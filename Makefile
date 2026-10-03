.PHONY: build test lint bestiary app run install ipad-simulator ipad-install clean

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

clean:
	rm -rf .build build ios/build
