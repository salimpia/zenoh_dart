import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'bindings/zenoh_generated.dart' as gen;

/// Defines core data types for the Zenoh Dart bindings.
class ZenohConfig {
  ZenohConfig({this.mode = ZenohMode.peer, this.locator});

  final ZenohMode mode;
  final String? locator;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'mode': mode.name,
    };
    if (locator != null) {
      json['connect'] = <String, Object?>{
        'endpoints': [locator],
      };
    }
    return json;
  }
}

enum ZenohMode {
  peer,
  client,
  router,
}

/// Represents a handle to a Zenoh session.
class ZenohSession {
  ZenohSession(this.pointer);

  final ffi.Pointer<gen.z_owned_session_t> pointer;

  int get handle => pointer.address;
}

/// Represents a sample delivered to subscribers.
class ZenohSample {
  const ZenohSample({required this.keyExpr, required this.payload});

  final String keyExpr;
  final Uint8List payload;

  String payloadAsString({Encoding encoding = utf8}) =>
      encoding.decode(payload);
}

/// Represents a subscription to a specific resource path.
class ZenohSubscriber {
  ZenohSubscriber(
    this.pointer, {
    required this.stream,
    required this.contextId,
    this.webHandle,
  });

  final ffi.Pointer<gen.z_owned_subscriber_t>? pointer;
  final Stream<ZenohSample> stream;
  final int contextId;
  // Using dynamic for web JSObject to avoid conditional imports
  final dynamic webHandle;

  int get handle => pointer?.address ?? 0;
}

/// Represents a publisher handle for a resource path.
class ZenohPublisher {
  ZenohPublisher(this.pointer, {this.webHandle});

  final ffi.Pointer<gen.z_owned_publisher_t>? pointer;
  // Using dynamic for web JSObject to avoid conditional imports
  final dynamic webHandle;

  int get handle => pointer?.address ?? 0;
}
