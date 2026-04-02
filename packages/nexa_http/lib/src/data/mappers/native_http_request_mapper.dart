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
    final headers = <MapEntry<String, String>>[];

    for (final header in requestHeaders.entries) {
      for (final value in header.value) {
        headers.add(MapEntry<String, String>(header.key, value));
      }
    }
    final contentType = request.body?.contentType;
    if (contentType != null &&
        !requestHeaders.containsKey('content-type') &&
        !clientConfig.defaultHeaders.containsKey('content-type')) {
      headers.add(
        MapEntry<String, String>('content-type', contentType.toString()),
      );
    }

    return NativeHttpRequestDto(
      method: request.method,
      url: resolvedUri.toString(),
      headers: headers,
      bodyBytes: request.body?.ffiTransferBytes,
      timeoutMs: request.timeout?.inMilliseconds,
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
