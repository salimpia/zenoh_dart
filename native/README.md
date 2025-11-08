# Native binary layout

Place platform-specific Zenoh binaries in the following structure:

```
native/
  android/
    arm64-v8a/libzenoh.so
    armeabi-v7a/libzenoh.so
    x86_64/libzenoh.so
  ios/
    Frameworks/zenoh.xcframework
  macos/
    aarch64/libzenoh.dylib
    x86_64/libzenoh.dylib
  linux/
    x86_64/libzenoh.so
    aarch64/libzenoh.so
  windows/
    x64/zenoh.dll
```

Future automation will download and verify these assets from official Zenoh releases.

The `tool/zenoh_binaries.json` file controls where the fetch script stores each artifact. Update the URLs and SHA-256 checksums when a new Zenoh release is published, then run:

```
dart run tool/fetch_zenoh_binaries.dart
```

The script currently downloads standalone ZIP archives for desktop targets. After download, extract the shared library (`libzenoh.so`, `libzenoh.dylib`, or `zenoh.dll`) into the same directory hierarchy illustrated above.

Alternatively, use the build scripts in `tool/` to compile Zenoh from source when official artifacts are unavailable:

- `tool/build_android_zenoh.sh` – builds using the Android NDK.
- `tool/build_ios_zenoh.sh` – creates an XCFramework on macOS.
- `tool/build_macos_zenoh.sh`, `tool/build_linux_zenoh.sh`, `tool/build_windows_zenoh.ps1` – rebuild desktop binaries.
