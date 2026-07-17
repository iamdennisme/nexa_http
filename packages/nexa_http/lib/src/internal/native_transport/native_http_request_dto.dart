import 'dart:typed_data';

final class NativeHttpRequestDto {
  const NativeHttpRequestDto({
    required this.method,
    required this.url,
    this.headers = const <MapEntry<String, String>>[],
    this.bodyBytes,
    this.timeoutMs,
  });

  final String method;
  final String url;
  final List<MapEntry<String, String>> headers;
  final Uint8List? bodyBytes;
  final int? timeoutMs;
}
