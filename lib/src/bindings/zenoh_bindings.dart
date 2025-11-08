import 'dart:ffi' as ffi;

import 'zenoh_generated.dart' as gen;

typedef ZenohSampleCallbackNative = ffi.Void Function(
  ffi.Pointer<gen.z_loaned_sample_t>,
  ffi.Pointer<ffi.Void>,
);

typedef ZenohDropCallbackNative = ffi.Void Function(
  ffi.Pointer<ffi.Void>,
);

/// Thin wrapper around the auto-generated bindings exposing the subset of the
/// modern z_* API required by the Dart layer. These helpers provide type-safe
/// accessors and abstract over optional argument initialization.
class ZenohBindings {
  ZenohBindings(ffi.DynamicLibrary library) : _native = gen.ZenohFFI(library);

  final gen.ZenohFFI _native;

  gen.ZenohFFI get raw => _native;

  // --- Config -----------------------------------------------------------------
  int zConfigDefault(ffi.Pointer<gen.z_owned_config_t> config) =>
      _native.z_config_default(config);

  int zcConfigFromStr(
    ffi.Pointer<gen.z_owned_config_t> config,
    ffi.Pointer<ffi.Char> json,
  ) =>
      _native.zc_config_from_str(config, json);

  void zConfigDrop(ffi.Pointer<gen.z_moved_config_t> config) =>
      _native.z_config_drop(config);

  ffi.Pointer<gen.z_loaned_config_t> zConfigLoan(
    ffi.Pointer<gen.z_owned_config_t> config,
  ) =>
      _native.z_config_loan(config);

  // --- Session ----------------------------------------------------------------
  int zOpen(
    ffi.Pointer<gen.z_owned_session_t> session,
    ffi.Pointer<gen.z_moved_config_t> config,
    ffi.Pointer<gen.z_open_options_t> options,
  ) =>
      _native.z_open(session, config, options);

  void zOpenOptionsDefault(
    ffi.Pointer<gen.z_open_options_t> options,
  ) =>
      _native.z_open_options_default(options);

  int zClose(
    ffi.Pointer<gen.z_loaned_session_t> session,
    ffi.Pointer<gen.z_close_options_t> options,
  ) =>
      _native.z_close(session, options);

  void zCloseOptionsDefault(
    ffi.Pointer<gen.z_close_options_t> options,
  ) =>
      _native.z_close_options_default(options);

  void zSessionDrop(ffi.Pointer<gen.z_moved_session_t> session) =>
      _native.z_session_drop(session);

  ffi.Pointer<gen.z_loaned_session_t> zSessionLoan(
    ffi.Pointer<gen.z_owned_session_t> session,
  ) =>
      _native.z_session_loan(session);

  // --- Key expressions --------------------------------------------------------
  int zKeyExprFromStr(
    ffi.Pointer<gen.z_owned_keyexpr_t> keyExpr,
    ffi.Pointer<ffi.Char> expr,
  ) =>
      _native.z_keyexpr_from_str(keyExpr, expr);

  void zKeyExprDrop(ffi.Pointer<gen.z_moved_keyexpr_t> keyExpr) =>
      _native.z_keyexpr_drop(keyExpr);

  ffi.Pointer<gen.z_loaned_keyexpr_t> zKeyExprLoan(
    ffi.Pointer<gen.z_owned_keyexpr_t> keyExpr,
  ) =>
      _native.z_keyexpr_loan(keyExpr);

  void zKeyExprAsViewString(
    ffi.Pointer<gen.z_loaned_keyexpr_t> keyExpr,
    ffi.Pointer<gen.z_view_string_t> outView,
  ) =>
      _native.z_keyexpr_as_view_string(keyExpr, outView);

  void zViewStringEmpty(ffi.Pointer<gen.z_view_string_t> view) =>
      _native.z_view_string_empty(view);

  ffi.Pointer<gen.z_loaned_string_t> zViewStringLoan(
    ffi.Pointer<gen.z_view_string_t> view,
  ) =>
      _native.z_view_string_loan(view);

  ffi.Pointer<ffi.Char> zStringData(
    ffi.Pointer<gen.z_loaned_string_t> string,
  ) =>
      _native.z_string_data(string);

  int zStringLen(ffi.Pointer<gen.z_loaned_string_t> string) =>
      _native.z_string_len(string);

  // --- Publisher --------------------------------------------------------------
  void zPublisherOptionsDefault(
    ffi.Pointer<gen.z_publisher_options_t> options,
  ) =>
      _native.z_publisher_options_default(options);

  int zDeclarePublisher(
    ffi.Pointer<gen.z_loaned_session_t> session,
    ffi.Pointer<gen.z_owned_publisher_t> publisher,
    ffi.Pointer<gen.z_loaned_keyexpr_t> keyExpr,
    ffi.Pointer<gen.z_publisher_options_t> options,
  ) =>
      _native.z_declare_publisher(session, publisher, keyExpr, options);

