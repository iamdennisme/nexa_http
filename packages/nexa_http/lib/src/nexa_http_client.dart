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
        defaultHeaders: Map<String, String>.unmodifiable(defaultHeaders),
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
}
