import 'api/api.dart';
import 'client/nexa_http_response_mapper.dart';
import 'client/nexa_http_transport_session.dart';
import 'client/real_call.dart';
import 'data/mappers/native_http_client_config_mapper.dart';
import 'data/mappers/native_http_request_mapper.dart';
import 'internal/config/client_options.dart';
import 'internal/testing/nexa_http_testing_overrides.dart';
import 'native_bridge/nexa_http_native_data_source_factory.dart';

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
    : _session = NexaHttpTransportSession(
        options: _options,
        dataSourceFactory:
            NexaHttpTestingOverrides.nativeDataSourceFactory ??
            const NexaHttpNativeDataSourceFactory(),
        requestMapper: NativeHttpRequestMapper.toDto,
        configMapper: NativeHttpClientConfigMapper.toDto,
        responseMapper: const NexaHttpResponseMapper(),
      );

  final ClientOptions _options;
  final NexaHttpTransportSession _session;
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
    return _session.close();
  }

  Future<Response> _execute(
    Request request, {
    void Function(void Function() cancelRequest)? onCancelReady,
    bool Function()? isCanceled,
  }) async {
    return _session.execute(
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
