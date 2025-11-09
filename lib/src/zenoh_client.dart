import 'dart:async';

import 'zenoh_platform_interface.dart';
import 'zenoh_client_native.dart'
    if (dart.library.js_interop) 'zenoh_client_web.dart';
import 'zenoh_types.dart';

export 'zenoh_platform_interface.dart';

/// High-level wrapper around the Zenoh library.
///
/// Automatically selects the appropriate implementation based on the platform:
/// - Native platforms (Android, iOS, macOS, Windows, Linux): Uses FFI bindings
/// - Web platform: Uses JavaScript interop (zenoh-ts)
class ZenohClient implements ZenohClientInterface {
  ZenohClient._(this._impl);

  final ZenohClientInterface _impl;

  @override
  bool get isClosed => _impl.isClosed;

  /// Opens a Zenoh session and returns a managed client instance.
  ///
  /// On native platforms, this loads the Zenoh C library via FFI.
  /// On web platforms, this requires zenoh-ts to be loaded.
  static Future<ZenohClient> connect(ZenohConfig config) async {
    final impl = await _createPlatformClient(config);
    return ZenohClient._(impl);
  }

  static Future<ZenohClientInterface> _createPlatformClient(
      ZenohConfig config) async {
    // This will be resolved at compile time based on the platform
    return await ZenohClientNative.connect(config);
  }

  @override
  Future<ZenohPublisher> declarePublisher(String keyExpr) =>
      _impl.declarePublisher(keyExpr);

  @override
  Future<ZenohSubscriber> subscribe(String keyExpr) => _impl.subscribe(keyExpr);

  @override
  Future<void> publishString(ZenohPublisher publisher, String data) =>
      _impl.publishString(publisher, data);

  @override
  Future<void> publishBytes(ZenohPublisher publisher, List<int> data) =>
      _impl.publishBytes(publisher, data);

  @override
  Future<void> undeclarePublisher(ZenohPublisher publisher) =>
      _impl.undeclarePublisher(publisher);

  @override
  Future<void> undeclareSubscriber(ZenohSubscriber subscriber) =>
      _impl.undeclareSubscriber(subscriber);

  @override
  Future<void> close() => _impl.close();
}
