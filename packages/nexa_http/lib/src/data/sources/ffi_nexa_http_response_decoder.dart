import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import '../../api/nexa_http_exception.dart';
import '../../internal/body/response_body_owner.dart';
import '../../internal/transport/transport_response.dart';
import '../dto/native_http_error_dto.dart';
import '../mappers/native_http_error_mapper.dart';

typedef BinaryResultRelease =
    void Function(Pointer<NexaHttpBinaryResult> resultPointer);

final class FfiNexaHttpResponseDecoder {
  const FfiNexaHttpResponseDecoder({
    required BinaryResultRelease releaseBinaryResult,
    required NativeFinalizer? binaryResultNativeFinalizer,
  }) : _releaseBinaryResult = releaseBinaryResult,
       _binaryResultNativeFinalizer = binaryResultNativeFinalizer;

  final BinaryResultRelease _releaseBinaryResult;
  final NativeFinalizer? _binaryResultNativeFinalizer;

  TransportResponse decode(Pointer<NexaHttpBinaryResult> resultPointer) {
    if (resultPointer == nullptr) {
      throw const NexaHttpException(
        kind: NexaHttpFailureKind.internal,
        message: 'The nexa_http native library returned a null binary result.',
        diagnostics: <String, Object?>{
          'stage': 'response_decode',
          'native_code': 'ffi_invalid_response',
        },
      );
    }

    var releaseResult = true;
    try {
      final result = resultPointer.ref;
      if (result.is_success == 0) {
        throw _decodeError(result.error_json);
      }

      final statusCode = result.status_code;
      final headers = _decodeHeaders(result.headers_ptr, result.headers_len);
      final finalUri = _decodeFinalUri(
        result.final_url_ptr,
        result.final_url_len,
      );
      final ResponseBodyOwner bodyOwner;
      if (result.body_len == 0) {
        releaseResult = false;
        _releaseBinaryResult(resultPointer);
        bodyOwner = DartResponseBodyOwner(Uint8List(0));
      } else {
        if (result.body_ptr == nullptr) {
          throw const NexaHttpException(
            kind: NexaHttpFailureKind.internal,
            message:
                'The nexa_http native library returned a null body pointer for a non-empty response body.',
            diagnostics: <String, Object?>{
              'stage': 'response_body_decode',
              'native_code': 'ffi_invalid_response',
            },
          );
        }
        bodyOwner = NativeResponseBodyOwner(
          result.body_ptr.asTypedList(result.body_len),
          release: () => _releaseBinaryResult(resultPointer),
          finalizer: _binaryResultNativeFinalizer,
          finalizerToken: resultPointer.cast(),
          externalSize: result.body_len,
        );
        releaseResult = false;
      }

      return TransportResponse(
        statusCode: statusCode,
        headers: headers,
        bodyOwner: bodyOwner,
        finalUri: finalUri,
      );
    } catch (_) {
      if (releaseResult) {
        _releaseBinaryResult(resultPointer);
      }
      rethrow;
    }
  }

  Map<String, List<String>> _decodeHeaders(
    Pointer<NexaHttpHeaderEntry> headersPointer,
    int headersLength,
  ) {
    if (headersLength == 0) {
      return const <String, List<String>>{};
    }
    if (headersPointer == nullptr) {
      throw const NexaHttpException(
        kind: NexaHttpFailureKind.internal,
        message:
            'The nexa_http native library returned invalid response headers.',
        diagnostics: <String, Object?>{
          'stage': 'response_headers_decode',
          'native_code': 'ffi_invalid_response',
        },
      );
    }

    final headers = <String, List<String>>{};
    for (var index = 0; index < headersLength; index += 1) {
      final entry = (headersPointer + index).ref;
      final name = _decodeSizedString(
        entry.name_ptr,
        entry.name_len,
        fieldName: 'response header name',
      );
      final value = _decodeSizedString(
        entry.value_ptr,
        entry.value_len,
        fieldName: 'response header value',
      );
      (headers[name] ??= <String>[]).add(value);
    }
    return headers;
  }

  Uri? _decodeFinalUri(Pointer<Char> finalUrlPointer, int finalUrlLength) {
    if (finalUrlLength == 0) {
      return null;
    }
    final value = _decodeSizedString(
      finalUrlPointer,
      finalUrlLength,
      fieldName: 'final response URL',
    );
    try {
      return Uri.parse(value);
    } on FormatException catch (error) {
      throw NexaHttpException(
        kind: NexaHttpFailureKind.internal,
        message:
            'The nexa_http native library returned an invalid final response URL.',
        diagnostics: <String, Object?>{
          'stage': 'response_final_url_decode',
          'native_code': 'ffi_invalid_response',
          'native_value': value,
          'error': error.toString(),
        },
      );
    }
  }

  NexaHttpException _decodeError(Pointer<Char> errorPointer) {
    if (errorPointer == nullptr) {
      return const NexaHttpException(
        kind: NexaHttpFailureKind.internal,
        message:
            'The nexa_http native library returned an invalid error result.',
        diagnostics: <String, Object?>{
          'stage': 'response_error_decode',
          'native_code': 'ffi_invalid_response',
        },
      );
    }

    try {
      final decoded = jsonDecode(errorPointer.cast<Utf8>().toDartString());
      if (decoded is! Map) {
        return const NexaHttpException(
          kind: NexaHttpFailureKind.internal,
          message:
              'The nexa_http native library returned invalid error payload.',
          diagnostics: <String, Object?>{
            'stage': 'response_error_decode',
            'native_code': 'ffi_invalid_response',
          },
        );
      }

      return NativeHttpErrorMapper.toDomain(
        NativeHttpErrorDto.fromJson(
          Map<String, dynamic>.from(decoded.cast<String, Object?>()),
        ),
      );
    } on Object catch (error) {
      return NexaHttpException(
        kind: NexaHttpFailureKind.internal,
        message:
            'The nexa_http native library returned malformed error payload.',
        diagnostics: <String, Object?>{
          'stage': 'response_error_decode',
          'native_code': 'ffi_invalid_response',
          'error_type': error.runtimeType.toString(),
          'error': error.toString(),
        },
      );
    }
  }

  String _decodeSizedString(
    Pointer<Char> pointer,
    int length, {
    required String fieldName,
  }) {
    if (length == 0) {
      return '';
    }
    if (pointer == nullptr) {
      throw NexaHttpException(
        kind: NexaHttpFailureKind.internal,
        message:
            'The nexa_http native library returned a null pointer for $fieldName.',
        diagnostics: <String, Object?>{
          'stage': 'response_field_decode',
          'field': fieldName,
          'native_code': 'ffi_invalid_response',
        },
      );
    }
    return pointer.cast<Utf8>().toDartString(length: length);
  }
}
