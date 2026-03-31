import 'package:flutter/cupertino.dart';
import 'package:nexa_http/nexa_http.dart';

import 'benchmark_models.dart';
import 'benchmark_runner.dart';

class BenchmarkPage extends StatefulWidget {
  const BenchmarkPage({
    super.key,
    required this.initialConfig,
    this.createClient,
  });

  final BenchmarkConfig initialConfig;
  final NexaHttpClient Function()? createClient;

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _concurrencyController;
  late final TextEditingController _totalRequestsController;
  late final TextEditingController _payloadSizeController;
  late final TextEditingController _warmupController;
  late final TextEditingController _timeoutController;

  late BenchmarkScenario _scenario;
  bool _isRunning = false;
  BenchmarkMetrics? _dartMetrics;
  BenchmarkMetrics? _nexaMetrics;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final config = widget.initialConfig;
    _scenario = config.scenario;
    _baseUrlController = TextEditingController(text: config.baseUrl);
    _concurrencyController =
        TextEditingController(text: '${config.concurrency}');
    _totalRequestsController =
        TextEditingController(text: '${config.totalRequests}');
    _payloadSizeController =
        TextEditingController(text: '${config.payloadSize}');
    _warmupController = TextEditingController(text: '${config.warmupRequests}');
    _timeoutController = TextEditingController(text: '${config.timeoutMillis}');
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _concurrencyController.dispose();
    _totalRequestsController.dispose();
    _payloadSizeController.dispose();
    _warmupController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  Future<void> _runBenchmark() async {
    final config = _parseConfig();
    if (config == null) {
      return;
    }

    setState(() {
      _isRunning = true;
      _errorText = null;
      _dartMetrics = null;
      _nexaMetrics = null;
    });

    try {
      final runner = const BenchmarkRunner();
      final dartMetrics = await runner.run(
        config: config,
        transport: DartHttpClientBenchmarkTransport(),
      );
      final nexaMetrics = await runner.run(
        config: config,
        transport: NexaHttpBenchmarkTransport(
          client: widget.createClient?.call() ??
              NexaHttpClientBuilder()
                  .callTimeout(config.timeout)
                  .userAgent('nexa_http_example/benchmark')
                  .build(),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _dartMetrics = dartMetrics;
        _nexaMetrics = nexaMetrics;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = 'Benchmark failed\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  BenchmarkConfig? _parseConfig() {
    final baseUrl = _baseUrlController.text.trim();
    final uri = Uri.tryParse(baseUrl);
    final concurrency = int.tryParse(_concurrencyController.text.trim());
    final totalRequests = int.tryParse(_totalRequestsController.text.trim());
    final payloadSize = int.tryParse(_payloadSizeController.text.trim());
    final warmupRequests = int.tryParse(_warmupController.text.trim());
    final timeoutMillis = int.tryParse(_timeoutController.text.trim());

    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() {
        _errorText = 'Benchmark failed\nBase URL must be a full URL.';
      });
      return null;
    }
    if (concurrency == null || concurrency <= 0) {
      setState(() {
        _errorText = 'Benchmark failed\nConcurrency must be greater than 0.';
      });
      return null;
    }
    if (totalRequests == null || totalRequests <= 0) {
      setState(() {
        _errorText = 'Benchmark failed\nTotal requests must be greater than 0.';
      });
      return null;
    }
    if (payloadSize == null || payloadSize <= 0) {
      setState(() {
        _errorText = 'Benchmark failed\nPayload size must be greater than 0.';
      });
      return null;
    }
    if (warmupRequests == null || warmupRequests < 0) {
      setState(() {
        _errorText = 'Benchmark failed\nWarmup requests cannot be negative.';
      });
      return null;
    }
    if (timeoutMillis == null || timeoutMillis <= 0) {
      setState(() {
        _errorText = 'Benchmark failed\nTimeout must be greater than 0.';
      });
      return null;
    }

    return BenchmarkConfig(
      baseUrl: baseUrl,
      scenario: _scenario,
      concurrency: concurrency,
      totalRequests: totalRequests,
      payloadSize: payloadSize,
      warmupRequests: warmupRequests,
      timeoutMillis: timeoutMillis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final resultCards = <Widget>[
      if (_dartMetrics != null) _MetricsCard(metrics: _dartMetrics!),
      if (_nexaMetrics != null) _MetricsCard(metrics: _nexaMetrics!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Concurrent Benchmark',
          style: textTheme.navTitleTextStyle.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Run the same request plan against Dart HttpClient and nexa_http. '
          'The page executes the two clients sequentially to avoid bandwidth '
          'self-interference.',
          style: textTheme.textStyle.copyWith(
            color: secondaryColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const <Widget>[
            _TransportBadge(label: 'nexa_http'),
            _TransportBadge(label: 'Dart HttpClient'),
          ],
        ),
        const SizedBox(height: 18),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Benchmark Controls',
                style: textTheme.navTitleTextStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Base URL',
                child: CupertinoTextField(
                  controller: _baseUrlController,
                  placeholder: 'http://127.0.0.1:8080',
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Scenario',
                style:
                    textTheme.textStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              CupertinoSlidingSegmentedControl<BenchmarkScenario>(
                groupValue: _scenario,
                children: const <BenchmarkScenario, Widget>{
                  BenchmarkScenario.bytes: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text('Bytes'),
                  ),
                  BenchmarkScenario.image: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text('Image'),
                  ),
                },
                onValueChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _scenario = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _SizedField(
                    label: 'Concurrency',
                    controller: _concurrencyController,
                  ),
                  _SizedField(
                    label: 'Total Requests',
                    controller: _totalRequestsController,
                  ),
                  _SizedField(
                    label: 'Warmup Requests',
                    controller: _warmupController,
                  ),
                  _SizedField(
                    label: 'Payload Size',
                    controller: _payloadSizeController,
                    hintText: 'bytes only',
                  ),
                  _SizedField(
                    label: 'Timeout (ms)',
                    controller: _timeoutController,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: _isRunning ? null : _runBenchmark,
                child: Text(_isRunning ? 'Benchmarking...' : 'Run Benchmark'),
              ),
              const SizedBox(height: 12),
              Text(
                _scenario == BenchmarkScenario.bytes
                    ? 'Bytes scenario hits /bytes with unique seeds and the '
                        'configured payload size.'
                    : 'Image scenario hits /image with unique IDs to keep the '
                        'download path honest.',
                style: textTheme.textStyle.copyWith(color: secondaryColor),
              ),
            ],
          ),
        ),
        if (_errorText != null) ...<Widget>[
          const SizedBox(height: 14),
          _SurfaceCard(
            child: Text(
              _errorText!,
              style: textTheme.textStyle.copyWith(
                color: const Color(0xFF9F1239),
                fontFamily: '.SF Mono',
              ),
            ),
          ),
        ],
        if (_dartMetrics != null && _nexaMetrics != null) ...<Widget>[
          const SizedBox(height: 14),
          _ComparisonCard(
            dartMetrics: _dartMetrics!,
            nexaMetrics: _nexaMetrics!,
          ),
        ],
        if (resultCards.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: resultCards[0]),
                    const SizedBox(width: 14),
                    Expanded(child: resultCards[1]),
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  resultCards[0],
                  const SizedBox(height: 14),
                  resultCards[1],
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.dartMetrics,
    required this.nexaMetrics,
  });

