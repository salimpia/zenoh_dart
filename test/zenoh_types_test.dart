import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zenoh_dart/src/zenoh_types.dart';

void main() {
  group('ZenohConfig', () {
    test('produces json with defaults', () {
      final config = ZenohConfig();
      expect(config.toJson(), equals({'mode': ZenohMode.peer.name}));
    });

    test('includes locator when provided', () {
      final config =
          ZenohConfig(mode: ZenohMode.client, locator: 'tcp/localhost:7447');
      expect(
        config.toJson(),
        equals({
          'mode': 'client',
          'connect': {
            'endpoints': ['tcp/localhost:7447'],
          },
        }),
      );
    });
  });

  group('ZenohSample', () {
    test('retains key expression and payload bytes', () {
      final payload = Uint8List.fromList(const [1, 2, 3]);
      final sample = ZenohSample(keyExpr: 'demo', payload: payload);

      expect(sample.keyExpr, 'demo');
      expect(sample.payload, same(payload));
    });

    test('decodes payload as string using utf8 by default', () {
      final sample = ZenohSample(
        keyExpr: 'demo',
        payload: Uint8List.fromList('zenoh'.codeUnits),
      );

      expect(sample.payloadAsString(), 'zenoh');
    });
  });
}
