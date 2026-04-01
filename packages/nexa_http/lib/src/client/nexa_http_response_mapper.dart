import '../api/api.dart';
import '../internal/transport/transport_response.dart';

final class NexaHttpResponseMapper {
  const NexaHttpResponseMapper();

  Response map({
    required Request request,
    required TransportResponse payload,
  }) {
    final finalUrl = payload.finalUri;
    final responseRequest = finalUrl == null
        ? request
        : request.newBuilder().url(finalUrl).build();

    final headers = payload.headers;
    final contentType = _parseContentType(headers);

    return Response(
      request: responseRequest,
      statusCode: payload.statusCode,
      headers: Headers.of(headers),
      body: adoptResponseBodyBytes(payload.bodyBytes, contentType: contentType),
      finalUrl: finalUrl,
    );
  }

  MediaType? _parseContentType(Map<String, List<String>> headers) {
    final values = headers['content-type'];
    if (values == null || values.isEmpty) {
      return null;
    }

    try {
      return MediaType.parse(values.last);
    } on FormatException {
      return null;
    }
  }
}
