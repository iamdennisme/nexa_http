import '../nexa_http_client.dart';

final class NexaHttpClientBuilder {
  Uri? _baseUrl;
  Duration? _callTimeout;
  String? _userAgent;
  final Map<String, String> _defaultHeaders = <String, String>{};

  NexaHttpClientBuilder baseUrl(Uri value) {
    _baseUrl = value;
    return this;
  }

  NexaHttpClientBuilder callTimeout(Duration value) {
    _callTimeout = value;
    return this;
  }

  NexaHttpClientBuilder userAgent(String value) {
    _userAgent = value;
    return this;
  }

  NexaHttpClientBuilder header(String name, String value) {
    _defaultHeaders[name] = value;
    return this;
  }

  NexaHttpClient build() {
    return NexaHttpClient(
      baseUrl: _baseUrl,
      callTimeout: _callTimeout,
      defaultHeaders: _defaultHeaders,
      userAgent: _userAgent,
    );
  }
}
