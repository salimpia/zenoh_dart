import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
/// Platform-specific implementations extend this class.
abstract class ZenohSession {
  /// Returns a numeric handle for the session (platform-specific).
  int get handle;
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
/// Platform-specific implementations extend this class.
abstract class ZenohSubscriber {
  ZenohSubscriber({
    required this.stream,
    required this.contextId,
  });

  final Stream<ZenohSample> stream;
  final int contextId;

  /// Returns a numeric handle for the subscriber (platform-specific).
  int get handle;
}

/// Represents a publisher handle for a resource path.
/// Platform-specific implementations extend this class.
abstract class ZenohPublisher {
  /// Returns a numeric handle for the publisher (platform-specific).
  int get handle;
}
