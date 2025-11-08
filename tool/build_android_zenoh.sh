#!/usr/bin/env bash
set -euo pipefail

# Builds Zenoh C for Android ABIs using the Android NDK.
# Requirements:
#   - ANDROID_NDK_HOME pointing to an installed NDK (r26 or newer recommended)
#   - CMake 3.22+
#   - Ninja (optional but faster)
#   - Zenoh source checkout path provided via ZENOH_SOURCE (defaults to ../zenoh)

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  echo "ANDROID_NDK_HOME is not set" >&2
  exit 1
fi

ZENOH_SOURCE=${ZENOH_SOURCE:-"../zenoh"}
if [[ ! -d "$ZENOH_SOURCE" ]]; then
  echo "Zenoh source not found at $ZENOH_SOURCE" >&2
  exit 1
fi

ABI_LIST=(arm64-v8a armeabi-v7a x86_64)
OUT_ROOT="native/android"

for ABI in "${ABI_LIST[@]}"; do
  BUILD_DIR="build/android/$ABI"
  INSTALL_DIR="$OUT_ROOT/$ABI"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

  cmake -S "$ZENOH_SOURCE" -B "$BUILD_DIR" \
    -DANDROID=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DANDROID_PLATFORM=android-24 \
    -DANDROID_ABI="$ABI" \
    -DANDROID_NDK="$ANDROID_NDK_HOME" \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -G Ninja

  cmake --build "$BUILD_DIR" --target zenoh-ffi
  cp "$BUILD_DIR/libzenoh-ffi.so" "$INSTALL_DIR/libzenoh.so"
  echo "Built $INSTALL_DIR/libzenoh.so"

done
