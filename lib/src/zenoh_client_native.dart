import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart' as pkgffi;

import 'bindings/native_library.dart';
import 'bindings/zenoh_bindings.dart';
import 'bindings/zenoh_generated.dart' as gen;
import 'zenoh_exceptions.dart';
import 'zenoh_platform_interface.dart';
import 'zenoh_types.dart';
import 'zenoh_types_native.dart';

/// Native FFI-based implementation of Zenoh client for desktop and mobile platforms.
class ZenohClientNative implements ZenohClientInterface {
  ZenohClientNative._(this._bindings, this.session);

  static final Map<int, _SubscriberContext> _subscriberContexts = {};
  static int _nextSubscriberContextId = 1;

  final ZenohBindings _bindings;
  final ZenohSessionNative session;

  bool _closed = false;
  final Map<int, ZenohSubscriberNative> _subscribers = {};
  final Set<int> _freedSubscriberContexts = {};

  @override
  bool get isClosed => _closed;

  /// Opens a Zenoh session and returns a managed client instance.
  static Future<ZenohClientNative> connect(ZenohConfig config) async {
    final bindings = await NativeLibrary.instance.ensureBindings();
    final sessionPtr = pkgffi.calloc<gen.z_owned_session_t>();

    try {
      _openSession(bindings, sessionPtr, config);
      return ZenohClientNative._(bindings, ZenohSessionNative(sessionPtr));
    } catch (error) {
      pkgffi.calloc.free(sessionPtr);
      rethrow;
    }
  }

  @override
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

