import 'api/api.dart';
import 'client/real_call.dart';
import 'internal/config/client_options.dart';
import 'internal/native_transport/nexa_http_native_transport.dart';

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

  NexaHttpClient._(this._options)
    : _transport = NexaHttpNativeTransport(options: _options);

  final ClientOptions _options;
  final NexaHttpNativeTransport _transport;
  Headers? _defaultHeadersView;

  Uri? get baseUrl => _options.baseUrl;

  Duration? get callTimeout => _options.timeout;

  Headers get defaultHeaders =>
      _defaultHeadersView ??= Headers.fromMap(_options.defaultHeaders);

  String? get userAgent => _options.userAgent;

  Call newCall(Request request) {
    return RealCall(request: request, executeRequest: _execute);
  }

  Future<void> close() {
    return _transport.close();
  }

  Future<Response> _execute(
    Request request, {
    void Function(void Function() cancelRequest)? onCancelReady,
    bool Function()? isCanceled,
  }) async {
    return _transport.execute(
      request,
      onCancelReady: onCancelReady,
      isCanceled: isCanceled,
    );
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
