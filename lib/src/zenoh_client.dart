import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart' as pkgffi;

import 'bindings/native_library.dart';
import 'bindings/zenoh_bindings.dart';
import 'bindings/zenoh_generated.dart' as gen;
import 'zenoh_exceptions.dart';
import 'zenoh_types.dart';

/// High-level wrapper around the native Zenoh library.
class ZenohClient {
  ZenohClient._(this._bindings, this.session);

  static final ffi.Pointer<ffi.NativeFunction<ZenohSampleCallbackNative>>
      _sampleCallbackPtr =
      ffi.Pointer.fromFunction<ZenohSampleCallbackNative>(_onSampleNative);

  static final ffi.Pointer<ffi.NativeFunction<ZenohDropCallbackNative>>
      _sampleDropPtr =
      ffi.Pointer.fromFunction<ZenohDropCallbackNative>(_onSampleDropNative);

  static final Map<int, _SubscriberContext> _subscriberContexts = {};
  static int _nextSubscriberContextId = 1;

  final ZenohBindings _bindings;
  final ZenohSession session;

  bool _closed = false;
  final Map<int, ZenohSubscriber> _subscribers = {};
  final Set<int> _freedSubscriberContexts = {};

  /// Opens a Zenoh session and returns a managed client instance.
  static Future<ZenohClient> connect(ZenohConfig config) async {
    final bindings = await NativeLibrary.instance.ensureBindings();
    final sessionPtr = pkgffi.calloc<gen.z_owned_session_t>();

    try {
      _openSession(bindings, sessionPtr, config);
      return ZenohClient._(bindings, ZenohSession(sessionPtr));
    } catch (error) {
      pkgffi.calloc.free(sessionPtr);
      rethrow;
    }
  }

  /// Creates a publisher for the given resource key expression.
  Future<ZenohPublisher> declarePublisher(String keyExpr) async {
    final publisherPtr = pkgffi.calloc<gen.z_owned_publisher_t>();
    try {
      final keyExprPtr = pkgffi.calloc<gen.z_owned_keyexpr_t>();
      final keyExprUtf8 = keyExpr.toNativeUtf8(allocator: pkgffi.calloc);
      final optionsPtr = pkgffi.calloc<gen.z_publisher_options_t>();

      try {
        final keyRc = _bindings.zKeyExprFromStr(
          keyExprPtr,
          keyExprUtf8.cast<ffi.Char>(),
        );
        if (keyRc != 0) {
          throw ZenohNativeCallException(
            'z_keyexpr_from_str failed',
            errorCode: keyRc,
          );
        }

        _bindings.zPublisherOptionsDefault(optionsPtr);

        final sessionLoan = _bindings.zSessionLoan(session.pointer);
        final keyLoan = _bindings.zKeyExprLoan(keyExprPtr);
        final rc = _bindings.zDeclarePublisher(
          sessionLoan,
          publisherPtr,
          keyLoan,
          optionsPtr,
        );

        _dropKeyExpr(keyExprPtr);

        if (rc != 0) {
          throw ZenohNativeCallException(
            'z_declare_publisher failed',
            errorCode: rc,
          );
        }
      } finally {
        pkgffi.calloc.free(optionsPtr);
        pkgffi.calloc.free(keyExprUtf8);
        pkgffi.calloc.free(keyExprPtr);
      }

      return ZenohPublisher(publisherPtr);
    } catch (_) {
      pkgffi.calloc.free(publisherPtr);
      rethrow;
    }
  }

