#!/bin/bash
set -e

# Configuration
APP_NAME="Task Scheduler.app"
SOURCE_DIR="./build_output"
DEST_DIR="/Applications/@My Apps"

echo "🚀 Starting Deployment for $APP_NAME..."

# 1. Check Source
if [ ! -d "$SOURCE_DIR/$APP_NAME" ]; then
    echo "❌ Error: Source app not found at $SOURCE_DIR/$APP_NAME"
    echo "   Please run ./build_app.sh first."
    exit 1
fi

# 2. Ensure Destination Directory Exists
if [ ! -d "$DEST_DIR" ]; then
    echo "📁 Creating destination directory: $DEST_DIR"
    mkdir -p "$DEST_DIR"
fi

# 3. Close App if Running
PROCESS_NAME=${APP_NAME%.app} # Remove .app extension for pgrep
if pgrep -x "$PROCESS_NAME" > /dev/null; then
    echo "🛑 Closing running instance of $PROCESS_NAME..."
    pkill -x "$PROCESS_NAME"
    # Wait a moment for it to close
    sleep 1
else
    echo "ℹ️  App is not currently running."
fi

# 4. Remove Old Version
if [ -d "$DEST_DIR/$APP_NAME" ]; then
    echo "🗑️  Removing old version from destination..."
    rm -rf "$DEST_DIR/$APP_NAME"
fi

# 5. Copy New Version
echo "📦 Copying new version to $DEST_DIR..."
cp -R "$SOURCE_DIR/$APP_NAME" "$DEST_DIR/$APP_NAME"

# 6. Reopen App
echo "🟢 Launching app..."
open "$DEST_DIR/$APP_NAME"

echo "🎉 Deployment Complete!"
