import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:nexa_http/nexa_http_dio.dart';

const String _fixtureBaseUrl = String.fromEnvironment(
  'RUST_NET_DIO_CONSUMER_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

void main() {
  runApp(const NexaHttpDioConsumerApp());
}

class NexaHttpDioConsumerApp extends StatelessWidget {
  const NexaHttpDioConsumerApp({
    super.key,
    this.autoInitialize = true,
  });

  final bool autoInitialize;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: NexaHttpDioConsumerPage(autoInitialize: autoInitialize),
    );
  }
}

class NexaHttpDioConsumerPage extends StatefulWidget {
  const NexaHttpDioConsumerPage({
    super.key,
    this.autoInitialize = true,
  });

  final bool autoInitialize;

  @override
  State<NexaHttpDioConsumerPage> createState() => _NexaHttpDioConsumerPageState();
}

class _NexaHttpDioConsumerPageState extends State<NexaHttpDioConsumerPage> {
  Dio? _rustNetDio;
  Dio? _directDio;
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
    _rustNetDio?.close(force: true);
    _directDio?.close(force: true);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final rustNetDio = Dio(
        BaseOptions(
          baseUrl: _fixtureBaseUrl,
          responseType: ResponseType.plain,
        ),
      )..httpClientAdapter = NexaHttpDioAdapter.client(
          config: const NexaHttpClientConfig(
            timeout: Duration(seconds: 10),
            userAgent: 'nexa_http_dio_consumer/1.0.0',
          ),
        );
      final directDio = Dio(
        BaseOptions(
          baseUrl: _fixtureBaseUrl,
          responseType: ResponseType.plain,
        ),
      );

      if (!mounted) {
        rustNetDio.close(force: true);
        directDio.close(force: true);
        return;
      }

      setState(() {
        _rustNetDio = rustNetDio;
        _directDio = directDio;
        _error = null;
      });
      debugPrint(
        'nexa_http_dio_consumer initialized: '
        'baseUrl=$_fixtureBaseUrl',
      );

      unawaited(_sendGet());
    } catch (error) {
      debugPrint('nexa_http_dio_consumer init failed: $error');
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
      dio: _rustNetDio,
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
      dio: _rustNetDio,
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
      dio: _rustNetDio,
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
      dio: _rustNetDio,
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

  Future<void> _runBinaryBenchmark() async {
    final rustNetDio = _rustNetDio;
    final directDio = _directDio;
    if (rustNetDio == null || directDio == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _result = 'Running binary benchmark ...';
    });

    try {
      const concurrency = 50;
      const bytesPerRequest = 64 * 1024;

      final direct = await _runBinaryScenario(
        dio: directDio,
        label: 'dio',
        concurrency: concurrency,
        bytesPerRequest: bytesPerRequest,
      );
      final rustNet = await _runBinaryScenario(
        dio: rustNetDio,
        label: 'nexa_http',
        concurrency: concurrency,
        bytesPerRequest: bytesPerRequest,
      );

      final deltaPercent = direct.elapsed.inMicroseconds == 0
          ? 0
          : ((rustNet.elapsed.inMicroseconds - direct.elapsed.inMicroseconds) /
                  direct.elapsed.inMicroseconds) *
              100;

      if (!mounted) {
        return;
      }

      setState(() {
        _result = 'Binary benchmark\n'
            'baseUrl: $_fixtureBaseUrl\n'
            '${direct.describe()}\n'
            '${rustNet.describe()}\n'
            'delta: ${deltaPercent.toStringAsFixed(2)}% nexa_http vs dio';
      });
    } catch (error) {
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

  Future<void> _performRequest({
    required String label,
    required Dio? dio,
    required Future<String> Function(Dio dio) run,
  }) async {
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
      debugPrint('nexa_http_dio_consumer request succeeded: $label => $result');
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
      });
    } catch (error) {
      debugPrint('nexa_http_dio_consumer request failed: $label => $error');
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

  Future<_BenchmarkResult> _runBinaryScenario({
    required Dio dio,
    required String label,
    required int concurrency,
    required int bytesPerRequest,
  }) async {
    final stopwatch = Stopwatch()..start();
    var totalBytes = 0;

    final responses = await Future.wait(
      List<Future<Response<List<int>>>>.generate(concurrency, (index) {
        return dio.get<List<int>>(
          '/bytes',
          queryParameters: <String, String>{
            'size': '$bytesPerRequest',
            'seed': '$index',
          },
          options: Options(responseType: ResponseType.bytes),
        );
      }),
    );

    for (final response in responses) {
      totalBytes += response.data?.length ?? 0;
    }

    stopwatch.stop();
    return _BenchmarkResult(
      label: label,
      elapsed: stopwatch.elapsed,
      totalBytes: totalBytes,
      requests: concurrency,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('nexa_http Dio Consumer'),
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
                _rustNetDio == null
                    ? 'Native runtime not initialized yet.'
                    : 'Native runtime: registered platform package',
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
                  CupertinoButton.filled(
                    onPressed: _isLoading ? null : _runBinaryBenchmark,
                    child: const Text('Benchmark'),
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

final class _BenchmarkResult {
  const _BenchmarkResult({
    required this.label,
    required this.elapsed,
    required this.totalBytes,
    required this.requests,
  });

  final String label;
  final Duration elapsed;
  final int totalBytes;
  final int requests;

  String describe() {
    final megabytes = totalBytes / (1024 * 1024);
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final throughput = seconds == 0 ? 0 : megabytes / seconds;
    return '$label: requests=$requests bytes=$totalBytes '
        'elapsed=${elapsed.inMilliseconds}ms '
        'throughput=${throughput.toStringAsFixed(2)} MiB/s';
  }
}
