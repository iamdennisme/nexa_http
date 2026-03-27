import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'nexa_http_response.freezed.dart';

@freezed
class NexaHttpResponse with _$NexaHttpResponse {
  const NexaHttpResponse._();

  const factory NexaHttpResponse({
    required int statusCode,
    @Default(<String, List<String>>{}) Map<String, List<String>> headers,
    @Default(<int>[]) List<int> bodyBytes,
    Uri? finalUri,
  }) = _NexaHttpResponse;

  bool get isSuccessful => statusCode >= 200 && statusCode < 300;

  String get bodyText => utf8.decode(bodyBytes);
}
