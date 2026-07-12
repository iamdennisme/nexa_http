// ignore_for_file: non_constant_identifier_names

import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:nexa_http/src/api/api.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:nexa_http/src/data/dto/native_http_request_dto.dart';
import 'package:nexa_http/src/data/sources/ffi_nexa_http_request_encoder.dart';
import 'package:test/test.dart';

void main() {
  test('copies a non-empty body into native ownership exactly once', () {
    final payload = Uint8List.fromList(const <int>[1, 2, 3, 4]);
    var allocationCount = 0;
    var copyCount = 0;
    Uint8List? copiedSource;

    final encoded = FfiNexaHttpRequestEncoder.encode(
      NativeHttpRequestDto(
        method: 'POST',
        url: 'https://example.com/upload',
        bodyBytes: payload,
      ),
      allocateBody: (bodyLength) {
        allocationCount += 1;
        return calloc<ffi.Uint8>(bodyLength);
      },
      copyBody: (source, destination) {
        copyCount += 1;
        copiedSource = source;
        destination.asTypedList(source.length).setAll(0, source);
      },
      releaseBody: (bodyPointer, _) => calloc.free(bodyPointer),
    );

    expect(allocationCount, 1);
    expect(copyCount, 1);
    expect(copiedSource, same(payload));
    expect(encoded.bodyPointer.asTypedList(encoded.bodyLength), payload);

    encoded.dispose();
  });

  test('rejects a null native allocation for a non-empty body', () {
    var copyCount = 0;
    var releaseCount = 0;

    expect(
      () => FfiNexaHttpRequestEncoder.encode(
        NativeHttpRequestDto(
          method: 'POST',
          url: 'https://example.com/upload',
          bodyBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        ),
        allocateBody: (_) => ffi.nullptr,
        copyBody: (_, _) {
          copyCount += 1;
        },
        releaseBody: (_, _) {
          releaseCount += 1;
        },
      ),
      throwsA(
        isA<NexaHttpException>().having(
          (error) => error.kind,
          'kind',
          NexaHttpFailureKind.internal,
        ),
      ),
    );
    expect(copyCount, 0);
    expect(releaseCount, 0);
  });

  test('releases native body memory once when copying fails', () {
    var releaseCount = 0;

    expect(
      () => FfiNexaHttpRequestEncoder.encode(
        NativeHttpRequestDto(
          method: 'POST',
          url: 'https://example.com/upload',
          bodyBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        ),
        allocateBody: (bodyLength) => calloc<ffi.Uint8>(bodyLength),
        copyBody: (_, _) => throw StateError('copy failed'),
        releaseBody: (bodyPointer, _) {
          releaseCount += 1;
          calloc.free(bodyPointer);
        },
      ),
      throwsA(isA<StateError>()),
    );
    expect(releaseCount, 1);
  });

  test('empty bodies allocate and copy nothing', () {
    var allocationCount = 0;
    var copyCount = 0;

    final encoded = FfiNexaHttpRequestEncoder.encode(
      NativeHttpRequestDto(
        method: 'POST',
        url: 'https://example.com/upload',
        bodyBytes: Uint8List(0),
      ),
      allocateBody: (_) {
        allocationCount += 1;
        return ffi.nullptr;
      },
      copyBody: (_, _) {
        copyCount += 1;
      },
      releaseBody: (_, _) {},
    );

    expect(allocationCount, 0);
    expect(copyCount, 0);
    expect(encoded.bodyPointer, ffi.nullptr);
    expect(encoded.bodyLength, 0);
    expect(encoded.bodyOwned, isFalse);

    encoded.dispose();
  });

  test('encodes structured native request fields into request args', () {
    final encoded = FfiNexaHttpRequestEncoder.encode(
      NativeHttpRequestDto(
        method: 'POST',
        url: 'https://example.com/upload',
        headers: <MapEntry<String, String>>[
          MapEntry<String, String>('accept', 'application/json'),
          MapEntry<String, String>('accept', 'application/problem+json'),
        ],
        bodyBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      ),
      allocateBody: (bodyLength) => calloc<ffi.Uint8>(bodyLength),
      releaseBody: (bodyPointer, _) => calloc.free(bodyPointer),
    );

    final wire = _StructuredRequestWire.fromPointer(encoded.pointer);

    expect(wire.method, 'POST');
    expect(wire.url, 'https://example.com/upload');
    expect(
      wire.headers.map((header) => (header.key, header.value)).toList(),
      equals(const <(String, String)>[
        ('accept', 'application/json'),
        ('accept', 'application/problem+json'),
      ]),
    );
    expect(wire.timeoutMs, isNull);
    expect(wire.bodyBytes, Uint8List.fromList(const <int>[1, 2, 3, 4]));
    expect(wire.bodyOwned, isTrue);

    encoded.dispose();
  });

  test(
    'releases owned request buffers exactly once when dispatch keeps ownership',
    () {
      var releaseCount = 0;
      final encoded = FfiNexaHttpRequestEncoder.encode(
        NativeHttpRequestDto(
          method: 'POST',
          url: 'https://example.com/upload',
          bodyBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        ),
        allocateBody: (bodyLength) => calloc<ffi.Uint8>(bodyLength),
        releaseBody: (bodyPointer, _) {
          releaseCount += 1;
          calloc.free(bodyPointer);
        },
      );

      encoded.dispose();

      expect(releaseCount, 1);
    },
  );

  test('does not release request buffers after body ownership transfer', () {
    var releaseCount = 0;
    final encoded = FfiNexaHttpRequestEncoder.encode(
      NativeHttpRequestDto(
        method: 'POST',
        url: 'https://example.com/upload',
        bodyBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      ),
      allocateBody: (bodyLength) => calloc<ffi.Uint8>(bodyLength),
      releaseBody: (bodyPointer, _) {
        releaseCount += 1;
        calloc.free(bodyPointer);
      },
    );

    encoded.transferBodyOwnership();
    encoded.dispose();

    expect(releaseCount, 0);
    calloc.free(encoded.bodyPointer);
  });
}

class _StructuredRequestWire {
  const _StructuredRequestWire({
    required this.method,
    required this.url,
    required this.headers,
    required this.timeoutMs,
    required this.bodyBytes,
    required this.bodyOwned,
  });

  factory _StructuredRequestWire.fromPointer(
    ffi.Pointer<NexaHttpRequestArgs> pointer,
  ) {
    final request = pointer.ref;
    final headers = <MapEntry<String, String>>[];
    for (var index = 0; index < request.headers_len; index += 1) {
      final entry = (request.headers_ptr + index).ref;
      headers.add(
        MapEntry<String, String>(
          _readUtf8(entry.name_ptr, entry.name_len),
          _readUtf8(entry.value_ptr, entry.value_len),
        ),
      );
    }

    return _StructuredRequestWire(
      method: _readUtf8(request.method_ptr, request.method_len),
      url: _readUtf8(request.url_ptr, request.url_len),
      headers: headers,
      timeoutMs: request.has_timeout == 0 ? null : request.timeout_ms,
      bodyBytes: request.body_ptr == ffi.nullptr
          ? Uint8List(0)
          : Uint8List.fromList(request.body_ptr.asTypedList(request.body_len)),
      bodyOwned: request.body_owned != 0,
    );
  }

  final String method;
  final String url;
  final List<MapEntry<String, String>> headers;
  final int? timeoutMs;
  final Uint8List bodyBytes;
  final bool bodyOwned;
}

String _readUtf8(ffi.Pointer<ffi.Char> pointer, int length) {
  if (length == 0) {
    return '';
  }
  return pointer.cast<Utf8>().toDartString(length: length);
}