  ffi.Pointer<gen.z_loaned_publisher_t> zPublisherLoan(
    ffi.Pointer<gen.z_owned_publisher_t> publisher,
  ) =>
      _native.z_publisher_loan(publisher);

  void zPublisherDrop(ffi.Pointer<gen.z_moved_publisher_t> publisher) =>
      _native.z_publisher_drop(publisher);

  int zPublisherPut(
    ffi.Pointer<gen.z_loaned_publisher_t> publisher,
    ffi.Pointer<gen.z_moved_bytes_t> payload,
    ffi.Pointer<gen.z_publisher_put_options_t> options,
  ) =>
      _native.z_publisher_put(publisher, payload, options);

  void zPublisherPutOptionsDefault(
    ffi.Pointer<gen.z_publisher_put_options_t> options,
  ) =>
      _native.z_publisher_put_options_default(options);

  // --- Bytes ------------------------------------------------------------------
  int zBytesCopyFromBuf(
    ffi.Pointer<gen.z_owned_bytes_t> dst,
    ffi.Pointer<ffi.Uint8> buffer,
    int length,
  ) =>
      _native.z_bytes_copy_from_buf(dst, buffer, length);

  void zBytesDrop(ffi.Pointer<gen.z_moved_bytes_t> bytes) =>
      _native.z_bytes_drop(bytes);

  int zBytesGetContiguousView(
    ffi.Pointer<gen.z_loaned_bytes_t> bytes,
    ffi.Pointer<gen.z_view_slice_t> view,
  ) =>
      _native.z_bytes_get_contiguous_view(bytes, view);

  gen.z_bytes_reader_t zBytesGetReader(
    ffi.Pointer<gen.z_loaned_bytes_t> bytes,
  ) =>
      _native.z_bytes_get_reader(bytes);

  int zBytesReaderRead(
    ffi.Pointer<gen.z_bytes_reader_t> reader,
    ffi.Pointer<ffi.Uint8> dst,
    int length,
  ) =>
      _native.z_bytes_reader_read(reader, dst, length);

  int zBytesReaderRemaining(
    ffi.Pointer<gen.z_bytes_reader_t> reader,
  ) =>
      _native.z_bytes_reader_remaining(reader);

  ffi.Pointer<gen.z_loaned_bytes_t> zSamplePayload(
    ffi.Pointer<gen.z_loaned_sample_t> sample,
  ) =>
      _native.z_sample_payload(sample);

  ffi.Pointer<gen.z_loaned_keyexpr_t> zSampleKeyExpr(
    ffi.Pointer<gen.z_loaned_sample_t> sample,
  ) =>
      _native.z_sample_keyexpr(sample);

  // --- Slices -----------------------------------------------------------------
  ffi.Pointer<gen.z_loaned_slice_t> zViewSliceLoan(
    ffi.Pointer<gen.z_view_slice_t> view,
  ) =>
      _native.z_view_slice_loan(view);

  ffi.Pointer<ffi.Uint8> zSliceData(
    ffi.Pointer<gen.z_loaned_slice_t> slice,
  ) =>
      _native.z_slice_data(slice);

  int zSliceLen(ffi.Pointer<gen.z_loaned_slice_t> slice) =>
      _native.z_slice_len(slice);

  // --- Subscribers ------------------------------------------------------------
  void zSubscriberOptionsDefault(
    ffi.Pointer<gen.z_subscriber_options_t> options,
  ) =>
      _native.z_subscriber_options_default(options);

  int zDeclareSubscriber(
    ffi.Pointer<gen.z_loaned_session_t> session,
    ffi.Pointer<gen.z_owned_subscriber_t> subscriber,
    ffi.Pointer<gen.z_loaned_keyexpr_t> keyExpr,
    ffi.Pointer<gen.z_moved_closure_sample_t> callback,
    ffi.Pointer<gen.z_subscriber_options_t> options,
  ) =>
      _native.z_declare_subscriber(
        session,
        subscriber,
        keyExpr,
        callback,
        options,
      );

  void zSubscriberDrop(ffi.Pointer<gen.z_moved_subscriber_t> subscriber) =>
      _native.z_subscriber_drop(subscriber);

  void zClosureSample(
    ffi.Pointer<gen.z_owned_closure_sample_t> closure,
    ffi.Pointer<ffi.NativeFunction<ZenohSampleCallbackNative>> call,
    ffi.Pointer<ffi.NativeFunction<ZenohDropCallbackNative>> drop,
    ffi.Pointer<ffi.Void> context,
  ) =>
      _native.z_closure_sample(closure, call, drop, context);

  void zClosureSampleDrop(
    ffi.Pointer<gen.z_moved_closure_sample_t> closure,
  ) =>
      _native.z_closure_sample_drop(closure);
}
