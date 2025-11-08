@TestOn('windows')
library zenoh_pubsub_integration_test;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zenoh_dart/zenoh_dart.dart';

void main() {
  late _ZenohRouter router;

  setUpAll(() async {
    router = await _ZenohRouter.start();
  });

  tearDownAll(() async {
    await router.stop();
  });

  test('publishes and receives a message via zenohd', () async {
    final keyExpr = 'demo/integration/${DateTime.now().millisecondsSinceEpoch}';
    final config = ZenohConfig(
      mode: ZenohMode.client,
      locator: router.endpoint,
    );

    late ZenohClient client;
    try {
      client = await ZenohClient.connect(config);
    } on ZenohNativeCallException catch (error) {
      fail(
        'Failed to open zenoh session: ${error.message} (code: ${error.errorCode})'
        '\n${router.dumpLogs()}',
      );
    } on ZenohException catch (error) {
      fail('Failed to open zenoh session: $error\n${router.dumpLogs()}');
    }
    addTearDown(() async {
      await client.close();
    });

    final subscriber = await client.subscribe(keyExpr);
    addTearDown(() async {
      await client.undeclareSubscriber(subscriber);
    });

    final publisher = await client.declarePublisher(keyExpr);
    addTearDown(() async {
      await client.undeclarePublisher(publisher);
    });

    final payload = 'zenoh-integration-${DateTime.now().toIso8601String()}';
    final sampleFuture = subscriber.stream.first;

    await client.publishString(publisher, payload);

    try {
      final sample = await sampleFuture.timeout(const Duration(seconds: 5));
      expect(sample.keyExpr, keyExpr);
      expect(sample.payloadAsString(), payload);
    } on TimeoutException catch (error) {
      fail('Timed out waiting for zenoh sample: $error\n${router.dumpLogs()}');
    }
  });
}

class _ZenohRouter {
  _ZenohRouter(
    this._process,
    this._stdoutSub,
    this._stderrSub,
    this._logs,
    this.endpoint,
  );

  final Process _process;
  final StreamSubscription<String> _stdoutSub;
  final StreamSubscription<String> _stderrSub;
  final List<String> _logs;
  final String endpoint;

  static Future<_ZenohRouter> start() async {
    final routerFile = File.fromUri(
      Directory.current.uri.resolve('native/windows/x64/msvc/zenohd.exe'),
    );
    if (!routerFile.existsSync()) {
      throw StateError(
        'zenohd.exe not found at ${routerFile.path}. Extract the native binaries first.',
      );
    }

    final logs = <String>[];
    final endpoints = <String>[];
    final completer = Completer<void>();

    final process = await Process.start(
      routerFile.path,
      const <String>[],
      workingDirectory: routerFile.parent.path,
      environment: <String, String>{
        'ZENOH_LOG': 'info',
      },
    );

    late final StreamSubscription<String> stdoutSub;
    late final StreamSubscription<String> stderrSub;
    String? resolvedEndpoint;

    Future<void> handleExit(int code) async {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('zenohd exited early with code $code\n${logs.join('\n')}'),
        );
      }
    }

    process.exitCode.then(handleExit);

    String? pickEndpoint() {
      for (final entry in endpoints) {
        if (!entry.contains('[')) {
          return entry;
        }
      }
      if (endpoints.isEmpty) {
        return null;
      }
      return endpoints.first;
    }

    void completeWhenReady() {
      resolvedEndpoint ??= pickEndpoint();
      if (!completer.isCompleted && resolvedEndpoint != null) {
        completer.complete();
      }
    }

    stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      logs.add('STDOUT: $line');
      const marker = 'Zenoh can be reached at: ';
      if (line.contains(marker)) {
        final candidate =
            line.substring(line.indexOf(marker) + marker.length).trim();
        endpoints.add(candidate);
        completeWhenReady();
      }
      if (line.contains('listening scout messages')) {
        completeWhenReady();
      }
    });

    stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      logs.add('STDERR: $line');
    });

    try {
      await completer.future.timeout(const Duration(seconds: 15));
    } catch (error) {
      await stdoutSub.cancel();
      await stderrSub.cancel();
      process.kill();
      await process.exitCode;
      rethrow;
    }

    resolvedEndpoint ??= pickEndpoint();
    if (resolvedEndpoint == null) {
      await stdoutSub.cancel();
      await stderrSub.cancel();
      process.kill();
      await process.exitCode;
      throw StateError(
        'Zenoh router did not report any reachable endpoints.\n${logs.join('\n')}',
      );
    }

    return _ZenohRouter(process, stdoutSub, stderrSub, logs, resolvedEndpoint!);
  }

  Future<void> stop() async {
    _process.kill();
    await _process.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
      _process.kill(ProcessSignal.sigterm);
      return _process.exitCode;
    });
    await _stdoutSub.cancel();
    await _stderrSub.cancel();
  }

  String dumpLogs() => _logs.join('\n');
}