  /// Subscribes to the given key expression.
  Future<ZenohSubscriber> subscribe(String keyExpr) async {
    if (_closed) {
      throw StateError('Cannot subscribe using a closed ZenohClient.');
    }

    final subscriberPtr = pkgffi.calloc<gen.z_owned_subscriber_t>();
    final controller = StreamController<ZenohSample>();
    final contextId = _registerSubscriberContext(controller, subscriberPtr);
    final contextPtr = ffi.Pointer<ffi.Void>.fromAddress(contextId);

    final keyExprPtr = pkgffi.calloc<gen.z_owned_keyexpr_t>();
    final keyExprUtf8 = keyExpr.toNativeUtf8(allocator: pkgffi.calloc);
    final optionsPtr = pkgffi.calloc<gen.z_subscriber_options_t>();
    final closurePtr = pkgffi.calloc<gen.z_owned_closure_sample_t>();

    var keyExprInitialized = false;
    var keyExprDropped = false;
    var closureInitialized = false;
    var closureDropped = false;

    try {
      final keyRc = _bindings.zKeyExprFromStr(
        keyExprPtr,
        keyExprUtf8.cast<ffi.Char>(),
      );
      if (keyRc != 0) {
        throw ZenohNativeCallException(
          'z_keyexpr_from_str failed',
          errorCode: keyRc,
        );
      }
      keyExprInitialized = true;

      _bindings.zSubscriberOptionsDefault(optionsPtr);

      _bindings.zClosureSample(
        closurePtr,
        _sampleCallbackPtr,
        _sampleDropPtr,
        contextPtr,
      );
      closureInitialized = true;

      final movedClosurePtr = closurePtr.cast<gen.z_moved_closure_sample_t>();

      final sessionLoan = _bindings.zSessionLoan(session.pointer);
      final keyLoan = _bindings.zKeyExprLoan(keyExprPtr);
      final rc = _bindings.zDeclareSubscriber(
        sessionLoan,
        subscriberPtr,
        keyLoan,
        movedClosurePtr,
        optionsPtr,
      );

      _dropKeyExpr(keyExprPtr);
      keyExprDropped = true;

      if (rc != 0) {
        _bindings.zClosureSampleDrop(movedClosurePtr);
        closureDropped = true;
        throw ZenohNativeCallException(
          'z_declare_subscriber failed',
          errorCode: rc,
        );
      }
    } catch (error) {
      if (keyExprInitialized && !keyExprDropped) {
        _dropKeyExpr(keyExprPtr);
      }
      if (closureInitialized && !closureDropped) {
        final movedClosurePtr = closurePtr.cast<gen.z_moved_closure_sample_t>();
        _bindings.zClosureSampleDrop(movedClosurePtr);
      }

      await _cleanupSubscriberFailure(contextId, subscriberPtr);
      pkgffi.calloc.free(keyExprUtf8);
      pkgffi.calloc.free(keyExprPtr);
      pkgffi.calloc.free(optionsPtr);
      pkgffi.calloc.free(closurePtr);
      rethrow;
    }

    pkgffi.calloc.free(keyExprUtf8);
    pkgffi.calloc.free(keyExprPtr);
    pkgffi.calloc.free(optionsPtr);
    pkgffi.calloc.free(closurePtr);

    final subscriber = ZenohSubscriber(
      subscriberPtr,
      stream: controller.stream,
      contextId: contextId,
    );
    _subscribers[contextId] = subscriber;
    return subscriber;
  }

  /// Publishes raw bytes using a previously declared publisher handle.
  Future<void> publish(ZenohPublisher publisher, List<int> payload) async {
    if (payload.isEmpty) {
      throw ArgumentError.value(payload, 'payload', 'must not be empty');
    }

    final dataPtr = pkgffi.calloc<ffi.Uint8>(payload.length);
    final bytesPtr = pkgffi.calloc<gen.z_owned_bytes_t>();

    try {
      dataPtr.asTypedList(payload.length).setAll(0, payload);

      final copyRc = _bindings.zBytesCopyFromBuf(
        bytesPtr,
        dataPtr,
        payload.length,
      );
      if (copyRc != 0) {
        throw ZenohNativeCallException(
          'z_bytes_copy_from_buf failed',
          errorCode: copyRc,
        );
      }
    } finally {
      pkgffi.calloc.free(dataPtr);
    }

    final movedBytesPtr = bytesPtr.cast<gen.z_moved_bytes_t>();

    final optionsPtr = pkgffi.calloc<gen.z_publisher_put_options_t>();
    _bindings.zPublisherPutOptionsDefault(optionsPtr);

    final publisherLoan = _bindings.zPublisherLoan(publisher.pointer);
    final rc =
        _bindings.zPublisherPut(publisherLoan, movedBytesPtr, optionsPtr);

    pkgffi.calloc.free(optionsPtr);

    if (rc != 0) {
      _bindings.zBytesDrop(movedBytesPtr);
      pkgffi.calloc.free(bytesPtr);
      throw ZenohNativeCallException('z_publisher_put failed', errorCode: rc);
    }

    pkgffi.calloc.free(bytesPtr);
  }