  final BenchmarkMetrics dartMetrics;
  final BenchmarkMetrics nexaMetrics;

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    final latencyDelta = _percentDelta(
      baseline: dartMetrics.averageLatency.inMicroseconds.toDouble(),
      candidate: nexaMetrics.averageLatency.inMicroseconds.toDouble(),
      lowerIsBetter: true,
    );
    final throughputDelta = _percentDelta(
      baseline: dartMetrics.megabytesPerSecond,
      candidate: nexaMetrics.megabytesPerSecond,
      lowerIsBetter: false,
    );
    final requestRateDelta = _percentDelta(
      baseline: dartMetrics.requestsPerSecond,
      candidate: nexaMetrics.requestsPerSecond,
      lowerIsBetter: false,
    );

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'A/B Summary',
            style: textTheme.navTitleTextStyle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'nexa_http vs Dart HttpClient',
            style: textTheme.textStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Average latency: ${_formatPercent(latencyDelta)}',
            style: textTheme.textStyle,
          ),
          const SizedBox(height: 6),
          Text(
            'Throughput: ${_formatPercent(throughputDelta)}',
            style: textTheme.textStyle,
          ),
          const SizedBox(height: 6),
          Text(
            'Requests/sec: ${_formatPercent(requestRateDelta)}',
            style: textTheme.textStyle,
          ),
        ],
      ),
    );
  }

  static double _percentDelta({
    required double baseline,
    required double candidate,
    required bool lowerIsBetter,
  }) {
    if (baseline == 0) {
      return 0;
    }
    final raw = (candidate - baseline) / baseline * 100;
    return lowerIsBetter ? -raw : raw;
  }

  static String _formatPercent(double value) {
    final prefix = value >= 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(1)}%';
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.metrics});

  final BenchmarkMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            metrics.transportLabel,
            style: textTheme.navTitleTextStyle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _MetricRow(
            label: 'Total Duration',
            value: '${metrics.totalDuration.inMilliseconds} ms',
          ),
          _MetricRow(
            label: 'Throughput',
            value: '${metrics.megabytesPerSecond.toStringAsFixed(2)} MiB/s',
          ),
          _MetricRow(
            label: 'Requests / sec',
            value: metrics.requestsPerSecond.toStringAsFixed(2),
          ),
          _MetricRow(
            label: 'Average Latency',
            value: '${metrics.averageLatency.inMilliseconds} ms',
          ),
          _MetricRow(
            label: 'P50 Latency',
            value: '${metrics.p50Latency.inMilliseconds} ms',
          ),
          _MetricRow(
            label: 'P95 Latency',
            value: '${metrics.p95Latency.inMilliseconds} ms',
          ),
          _MetricRow(
            label: 'Success',
            value: '${metrics.successCount}',
          ),
          _MetricRow(
            label: 'Failure',
            value: '${metrics.failureCount}',
          ),
          _MetricRow(
            label: 'Bytes Received',
            value: '${metrics.totalBytes}',
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.textStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: textTheme.textStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _SizedField extends StatelessWidget {
  const _SizedField({
    required this.label,
    required this.controller,
    this.hintText,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: _LabeledField(
        label: label,
        child: CupertinoTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          placeholder: hintText,
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6ECF6)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class _TransportBadge extends StatelessWidget {
  const _TransportBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: textTheme.textStyle.copyWith(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
