#!/bin/bash
set -e

# Configuration (overridable via env vars for CI/local parity)
APP_NAME="${APP_NAME_OVERRIDE:-Task Scheduler}"
APP_FILE="${APP_FILE_OVERRIDE:-$APP_NAME.app}"
DMG_NAME="${DMG_NAME_OVERRIDE:-TaskScheduler}"
SOURCE_APP="${APP_SOURCE_OVERRIDE:-./$APP_FILE}"
BUILD_DIR="${BUILD_DIR_OVERRIDE:-./build_output}"
DMG_DIR="${DMG_DIR_OVERRIDE:-./dmg_output}"
VOLUME_NAME="${DMG_VOLUME_NAME_OVERRIDE:-Task Scheduler Installer}"
BACKGROUND_FILE="${DMG_BACKGROUND_FILE_OVERRIDE:-dmg_background.png}"
REPO_URL="${DMG_REPO_URL_OVERRIDE:-https://github.com/kibermaks/TaskScheduler}"
INCLUDE_README="${DMG_INCLUDE_README_OVERRIDE:-false}"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}📦 Creating DMG for $APP_NAME...${NC}"

# Function to cleanup any stuck DMG mounts
cleanup_dmg_mounts() {
    echo -e "${BLUE}🧹 Cleaning up any stuck DMG mounts...${NC}"
    hdiutil detach "/Volumes/$VOLUME_NAME" -force 2>/dev/null || true
    pkill -9 diskimages-helper 2>/dev/null || true
    sleep 1
}

get_version() {
    grep "MARKETING_VERSION =" "TaskScheduler.xcodeproj/project.pbxproj" | head -n 1 | sed 's/.*= //;s/;//' | tr -d '[:space:]'
}

get_build_number() {
    grep "CURRENT_PROJECT_VERSION =" "TaskScheduler.xcodeproj/project.pbxproj" | head -n 1 | sed 's/.*= //;s/;//' | tr -d '[:space:]'
}

if [ ! -d "$SOURCE_APP" ]; then
    if [ -d "$BUILD_DIR/$APP_FILE" ]; then
        SOURCE_APP="$BUILD_DIR/$APP_FILE"
        echo -e "${YELLOW}ℹ️  Using app from build_output${NC}"
    else
        echo -e "${RED}❌ Error: $APP_FILE not found.${NC}"
        echo "   Please run ./build_app.sh first."
        exit 1
    fi
fi

VERSION="${DMG_VERSION_OVERRIDE:-$(get_version)}"
BUILD=$(get_build_number)

if [ -z "$VERSION" ]; then
    echo -e "${YELLOW}⚠️  Could not detect version. Using 'latest'${NC}"
    VERSION="latest"
fi

echo -e "   Version: ${GREEN}$VERSION${NC} (Build $BUILD)"

cleanup_dmg_mounts

if [ -d "$DMG_DIR" ]; then
    echo -e "${BLUE}🧹 Cleaning previous DMG artifacts...${NC}"
    rm -rf "$DMG_DIR"
fi
mkdir -p "$DMG_DIR"

TEMP_DMG_FOLDER="$DMG_DIR/temp_dmg"
mkdir -p "$TEMP_DMG_FOLDER"

echo -e "${BLUE}📋 Copying app bundle...${NC}"
cp -R "$SOURCE_APP" "$TEMP_DMG_FOLDER/$APP_FILE"

echo -e "${BLUE}🔗 Creating Applications shortcut...${NC}"
ln -s /Applications "$TEMP_DMG_FOLDER/Applications"

# Copy background if it exists
if [ -f "$BACKGROUND_FILE" ]; then
    mkdir -p "$TEMP_DMG_FOLDER/.background"
    cp "$BACKGROUND_FILE" "$TEMP_DMG_FOLDER/.background/"
fi

INCLUDE_README_NORMALIZED=$(printf '%s' "$INCLUDE_README" | tr '[:upper:]' '[:lower:]')
if [ "$INCLUDE_README_NORMALIZED" = "true" ]; then
    cat > "$TEMP_DMG_FOLDER/README.txt" <<EOF
$APP_NAME - Installation Instructions
=====================================

To install $APP_NAME:

1. Drag "$APP_FILE" to the "Applications" folder
2. Open from Applications or Spotlight
3. Grant Calendar permissions when prompted
4. Start scheduling your productive day!

Requirements:
- macOS 13.0 or later
- Calendar access (requested on first launch)

For more information, visit:
$REPO_URL

---
$APP_NAME is open source software released under the MIT License.
EOF
fi

DMG_FILENAME="${DMG_FILENAME_OVERRIDE:-$DMG_NAME-$VERSION.dmg}"
DMG_PATH="$DMG_DIR/$DMG_FILENAME"

if [ -f "$DMG_PATH" ]; then
    rm "$DMG_PATH"
fi

echo -e "${BLUE}🎨 Creating DMG...${NC}"

TEMP_DMG="$DMG_DIR/temp.dmg"

hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$TEMP_DMG_FOLDER" \
    -ov \
    -format UDRW \
    "$TEMP_DMG" \
    > /dev/null

echo -e "${BLUE}🔧 Configuring DMG layout...${NC}"
MOUNT_DIR="/Volumes/$VOLUME_NAME"
hdiutil attach "$TEMP_DMG" -mountpoint "$MOUNT_DIR" -nobrowse > /dev/null

# Set up the DMG window with custom background and layout
osascript <<EOF > /dev/null 2>&1 || true
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 1000, 550}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background picture of viewOptions to file ".background:$BACKGROUND_FILE"
        set position of item "$APP_FILE" of container window to {125, 185}
        set position of item "Applications" of container window to {465, 185}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

echo -e "${BLUE}💾 Finalizing DMG...${NC}"
sync
hdiutil detach "$MOUNT_DIR" -force > /dev/null 2>&1 || true
sleep 2

hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" \
    > /dev/null 2>&1

# Cleanup again just to be safe
cleanup_dmg_mounts

echo -e "${BLUE}🧹 Cleaning up...${NC}"
rm -rf "$TEMP_DMG_FOLDER"
rm "$TEMP_DMG"

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)

echo ""
echo -e "${GREEN}✅ DMG created successfully!${NC}"
echo -e "   📍 Location: ${BLUE}$DMG_PATH${NC}"
echo -e "   📊 Size: ${YELLOW}$DMG_SIZE${NC}"
echo -e "   🏷️  Version: ${GREEN}$VERSION${NC} (Build $BUILD)"
echo ""
echo -e "${BLUE}🚀 Ready for distribution!${NC}"

if [ -z "${CI:-}" ] && command -v open &> /dev/null; then
    open "$DMG_DIR"
fi
