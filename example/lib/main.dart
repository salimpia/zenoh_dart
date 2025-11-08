import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zenoh_dart/zenoh_dart.dart';

void main() {
  runApp(const ZenohExampleApp());
}

class ZenohExampleApp extends StatefulWidget {
  const ZenohExampleApp({super.key});

  @override
  State<ZenohExampleApp> createState() => _ZenohExampleAppState();
}

class _ZenohExampleAppState extends State<ZenohExampleApp> {
  ZenohClient? _client;
  ZenohPublisher? _publisher;
  ZenohSubscriber? _subscriber;
  StreamSubscription<ZenohSample>? _subscription;
  String _status = 'Disconnected';
  String? _lastMessage;

  @override
  void initState() {
    super.initState();
    _initZenoh();
  }

  Future<void> _initZenoh() async {
    setState(() => _status = 'Connecting...');
    try {
      final client = await ZenohClient.connect(ZenohConfig());
      final publisher = await client.declarePublisher('demo/example');
      final subscriber = await client.subscribe('demo/example');
      final subscription = subscriber.stream.listen(
        (sample) => setState(() => _lastMessage = sample.payloadAsString()),
        onError: (Object error) =>
            setState(() => _status = 'Subscription error: $error'),
      );
      setState(() {
        _client = client;
        _publisher = publisher;
        _subscriber = subscriber;
        _subscription = subscription;
        _status = 'Connected';
      });
    } catch (error) {
      setState(() => _status = 'Error: $error');
    }
  }

  Future<void> _sendMessage() async {
    final client = _client;
    final publisher = _publisher;
    if (client == null || publisher == null) {
      return;
    }

    setState(() => _status = 'Publishing...');
    try {
      final payload =
          'Hello from Flutter at ${DateTime.now().toIso8601String()}';
      await client.publishString(publisher, payload);
      setState(() => _status = 'Last publish succeeded');
    } catch (error) {
      setState(() => _status = 'Publish failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Zenoh Dart Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_status),
              if (_lastMessage != null) ...[
                const SizedBox(height: 12),
                Text('Last message: $_lastMessage'),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _client == null ? null : _sendMessage,
                child: const Text('Send message'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    final client = _client;
    final publisher = _publisher;
    final subscriber = _subscriber;
    final subscription = _subscription;
    if (subscription != null) {
      subscription.cancel();
    }
    if (client != null) {
      if (publisher != null) {
        unawaited(client.undeclarePublisher(publisher));
      }
      if (subscriber != null) {
        unawaited(client.undeclareSubscriber(subscriber));
      }
      unawaited(client.close());
    }
    super.dispose();
  }
}
