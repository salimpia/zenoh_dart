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

- **Status**: Experimental WASM support via architecture changes.
- **Implementation**: Uses platform-specific code separation with conditional imports.
- **Future path**: Will integrate with zenoh-ts (Zenoh's TypeScript/JavaScript bindings) once fully production-ready.
- **Current state**: 
  - Platform interface defined (`ZenohClientInterface`)
  - Native implementation (`ZenohClientNative`) for desktop/mobile
  - Web stub implementation (`ZenohClientWeb`) ready for zenoh-ts integration
  - Automatic platform selection at compile time
- **To use on web** (when zenoh-ts is ready):
  1. Include zenoh-ts in your HTML: 
     ```html
     <script src="https://unpkg.com/@eclipse-zenoh/zenoh-ts@latest/dist/index.js"></script>
     ```
  2. The same Dart API will work across all platforms
  3. Complete the `ZenohClientWeb` implementation with actual JS interop calls
