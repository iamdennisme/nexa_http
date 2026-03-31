import 'api/api.dart';
import 'client/real_call.dart';
import 'internal/config/client_options.dart';

final class NexaHttpClient {
  factory NexaHttpClient({
    Uri? baseUrl,
    Duration? callTimeout,
    Map<String, String> defaultHeaders = const <String, String>{},
    String? userAgent,
  }) {
    return NexaHttpClient._(
      ClientOptions(
        baseUrl: baseUrl,
        defaultHeaders: _normalizeDefaultHeaders(defaultHeaders),
        timeout: callTimeout,
        userAgent: userAgent,
      ),
    );
  }

  NexaHttpClient._(this._options);

  final ClientOptions _options;

  Uri? get baseUrl => _options.baseUrl;

  Duration? get callTimeout => _options.timeout;

  Headers get defaultHeaders => Headers.fromMap(_options.defaultHeaders);

  String? get userAgent => _options.userAgent;

  Call newCall(Request request) {
    return RealCall(clientOptions: _options, request: request);
  }

  static Map<String, String> _normalizeDefaultHeaders(
    Map<String, String> headers,
  ) {
    if (headers.isEmpty) {
      return const <String, String>{};
    }

    final normalized = <String, String>{};
    for (final entry in headers.entries) {
      normalized[entry.key.trim().toLowerCase()] = entry.value;
    }
    return Map<String, String>.unmodifiable(normalized);
  }
}
