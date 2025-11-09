## 0.2.0

### Breaking Changes
- **Type System Update**: `ZenohPublisher` and `ZenohSubscriber` now use nullable pointers (`Pointer<T>?`) to support both native FFI and web platforms
- **Platform Abstraction**: Direct usage of internal types may require updates to accommodate the new platform-agnostic architecture

### Features
- **WASM/Web Platform Support**: Added comprehensive web platform compatibility
  - Created `ZenohClientInterface` for platform-agnostic API design
  - Implemented platform-specific facades: `ZenohClientNative` (FFI) and `ZenohClientWeb` (JS interop stub)
  - Automatic platform selection via conditional imports (`dart.library.js_interop`)
  - Added `webHandle` field to types for future JavaScript integration
- **Documentation**: Added comprehensive guides for web platform implementation (`doc/web_platform_support.md`)
- **Architecture**: Zero-cost abstraction with compile-time platform selection

### Improvements
- Fixed zenoh-ts library URL reference to use correct distribution file (`index.js`)
- Enhanced type safety with nullable pointer pattern
- Improved cross-platform code organization and maintainability

### Migration Guide
If you're using `ZenohPublisher` or `ZenohSubscriber` directly:
```dart
// Before
final handle = publisher.pointer.address;

// After
final handle = publisher.handle; // Uses getter that handles null safety
```

## 0.1.0-dev.0

### Platform Architecture
- **WASM/Web compatibility**: Refactored for multi-platform support
  - Created `ZenohClientInterface` for platform-agnostic API
  - Separated native implementation into `ZenohClientNative` (FFI-based)
  - Added `ZenohClientWeb` stub for future zenoh-ts integration
  - Automatic platform selection via conditional imports
  - Updated types to support both native pointers and web handles

### Features
- Initial project scaffold with platform-aware FFI bindings.
- Added high-level subscriber support with Dart callbacks and stream delivery.
- Expanded example app to exercise publisher/subscriber loopback messaging.
- Documented end-to-end publish/subscribe flow in README.
- Added convenience helpers for string payloads (`ZenohClient.publishString`,
  `ZenohSample.payloadAsString`).

### Known Limitations
- Web platform requires zenoh-ts library (not yet fully integrated)
- Android/iOS binaries not included (build scripts provided)
