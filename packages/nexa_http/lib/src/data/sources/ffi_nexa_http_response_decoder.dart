import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:nexa_http/nexa_http_bindings_generated.dart';

import '../../api/nexa_http_exception.dart';
import '../../internal/body/native_response_body_bytes.dart';
import '../../internal/transport/transport_response.dart';
import '../dto/native_http_error_dto.dart';
import '../mappers/native_http_error_mapper.dart';

typedef BinaryResultRelease = void Function(
  Pointer<NexaHttpBinaryResult> resultPointer,
);

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
        code: 'ffi_invalid_response',
        message: 'The nexa_http native library returned a null binary result.',
      );
    }

    final result = resultPointer.ref;
    if (result.is_success == 0) {
      throw _decodeError(result.error_json);
    }

    final headers = _decodeHeaders(result.headers_ptr, result.headers_len);
    final finalUri = _decodeFinalUri(
      result.final_url_ptr,
      result.final_url_len,
    );
    final bodyBytes = _takeResponseBody(resultPointer, result);

    return TransportResponse(
      statusCode: result.status_code,
      headers: headers,
      bodyBytes: bodyBytes,
      finalUri: finalUri,
    );
  }

  bool adoptsBodyOwnership(NexaHttpBinaryResult result) {
    return result.body_ptr != nullptr && result.body_len > 0;
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
        code: 'ffi_invalid_response',
        message:
            'The nexa_http native library returned invalid response headers.',
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

  List<int> _takeResponseBody(
    Pointer<NexaHttpBinaryResult> resultPointer,
    NexaHttpBinaryResult result,
  ) {
    if (result.body_len == 0) {
      return const <int>[];
    }
    if (result.body_ptr == nullptr) {
      throw const NexaHttpException(
        code: 'ffi_invalid_response',
        message:
            'The nexa_http native library returned a null body pointer for a non-empty response body.',
      );
    }

    final bytes = result.body_ptr.asTypedList(result.body_len);
    return adoptNativeResponseBodyBytes(
      bytes,
      release: () => _releaseBinaryResult(resultPointer),
      finalizer: _binaryResultNativeFinalizer,
      finalizerToken: resultPointer.cast(),
      externalSize: result.body_len,
    );
  }

  Uri? _decodeFinalUri(Pointer<Char> finalUrlPointer, int finalUrlLength) {
    if (finalUrlLength == 0) {
      return null;
    }
    return Uri.tryParse(
      _decodeSizedString(
        finalUrlPointer,
        finalUrlLength,
        fieldName: 'final response URL',
      ),
    );
  }

  NexaHttpException _decodeError(Pointer<Char> errorPointer) {
    if (errorPointer == nullptr) {
      return const NexaHttpException(
        code: 'ffi_invalid_response',
        message:
            'The nexa_http native library returned an invalid error result.',
      );
    }

    final decoded = jsonDecode(errorPointer.cast<Utf8>().toDartString());
    if (decoded is! Map) {
      return const NexaHttpException(
        code: 'ffi_invalid_response',
        message: 'The nexa_http native library returned invalid error payload.',
      );
    }

    return NativeHttpErrorMapper.toDomain(
      NativeHttpErrorDto.fromJson(
        Map<String, dynamic>.from(decoded.cast<String, Object?>()),
      ),
    );
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
        code: 'ffi_invalid_response',
        message:
            'The nexa_http native library returned a null pointer for $fieldName.',
      );
    }
    return pointer.cast<Utf8>().toDartString(length: length);
  }
}
