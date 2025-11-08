# zenoh_dart

Dart and Flutter FFI bindings for [Eclipse Zenoh](https://zenoh.io), prepared by M-PIA. This package exposes Zenoh's core APIs to Flutter apps across Android, iOS, macOS, Windows, and Linux. Web support will follow once WebAssembly bindings are production ready.

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

The `native/` directory will contain per-platform Zenoh distributions. A future `tool/fetch_zenoh_binaries.dart` script will download official builds and verify checksums during CI.

Run the helper to populate binaries (Android/iOS entries remain TODO until official artifacts are available):

```bash
dart run tool/fetch_zenoh_binaries.dart
```

Zipped artifacts are stored under `native/<platform>/`; unzip them locally and keep the shared library in the same directory so Flutter's asset bundling can locate it.

If you need to build the binaries yourself, see `docs/platform_support.md` along with the scripts in `tool/` (e.g., `build_android_zenoh.sh`, `build_ios_zenoh.sh`).

## Generating bindings

Place the Zenoh C headers under `native/include/` (the project ships with a minimal `zenoh.h` stub for bootstrapping). Once the official headers are available, regenerate the Dart FFI layer with:

```bash
dart run ffigen
```

The command writes expanded bindings into `lib/src/bindings/zenoh_generated.dart`, which you can then wrap with higher-level Dart helpers.

## Licensing

This project adopts the Apache License 2.0 with an explicit NOTICE file referencing M-PIA. See `LICENSE` and `NOTICE` for details.
