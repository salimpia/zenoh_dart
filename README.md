# zenoh_dart

Dart and Flutter FFI bindings for [Eclipse Zenoh](https://zenoh.io), prepared by M-PIA. This package exposes Zenoh's core APIs to Flutter apps across Android, iOS, macOS, Windows, Linux, and Web (experimental).

## Project goals

- Ship prebuilt Zenoh native libraries for each supported platform and architecture.
- Offer idiomatic Dart wrappers for sessions, publishers, subscribers, and queries.
- Provide ready-to-run examples for ROS 2 bridge scenarios.
- Publish the package on pub.dev under the M-PIA banner.

## Getting started

1. Install the Dart and Flutter SDKs (`>= 3.4.0` / `>= 3.24.0`).
2. Add the dependency once the package is published:

   ```bash
   flutter pub add zenoh_dart
   ```

3. Initialize a session and interact with Zenoh resources:

   ```dart
   final client = await ZenohClient.connect(ZenohConfig());

   final publisher = await client.declarePublisher('demo/example');
   final subscriber = await client.subscribe('demo/example');

    final sub = subscriber.stream.listen((sample) {
       final message = sample.payloadAsString();
       debugPrint('🔔 received: ${sample.keyExpr} -> $message');
   });

    await client.publishString(publisher, 'Hello Zenoh!');

   await sub.cancel();
   await client.undeclareSubscriber(subscriber);
   await client.undeclarePublisher(publisher);
   await client.close();
   ```

## Native binaries

The `native/` directory contains per-platform Zenoh distributions. **Native binary archives (`.zip` files) are not included in the package to keep the download size reasonable.**

### Download binaries

Run the helper script to download and extract official Zenoh C binaries:

```bash
dart run tool/fetch_zenoh_binaries.dart
```

This script downloads platform-specific archives from the [Zenoh C releases](https://github.com/eclipse-zenoh/zenoh-c/releases) and verifies SHA-256 checksums. Extract the downloaded archives to keep the shared library (`.dll`, `.so`, `.dylib`) in the correct `native/<platform>/<arch>/` directory.

### Platform support

- ✅ **Windows** (x64 MSVC)
- ✅ **macOS** (x64, arm64)
- ✅ **Linux** (x64, arm64, armv7)
- ⚠️ **Android/iOS**: Native binaries are not yet officially published. See `doc/platform_support.md` and build scripts in `tool/` for instructions on building from source.
- 🚧 **Web**: Experimental support with platform-agnostic architecture. Full implementation pending zenoh-ts integration. See `doc/platform_support.md` for details.

**Note**: Windows GNU toolchain binaries are not included in the package to reduce size. Use the MSVC binaries (default on Windows) or download the GNU version via `dart run tool/fetch_zenoh_binaries.dart` if needed.

## Generating bindings

Place the Zenoh C headers under `native/include/` (the project ships with a minimal `zenoh.h` stub for bootstrapping). Once the official headers are available, regenerate the Dart FFI layer with:

```bash
dart run ffigen
```

The command writes expanded bindings into `lib/src/bindings/zenoh_generated.dart`, which you can then wrap with higher-level Dart helpers.

## Platform support

See `doc/platform_support.md` for detailed build requirements and instructions.

## Licensing

This project adopts the Apache License 2.0 with an explicit NOTICE file referencing M-PIA. See `LICENSE` and `NOTICE` for details.
