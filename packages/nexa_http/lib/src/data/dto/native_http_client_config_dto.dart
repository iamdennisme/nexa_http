final class NativeHttpClientConfigDto {
  const NativeHttpClientConfigDto({
    this.defaultHeaders = const <String, String>{},
    this.timeoutMs,
    this.userAgent,
  });

  final Map<String, String> defaultHeaders;
  final int? timeoutMs;
  final String? userAgent;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'default_headers': defaultHeaders,
      'timeout_ms': timeoutMs,
      'user_agent': userAgent,
    };
  }
}
