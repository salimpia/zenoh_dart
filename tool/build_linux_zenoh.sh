#!/usr/bin/env bash
set -euo pipefail

# Builds Zenoh shared libraries for Linux targets using the host toolchain.
# Requirements:
#   - GCC or Clang
#   - CMake 3.22+

ZENOH_SOURCE=${ZENOH_SOURCE:-"../zenoh"}
if [[ ! -d "$ZENOH_SOURCE" ]]; then
  echo "Zenoh source not found at $ZENOH_SOURCE" >&2
  exit 1
fi

BUILD_ROOT="build/linux"
OUT_DIR="native/linux/host"
rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT" "$OUT_DIR"

cmake -S "$ZENOH_SOURCE" -B "$BUILD_ROOT" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_ROOT" --target zenoh-ffi

cp "$BUILD_ROOT/libzenoh-ffi.so" "$OUT_DIR/libzenoh.so"

echo "Shared library ready at $OUT_DIR/libzenoh.so"
