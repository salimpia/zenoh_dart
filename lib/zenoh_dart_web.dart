// ignore_for_file: avoid_print

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Stub registrar for web builds until WASM bindings are available.
class ZenohDartPlugin {
  static void registerWith(Registrar registrar) {
    // Provide a console warning so developers know web is not yet functional.
    print('Zenoh is not yet supported on the web platform.');
  }
}

/// Temporary alias to keep references working until downstream apps migrate.
typedef ZenohDartWeb = ZenohDartPlugin;
