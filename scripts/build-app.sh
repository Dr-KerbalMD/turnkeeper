#!/bin/sh
# Builds "build/Combat Pad.app" from the Swift package.
#
# VERSION    version written to the bundle (default 0.0.0)
# UNIVERSAL  set to 1 to build for both Apple silicon and Intel
set -eu

cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.0.0}"
APP="build/Combat Pad.app"
EXECUTABLE="CombatPad"

if [ "${UNIVERSAL:-0}" = "1" ]; then
    swift build -c release --arch arm64 --arch x86_64
    BINARY=".build/apple/Products/Release/$EXECUTABLE"
else
    swift build -c release
    BINARY="$(swift build -c release --show-bin-path)/$EXECUTABLE"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$EXECUTABLE"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# The imported bestiary and art (see "make bestiary"), bundled as a folder like on the iPad.
if [ -d Generated ]; then
    ditto Generated "$APP/Contents/Resources/Generated"
else
    echo "Warning: Generated/ is missing; run \"make bestiary\" to bundle the bestiary." >&2
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Combat Pad</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.scooper4711.CombatPad</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Combat Pad</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.role-playing-games</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Combat Pad listens while you hold Hold to Say Initiative, so you can say the initiative total.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Combat Pad turns the initiative you say into a number, on this device when it can.</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Combat Pad syncs encounters with your other devices on this network.</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_combatpad._tcp</string>
    </array>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Combat Pad Library</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>io.github.scooper4711.combatpad.library</string>
            </array>
        </dict>
    </array>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>io.github.scooper4711.combatpad.library</string>
            <key>UTTypeDescription</key>
            <string>Combat Pad Library</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.json</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>combatpad</string>
                </array>
            </dict>
        </dict>
    </array>
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>io.github.scooper4711.pluck.statblock</string>
            <key>UTTypeDescription</key>
            <string>Pathfinder Stat Block</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.json</string>
            </array>
        </dict>
    </array>
    <key>NSHumanReadableCopyright</key>
    <string>Not published, endorsed, or specifically approved by Paizo.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough to run locally; Gatekeeper will still ask on other Macs.
codesign --force --sign - "$APP"
# The bundle is rebuilt at the same path, so Finder and LaunchServices keep showing the icon they cached
# for it (none, from the first build). Touching it and re-registering makes them read the icon again.
touch "$APP"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$APP"
echo "Built $APP ($VERSION)"
