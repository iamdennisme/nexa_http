import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:nexa_http/nexa_http_bindings_generated.dart';

import '../dto/native_http_request_dto.dart';

final class FfiNexaHttpRequestEncoder {
  const FfiNexaHttpRequestEncoder._();

  static FfiEncodedNativeRequest encode(
    NativeHttpRequestDto request, {
    required Pointer<Uint8> Function(int bodyLength) allocateBody,
    required void Function(Pointer<Uint8> bodyPointer, int bodyLength)
    releaseBody,
  }) {
    return FfiEncodedNativeRequest._fromDto(
      request,
      allocateBody: allocateBody,
      releaseBody: releaseBody,
    );
  }
}

final class FfiEncodedNativeRequest {
  FfiEncodedNativeRequest._({
    required Arena arena,
    required this.pointer,
    required this.releaseBody,
    required this.bodyPointer,
    required this.bodyLength,
    required this.bodyOwned,
  }) : _arena = arena;

  final Arena _arena;
  final Pointer<NexaHttpRequestArgs> pointer;
  final void Function(Pointer<Uint8> bodyPointer, int bodyLength) releaseBody;
  final Pointer<Uint8> bodyPointer;
  final int bodyLength;
  bool bodyOwned;

  factory FfiEncodedNativeRequest._fromDto(
    NativeHttpRequestDto request, {
    required Pointer<Uint8> Function(int bodyLength) allocateBody,
    required void Function(Pointer<Uint8> bodyPointer, int bodyLength)
    releaseBody,
  }) {
    final arena = Arena();
    final pointer = arena<NexaHttpRequestArgs>();
    final method = _NativeUtf8Slice.allocate(request.method, arena);
    final url = _NativeUtf8Slice.allocate(request.url, arena);
    final headers = request.headers;
    final headersLength = headers.length;
    final headersPointer = headersLength == 0
        ? nullptr
        : arena<NexaHttpHeaderEntry>(headersLength);

    var index = 0;
    for (final header in headers) {
      final name = _NativeUtf8Slice.allocate(header.key, arena);
      final value = _NativeUtf8Slice.allocate(header.value, arena);
      headersPointer[index]
        ..name_ptr = name.pointer.cast()
        ..name_len = name.length
        ..value_ptr = value.pointer.cast()
        ..value_len = value.length;
      index += 1;
    }

    final bodyBytes = request.bodyBytes;
    final bodyPointer = bodyBytes == null || bodyBytes.isEmpty
        ? nullptr
        : allocateBody(bodyBytes.length);
    if (bodyPointer != nullptr) {
      bodyPointer.asTypedList(bodyBytes!.length).setAll(0, bodyBytes);
    }
    final bodyLength = bodyBytes?.length ?? 0;
    final bodyOwned = bodyPointer != nullptr && bodyLength > 0;

    final timeoutMs = request.timeoutMs;
    pointer.ref
      ..method_ptr = method.pointer.cast()
      ..method_len = method.length
      ..url_ptr = url.pointer.cast()
      ..url_len = url.length
      ..headers_ptr = headersPointer
      ..headers_len = headersLength
      ..body_ptr = bodyPointer
      ..body_len = bodyLength
      ..body_owned = bodyOwned ? 1 : 0
      ..timeout_ms = timeoutMs ?? 0
      ..has_timeout = timeoutMs == null ? 0 : 1;

    return FfiEncodedNativeRequest._(
      arena: arena,
      pointer: pointer,
      releaseBody: releaseBody,
      bodyPointer: bodyPointer,
      bodyLength: bodyLength,
      bodyOwned: bodyOwned,
    );
  }

  void transferBodyOwnership() {
    bodyOwned = false;
  }

  void dispose() {
    if (bodyOwned && bodyPointer != nullptr && bodyLength > 0) {
      releaseBody(bodyPointer, bodyLength);
    }
    _arena.releaseAll();
  }
}

final class _NativeUtf8Slice {
  const _NativeUtf8Slice(this.pointer, this.length);

  final Pointer<Utf8> pointer;
  final int length;

  factory _NativeUtf8Slice.allocate(String value, Arena arena) {
    final encoded = utf8.encode(value);
    final pointer = arena<Uint8>(encoded.length + 1);
    final bytes = pointer.asTypedList(encoded.length + 1);
    bytes.setAll(0, encoded);
    bytes[encoded.length] = 0;
    return _NativeUtf8Slice(pointer.cast(), encoded.length);
  }
}
