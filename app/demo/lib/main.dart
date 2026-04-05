import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:nexa_http/nexa_http.dart';
import 'package:path/path.dart' as p;

import 'src/benchmark/benchmark_models.dart';
import 'src/benchmark/benchmark_page.dart';
import 'src/playground/http_playground_page.dart';

const String _exampleBaseUrl = String.fromEnvironment(
  'NEXA_HTTP_DEMO_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);
const String _benchmarkScenario = String.fromEnvironment(
  'NEXA_HTTP_DEMO_BENCHMARK_SCENARIO',
  defaultValue: 'bytes',
);
const int _benchmarkConcurrency = int.fromEnvironment(
  'NEXA_HTTP_DEMO_BENCHMARK_CONCURRENCY',
  defaultValue: 8,
);
const int _benchmarkTotalRequests = int.fromEnvironment(
  'NEXA_HTTP_DEMO_BENCHMARK_TOTAL_REQUESTS',
  defaultValue: 48,
);
const int _benchmarkPayloadSize = int.fromEnvironment(
  'NEXA_HTTP_DEMO_BENCHMARK_PAYLOAD_SIZE',
  defaultValue: 65536,
);
const int _benchmarkWarmupRequests = int.fromEnvironment(
  'NEXA_HTTP_DEMO_BENCHMARK_WARMUP_REQUESTS',
  defaultValue: 4,
);
const int _benchmarkTimeoutMillis = int.fromEnvironment(
  'NEXA_HTTP_DEMO_BENCHMARK_TIMEOUT_MS',
  defaultValue: 10000,
);
const bool _autoRunBenchmark = bool.fromEnvironment(
  'NEXA_HTTP_DEMO_AUTO_RUN_BENCHMARK',
  defaultValue: false,
);
const bool _exitAfterBenchmark = bool.fromEnvironment(
  'NEXA_HTTP_DEMO_EXIT_AFTER_BENCHMARK',
  defaultValue: false,
);
const String _benchmarkOutputPath = String.fromEnvironment(
  'NEXA_HTTP_DEMO_BENCHMARK_OUTPUT_PATH',
  defaultValue: '',
);

typedef NexaHttpDemoClientFactory = NexaHttpClient Function();

void main() {
  final contractPath = _resolvedMacosNativeContractPath();
  if (contractPath != null) {
    stdout.writeln('NEXA_HTTP_MACOS_CONTRACT_PATH=$contractPath');
  }
  runApp(
    NexaHttpDemoApp(
      initialSection: _autoRunBenchmark
          ? ExampleDemoSection.benchmark
          : ExampleDemoSection.playground,
      autoRunBenchmark: _autoRunBenchmark,
      onBenchmarkComplete: _handleBenchmarkComplete,
      onBenchmarkError: _handleBenchmarkError,
    ),
  );
}

class NexaHttpDemoApp extends StatelessWidget {
  const NexaHttpDemoApp({
    super.key,
    this.createClient,
    this.initialSection = ExampleDemoSection.playground,
    this.initialBenchmarkConfig,
    this.autoRunBenchmark = false,
    this.executeBenchmark,
    this.onBenchmarkComplete,
    this.onBenchmarkError,
  });

  final NexaHttpDemoClientFactory? createClient;
  final ExampleDemoSection initialSection;
  final BenchmarkConfig? initialBenchmarkConfig;
  final bool autoRunBenchmark;
  final BenchmarkExecutionCallback? executeBenchmark;
  final BenchmarkCompleteCallback? onBenchmarkComplete;
  final BenchmarkErrorCallback? onBenchmarkError;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: Color(0xFF105DFB),
        scaffoldBackgroundColor: Color(0xFFF4F6FB),
      ),
      home: NexaHttpDemoPage(
        createClient: createClient,
        initialSection: initialSection,
        initialBenchmarkConfig: initialBenchmarkConfig,
        autoRunBenchmark: autoRunBenchmark,
        executeBenchmark: executeBenchmark,
        onBenchmarkComplete: onBenchmarkComplete,
        onBenchmarkError: onBenchmarkError,
      ),
    );
  }
}

class NexaHttpDemoPage extends StatefulWidget {
  const NexaHttpDemoPage({
    super.key,
    this.createClient,
    this.initialSection = ExampleDemoSection.playground,
    this.initialBenchmarkConfig,
    this.autoRunBenchmark = false,
    this.executeBenchmark,
    this.onBenchmarkComplete,
    this.onBenchmarkError,
  });

