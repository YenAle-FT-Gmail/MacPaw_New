#!/bin/bash
# build_dmg.sh — Build, sign, notarize, and package BlackBox.app into a DMG
set -euo pipefail

APP_NAME="BlackBox"
SCHEME="BlackBox"
BUILD_DIR="$(pwd)/.build/release"
DMG_DIR="$(pwd)/.build/dmg"
DMG_NAME="${APP_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"

# ─── CONFIGURATION ───
# Set these env vars or edit directly:
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}" # e.g. "Developer ID Application: Your Name (TEAMID)"
TEAM_ID="${TEAM_ID:-}"
BUNDLE_ID="com.blackbox.privacy"
NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-}" # Keychain profile from `xcrun notarytool store-credentials`

echo "╔══════════════════════════════════════╗"
echo "║     BlackBox DMG Build Script        ║"
echo "╚══════════════════════════════════════╝"

# ─── Step 1: Build release ───
echo ""
echo "▸ Building release..."
swift build -c release 2>&1 | tail -5

# ─── Step 2: Create .app bundle ───
echo "▸ Creating .app bundle..."
APP_BUNDLE="${DMG_DIR}/${APP_NAME}.app"
rm -rf "${DMG_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Copy resources
if [ -d "${BUILD_DIR}/${APP_NAME}_${APP_NAME}.resources" ]; then
    cp -R "${BUILD_DIR}/${APP_NAME}_${APP_NAME}.resources/"* "${APP_BUNDLE}/Contents/Resources/" 2>/dev/null || true
fi

# Copy icon
if [ -f "BlackBox/Resources/AppIcon.png" ]; then
    cp "BlackBox/Resources/AppIcon.png" "${APP_BUNDLE}/Contents/Resources/"
fi

# Copy entitlements
if [ -f "BlackBox/Resources/BlackBox.entitlements" ]; then
    cp "BlackBox/Resources/BlackBox.entitlements" "${APP_BUNDLE}/Contents/Resources/"
fi

# Create Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 BlackBox. All rights reserved.</string>
</dict>
</plist>
PLIST

echo "  ✓ ${APP_NAME}.app created"

# ─── Step 3: Code signing (optional) ───
if [ -n "${SIGNING_IDENTITY}" ]; then
    echo "▸ Code signing with: ${SIGNING_IDENTITY}"
    codesign --force --options runtime \
        --entitlements "BlackBox/Resources/BlackBox.entitlements" \
        --sign "${SIGNING_IDENTITY}" \
        "${APP_BUNDLE}"
    echo "  ✓ Signed"
else
    echo "▸ Skipping code signing (set SIGNING_IDENTITY env var)"
fi

# ─── Step 4: Create DMG ───
echo "▸ Creating DMG..."
DMG_TEMP="${DMG_DIR}/temp.dmg"
DMG_FINAL="${DMG_DIR}/${DMG_NAME}"

# Create temp DMG
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov -format UDRW \
    "${DMG_TEMP}" > /dev/null

# Mount
MOUNT_POINT=$(hdiutil attach "${DMG_TEMP}" -readwrite -noverify | grep "/Volumes/" | awk '{print $3}')
echo "  Mounted at: ${MOUNT_POINT}"

# Add Applications symlink
ln -sf /Applications "${MOUNT_POINT}/Applications"

# Set background and layout with AppleScript
osascript << 'APPLESCRIPT'
tell application "Finder"
    try
        set diskName to "BlackBox"
        set theDisk to disk diskName
        open theDisk
        set current view of container window of theDisk to icon view
        set opts to icon view options of container window of theDisk
        set icon size of opts to 128
        set arrangement of opts to not arranged
        set position of item "BlackBox.app" of theDisk to {160, 200}
        set position of item "Applications" of theDisk to {480, 200}
        close container window of theDisk
    end try
end tell
APPLESCRIPT

# Unmount
hdiutil detach "${MOUNT_POINT}" > /dev/null 2>&1 || true

# Convert to compressed final DMG
hdiutil convert "${DMG_TEMP}" -format UDZO -o "${DMG_FINAL}" > /dev/null
rm -f "${DMG_TEMP}"

echo "  ✓ ${DMG_NAME} created"

# ─── Step 5: Notarize (optional) ───
if [ -n "${NOTARIZE_PROFILE}" ] && [ -n "${TEAM_ID}" ]; then
    echo "▸ Notarizing..."
    xcrun notarytool submit "${DMG_FINAL}" \
        --keychain-profile "${NOTARIZE_PROFILE}" \
        --team-id "${TEAM_ID}" \
        --wait
    
    echo "▸ Stapling..."
    xcrun stapler staple "${DMG_FINAL}"
    echo "  ✓ Notarized and stapled"
else
    echo "▸ Skipping notarization (set NOTARIZE_PROFILE and TEAM_ID env vars)"
fi

# ─── Done ───
DMG_SIZE=$(du -h "${DMG_FINAL}" | awk '{print $1}')
echo ""
echo "═══════════════════════════════════════"
echo "  ✓ Build complete!"
echo "  → ${DMG_FINAL} (${DMG_SIZE})"
echo "═══════════════════════════════════════"
