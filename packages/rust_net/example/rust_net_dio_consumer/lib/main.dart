import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:rust_net/rust_net_dio.dart';

const String _fixtureBaseUrl = String.fromEnvironment(
  'RUST_NET_DIO_CONSUMER_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

void main() {
  runApp(const RustNetDioConsumerApp());
}

class RustNetDioConsumerApp extends StatelessWidget {
  const RustNetDioConsumerApp({
    super.key,
    this.autoInitialize = true,
  });

  final bool autoInitialize;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: RustNetDioConsumerPage(autoInitialize: autoInitialize),
    );
  }
}

class RustNetDioConsumerPage extends StatefulWidget {
  const RustNetDioConsumerPage({
    super.key,
    this.autoInitialize = true,
  });

  final bool autoInitialize;

  @override
  State<RustNetDioConsumerPage> createState() => _RustNetDioConsumerPageState();
}

class _RustNetDioConsumerPageState extends State<RustNetDioConsumerPage> {
  Dio? _dio;
  String? _error;
  String _result = 'Ready';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoInitialize) {
      unawaited(_initialize());
    }
  }

  @override
  void dispose() {
    _dio?.close(force: true);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: _fixtureBaseUrl,
          responseType: ResponseType.plain,
        ),
        )..httpClientAdapter = RustNetDioAdapter.client(
          config: const RustNetClientConfig(
            timeout: Duration(seconds: 10),
            userAgent: 'rust_net_dio_consumer/2.0.0',
          ),
        );

      if (!mounted) {
        dio.close(force: true);
        return;
      }

      setState(() {
        _dio = dio;
        _error = null;
      });
      debugPrint(
        'rust_net_dio_consumer initialized: '
        'native_asset=bundled, baseUrl=$_fixtureBaseUrl',
      );

      unawaited(_sendGet());
    } catch (error) {
      debugPrint('rust_net_dio_consumer init failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
      });
    }
  }

  Future<void> _sendGet() async {
    await _performRequest(
      label: 'GET /get',
      run: (dio) async {
        final response = await dio.get<String>(
          '/get',
          queryParameters: const <String, String>{'source': 'dio_consumer'},
        );
        return _formatResponse(
          method: 'GET',
          statusCode: response.statusCode,
          data: response.data,
        );
      },
    );
  }

  Future<void> _sendPost() async {
    await _performRequest(
      label: 'POST /echo',
      run: (dio) async {
        final payload = jsonEncode(
          <String, Object?>{'source': 'dio_consumer', 'kind': 'post'},
        );
        final response = await dio.post<String>(
          '/echo',
          data: payload,
          options: Options(contentType: Headers.jsonContentType),
        );
        return _formatResponse(
          method: 'POST',
          statusCode: response.statusCode,
          data: response.data,
        );
      },
    );
  }

  Future<void> _send404() async {
    await _performRequest(
      label: 'GET /status/404',
      run: (dio) async {
        final response = await dio.get<String>(
          '/status/404',
          options: Options(
            validateStatus: (_) => true,
            responseType: ResponseType.plain,
          ),
        );
        return _formatResponse(
          method: 'GET',
          statusCode: response.statusCode,
          data: response.data,
        );
      },
    );
  }

  Future<void> _sendTimeout() async {
    await _performRequest(
      label: 'GET /slow',
      run: (dio) async {
        try {
          await dio.get<void>(
            '/slow',
            queryParameters: const <String, String>{'delay_ms': '200'},
            options: Options(
              receiveTimeout: const Duration(milliseconds: 20),
            ),
          );
          return 'Expected a timeout, but the request succeeded.';
        } on DioException catch (error) {
          return 'GET /slow\n'
              'DioExceptionType: ${error.type.name}\n'
              'Message: ${error.message}';
        }
      },
    );
  }

  Future<void> _performRequest({
    required String label,
    required Future<String> Function(Dio dio) run,
  }) async {
    final dio = _dio;
    if (dio == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _result = 'Running $label ...';
    });

    try {
      final result = await run(dio);
      debugPrint('rust_net_dio_consumer request succeeded: $label => $result');
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
      });
    } catch (error) {
      debugPrint('rust_net_dio_consumer request failed: $label => $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatResponse({
    required String method,
    required int? statusCode,
    required String? data,
  }) {
    final preview = data ?? '';
    return '$method\n'
        'Status: ${statusCode ?? 'unknown'}\n\n'
        '${preview.length > 600 ? '${preview.substring(0, 600)}...' : preview}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('rust_net Dio Consumer'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Standalone Dio Integration',
                style: theme.textTheme.navLargeTitleTextStyle,
              ),
              const SizedBox(height: 12),
              Text(
                'Fixture base URL: $_fixtureBaseUrl',
                style: theme.textTheme.textStyle,
              ),
              const SizedBox(height: 8),
              Text(
                'Native asset: bundled by build hook',
                style: theme.textTheme.textStyle,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  CupertinoButton.filled(
                    onPressed: _isLoading ? null : _sendGet,
                    child: const Text('GET'),
                  ),
                  CupertinoButton.filled(
                    onPressed: _isLoading ? null : _sendPost,
                    child: const Text('POST'),
                  ),
                  CupertinoButton.filled(
                    onPressed: _isLoading ? null : _send404,
                    child: const Text('404'),
                  ),
                  CupertinoButton.filled(
                    onPressed: _isLoading ? null : _sendTimeout,
                    child: const Text('Timeout'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Text(
                  _error!,
                  style: theme.textTheme.textStyle.copyWith(
                    color: CupertinoColors.systemRed.resolveFrom(context),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: CupertinoColors.secondarySystemBackground
                        .resolveFrom(context),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _result,
                      style: theme.textTheme.textStyle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
