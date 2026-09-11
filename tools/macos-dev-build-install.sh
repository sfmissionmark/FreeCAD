#!/usr/bin/env bash
# Build the pixi/conda dev tree and drop a thin launcher app in /Applications
# so FreeCAD can be started like any other Mac app. This is a convenience
# wrapper around `pixi run configure/build/install`, not a relocatable
# macOS .app bundle -- the launcher just execs the binary from this checkout,
# so the checkout has to stay in place.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

BUILD_TYPE="${1:-debug}"

# conda-forge's clang toolchain on this machine chokes on the macOS SDK that
# ships with Xcode-beta (the active `xcode-select` toolchain) -- <complex>
# ends up with undeclared NAN/INFINITY. Pin to the stable Xcode's SDK for
# configure if it's present; otherwise fall back to whatever xcrun resolves.
STABLE_SDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
if [[ -d "$STABLE_SDK" ]]; then
  export SDKROOT="$STABLE_SDK"
fi

pixi run "configure-${BUILD_TYPE}"
pixi run "build-${BUILD_TYPE}"
pixi run "install-${BUILD_TYPE}"

BIN="$PROJECT_DIR/.pixi/envs/default/bin/FreeCAD"
APP="/Applications/FreeCAD-dev.app"
MACOS_DIR="$APP/Contents/MacOS"

mkdir -p "$MACOS_DIR" "$APP/Contents/Resources"

bash "$PROJECT_DIR/tools/macos-build-icon.sh" "$APP/Contents/Resources/FreeCAD-dev.icns"

cat > "$MACOS_DIR/FreeCAD-dev" <<EOF
#!/usr/bin/env bash
exec "$BIN" "\$@"
EOF
chmod +x "$MACOS_DIR/FreeCAD-dev"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>FreeCAD-dev</string>
  <key>CFBundleIdentifier</key>
  <string>org.freecad.FreeCAD-dev</string>
  <key>CFBundleName</key>
  <string>FreeCAD (dev)</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${BUILD_TYPE}</string>
  <key>CFBundleIconFile</key>
  <string>FreeCAD-dev.icns</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>FCStd</string>
        <string>FCMat</string>
        <string>FCParam</string>
      </array>
      <key>LSItemContentTypes</key>
      <array>
        <string>org.freecad.fcstd</string>
      </array>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Owner</string>
    </dict>
    <dict>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>FCMacro</string>
        <string>FCScript</string>
      </array>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Owner</string>
    </dict>
  </array>
  <key>UTExportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key>
      <string>org.freecad.fcstd</string>
      <key>UTTypeDescription</key>
      <string>FreeCAD Document</string>
      <key>UTTypeConformsTo</key>
      <array>
        <string>public.data</string>
      </array>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array>
          <string>FCStd</string>
        </array>
      </dict>
    </dict>
  </array>
</dict>
</plist>
PLIST

# Nudge Launch Services / Finder to notice the (re)built app, then re-register
# it so the document-type associations above actually take.
touch "$APP"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$APP"
fi

# Make FreeCAD-dev the default handler for its own document types. `duti`
# drives the same Launch Services API as Finder's "Open With > Change All".
if ! command -v duti >/dev/null 2>&1 && command -v brew >/dev/null 2>&1; then
  brew install duti >/dev/null 2>&1 || true
fi
if command -v duti >/dev/null 2>&1; then
  duti -s org.freecad.FreeCAD-dev org.freecad.fcstd all 2>/dev/null || true
  for ext in FCStd FCMat FCParam FCMacro FCScript; do
    duti -s org.freecad.FreeCAD-dev "$ext" all 2>/dev/null || true
  done
  echo "FreeCAD-dev.app set as default handler for FreeCAD document types."
else
  echo "duti not available -- skipped setting default file handler." \
       "Install with 'brew install duti' or set it via Finder > Get Info > Open With > Change All."
fi


# Icon caches are notoriously sticky -- force a redraw.
touch "$APP"
killall Finder >/dev/null 2>&1 || true
killall Dock >/dev/null 2>&1 || true

echo "FreeCAD (dev) installed: $APP -> $BIN"
