#!/bin/bash
set -e

# Configuration
SCHEME="TaskScheduler"
PROJECT="TaskScheduler.xcodeproj"
BUILD_DIR="./build_output"
# Team ID found in project.pbxproj
TEAM_ID="252H5L8A2H"

# Function to get current marketing version
get_version() {
    # Try agvtool first
    local ver=$(agvtool what-marketing-version -terse1 2>/dev/null || true)
    
    # If empty, try grep from project file (fallback)
    if [ -z "$ver" ]; then
        ver=$(grep "MARKETING_VERSION =" "$PROJECT/project.pbxproj" | head -n 1 | sed 's/.*= //;s/;//' | tr -d '[:space:]')
    fi
    
    echo "$ver"
}

# Determine increment type
INCREMENT_TYPE="patch"
if [[ "$1" == "major" ]]; then
    INCREMENT_TYPE="major"
elif [[ "$1" == "minor" ]]; then
    INCREMENT_TYPE="minor"
fi

echo "📋 Preparing to build ($INCREMENT_TYPE increment)..."

# 0. Clean Build Directory
if [ -d "$BUILD_DIR" ]; then
    echo "🧹 Cleaning previous build artifacts..."
    rm -rf "$BUILD_DIR"
fi

# 1. Get Current Version
CURRENT_VERSION=$(get_version)
if [ -z "$CURRENT_VERSION" ]; then
    echo "⚠️  Could not detect current version. Defaulting to 1.0"
    CURRENT_VERSION="1.0"
fi
echo "   Current Version: $CURRENT_VERSION"

# 2. Calculate New Version
IFS='.' read -r -a parts <<< "$CURRENT_VERSION"
major="${parts[0]:-1}"
minor="${parts[1]:-0}"

NEW_VERSION="$CURRENT_VERSION"
VERSION_CHANGED=false

if [ "$INCREMENT_TYPE" == "major" ]; then
    major=$((major + 1))
    minor=0
    NEW_VERSION="$major.$minor"
    VERSION_CHANGED=true
elif [ "$INCREMENT_TYPE" == "minor" ]; then
    minor=$((minor + 1))
    NEW_VERSION="$major.$minor"
    VERSION_CHANGED=true
else
    # Patch increment: we stay on the same marketing version
    # but we will increment the build number below.
    NEW_VERSION="$CURRENT_VERSION"
fi

if [ "$VERSION_CHANGED" = true ]; then
    echo "   New Version:     $NEW_VERSION"
    echo "🔧 Updating Project Version..."
    xcrun agvtool new-marketing-version "$NEW_VERSION" > /dev/null
else
    echo "   Version remains: $NEW_VERSION"
fi

# 4. Increment Build Number (Project Version)
echo "🔧 Incrementing Build Number..."
# agvtool next-version handles the increment of CURRENT_PROJECT_VERSION
xcrun agvtool next-version -all > /dev/null

# Capture the new build number
NEW_BUILD_NUMBER=$(agvtool what-version -terse)
echo "   New Build Number: $NEW_BUILD_NUMBER"

# 5. Build
echo "🚀 Starting Release Build for $SCHEME..."

xcodebuild -project "$PROJECT" \
           -scheme "$SCHEME" \
           -configuration Release \
           -destination 'platform=macOS,arch=arm64' \
           clean build \
           DEVELOPMENT_TEAM="$TEAM_ID" \
           CODE_SIGN_STYLE="Automatic" \
           CODE_SIGNING_REQUIRED="YES" \
           CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
           MARKETING_VERSION="$NEW_VERSION" \
           CURRENT_PROJECT_VERSION="$NEW_BUILD_NUMBER" \
           -quiet

# 6. Copy Artifact
APP_PATH=$(find "$BUILD_DIR" -maxdepth 1 -name "*.app" | head -n 1)

if [ -n "$APP_PATH" ]; then
    APP_NAME=$(basename "$APP_PATH")
    echo "✅ Build successful! Found $APP_NAME"
    
    # Kill if running
    APP_PROCESS_NAME="${APP_NAME%.app}"
    if pgrep -x "$APP_PROCESS_NAME" > /dev/null 2>&1; then
        echo "🔪 Stopping running instance of $APP_PROCESS_NAME..."
        killall "$APP_PROCESS_NAME" 2>/dev/null || true
        sleep 0.5
    fi
    
    if [ -d "./$APP_NAME" ]; then
        rm -rf "./$APP_NAME"
    fi
    
    cp -R "$APP_PATH" "./$APP_NAME"
    touch "./$APP_NAME"
    echo "🎉 Done! version $NEW_VERSION (build $NEW_BUILD_NUMBER) is ready in this folder."
    open "./$APP_NAME"
else
    echo "❌ Build failed. Could not find .app."
    exit 1
fi
