import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http_demo/src/benchmark/benchmark_models.dart';

import 'package:nexa_http_demo/main.dart';

void main() {
  testWidgets('renders HTTP playground and benchmark demos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NexaHttpDemoApp());
    await tester.pump();

    expect(find.text('nexa_http Demo'), findsOneWidget);
    expect(find.text('HTTP Playground'), findsNWidgets(2));
    expect(find.text('Benchmark'), findsOneWidget);
    expect(find.text('Request Playground'), findsOneWidget);
    expect(find.text('Send Request'), findsOneWidget);
  });

  testWidgets('shows benchmark controls after switching demos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NexaHttpDemoApp());
    await tester.pump();

    await tester.tap(find.text('Benchmark'));
    await tester.pumpAndSettle();

    expect(find.text('Concurrent Benchmark'), findsOneWidget);
    expect(find.text('Scenario'), findsOneWidget);
    expect(find.text('Bytes'), findsOneWidget);
    expect(find.text('Image'), findsOneWidget);
    expect(find.text('Concurrency'), findsOneWidget);
    expect(find.text('Total Requests'), findsOneWidget);
    expect(find.text('Warmup Requests'), findsOneWidget);
    expect(find.text('Run Benchmark'), findsOneWidget);
    expect(find.text('nexa_http'), findsOneWidget);
    expect(find.text('Dart HttpClient'), findsOneWidget);
  });

  testWidgets('can start directly on the benchmark demo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const NexaHttpDemoApp(initialSection: ExampleDemoSection.benchmark),
    );
    await tester.pump();

    expect(find.text('Concurrent Benchmark'), findsOneWidget);
    expect(find.text('Run Benchmark'), findsOneWidget);
  });

  testWidgets('creates the lightweight client synchronously during build', (
    WidgetTester tester,
  ) async {
    var createClientCallCount = 0;

    await tester.pumpWidget(
      NexaHttpDemoApp(
        createClient: () {
          createClientCallCount += 1;
          return NexaHttpClient();
        },
      ),
    );

    expect(createClientCallCount, 1);
    expect(
      find.text('Transport initializes lazily on first request.'),
      findsOneWidget,
    );
  });

  testWidgets('renders richer benchmark metrics after execution', (
    WidgetTester tester,
  ) async {
    const config = BenchmarkConfig(
      baseUrl: 'http://127.0.0.1:8080',
      scenario: BenchmarkScenario.bytes,
      concurrency: 4,
      totalRequests: 12,
      payloadSize: 2048,
      warmupRequests: 2,
      timeoutMillis: 3000,
    );
    final dartMetrics = BenchmarkMetrics.fromSamples(
      transportLabel: 'Dart HttpClient',
      totalDuration: const Duration(milliseconds: 250),
      firstRequestLatency: const Duration(milliseconds: 45),
      runOrderIndex: 0,
      samples: const <BenchmarkSample>[
        BenchmarkSample(
          latency: Duration(milliseconds: 12),
          bytesReceived: 1024,
          isSuccess: true,
        ),
      ],
    );
    final nexaMetrics = BenchmarkMetrics.fromSamples(
      transportLabel: 'nexa_http',
      totalDuration: const Duration(milliseconds: 180),
      firstRequestLatency: const Duration(milliseconds: 18),
      runOrderIndex: 1,
      samples: const <BenchmarkSample>[
        BenchmarkSample(
          latency: Duration(milliseconds: 9),
          bytesReceived: 1024,
          isSuccess: true,
        ),
      ],
    );

    await tester.pumpWidget(
      NexaHttpDemoApp(
        initialSection: ExampleDemoSection.benchmark,
        autoRunBenchmark: true,
        initialBenchmarkConfig: config,
        executeBenchmark: (receivedConfig) async {
          expect(receivedConfig.baseUrl, config.baseUrl);
          return BenchmarkExecutionResult(
            dartMetrics: dartMetrics,
            nexaMetrics: nexaMetrics,
          );
        },
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('First Request'), findsNWidgets(2));
    expect(find.text('Post-warmup Avg'), findsNWidgets(2));
    expect(find.text('P99 Latency'), findsNWidgets(2));
  });
}
