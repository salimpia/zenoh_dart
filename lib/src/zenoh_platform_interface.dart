import 'dart:async';

import 'zenoh_types.dart';

/// Abstract interface for Zenoh client implementations across platforms.
///
/// This allows native (FFI-based) and web (JS interop-based) implementations
/// to coexist while sharing the same public API surface.
abstract class ZenohClientInterface {
  /// Opens a Zenoh session with the given configuration.
  static Future<ZenohClientInterface> connect(ZenohConfig config) {
    throw UnimplementedError(
      'ZenohClientInterface.connect() must be overridden by platform implementation',
    );
  }

  /// Creates a publisher for the given resource key expression.
  Future<ZenohPublisher> declarePublisher(String keyExpr);

  /// Creates a subscriber for the given resource key expression.
  Future<ZenohSubscriber> subscribe(String keyExpr);

  /// Publishes string data to the specified publisher.
  Future<void> publishString(ZenohPublisher publisher, String data);

  /// Publishes binary data to the specified publisher.
  Future<void> publishBytes(ZenohPublisher publisher, List<int> data);

  /// Removes a publisher and releases its resources.
  Future<void> undeclarePublisher(ZenohPublisher publisher);

  /// Removes a subscriber and releases its resources.
  Future<void> undeclareSubscriber(ZenohSubscriber subscriber);

  /// Closes the Zenoh session and releases all resources.
  Future<void> close();

  /// Returns true if the session has been closed.
  bool get isClosed;
}
