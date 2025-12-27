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
INCREMENT_TYPE="minor"
if [[ "$1" == "major" ]]; then
    INCREMENT_TYPE="major"
fi

echo "📋 Preparing to build ($INCREMENT_TYPE increment)..."

# 1. Get Current Version
CURRENT_VERSION=$(get_version)
if [ -z "$CURRENT_VERSION" ]; then
    echo "⚠️  Could not detect current version. Defaulting to 1.0"
    CURRENT_VERSION="1.0"
fi
echo "   Current Version: $CURRENT_VERSION"

# 2. Calculate New Version
IFS='.' read -r -a parts <<< "$CURRENT_VERSION"
major="${parts[0]}"
minor="${parts[1]:-0}"
patch="${parts[2]:-0}"

if [ "$INCREMENT_TYPE" == "major" ]; then
    major=$((major + 1))
    minor=0
    patch=0
else
    # Default to minor increment
    minor=$((minor + 1))
fi

NEW_VERSION="$major.$minor"
# If there was a patch originally, keep format? usually X.Y is enough for marketing. 
# Let's clean it to X.Y
echo "   New Version:     $NEW_VERSION"

# 3. Apply New Version
echo "🔧 Updating Project Version..."
# Use agvtool to set new marketing version
xcrun agvtool new-marketing-version "$NEW_VERSION" > /dev/null

# 4. Increment Build Number (Project Version)
echo "🔧 Incrementing Build Number..."
xcrun agvtool next-version -all > /dev/null

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
           -quiet

# 6. Copy Artifact
APP_PATH=$(find "$BUILD_DIR" -maxdepth 1 -name "*.app" | head -n 1)

if [ -n "$APP_PATH" ]; then
    APP_NAME=$(basename "$APP_PATH")
    echo "✅ Build successful! Found $APP_NAME"
    
    if [ -d "./$APP_NAME" ]; then
        rm -rf "./$APP_NAME"
    fi
    
    cp -R "$APP_PATH" "./$APP_NAME"
    echo "🎉 Done! version $NEW_VERSION is ready in this folder."
else
    echo "❌ Build failed. Could not find .app."
    exit 1
fi