  final NexaHttpDemoClientFactory? createClient;
  final ExampleDemoSection initialSection;
  final BenchmarkConfig? initialBenchmarkConfig;
  final bool autoRunBenchmark;
  final BenchmarkExecutionCallback? executeBenchmark;
  final BenchmarkCompleteCallback? onBenchmarkComplete;
  final BenchmarkErrorCallback? onBenchmarkError;

  @override
  State<NexaHttpDemoPage> createState() => _NexaHttpDemoPageState();
}

class _NexaHttpDemoPageState extends State<NexaHttpDemoPage> {
  late ExampleDemoSection _section;
  NexaHttpClient? _playgroundClient;
  Object? _clientCreationError;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    try {
      _playgroundClient =
          widget.createClient?.call() ??
          NexaHttpClientBuilder()
              .callTimeout(const Duration(seconds: 15))
              .userAgent('nexa_http_demo/playground')
              .build();
    } catch (error) {
      _clientCreationError = error;
    }
  }

  @override
  void dispose() {
    final client = _playgroundClient;
    if (client != null) {
      unawaited(client.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final benchmarkDefaults =
        widget.initialBenchmarkConfig ??
        BenchmarkConfig(
          baseUrl: _exampleBaseUrl,
          scenario: _benchmarkScenario == 'image'
              ? BenchmarkScenario.image
              : BenchmarkScenario.bytes,
          concurrency: _benchmarkConcurrency,
          totalRequests: _benchmarkTotalRequests,
          payloadSize: _benchmarkPayloadSize,
          warmupRequests: _benchmarkWarmupRequests,
          timeoutMillis: _benchmarkTimeoutMillis,
        );

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('nexa_http Demo'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: <Widget>[
            const _HeroCard(),
            const SizedBox(height: 18),
            CupertinoSlidingSegmentedControl<ExampleDemoSection>(
              groupValue: _section,
              children: const <ExampleDemoSection, Widget>{
                ExampleDemoSection.playground: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text('HTTP Playground'),
                ),
                ExampleDemoSection.benchmark: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text('Benchmark'),
                ),
              },
              onValueChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _section = value;
                });
              },
            ),
            const SizedBox(height: 18),
            if (_section == ExampleDemoSection.playground)
              HttpPlaygroundPage(
                client: _playgroundClient,
                clientCreationError: _clientCreationError,
                initialUrl: '$_exampleBaseUrl/get?source=playground',
              )
            else
              BenchmarkPage(
                createClient: widget.createClient,
                initialConfig: benchmarkDefaults,
                autoRun: widget.autoRunBenchmark,
                executeBenchmark: widget.executeBenchmark,
                onBenchmarkComplete: widget.onBenchmarkComplete,
                onBenchmarkError: widget.onBenchmarkError,
              ),
          ],
        ),
      ),
    );
  }
}

enum ExampleDemoSection { playground, benchmark }

void _handleBenchmarkComplete(
  BenchmarkConfig config,
  BenchmarkMetrics dartMetrics,
  BenchmarkMetrics nexaMetrics,
) {
  final payload = jsonEncode(
    buildBenchmarkSuccessPayload(
      config: config,
      dartMetrics: dartMetrics,
      nexaMetrics: nexaMetrics,
    ),
  );

  _writeBenchmarkPayload(payload);
  stdout.writeln('NEXA_HTTP_BENCHMARK_RESULT=$payload');

  if (_exitAfterBenchmark) {
    unawaited(Future<void>.delayed(Duration.zero, () => exit(0)));
  }
}

void _handleBenchmarkError(Object error) {
  final payload = jsonEncode(<String, Object?>{
    'status': 'error',
    'error': '$error',
  });

  _writeBenchmarkPayload(payload);
  stderr.writeln('NEXA_HTTP_BENCHMARK_RESULT=$payload');

  if (_exitAfterBenchmark) {
    unawaited(Future<void>.delayed(Duration.zero, () => exit(1)));
  }
}

void _writeBenchmarkPayload(String payload) {
  if (_benchmarkOutputPath.trim().isEmpty) {
    return;
  }

  final outputFile = File(_benchmarkOutputPath.trim());
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(payload);
}

