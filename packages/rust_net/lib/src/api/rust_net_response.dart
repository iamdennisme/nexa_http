import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'rust_net_response.freezed.dart';

@freezed
class RustNetResponse with _$RustNetResponse {
  const RustNetResponse._();

  const factory RustNetResponse({
    required int statusCode,
    @Default(<String, List<String>>{}) Map<String, List<String>> headers,
    @Default(<int>[]) List<int> bodyBytes,
    Uri? finalUri,
  }) = _RustNetResponse;

  bool get isSuccessful => statusCode >= 200 && statusCode < 300;

  String get bodyText => utf8.decode(bodyBytes);
}
