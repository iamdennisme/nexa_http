import '../../api/nexa_http_exception.dart';
import '../../api/request.dart';
import '../../internal/config/client_options.dart';
import '../dto/native_http_request_dto.dart';

final class NativeHttpRequestMapper {
  const NativeHttpRequestMapper._();

  static Future<Map<String, Object?>> toPayload({
    required ClientOptions clientConfig,
    required Request request,
  }) async {
    final resolvedUri = _resolveUri(clientConfig.baseUrl, request.url);
    final headers = <String, String>{
      ...clientConfig.defaultHeaders,
      ...request.headers.toMap(),
    };
    final userAgent = clientConfig.userAgent;
    if (userAgent != null &&
        userAgent.isNotEmpty &&
        !_containsHeader(headers, 'user-agent')) {
      headers['user-agent'] = userAgent;
    }
    final contentType = request.body?.contentType;
    if (contentType != null && !_containsHeader(headers, 'content-type')) {
      headers['content-type'] = contentType.toString();
    }

    final dto = NativeHttpRequestDto(
      method: request.method,
      url: resolvedUri.toString(),
      headers: headers,
      bodyBytes: request.body?.bytesValue,
      timeoutMs: request.timeout?.inMilliseconds ??
          clientConfig.timeout?.inMilliseconds,
    );

    return <String, Object?>{
      ...dto.toJson(),
      if (dto.bodyBytes != null) 'bodyBytes': dto.bodyBytes,
    };
  }

  static Uri _resolveUri(Uri? baseUrl, Uri requestUri) {
    if (requestUri.hasScheme) {
      return requestUri;
    }
    if (baseUrl == null) {
      throw NexaHttpException(
        code: 'invalid_request',
        message: 'Relative request URL requires NexaHttpClientBuilder.baseUrl().',
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
