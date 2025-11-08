/// Base class for Zenoh-related failures.
class ZenohException implements Exception {
  ZenohException(this.message);

  final String message;

  @override
  String toString() => 'ZenohException: $message';
}

/// Thrown when a native call returns an error code.
class ZenohNativeCallException extends ZenohException {
  ZenohNativeCallException(super.message, {this.errorCode});

  final int? errorCode;
}
