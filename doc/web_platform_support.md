# Web Platform Support for zenoh_dart

## Architecture Overview

The `zenoh_dart` package has been refactored to support both native platforms (via FFI) and web platforms (via JavaScript interop) using a common interface.

### Key Components

1. **`ZenohClientInterface`** (`lib/src/zenoh_platform_interface.dart`)
   - Abstract interface defining the API contract
   - All platform implementations must implement this interface
   - Ensures consistent API across platforms

2. **`ZenohClientNative`** (`lib/src/zenoh_client_native.dart`)
   - FFI-based implementation for native platforms
   - Uses Zenoh C library via dynamic library loading
   - Supports: Windows, macOS, Linux, Android, iOS

3. **`ZenohClientWeb`** (`lib/src/zenoh_client_web.dart`)
   - JavaScript interop-based implementation for web
   - Currently a stub/placeholder
   - Will integrate with zenoh-ts when ready

4. **`ZenohClient`** (`lib/src/zenoh_client.dart`)
   - Facade that automatically selects the appropriate implementation
   - Uses conditional imports: `if (dart.library.js_interop) 'zenoh_client_web.dart'`
   - Provides transparent platform detection

## Current Web Status

### ✅ Implemented
- Platform-agnostic interface design
- Conditional import mechanism for platform selection
- Type system supporting both FFI pointers and web handles
- Stub implementation with proper error messages

### 🚧 Pending
- Full zenoh-ts JavaScript interop implementation
- Promise-to-Future conversion helpers
- Proper JS object marshalling
- Testing with actual zenoh-ts library

## Integration with zenoh-ts

### Prerequisites

To use `zenoh_dart` on web once implemented, you'll need to include zenoh-ts in your HTML:

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Zenoh Flutter Web App</title>
    <script defer src="main.dart.js"></script>
    
    <!-- Include zenoh-ts -->
    <script src="https://unpkg.com/@eclipse-zenoh/zenoh-ts@latest/dist/index.js"></script>
</head>
<body>
    <script>
        // The zenoh global object will be available
        window.addEventListener('load', function(ev) {
            // Your Flutter app will detect and use zenoh-ts automatically
        });
    </script>
</body>
</html>
```

### Usage (Same API Everywhere!)

The beauty of this architecture is that your Dart code remains identical across platforms:

```dart
import 'package:zenoh_dart/zenoh_dart.dart';

void main() async {
  // This works on native AND web!
  final client = await ZenohClient.connect(ZenohConfig());
  
  final publisher = await client.declarePublisher('demo/example');
  await client.publishString(publisher, 'Hello from ${Platform.operatingSystem}!');
  
  final subscriber = await client.subscribe('demo/example');
  subscriber.stream.listen((sample) {
    print('Received: ${sample.payloadAsString()}');
  });
}
```

## Implementation Roadmap

### Phase 1: Core Infrastructure ✅
- [x] Define platform interface
- [x] Refactor native implementation
- [x] Create web stub
- [x] Set up conditional imports
- [x] Update type system for cross-platform support

### Phase 2: zenoh-ts Integration 🚧
- [ ] Implement JS interop for zenoh.open()
- [ ] Implement publisher declarations
- [ ] Implement subscriber with callbacks
- [ ] Handle JavaScript Promises properly
- [ ] Implement proper error handling

### Phase 3: Testing & Refinement
- [ ] Add web-specific tests
- [ ] Test with real zenoh-ts library
- [ ] Performance optimization
- [ ] Documentation and examples

### Phase 4: Advanced Features
- [ ] Query/queryable support on web
- [ ] Advanced configuration options
- [ ] WebSocket transport tuning
- [ ] Binary data handling optimization

## Technical Notes

### Why Conditional Imports?

Dart's conditional imports allow compile-time selection of implementations:

```dart
import 'zenoh_client_native.dart'
    if (dart.library.js_interop) 'zenoh_client_web.dart';
```

This means:
- **On native platforms**: Imports `zenoh_client_native.dart` (FFI version)
- **On web platform**: Imports `zenoh_client_web.dart` (JS interop version)
- **Zero runtime overhead**: The unused implementation is tree-shaken away

### Type System Considerations

To support both platforms, types use nullable pointers:

```dart
class ZenohPublisher {
  final Pointer<z_owned_publisher_t>? pointer;  // null on web
  final dynamic webHandle;                       // null on native
  
  int get handle => pointer?.address ?? 0;
}
```

This allows:
- Native platforms to use FFI pointers
- Web platform to use JavaScript object handles
- Shared API without runtime type checks

### Memory Management

- **Native**: Manual FFI memory management with `calloc.free()`
- **Web**: JavaScript garbage collection handles cleanup
- **Interface**: Both use async `close()` for consistent resource cleanup

## Contributing

To complete the web implementation:

1. Study the zenoh-ts API at https://github.com/eclipse-zenoh/zenoh-ts
2. Implement JS interop in `lib/src/zenoh_client_web.dart`
3. Add proper type conversions (Dart ↔ JavaScript)
4. Test with the zenoh-ts library loaded
5. Submit PR with working examples

## References

- [Zenoh TypeScript/JavaScript bindings](https://github.com/eclipse-zenoh/zenoh-ts)
- [Dart JS interop](https://dart.dev/web/js-interop)
- [Flutter web platform views](https://docs.flutter.dev/platform-integration/web/platform-views)
- [Conditional imports in Dart](https://dart.dev/guides/libraries/create-library-packages#conditionally-importing-and-exporting-library-files)
