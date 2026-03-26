import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'rust_net_method.dart';

part 'rust_net_request.freezed.dart';

@freezed
class RustNetRequest with _$RustNetRequest {
  const RustNetRequest._();

  const factory RustNetRequest({
    required RustNetMethod method,
    required Uri uri,
    @Default(<String, String>{}) Map<String, String> headers,
    List<int>? bodyBytes,
    Duration? timeout,
  }) = _RustNetRequest;

  factory RustNetRequest.get({
    required Uri uri,
    Map<String, String> headers = const <String, String>{},
    Duration? timeout,
  }) {
    return RustNetRequest(
      method: RustNetMethod.get,
      uri: uri,
      headers: headers,
      timeout: timeout,
    );
  }

  factory RustNetRequest.delete({
    required Uri uri,
    Map<String, String> headers = const <String, String>{},
    Duration? timeout,
  }) {
    return RustNetRequest(
      method: RustNetMethod.delete,
      uri: uri,
      headers: headers,
      timeout: timeout,
    );
  }

  factory RustNetRequest.text({
    required RustNetMethod method,
    required Uri uri,
    required String body,
    Encoding encoding = utf8,
    Map<String, String> headers = const <String, String>{},
    Duration? timeout,
  }) {
    return RustNetRequest(
      method: method,
      uri: uri,
      headers: headers,
      bodyBytes: encoding.encode(body),
      timeout: timeout,
    );
  }

  factory RustNetRequest.json({
    required RustNetMethod method,
    required Uri uri,
    required Object? body,
    Encoding encoding = utf8,
    Map<String, String> headers = const <String, String>{},
    Duration? timeout,
  }) {
    return RustNetRequest(
      method: method,
      uri: uri,
      headers: <String, String>{
        'content-type': 'application/json',
        ...headers,
      },
      bodyBytes: encoding.encode(jsonEncode(body)),
      timeout: timeout,
    );
  }

  bool get hasBody => bodyBytes != null && bodyBytes!.isNotEmpty;
}
