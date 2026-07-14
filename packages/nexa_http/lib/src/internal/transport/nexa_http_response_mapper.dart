import 'dart:typed_data';

import '../../api/api.dart';
import '../../api/response_body.dart';
import '../body/response_body_owner.dart';
import 'transport_response.dart';

final class NexaHttpResponseMapper {
  const NexaHttpResponseMapper();

  Response map({required Request request, required TransportResponse payload}) {
    final bodyOwner = payload.bodyOwner ?? DartResponseBodyOwner(Uint8List(0));
    var ownershipTransferred = false;
    try {
      final finalUrl = payload.finalUri;
      final responseRequest = finalUrl == null
          ? request
          : request.newBuilder().url(finalUrl).build();

      final headers = payload.headers;
      final contentType = _parseContentType(headers);
      final body = ResponseBodyTransportAccess.adopt(
        bodyOwner,
        contentType: contentType,
      );
      final response = Response(
        request: responseRequest,
        statusCode: payload.statusCode,
        headers: Headers.of(headers),
        body: body,
        finalUrl: finalUrl,
      );
      ownershipTransferred = true;
      return response;
    } finally {
      if (!ownershipTransferred) {
        bodyOwner.release();
      }
    }
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
