import 'dart:ffi' as ffi;

import 'bindings/zenoh_generated.dart' as gen;
import 'zenoh_types.dart';

/// Native platform implementation of ZenohSession.
class ZenohSessionNative extends ZenohSession {
  ZenohSessionNative(this.pointer);

  final ffi.Pointer<gen.z_owned_session_t> pointer;

  @override
  int get handle => pointer.address;
}

/// Native platform implementation of ZenohSubscriber.
class ZenohSubscriberNative extends ZenohSubscriber {
  ZenohSubscriberNative(
    this.pointer, {
    required super.stream,
    required super.contextId,
  });

  final ffi.Pointer<gen.z_owned_subscriber_t> pointer;

  @override
  int get handle => pointer.address;
}

/// Native platform implementation of ZenohPublisher.
class ZenohPublisherNative extends ZenohPublisher {
  ZenohPublisherNative(this.pointer);

  final ffi.Pointer<gen.z_owned_publisher_t> pointer;

  @override
  int get handle => pointer.address;
}
