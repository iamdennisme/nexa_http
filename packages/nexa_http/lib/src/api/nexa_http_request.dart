import 'package:freezed_annotation/freezed_annotation.dart';

import 'nexa_http_method.dart';

part 'nexa_http_request.freezed.dart';

@freezed
class NexaHttpRequest with _$NexaHttpRequest {
  const NexaHttpRequest._();

  const factory NexaHttpRequest({
    required NexaHttpMethod method,
    required Uri uri,
    @Default(<String, String>{}) Map<String, String> headers,
    List<int>? bodyBytes,
    Duration? timeout,
  }) = _NexaHttpRequest;

  factory NexaHttpRequest.get({
    required Uri uri,
    Map<String, String> headers = const <String, String>{},
    Duration? timeout,
  }) {
    return NexaHttpRequest(
      method: NexaHttpMethod.get,
      uri: uri,
      headers: headers,
      timeout: timeout,
    );
  }

  factory NexaHttpRequest.post({
    required Uri uri,
    Map<String, String> headers = const <String, String>{},
    List<int>? bodyBytes,
    Duration? timeout,
  }) {
    return NexaHttpRequest(
      method: NexaHttpMethod.post,
      uri: uri,
      headers: headers,
      bodyBytes: bodyBytes,
      timeout: timeout,
    );
  }

  factory NexaHttpRequest.put({
    required Uri uri,
    Map<String, String> headers = const <String, String>{},
    List<int>? bodyBytes,
    Duration? timeout,
  }) {
    return NexaHttpRequest(
      method: NexaHttpMethod.put,
      uri: uri,
      headers: headers,
      bodyBytes: bodyBytes,
      timeout: timeout,
    );
  }

  factory NexaHttpRequest.delete({
    required Uri uri,
    Map<String, String> headers = const <String, String>{},
    Duration? timeout,
  }) {
    return NexaHttpRequest(
      method: NexaHttpMethod.delete,
      uri: uri,
      headers: headers,
      timeout: timeout,
    );
  }

  bool get hasBody => bodyBytes != null && bodyBytes!.isNotEmpty;
}