      return ZenohPublisherNative(publisherPtr);
    } catch (_) {
      pkgffi.calloc.free(publisherPtr);
      rethrow;
    }
  }

  @override
  Future<ZenohSubscriber> subscribe(String keyExpr) async {
    if (_closed) {
      throw StateError('Cannot subscribe using a closed ZenohClient.');
    }

    final subscriberPtr = pkgffi.calloc<gen.z_owned_subscriber_t>();
    final closurePtr = pkgffi.calloc<gen.z_owned_closure_sample_t>();
    final handlerPtr = pkgffi.calloc<gen.z_owned_fifo_handler_sample_t>();

    final controller = StreamController<ZenohSample>.broadcast();
    final contextId = _registerSubscriberContext(
      controller,
      subscriberPtr,
      handlerPtr,
    );

    final keyExprPtr = pkgffi.calloc<gen.z_owned_keyexpr_t>();
    final keyExprUtf8 = keyExpr.toNativeUtf8(allocator: pkgffi.calloc);
    final optionsPtr = pkgffi.calloc<gen.z_subscriber_options_t>();

    var keyExprInitialized = false;
    var keyExprDropped = false;

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
      _bindings.zFifoChannelSampleNew(closurePtr, handlerPtr, 256);

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
        throw ZenohNativeCallException(
          'z_declare_subscriber failed',
          errorCode: rc,
        );
      }
    } catch (error) {
      if (keyExprInitialized && !keyExprDropped) {
        _dropKeyExpr(keyExprPtr);
      }

      await _cleanupSubscriberFailure(contextId, subscriberPtr, handlerPtr);
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

    final subscriber = ZenohSubscriberNative(
      subscriberPtr,
      stream: controller.stream,
      contextId: contextId,
    );
    _subscribers[contextId] = subscriber;
    return subscriber;
  }

  /// Publishes raw bytes using a previously declared publisher handle.
  Future<void> publish(
    ZenohPublisher publisher,
    List<int> payload, {
    List<int>? attachment,
  }) async {
    if (payload.isEmpty) {
      throw ArgumentError.value(payload, 'payload', 'must not be empty');
    }

    final nativePublisher = publisher as ZenohPublisherNative;
    final ptr = nativePublisher.pointer;

    final dataPtr = pkgffi.calloc<ffi.Uint8>(payload.length);
    final bytesPtr = pkgffi.calloc<gen.z_owned_bytes_t>();

    ffi.Pointer<ffi.Uint8>? attachDataPtr;
    ffi.Pointer<gen.z_owned_bytes_t>? attachBytesPtr;
    ffi.Pointer<gen.z_moved_bytes_t>? movedAttachPtr;

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

      if (attachment != null && attachment.isNotEmpty) {
        attachDataPtr = pkgffi.calloc<ffi.Uint8>(attachment.length);
        attachBytesPtr = pkgffi.calloc<gen.z_owned_bytes_t>();
        attachDataPtr.asTypedList(attachment.length).setAll(0, attachment);
        final copyAttachRc = _bindings.zBytesCopyFromBuf(
          attachBytesPtr,
          attachDataPtr,
          attachment.length,
        );
        if (copyAttachRc != 0) {
          throw ZenohNativeCallException(
            'z_bytes_copy_from_buf failed for attachment',
            errorCode: copyAttachRc,
          );
        }
        movedAttachPtr = attachBytesPtr.cast<gen.z_moved_bytes_t>();
      }
    } finally {
      pkgffi.calloc.free(dataPtr);
      if (attachDataPtr != null) {
        pkgffi.calloc.free(attachDataPtr);
      }
    }

    final movedBytesPtr = bytesPtr.cast<gen.z_moved_bytes_t>();

    final optionsPtr = pkgffi.calloc<ffi.Pointer<ffi.Void>>(4);
    _bindings.zPublisherPutOptionsDefault(
      optionsPtr.cast<gen.z_publisher_put_options_t>(),
    );

    if (movedAttachPtr != null) {
      // Offset 24 (index 3) is attachment pointer in 64-bit z_publisher_put_options_t
      optionsPtr[3] = movedAttachPtr.cast<ffi.Void>();
    }

    final publisherLoan = _bindings.zPublisherLoan(ptr);
    final rc = _bindings.zPublisherPut(
      publisherLoan,
      movedBytesPtr,
      optionsPtr.cast<gen.z_publisher_put_options_t>(),
    );

    pkgffi.calloc.free(optionsPtr);
    if (attachBytesPtr != null) {
      pkgffi.calloc.free(attachBytesPtr);
    }

    if (rc != 0) {
      _bindings.zBytesDrop(movedBytesPtr);
      pkgffi.calloc.free(bytesPtr);
      throw ZenohNativeCallException('z_publisher_put failed', errorCode: rc);
    }

    pkgffi.calloc.free(bytesPtr);
  }

  @override
  Future<void> publishString(
    ZenohPublisher publisher,
    String message, {
    List<int>? attachment,
    Encoding encoding = utf8,
  }) async {
    final data = encoding.encode(message);
    await publish(publisher, data, attachment: attachment);
  }

  @override
  Future<void> publishBytes(
    ZenohPublisher publisher,
    List<int> data, {
    List<int>? attachment,
  }) async {
    await publish(publisher, data, attachment: attachment);
  }

  @override
  Future<void> undeclarePublisher(ZenohPublisher publisher) async {
    final nativePublisher = publisher as ZenohPublisherNative;
    final ptr = nativePublisher.pointer;
    final movedPtr = ptr.cast<gen.z_moved_publisher_t>();
    _bindings.zPublisherDrop(movedPtr);
    pkgffi.calloc.free(ptr);
  }

  @override
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

    final nativeSubscriber = subscriber as ZenohSubscriberNative;
    final ptr = nativeSubscriber.pointer;
    final movedPtr = ptr.cast<gen.z_moved_subscriber_t>();
    _bindings.zSubscriberDrop(movedPtr);

    final alreadyFreed = _freedSubscriberContexts.remove(subscriber.contextId);
    if (!alreadyFreed) {
      pkgffi.calloc.free(ptr);
    }
  }

  @override
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
    ffi.Pointer<gen.z_owned_fifo_handler_sample_t> handlerPtr,
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
    ffi.Pointer<gen.z_owned_fifo_handler_sample_t> handlerPtr,
  ) {
    final id = _nextSubscriberContextId++;
    _subscriberContexts[id] =
        _SubscriberContext(this, controller, subscriberPtr, handlerPtr);
    return id;
  }

  ZenohSample _readSample(ffi.Pointer<gen.z_loaned_sample_t> samplePtr) {
    final keyExprLoan = _bindings.zSampleKeyExpr(samplePtr);
    final keyExpr = _readKeyExpr(keyExprLoan);
    final payloadLoan = _bindings.zSamplePayload(samplePtr);
    final payload = _readPayload(payloadLoan);
    final attachLoan = _bindings.zSampleAttachment(samplePtr);
    final Uint8List? attachment =
        attachLoan.address != 0 ? _readPayload(attachLoan) : null;
    return ZenohSample(
      keyExpr: keyExpr,
      payload: payload,
      attachment: attachment,
    );
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
  _SubscriberContext(this.client, this.controller, this.pointer, this.handlerPtr) {
    _startPolling();
  }

  final ZenohClientNative client;
  final StreamController<ZenohSample> controller;
  ffi.Pointer<gen.z_owned_subscriber_t>? pointer;
  ffi.Pointer<gen.z_owned_fifo_handler_sample_t>? handlerPtr;

  Timer? _pollingTimer;
  Future<void>? _closeFuture;
  bool _isPolling = false;

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 2), (_) {
      _pollSamples();
    });
  }

  void _pollSamples() {
    final hPtr = handlerPtr;
    if (hPtr == null || _isPolling) return;
    _isPolling = true;

    try {
      final handlerLoan = client._bindings.zFifoHandlerSampleLoan(hPtr);
      final ownedSamplePtr = pkgffi.calloc<gen.z_owned_sample_t>();
      try {
        while (true) {
          final rc =
              client._bindings.zFifoHandlerSampleTryRecv(handlerLoan, ownedSamplePtr);
          if (rc != 0) {
            break;
          }
          final loanedSample = client._bindings.zSampleLoan(ownedSamplePtr);
          try {
            final sample = client._readSample(loanedSample);
            if (!controller.isClosed) {
              controller.add(sample);
            }
          } finally {
            client._bindings
                .zSampleDrop(ownedSamplePtr.cast<gen.z_moved_sample_t>());
          }
        }
      } finally {
        pkgffi.calloc.free(ownedSamplePtr);
      }
    } catch (e, st) {
      if (!controller.isClosed) {
        controller.addError(e, st);
      }
    } finally {
      _isPolling = false;
    }
  }

  Future<void> close() async {
    if (_closeFuture != null) return _closeFuture!;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _pollSamples();

    final hPtr = handlerPtr;
    if (hPtr != null) {
      handlerPtr = null;
      client._bindings.zFifoHandlerSampleDrop(
          hPtr.cast<gen.z_moved_fifo_handler_sample_t>());
      pkgffi.calloc.free(hPtr);
    }

    return _closeFuture = controller.close();
  }
}
