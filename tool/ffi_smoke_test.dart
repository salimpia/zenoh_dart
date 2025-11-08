import 'package:flutter/foundation.dart';
import 'package:zenoh_dart/src/bindings/native_library.dart';

Future<void> main() async {
  try {
    await NativeLibrary.instance.ensureBindings();
    debugPrint('✅ Native library loaded successfully.');
  } catch (error, stackTrace) {
    debugPrint('❌ Failed to load native bindings: $error');
    debugPrint(stackTrace.toString());
    rethrow;
  }
}
