#!/usr/bin/env bash
set -euo pipefail

# Builds Zenoh for macOS (arm64 + x86_64) and combines into a universal dylib.
# Requirements:
#   - macOS with clang toolchain
#   - CMake 3.22+

ZENOH_SOURCE=${ZENOH_SOURCE:-"../zenoh"}
if [[ ! -d "$ZENOH_SOURCE" ]]; then
  echo "Zenoh source not found at $ZENOH_SOURCE" >&2
  exit 1
fi

BUILD_ROOT="build/macos"
OUT_DIR="native/macos"
rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT" "$OUT_DIR"

function build_arch() {
  local arch=$1
  local dir="$BUILD_ROOT/$arch"
  cmake -S "$ZENOH_SOURCE" -B "$dir" \
    -DCMAKE_OSX_ARCHITECTURES="$arch" \
    -DCMAKE_BUILD_TYPE=Release
  cmake --build "$dir" --target zenoh-ffi
  echo "$dir/libzenoh-ffi.dylib"
}

LIB_ARM64=$(build_arch arm64)
LIB_X86=$(build_arch x86_64)

lipo -create "$LIB_ARM64" "$LIB_X86" -output "$OUT_DIR/libzenoh.dylib"

echo "Universal binary ready at $OUT_DIR/libzenoh.dylib"
