#!/bin/bash
set -euo pipefail

# Ensure Xcode.app toolchain is used even if xcode-select points at CLT,
# while still allowing CI to pin a specific Xcode with DEVELOPER_DIR.
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

APP_NAME="NotchAgent"
TARGET_NAME="NotchAgent"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
RESOURCE_DIR="Sources/NotchAgent/Resources"

BUILD_MAC=true
NOTARIZE=false

usage() {
    cat <<'EOF'
Usage: ./build.sh [--notarize]

  --notarize    Notarize macOS app bundle / DMG after signing
  --help        Show this help
EOF
}

for arg in "$@"; do
    case "$arg" in
        --notarize)
            NOTARIZE=true
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            usage >&2
            exit 1
            ;;
    esac
done

build_mac() {
    echo "Building $APP_NAME (universal)..."
    swift build -c release --arch arm64
    swift build -c release --arch x86_64

    echo "Creating universal binaries..."
    ARM_DIR=".build/arm64-apple-macosx/release"
    X86_DIR=".build/x86_64-apple-macosx/release"

    echo "Creating app bundle..."
    rm -rf "$APP_BUNDLE"
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Helpers"
    mkdir -p "$APP_BUNDLE/Contents/Resources"
    mkdir -p "$APP_BUNDLE/Contents/Frameworks"

    lipo -create "$ARM_DIR/$TARGET_NAME" "$X86_DIR/$TARGET_NAME" \
         -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    lipo -create "$ARM_DIR/notchagent-bridge" "$X86_DIR/notchagent-bridge" \
         -output "$APP_BUNDLE/Contents/Helpers/notchagent-bridge"
    lipo -create "$ARM_DIR/notchagent-cli" "$X86_DIR/notchagent-cli" \
         -output "$APP_BUNDLE/Contents/Helpers/notchagent-cli"
    cp Info.plist "$APP_BUNDLE/Contents/Info.plist"

    echo "Embedding frameworks..."
    # Sparkle.xcframework macos-arm64_x86_64 slice is already universal; copy as-is to preserve symlinks.
    SPARKLE_SRC=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
    if [ ! -d "$SPARKLE_SRC" ]; then
        echo "Missing Sparkle.framework at $SPARKLE_SRC" >&2
        exit 1
    fi
    ditto "$SPARKLE_SRC" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"

    # Add rpath so executables can locate embedded frameworks.
    install_name_tool -add_rpath "@executable_path/../Frameworks" \
        "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    install_name_tool -add_rpath "@executable_path/../../Frameworks" \
        "$APP_BUNDLE/Contents/Helpers/notchagent-bridge" 2>/dev/null || true

    echo "Copying prebuilt app icon assets..."
    cp "$RESOURCE_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    cp "$RESOURCE_DIR/Assets.car" "$APP_BUNDLE/Contents/Resources/Assets.car"

    # Copy SPM resource bundles into Contents/Resources/ (required for code signing)
    for bundle in .build/*/release/*.bundle; do
        if [ -e "$bundle" ]; then
            cp -R "$bundle" "$APP_BUNDLE/Contents/Resources/"
            break
        fi
    done

    echo "Clearing extended attributes before signing..."
    xattr -cr "$APP_BUNDLE"

    ENTITLEMENTS="NotchAgent.entitlements"

    # Use SIGN_ID env var, or auto-detect: prefer "Developer ID Application" for distribution,
    # fall back to any valid identity, then ad-hoc
    if [ -z "${SIGN_ID:-}" ]; then
        SIGN_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/' 2>/dev/null || true)
    fi
    if [ -z "$SIGN_ID" ]; then
        SIGN_ID=$(security find-identity -v -p codesigning | grep -v "REVOKED" | grep '"' | head -1 | sed 's/.*"\(.*\)".*/\1/' 2>/dev/null || true)
    fi
    if [ -z "$SIGN_ID" ]; then
        echo "No developer certificate found, using ad-hoc signing..."
        SIGN_ID="-"
    fi

    echo "Code signing ($SIGN_ID)..."
    # Sign embedded frameworks first (inside-out).
    SPARKLE_FW="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
    # Sign nested helpers inside Sparkle before the framework itself.
    for xpc in "$SPARKLE_FW/Versions/B/XPCServices/"*.xpc; do
        [ -e "$xpc" ] || continue
        codesign --force --options runtime --sign "$SIGN_ID" "$xpc"
    done
    if [ -d "$SPARKLE_FW/Versions/B/Updater.app" ]; then
        codesign --force --options runtime --sign "$SIGN_ID" "$SPARKLE_FW/Versions/B/Updater.app"
    fi
    if [ -e "$SPARKLE_FW/Versions/B/Autoupdate" ]; then
        codesign --force --options runtime --sign "$SIGN_ID" "$SPARKLE_FW/Versions/B/Autoupdate"
    fi
    codesign --force --options runtime --sign "$SIGN_ID" "$SPARKLE_FW"

    for helper in "$APP_BUNDLE/Contents/Helpers/"*; do
        [ -f "$helper" ] || continue
        codesign --force --options runtime --sign "$SIGN_ID" "$helper"
    done
    codesign --force --options runtime --sign "$SIGN_ID" --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

    if [ "$NOTARIZE" = true ] && [[ "$SIGN_ID" == *"Developer ID"* ]]; then
        echo "Creating ZIP for notarization..."
        ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
        ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

        echo "Submitting for notarization..."
        if xcrun notarytool submit "$ZIP_PATH" --keychain-profile "NotchAgent" --wait 2>&1 | tee /dev/stderr | grep -q "status: Accepted"; then
            echo "Stapling notarization ticket..."
            xcrun stapler staple "$APP_BUNDLE"
        else
            echo "ERROR: Notarization failed. Run 'xcrun notarytool log <submission-id> --keychain-profile NotchAgent' for details."
            rm -f "$ZIP_PATH"
            exit 1
        fi
        rm -f "$ZIP_PATH"

        echo "Creating DMG..."
        DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
        rm -f "$DMG_PATH"
        create-dmg \
            --volname "$APP_NAME" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "$APP_NAME.app" 150 185 \
            --app-drop-link 450 185 \
            --no-internet-enable \
            "$DMG_PATH" "$APP_BUNDLE"

        codesign --force --sign "$SIGN_ID" "$DMG_PATH"
        echo "Notarizing DMG..."
        if xcrun notarytool submit "$DMG_PATH" --keychain-profile "NotchAgent" --wait 2>&1 | tee /dev/stderr | grep -q "status: Accepted"; then
            xcrun stapler staple "$DMG_PATH"
            echo "DMG ready: $DMG_PATH"
        else
            echo "WARNING: DMG notarization failed, but app is notarized."
        fi
    fi

    echo "Done: $APP_BUNDLE"
    echo "Run: open $APP_BUNDLE"
}

if [ "$BUILD_MAC" = true ]; then
    build_mac
fi
