#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-sim}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="${LITERT_LM_BUILD_DIR:-/tmp/OpenEdgeLiteRTLMMinimal}"
MINIMAL_REPO="${LITERT_LM_MINIMAL_REPO:-https://github.com/scriptease/LiteRTLMMinimal.git}"
OUT_DIR="$PROJECT_ROOT/ios/Frameworks"
IOS_MIN_VERSION="${IOS_MIN_VERSION:-26.2}"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

case "$MODE" in
  sim)
    PLATFORMS=("ios_sim_arm64")
    ;;
  device)
    PLATFORMS=("ios_arm64")
    ;;
  all)
    PLATFORMS=("ios_arm64" "ios_sim_arm64")
    ;;
  *)
    echo "Usage: $0 [sim|device|all]"
    exit 1
    ;;
esac

if ! command -v bazel >/dev/null 2>&1; then
  echo "Bazelisk is required. Install it with: brew install bazelisk"
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required. Install Xcode and select it with xcode-select."
  exit 1
fi

if [ ! -d "$WORKDIR/.git" ]; then
  echo "==> Cloning LiteRT-LM minimal build workspace..."
  git clone --depth 1 "$MINIMAL_REPO" "$WORKDIR"
fi

if [ ! -d "$WORKDIR/LiteRT-LM/c" ]; then
  echo "==> Initializing LiteRT-LM submodule..."
  git -C "$WORKDIR" submodule update --init --depth 1
fi

echo "==> Building LiteRT-LM runtime slices: ${PLATFORMS[*]}"
for platform in "${PLATFORMS[@]}"; do
  if [ -f "$WORKDIR/build/lib/$platform/libc_engine.a" ]; then
    echo "    $platform already built."
  else
    bash "$WORKDIR/scripts/build-litert-macos.sh" "$platform"
  fi
done

WRAP_DIR="$WORKDIR/build/open-edge-wrapped-frameworks"
XCF_DIR="$WORKDIR/build/open-edge-xcframeworks"
rm -rf "$WRAP_DIR" "$XCF_DIR"
mkdir -p "$WRAP_DIR" "$XCF_DIR" "$OUT_DIR"

plist_platform() {
  case "$1" in
    ios_arm64) echo "iPhoneOS" ;;
    ios_sim_arm64) echo "iPhoneSimulator" ;;
    *) echo "iPhoneOS" ;;
  esac
}

wrap_static_litertlm_framework() {
  local platform="$1"
  local framework="$WRAP_DIR/$platform/LiteRTLM.framework"
  local plist_platform_name
  plist_platform_name="$(plist_platform "$platform")"

  mkdir -p "$framework/Headers"
  cp "$WORKDIR/build/lib/$platform/libc_engine.a" "$framework/LiteRTLM"
  cp "$WORKDIR/LiteRT-LM/c/engine.h" "$framework/Headers/engine.h"

  cat > "$framework/Headers/module.modulemap" <<'MODULEMAP'
framework module LiteRTLM {
  umbrella header "engine.h"
  export *
  module * { export * }
}
MODULEMAP

  cat > "$framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>LiteRTLM</string>
  <key>CFBundleIdentifier</key><string>ai.openedge.LiteRTLM</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>LiteRTLM</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleSupportedPlatforms</key><array><string>$plist_platform_name</string></array>
  <key>MinimumOSVersion</key><string>$IOS_MIN_VERSION</string>
</dict>
</plist>
PLIST
}

wrap_constraint_provider_framework() {
  local platform="$1"
  local framework="$WRAP_DIR/$platform/GemmaModelConstraintProvider.framework"
  local source="$WORKDIR/build/lib/$platform/libGemmaModelConstraintProvider.dylib"
  local plist_platform_name
  plist_platform_name="$(plist_platform "$platform")"

  mkdir -p "$framework"
  cp "$source" "$framework/GemmaModelConstraintProvider"
  install_name_tool -id \
    "@rpath/GemmaModelConstraintProvider.framework/GemmaModelConstraintProvider" \
    "$framework/GemmaModelConstraintProvider" 2>/dev/null || true

  cat > "$framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>GemmaModelConstraintProvider</string>
  <key>CFBundleIdentifier</key><string>ai.openedge.GemmaModelConstraintProvider</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>GemmaModelConstraintProvider</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleSupportedPlatforms</key><array><string>$plist_platform_name</string></array>
  <key>MinimumOSVersion</key><string>$IOS_MIN_VERSION</string>
</dict>
</plist>
PLIST
}

create_xcframework() {
  local name="$1"
  local args=()

  for platform in "${PLATFORMS[@]}"; do
    args+=("-framework" "$WRAP_DIR/$platform/$name.framework")
  done

  rm -rf "$XCF_DIR/$name.xcframework"
  xcodebuild -create-xcframework "${args[@]}" -output "$XCF_DIR/$name.xcframework"
  rm -rf "$OUT_DIR/$name.xcframework"
  cp -R "$XCF_DIR/$name.xcframework" "$OUT_DIR/$name.xcframework"
}

echo "==> Packaging XCFrameworks..."
for platform in "${PLATFORMS[@]}"; do
  wrap_static_litertlm_framework "$platform"
  wrap_constraint_provider_framework "$platform"
done

create_xcframework "LiteRTLM"
create_xcframework "GemmaModelConstraintProvider"

echo "==> Done. Frameworks are available in $OUT_DIR"
du -sh "$OUT_DIR"/*.xcframework
echo "==> Next: cd ios && pod install"
