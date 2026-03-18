import 'dart:convert';

import 'package:rust_net_core/rust_net_core.dart';

import '../dto/native_http_response_dto.dart';

final class NativeHttpResponseMapper {
  const NativeHttpResponseMapper._();

  static RustNetResponse toDomain(NativeHttpResponseDto dto) {
    return RustNetResponse(
      statusCode: dto.statusCode,
      headers: dto.headers,
      bodyBytes: base64Decode(dto.bodyBase64),
      finalUri: dto.finalUrl == null ? null : Uri.tryParse(dto.finalUrl!),
    );
  }
}
