# Copilot Instructions for zenoh_dart

## Project Overview
This is a Dart/Flutter FFI plugin providing bindings to Eclipse Zenoh (<https://zenoh.io>) middleware. The project bundles prebuilt native Zenoh libraries for Android, iOS, macOS, Windows, and Linux platforms, and exposes an idiomatic Dart API wrapping Zenoh's pub/sub and query capabilities.

## Architecture

### Three-Layer FFI Design
1. **Native binaries** (`native/`): Platform-specific Zenoh C libraries (`.so`, `.dylib`, `.dll`)
2. **Low-level bindings** (`lib/src/bindings/`):
   - `zenoh_bindings.dart`: Handcrafted FFI typedefs for core functions (`zn_open`, `zn_close`, etc.)
   - `zenoh_generated.dart`: Auto-generated via `ffigen` from `native/include/zenoh.h`
   - `native_library.dart`: Platform-aware dynamic library loader
3. **High-level API** (`lib/src/`): Idiomatic Dart wrappers (`ZenohClient`, `ZenohPublisher`, etc.) managing session lifecycle and memory

### Critical Paths
- **Session initialization**: `ZenohClient.connect()` → `NativeLibrary.ensureBindings()` → `DynamicLibrary.open()`
- **Publishing flow**: `declarePublisher()` → `publish()` → `znPut()` native call with manual memory management via `ffi.calloc`
- **Memory safety**: All FFI pointer allocations MUST be freed in `finally` blocks (see `zenoh_client.dart` for pattern)

## Development Workflows

### Regenerating FFI Bindings
When `native/include/zenoh.h` is updated:
```bash
dart run ffigen
```
This overwrites `lib/src/bindings/zenoh_generated.dart`. Update `zenoh_bindings.dart` manually if new functions are needed before full generation is complete.

### Fetching Native Binaries
Download prebuilt Zenoh libraries (defined in `tool/zenoh_binaries.json`):
```bash
dart run tool/fetch_zenoh_binaries.dart
```
- Downloads ZIPs from GitHub releases, verifies SHA-256 checksums
- Currently desktop platforms only; Android/iOS entries are TODO
- After download, manually extract `.so`/`.dylib`/`.dll` into the correct `native/<platform>/<arch>/` subdirectories

### Building Binaries from Source
When official releases are unavailable:
- **Android**: `tool/build_android_zenoh.sh` (requires Android NDK)
- **iOS**: `tool/build_ios_zenoh.sh` (macOS + Xcode, produces XCFramework)
- **macOS/Linux/Windows**: `tool/build_macos_zenoh.sh`, `tool/build_linux_zenoh.sh`, `tool/build_windows_zenoh.ps1`

See `docs/platform_support.md` for detailed build requirements per platform.

### Testing
Run unit tests (currently limited due to missing native binaries):
```bash
flutter test
```
Add integration tests in `test/` once all platforms have working binaries. Tests validate session lifecycle and pub/sub flows.

## Project-Specific Conventions

### Native Binary Organization
```
native/<platform>/<arch>/<library_name>
```
Example: `native/windows/x64/zenoh.dll`, `native/linux/x86_64/libzenoh.so`

### FFI Pattern: Manual Memory Management
All pointer allocations use `ffi.calloc` and require explicit cleanup:
```dart
final ptr = ffi.calloc<Type>();
try {
  // Use pointer
} finally {
  ffi.calloc.free(ptr);
}
```
NEVER rely on Dart GC for FFI memory—always use `finally` blocks.

### Error Handling Convention
Native calls return `int` error codes (0 = success). Wrap failures with `ZenohNativeCallException`:
```dart
final rc = bindings.znOpen(sessionPtr, configPtr.cast());
if (rc != 0) {
  throw ZenohNativeCallException('zn_open failed', errorCode: rc);
}
```

### Configuration as JSON
`ZenohConfig` serializes to JSON strings passed to the native layer:
```dart
final configJson = jsonEncode(config.toJson());
final configPtr = configJson.toNativeUtf8(allocator: ffi.calloc);
```

### Platform Detection in `native_library.dart`
The library filename resolver uses `Platform.isMacOS`, `Platform.isWindows`, etc. to select the correct library name. Fallback behavior: try bundled path first, then system-wide lookup.

## Integration Points

### External Dependencies
- **Zenoh C library**: Core dependency, version pinned to 1.6.2 (see `tool/zenoh_binaries.json`)
- **FFI packages**: `ffi` for bindings, `ffigen` for code generation
- **crypto**: Used in `fetch_zenoh_binaries.dart` for SHA-256 verification

### Plugin Registration (`pubspec.yaml`)
Declared as `ffiPlugin: true` for all native platforms. Web support is stubbed with `zenoh_dart_web.dart` but non-functional until Zenoh WASM support lands.

### Cross-Platform Considerations
- Android/iOS binaries are currently TODO—official Zenoh releases don't include mobile artifacts yet
- Desktop platforms (Windows/macOS/Linux) have full support with prebuilt binaries
- Web awaits Zenoh WebAssembly port

## Blockers & TODOs
- [ ] Implement subscriber/query APIs (currently only publisher is functional)
- [ ] Add callback handling for async Zenoh events (requires FFI callback patterns)
- [ ] Populate Android/iOS binary URLs in `zenoh_binaries.json` once upstream publishes them
- [ ] Expand `native_library.dart` with proper asset bundling paths (currently uses fallback lookup)

## Key Files for Context
- `lib/src/zenoh_client.dart`: Main API entry point, demonstrates FFI patterns
- `lib/src/bindings/zenoh_bindings.dart`: Handcrafted FFI signatures
- `tool/fetch_zenoh_binaries.dart`: Binary download automation
- `docs/implementation_plan.md`: Roadmap for subscriber/query features
- `native/README.md`: Binary layout specification

## Testing & Validation
Before committing changes:
1. Run `dart analyze` to catch static issues
2. Run `flutter test` to verify existing unit tests
3. If modifying FFI code, test on at least one desktop platform with actual native library loaded
4. Update `CHANGELOG.md` with user-facing changes
