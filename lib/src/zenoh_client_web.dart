import 'dart:async';
import 'dart:convert';

import 'zenoh_platform_interface.dart';
import 'zenoh_types.dart';
// ignore: unused_import
import 'zenoh_types_web.dart';

/// Web implementation of Zenoh client using JavaScript interop.
///
/// This implementation is a placeholder for future WASM support.
/// Actual implementation will use zenoh-ts (Zenoh's TypeScript/JavaScript bindings)
/// once it's properly integrated.
class ZenohClientWeb implements ZenohClientInterface {
  ZenohClientWeb._();

  bool _closed = false;

  @override
  bool get isClosed => _closed;

  /// Opens a Zenoh session using zenoh-ts.
  static Future<ZenohClientWeb> connect(ZenohConfig config) async {
    throw UnimplementedError(
      'Web platform support is not yet implemented.\n'
      'This requires zenoh-ts JavaScript library to be loaded.\n'
      'Include in your HTML: <script src="https://unpkg.com/@eclipse-zenoh/zenoh-ts@latest/dist/index.js"></script>\n'
      'See https://github.com/eclipse-zenoh/zenoh-ts for details.',
    );
  }

  @override
  Future<ZenohPublisher> declarePublisher(String keyExpr) async {
    throw UnimplementedError('Web platform not yet implemented');
  }

  @override
  Future<ZenohSubscriber> subscribe(String keyExpr) async {
    throw UnimplementedError('Web platform not yet implemented');
  }

  @override
  Future<void> publishString(
    ZenohPublisher publisher,
    String data, {
    Encoding encoding = utf8,
  }) async {
    throw UnimplementedError('Web platform not yet implemented');
  }

  @override
  Future<void> publishBytes(ZenohPublisher publisher, List<int> data) async {
    throw UnimplementedError('Web platform not yet implemented');
  }

  @override
  Future<void> undeclarePublisher(ZenohPublisher publisher) async {
    throw UnimplementedError('Web platform not yet implemented');
  }

  @override
  Future<void> undeclareSubscriber(ZenohSubscriber subscriber) async {
    throw UnimplementedError('Web platform not yet implemented');
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
  }
}
