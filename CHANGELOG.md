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
