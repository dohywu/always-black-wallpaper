#!/bin/zsh
# Builds "Always Black Wallpaper.app" with Xcode (Release).
# Usage: ./build.sh            -> build only
#        ./build.sh --install  -> also copies it to /Applications and launches it
set -euo pipefail

ROOT="${0:A:h}"
APP_NAME="Always Black Wallpaper"
# Keep build output outside the project: iCloud Drive adds xattrs to bundles in
# synced folders (~/Documents, ~/Desktop), which makes codesign fail.
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/AlwaysBlackWallpaper"
APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"

xcodebuild -project "$ROOT/AlwaysBlackWallpaper.xcodeproj" \
    -scheme AlwaysBlackWallpaper -configuration Release \
    -derivedDataPath "$DERIVED_DATA" -quiet build
echo "Built: $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x "$APP_NAME" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" /Applications/
    echo "Installed: /Applications/$APP_NAME.app"
    open "/Applications/$APP_NAME.app"
fi
