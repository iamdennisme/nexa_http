import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:nexa_http/nexa_http_bindings_generated.dart';

import '../dto/native_http_client_config_dto.dart';

final class FfiNexaHttpClientConfigEncoder {
  const FfiNexaHttpClientConfigEncoder._();

  static FfiEncodedNativeClientConfig encode(NativeHttpClientConfigDto config) {
    return FfiEncodedNativeClientConfig._fromDto(config);
  }
}

final class FfiEncodedNativeClientConfig {
  FfiEncodedNativeClientConfig._(this._arena, this.pointer);

  final Arena _arena;
  final Pointer<NexaHttpClientConfigArgs> pointer;

  factory FfiEncodedNativeClientConfig._fromDto(NativeHttpClientConfigDto config) {
    final arena = Arena();
    final pointer = arena<NexaHttpClientConfigArgs>();
    final defaultHeaders = config.defaultHeaders.entries.toList(growable: false);
    final defaultHeadersPointer = defaultHeaders.isEmpty
        ? nullptr
        : arena<NexaHttpHeaderEntry>(defaultHeaders.length);

    for (var index = 0; index < defaultHeaders.length; index += 1) {
      final header = defaultHeaders[index];
      final name = _NativeUtf8Slice.allocate(header.key, arena);
      final value = _NativeUtf8Slice.allocate(header.value, arena);
      defaultHeadersPointer[index]
        ..name_ptr = name.pointer.cast()
        ..name_len = name.length
        ..value_ptr = value.pointer.cast()
        ..value_len = value.length;
    }

    final userAgent = config.userAgent;
    final encodedUserAgent = userAgent == null
        ? null
        : _NativeUtf8Slice.allocate(userAgent, arena);

    pointer.ref
      ..default_headers_ptr = defaultHeadersPointer
      ..default_headers_len = defaultHeaders.length
      ..user_agent_ptr = encodedUserAgent?.pointer.cast() ?? nullptr
      ..user_agent_len = encodedUserAgent?.length ?? 0
      ..timeout_ms = config.timeoutMs ?? 0
      ..has_timeout = config.timeoutMs == null ? 0 : 1;

    return FfiEncodedNativeClientConfig._(arena, pointer);
  }

  void dispose() {
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
