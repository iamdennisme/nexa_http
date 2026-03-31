import 'dart:convert';

final class TransportResponse {
  const TransportResponse({
    required this.statusCode,
    this.headers = const <String, List<String>>{},
    this.bodyBytes = const <int>[],
    this.finalUri,
  });

  final int statusCode;
  final Map<String, List<String>> headers;
  final List<int> bodyBytes;
  final Uri? finalUri;

  bool get isSuccessful => statusCode >= 200 && statusCode < 300;

  String get bodyText => utf8.decode(bodyBytes);
}
