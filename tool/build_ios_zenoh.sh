#!/usr/bin/env bash
set -euo pipefail

# Builds Zenoh static libraries for iOS and packages them into an XCFramework.
# Requirements:
#   - macOS with Xcode Command Line Tools
#   - ZENOH_SOURCE pointing to zenoh repository (defaults to ../zenoh)
#   - CMake 3.22+

ZENOH_SOURCE=${ZENOH_SOURCE:-"../zenoh"}
if [[ ! -d "$ZENOH_SOURCE" ]]; then
  echo "Zenoh source not found at $ZENOH_SOURCE" >&2
  exit 1
fi

BUILD_ROOT="build/ios"
OUT_DIR="native/ios/Frameworks"
rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT" "$OUT_DIR"

function build_arch() {
  local sdk=$1
  local archs=$2
  local dir_suffix=${archs//;/_}
  local build_dir="$BUILD_ROOT/$sdk-$dir_suffix"
  cmake -S "$ZENOH_SOURCE" -B "$build_dir" \
    -GXcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES="$archs" \
    -DCMAKE_OSX_SYSROOT="$sdk" \
    -DCMAKE_TRY_COMPILE_OSX_ARCHITECTURES="$archs" \
    -DCMAKE_IOS_INSTALL_COMBINED=YES \
    -DCMAKE_BUILD_TYPE=Release
  cmake --build "$build_dir" --config Release --target zenoh-ffi
  echo "$build_dir/Release-$sdk/libzenoh-ffi.a"
}

IPHONE_LIB=$(build_arch iphoneos arm64)
SIM_LIB=$(build_arch iphonesimulator "x86_64;arm64")

xcodebuild -create-xcframework \
  -library "$IPHONE_LIB" \
  -library "$SIM_LIB" \
  -output "$OUT_DIR/zenoh.xcframework"

echo "XCFramework ready at $OUT_DIR/zenoh.xcframework"
