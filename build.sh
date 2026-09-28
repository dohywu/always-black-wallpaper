#!/bin/zsh
# Builds "Always Black Wallpaper.app" with swiftc only (works without full Xcode).
# Usage: ./build.sh            -> build/Always Black Wallpaper.app
#        ./build.sh --install  -> also copies it to /Applications and launches it
set -euo pipefail

ROOT="${0:A:h}"
APP_NAME="Always Black Wallpaper"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"

extra_flags=()
# Some Command Line Tools releases ship both module.modulemap and bridging.modulemap
# for SwiftBridging, which breaks importing ServiceManagement ("redefinition of module
# 'SwiftBridging'"). Hide the duplicate with a VFS overlay instead of editing system files.
SWIFT_INCLUDE="$(xcode-select -p)/usr/include/swift"
if [[ -f "$SWIFT_INCLUDE/module.modulemap" && -f "$SWIFT_INCLUDE/bridging.modulemap" ]]; then
    mkdir -p "$BUILD_DIR/tmp"
    : > "$BUILD_DIR/tmp/empty.modulemap"
    cat > "$BUILD_DIR/tmp/overlay.yaml" <<EOF
{ "version": 0, "case-sensitive": "false", "roots": [ { "type": "file",
  "name": "$SWIFT_INCLUDE/module.modulemap",
  "external-contents": "$BUILD_DIR/tmp/empty.modulemap" } ] }
EOF
    extra_flags=(-vfsoverlay "$BUILD_DIR/tmp/overlay.yaml" -Xcc -ivfsoverlay -Xcc "$BUILD_DIR/tmp/overlay.yaml")
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -parse-as-library \
    -sdk "$SDK" -target "$ARCH-apple-macos15.0" \
    "${extra_flags[@]}" \
    "$ROOT"/AlwaysBlackWallpaper/*.swift \
    -o "$APP/Contents/MacOS/$APP_NAME"

cp "$ROOT/AlwaysBlackWallpaper/Info.plist" "$APP/Contents/Info.plist"
xattr -cr "$APP"
codesign --force --sign - "$APP"
echo "Built: $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x "$APP_NAME" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" /Applications/
    echo "Installed: /Applications/$APP_NAME.app"
    open "/Applications/$APP_NAME.app"
fi