String? _resolvedMacosNativeContractPath() {
  final explicit = Platform.environment['NEXA_HTTP_NATIVE_MACOS_CONTRACT_PATH'];
  if (explicit != null && explicit.trim().isNotEmpty) {
    return explicit.trim();
  }
  if (!Platform.isMacOS) {
    return null;
  }
  return p.normalize(
    p.join(
      File(Platform.resolvedExecutable).parent.path,
      '..',
      'Frameworks',
      'nexa_http_native_macos.framework',
      'Versions',
      'A',
      'Resources',
      'nexa_http_native.bundle',
      'Contents',
      'Resources',
      'libnexa_http_native.dylib',
    ),
  );
}

Map<String, Object?> buildBenchmarkSuccessPayload({
  required BenchmarkConfig config,
  required BenchmarkMetrics dartMetrics,
  required BenchmarkMetrics nexaMetrics,
}) {
  final orderedResults = <BenchmarkMetrics>[dartMetrics, nexaMetrics]..sort(
    (left, right) => (left.runOrderIndex ?? 999).compareTo(
      right.runOrderIndex ?? 999,
    ),
  );

  return <String, Object?>{
    'status': 'success',
    'config': <String, Object?>{
      'baseUrl': config.baseUrl,
      'scenario': config.scenario.name,
      'concurrency': config.concurrency,
      'totalRequests': config.totalRequests,
      'payloadSize': config.payloadSize,
      'warmupRequests': config.warmupRequests,
      'timeoutMillis': config.timeoutMillis,
    },
    'runOrder': orderedResults
        .map((metrics) => metrics.transportLabel)
        .toList(growable: false),
    'results': orderedResults
        .map(_benchmarkMetricsToJson)
        .toList(growable: false),
    'comparison': <String, double>{
      'averageLatencyPercent': _percentDelta(
        baseline: dartMetrics.averageLatency.inMicroseconds.toDouble(),
        candidate: nexaMetrics.averageLatency.inMicroseconds.toDouble(),
        lowerIsBetter: true,
      ),
      'throughputPercent': _percentDelta(
        baseline: dartMetrics.megabytesPerSecond,
        candidate: nexaMetrics.megabytesPerSecond,
        lowerIsBetter: false,
      ),
      'requestsPerSecondPercent': _percentDelta(
        baseline: dartMetrics.requestsPerSecond,
        candidate: nexaMetrics.requestsPerSecond,
        lowerIsBetter: false,
      ),
    },
  };
}

Map<String, Object?> _benchmarkMetricsToJson(BenchmarkMetrics metrics) {
  return <String, Object?>{
    'transportLabel': metrics.transportLabel,
    'runOrderIndex': metrics.runOrderIndex,
    'totalDurationMillis': metrics.totalDuration.inMilliseconds,
    'firstRequestLatencyMillis': metrics.firstRequestLatency.inMilliseconds,
    'successCount': metrics.successCount,
    'failureCount': metrics.failureCount,
    'failureBreakdown': metrics.failureBreakdown,
    'totalBytes': metrics.totalBytes,
    'averageLatencyMillis': metrics.averageLatency.inMilliseconds,
    'postWarmupAverageLatencyMillis':
        metrics.postWarmupAverageLatency.inMilliseconds,
    'p50LatencyMillis': metrics.p50Latency.inMilliseconds,
    'p95LatencyMillis': metrics.p95Latency.inMilliseconds,
    'p99LatencyMillis': metrics.p99Latency.inMilliseconds,
    'maxLatencyMillis': metrics.maxLatency.inMilliseconds,
    'requestsPerSecond': metrics.requestsPerSecond,
    'megabytesPerSecond': metrics.megabytesPerSecond,
  };
}

double _percentDelta({
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

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF17336A),
            Color(0xFF2E6BFF),
          ],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22105DFB),
            blurRadius: 26,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Public API first, transport second.',
              style: textTheme.navLargeTitleTextStyle.copyWith(
                color: CupertinoColors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Use the playground to send real requests with the OkHttp-style '
              'API. Use the benchmark page to compare nexa_http with Dart '
              'HttpClient under the same concurrent workload.',
              style: textTheme.textStyle.copyWith(
                color: const Color(0xFFD7E4FF),
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