  /// Encodes [message] using [encoding] and publishes it.
  Future<void> publishString(
    ZenohPublisher publisher,
    String message, {
    Encoding encoding = utf8,
  }) async {
    final data = encoding.encode(message);
    await publish(publisher, data);
  }

  /// Undeclares a previously registered publisher.
  Future<void> undeclarePublisher(ZenohPublisher publisher) async {
    final movedPtr = publisher.pointer.cast<gen.z_moved_publisher_t>();
    _bindings.zPublisherDrop(movedPtr);
    pkgffi.calloc.free(publisher.pointer);
  }

  /// Cancels an active subscriber and releases native resources.
  Future<void> undeclareSubscriber(ZenohSubscriber subscriber) async {
    final context = _subscriberContexts.remove(subscriber.contextId);
    if (context != null) {
      await _handleSubscriberDrop(
        subscriber.contextId,
        context,
        freeHandle: false,
      );
    } else {
      _subscribers.remove(subscriber.contextId);
    }

    final movedPtr = subscriber.pointer.cast<gen.z_moved_subscriber_t>();
    _bindings.zSubscriberDrop(movedPtr);

    final alreadyFreed = _freedSubscriberContexts.remove(subscriber.contextId);
    if (!alreadyFreed) {
      pkgffi.calloc.free(subscriber.pointer);
    }
  }

  /// Shuts down the underlying Zenoh session.
  Future<void> close() async {
    if (_closed) {
      return;
    }

    await _dropAllSubscribers();
    _freedSubscriberContexts.clear();

    ZenohNativeCallException? pending;
    final loanedSession = _bindings.zSessionLoan(session.pointer);
    final optionsPtr = pkgffi.calloc<gen.z_close_options_t>();
    try {
      _bindings.zCloseOptionsDefault(optionsPtr);
      final rc = _bindings.zClose(loanedSession, optionsPtr);
      if (rc != 0) {
        pending = ZenohNativeCallException('z_close failed', errorCode: rc);
      }
    } finally {
      pkgffi.calloc.free(optionsPtr);
    }

    _dropSessionHandle();

    if (pending != null) {
      throw pending;
    }
  }

  Future<void> _cleanupSubscriberFailure(
    int contextId,
    ffi.Pointer<gen.z_owned_subscriber_t> subscriberPtr,
  ) async {
    final context = _subscriberContexts.remove(contextId);
    if (context != null) {
      context.pointer = null;
      await context.close();
    }
    _subscribers.remove(contextId);
    _freedSubscriberContexts.remove(contextId);
    pkgffi.calloc.free(subscriberPtr);
  }

  Future<void> _handleSubscriberDrop(
    int contextId,
    _SubscriberContext context, {
    required bool freeHandle,
  }) async {
    final subscriber = _subscribers.remove(contextId);
    final handle = subscriber?.pointer ?? context.pointer;
    if (freeHandle && handle != null) {
      pkgffi.calloc.free(handle);
      _freedSubscriberContexts.add(contextId);
    }
    context.pointer = null;
    await context.close();
  }

  Future<void> _dropAllSubscribers() async {
    if (_subscribers.isEmpty) {
      return;
    }

    final existing = List<ZenohSubscriber>.from(_subscribers.values);
    for (final subscriber in existing) {
      await undeclareSubscriber(subscriber);
    }
  }

  int _registerSubscriberContext(
    StreamController<ZenohSample> controller,
    ffi.Pointer<gen.z_owned_subscriber_t> subscriberPtr,
  ) {
    final id = _nextSubscriberContextId++;
    _subscriberContexts[id] =
        _SubscriberContext(this, controller, subscriberPtr);
    return id;
  }

  ZenohSample _readSample(ffi.Pointer<gen.z_loaned_sample_t> samplePtr) {
    final keyExprLoan = _bindings.zSampleKeyExpr(samplePtr);
    final keyExpr = _readKeyExpr(keyExprLoan);
    final payloadLoan = _bindings.zSamplePayload(samplePtr);
    final payload = _readPayload(payloadLoan);
    return ZenohSample(keyExpr: keyExpr, payload: payload);
  }

