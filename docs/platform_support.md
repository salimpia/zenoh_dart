# Platform Support Strategy

This document outlines how the `zenoh_dart` package prepares native binaries for each Flutter-supported platform.

## Android

- **Build system**: Android NDK via CMake.
- **Artifacts**: `libzenoh.so` for `arm64-v8a`, `armeabi-v7a`, and `x86_64`.
- **Workflow**:
  1. Fetch Zenoh source (tag v1.6.2 or newer).
  2. Use the NDK toolchain file in conjunction with CMake to produce `.so` libraries.
  3. Copy outputs into `native/android/<abi>/` for bundling.
- **Automation**: `tool/build_android_zenoh.sh` (see below) compiles all ABIs in one run when executed on Linux/macOS with the NDK installed.

## iOS

- **Build system**: Xcode toolchain (clang + `xcodebuild`).
- **Artifacts**: XCFramework containing Zenoh static libraries for device and simulator.
- **Workflow**:
  1. Build static libraries for `iphoneos` and `iphonesimulator`.
  2. Wrap them into `zenoh.xcframework`.
  3. Place the resulting bundle under `native/ios/Frameworks/`.
- **Automation**: `tool/build_ios_zenoh.sh` orchestrates the two-stage build when run on macOS with Xcode.

## macOS

- **Preferred path**: Consume the prebuilt ZIP from official releases (`tool/fetch_zenoh_binaries.dart`).
- **Alternate path**: `tool/build_macos_zenoh.sh` builds universal binaries if a custom compile is required.

## Windows

- **Preferred path**: Use the MSVC or MinGW prebuilt ZIPs downloaded by `tool/fetch_zenoh_binaries.dart`.
- **Alternate path**: `tool/build_windows_zenoh.ps1` provides a PowerShell script that configures and builds with Visual Studio.

## Linux

- **Preferred path**: Use prebuilt GNU/Linux ZIPs.
- **Alternate path**: `tool/build_linux_zenoh.sh` builds using the host GCC/Clang toolchain.

## Web

- Currently unsupported; targeting WebAssembly once upstream Zenoh exposes the necessary interfaces.
