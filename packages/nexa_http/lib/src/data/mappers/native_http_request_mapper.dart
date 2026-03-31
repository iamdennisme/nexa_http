import '../../api/nexa_http_exception.dart';
import '../../api/request.dart';
import '../../internal/config/client_options.dart';
import '../dto/native_http_request_dto.dart';

final class NativeHttpRequestMapper {
  const NativeHttpRequestMapper._();

  static NativeHttpRequestDto toDto({
    required ClientOptions clientConfig,
    required Request request,
  }) {
    final resolvedUri = _resolveUri(clientConfig.baseUrl, request.url);
    final requestHeaders = request.headers.toMultimap();
    final requestHeaderNames = requestHeaders.keys.toSet();
    final headers = <MapEntry<String, String>>[];

    for (final header in clientConfig.defaultHeaders.entries) {
      final name = header.key.trim().toLowerCase();
      if (requestHeaderNames.contains(name)) {
        continue;
      }
      headers.add(MapEntry<String, String>(name, header.value));
    }

    for (final header in requestHeaders.entries) {
      for (final value in header.value) {
        headers.add(MapEntry<String, String>(header.key, value));
      }
    }

    final seenHeaderNames = <String>{
      ...headers.map((header) => header.key),
    };

    final userAgent = clientConfig.userAgent;
    if (userAgent != null &&
        userAgent.isNotEmpty &&
        !seenHeaderNames.contains('user-agent')) {
      headers.add(MapEntry<String, String>('user-agent', userAgent));
      seenHeaderNames.add('user-agent');
    }
    final contentType = request.body?.contentType;
    if (contentType != null && !seenHeaderNames.contains('content-type')) {
      headers.add(
        MapEntry<String, String>('content-type', contentType.toString()),
      );
    }

    return NativeHttpRequestDto(
      method: request.method,
      url: resolvedUri.toString(),
      headers: headers,
      bodyBytes: request.body?.bytesValue,
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
        message:
            'Relative request URL requires NexaHttpClientBuilder.baseUrl().',
        uri: requestUri,
      );
    }
    return baseUrl.resolveUri(requestUri);
  }
}
