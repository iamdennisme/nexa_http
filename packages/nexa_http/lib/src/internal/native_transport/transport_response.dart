import '../body/response_body_owner.dart';

final class TransportResponse {
  const TransportResponse({
    required this.statusCode,
    this.headers = const <String, List<String>>{},
    this.bodyOwner,
    this.finalUri,
  });

  final int statusCode;
  final Map<String, List<String>> headers;
  final ResponseBodyOwner? bodyOwner;
  final Uri? finalUri;
}
