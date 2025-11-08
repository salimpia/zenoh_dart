# Implementation Plan

## Native library distribution

1. ✅ Track release metadata in `tool/zenoh_binaries.json` (URLs still pending official sources).
2. ✅ Extend `tool/fetch_zenoh_binaries.dart` to download artifacts and verify hashes.
3. Store unpacked shared libraries under `native/<platform>/` for bundling.
4. ✅ Document manual steps and eventual CI automation in `README.md`.
5. ✅ Provide per-platform build scripts in `tool/` for cases where official artifacts are unavailable.

## Bindings generation

1. ✅ Maintain minimal handcrafted bindings in `lib/src/bindings/zenoh_bindings.dart` for bootstrap.
2. Use `ffigen` with `ffigen.yaml` to generate the full API into `lib/src/bindings/zenoh_generated.dart`.
3. Wrap generated bindings with idiomatic classes in `lib/src`.
4. Add unit tests validating session lifecycle and basic publish/subscribe flows once native binaries are available.

## High-level Dart API

1. ✅ Expand `ZenohClient` with publish helpers backed by the bindings (subscribe/query pending).
2. Provide resource lifecycle classes (`ZenohPublisher`, `ZenohSubscriber`) that manage underlying handles safely.
3. Expose streaming APIs using `StreamController` for subscriber callbacks.
4. Supply example snippets for ROS 2 interoperability in `example/lib/`.
5. Implement subscription/query wrappers once native callbacks are wired.

## Tooling and CI

1. Create GitHub Actions workflows to fetch binaries and run Flutter unit tests on all platforms.
2. Add formatting and static analysis checks (`dart format`, `flutter analyze`).
3. Configure publishing safeguards (version checks, changelog gates).
