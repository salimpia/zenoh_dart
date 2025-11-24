import 'zenoh_types.dart';

/// Web platform implementation of ZenohSession.
class ZenohSessionWeb extends ZenohSession {
  ZenohSessionWeb(this.webHandle);

  final dynamic webHandle;

  @override
  int get handle => 0; // Web doesn't use numeric handles
}

/// Web platform implementation of ZenohSubscriber.
class ZenohSubscriberWeb extends ZenohSubscriber {
  ZenohSubscriberWeb({
    required this.webHandle,
    required super.stream,
    required super.contextId,
  });

  final dynamic webHandle;

  @override
  int get handle => 0; // Web doesn't use numeric handles
}

/// Web platform implementation of ZenohPublisher.
class ZenohPublisherWeb extends ZenohPublisher {
  ZenohPublisherWeb(this.webHandle);

  final dynamic webHandle;

  @override
  int get handle => 0; // Web doesn't use numeric handles
}
