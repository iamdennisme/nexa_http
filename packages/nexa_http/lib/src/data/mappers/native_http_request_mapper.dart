import '../../api/api.dart';

import '../dto/native_http_request_dto.dart';

final class NativeHttpRequestMapper {
  const NativeHttpRequestMapper._();

  static NativeHttpRequestDto toDto({
    required NexaHttpClientConfig clientConfig,
    required NexaHttpRequest request,
  }) {
    final resolvedUri = _resolveUri(clientConfig.baseUrl, request.uri);
    final headers = <String, String>{
      ...clientConfig.defaultHeaders,
      ...request.headers,
    };
    final userAgent = clientConfig.userAgent;
    if (userAgent != null &&
        userAgent.isNotEmpty &&
        !_containsHeader(headers, 'user-agent')) {
      headers['user-agent'] = userAgent;
    }

    return NativeHttpRequestDto(
      method: request.method.wireValue,
      url: resolvedUri.toString(),
      headers: headers,
      bodyBytes: request.bodyBytes,
      timeoutMs: request.timeout?.inMilliseconds ??
          clientConfig.timeout?.inMilliseconds,
    );
  }

  static Uri _resolveUri(Uri? baseUrl, Uri requestUri) {
    if (requestUri.hasScheme) {
      return requestUri;
    }
    if (baseUrl == null) {
      throw NexaHttpException(
        code: 'invalid_request',
        message: 'Relative request URI requires NexaHttpClientConfig.baseUrl.',
        uri: requestUri,
      );
    }
    return baseUrl.resolveUri(requestUri);
  }

  static bool _containsHeader(Map<String, String> headers, String name) {
    final lowerCaseName = name.toLowerCase();
    return headers.keys.any((key) => key.toLowerCase() == lowerCaseName);
  }
}