  String _readKeyExpr(ffi.Pointer<gen.z_loaned_keyexpr_t> keyExprLoan) {
    final viewPtr = pkgffi.calloc<gen.z_view_string_t>();
    try {
      _bindings.zViewStringEmpty(viewPtr);
      _bindings.zKeyExprAsViewString(keyExprLoan, viewPtr);
      final loanedString = _bindings.zViewStringLoan(viewPtr);
      final length = _bindings.zStringLen(loanedString);
      if (length == 0) {
        return '';
      }

      final dataPtr = _bindings.zStringData(loanedString).cast<ffi.Uint8>();
      final bytes = dataPtr.asTypedList(length);
      return utf8.decode(bytes);
    } finally {
      pkgffi.calloc.free(viewPtr);
    }
  }

  Uint8List _readPayload(ffi.Pointer<gen.z_loaned_bytes_t> bytesLoan) {
    final viewPtr = pkgffi.calloc<gen.z_view_slice_t>();
    try {
      final rc = _bindings.zBytesGetContiguousView(bytesLoan, viewPtr);
      if (rc != 0) {
        throw ZenohNativeCallException(
          'z_bytes_get_contiguous_view failed',
          errorCode: rc,
        );
      }

      final sliceLoan = _bindings.zViewSliceLoan(viewPtr);
      final length = _bindings.zSliceLen(sliceLoan);
      if (length == 0) {
        return Uint8List(0);
      }

      final dataPtr = _bindings.zSliceData(sliceLoan);
      final bytes = dataPtr.asTypedList(length);
      return Uint8List.fromList(bytes);
    } finally {
      pkgffi.calloc.free(viewPtr);
    }
  }

  static void _onSampleNative(
    ffi.Pointer<gen.z_loaned_sample_t> samplePtr,
    ffi.Pointer<ffi.Void> contextPtr,
  ) {
    final context = _subscriberContexts[contextPtr.address];
    if (context == null) {
      return;
    }

    try {
      final sample = context.client._readSample(samplePtr);
      context.controller.add(sample);
    } catch (error, stackTrace) {
      context.controller.addError(error, stackTrace);
    }
  }

  static void _onSampleDropNative(ffi.Pointer<ffi.Void> contextPtr) {
    final id = contextPtr.address;
    final context = _subscriberContexts.remove(id);
    if (context == null) {
      return;
    }

    unawaited(
      context.client._handleSubscriberDrop(id, context, freeHandle: true),
    );
  }

  static void _openSession(
    ZenohBindings bindings,
    ffi.Pointer<gen.z_owned_session_t> sessionPtr,
    ZenohConfig config,
  ) {
    final configJson = jsonEncode(config.toJson());
    final configUtf8 = configJson.toNativeUtf8(allocator: pkgffi.calloc);
    final configPtr = pkgffi.calloc<gen.z_owned_config_t>();

    try {
      final configRc = bindings.zcConfigFromStr(
        configPtr,
        configUtf8.cast<ffi.Char>(),
      );
      if (configRc != 0) {
        throw ZenohNativeCallException(
          'zc_config_from_str failed',
          errorCode: configRc,
        );
      }
    } finally {
      pkgffi.calloc.free(configUtf8);
    }

    final movedConfigPtr = configPtr.cast<gen.z_moved_config_t>();

    final optionsPtr = pkgffi.calloc<gen.z_open_options_t>();
    bindings.zOpenOptionsDefault(optionsPtr);

    final rc = bindings.zOpen(sessionPtr, movedConfigPtr, optionsPtr);

    pkgffi.calloc.free(optionsPtr);
    pkgffi.calloc.free(configPtr);

    if (rc != 0) {
      bindings.zSessionDrop(sessionPtr.cast<gen.z_moved_session_t>());

      throw ZenohNativeCallException('z_open failed', errorCode: rc);
    }
  }

  void _dropKeyExpr(ffi.Pointer<gen.z_owned_keyexpr_t> keyExpr) {
    _bindings.zKeyExprDrop(keyExpr.cast<gen.z_moved_keyexpr_t>());
  }

  void _dropSessionHandle() {
    if (_closed) {
      return;
    }

    _bindings.zSessionDrop(session.pointer.cast<gen.z_moved_session_t>());
    pkgffi.calloc.free(session.pointer);
    _closed = true;
  }
}

class _SubscriberContext {
  _SubscriberContext(this.client, this.controller, this.pointer);

  final ZenohClient client;
  final StreamController<ZenohSample> controller;
  ffi.Pointer<gen.z_owned_subscriber_t>? pointer;

  Future<void>? _closeFuture;

  Future<void> close() {
    return _closeFuture ??= controller.close();
  }
}
