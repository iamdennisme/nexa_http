import 'package:flutter/cupertino.dart';
import 'package:nexa_http/nexa_http.dart';

import 'src/benchmark/benchmark_models.dart';
import 'src/benchmark/benchmark_page.dart';
import 'src/playground/http_playground_page.dart';

const String _exampleBaseUrl = String.fromEnvironment(
  'NEXA_HTTP_EXAMPLE_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);
const String _benchmarkScenario = String.fromEnvironment(
  'NEXA_HTTP_EXAMPLE_BENCHMARK_SCENARIO',
  defaultValue: 'bytes',
);
const int _benchmarkConcurrency = int.fromEnvironment(
  'NEXA_HTTP_EXAMPLE_BENCHMARK_CONCURRENCY',
  defaultValue: 8,
);
const int _benchmarkTotalRequests = int.fromEnvironment(
  'NEXA_HTTP_EXAMPLE_BENCHMARK_TOTAL_REQUESTS',
  defaultValue: 48,
);
const int _benchmarkPayloadSize = int.fromEnvironment(
  'NEXA_HTTP_EXAMPLE_BENCHMARK_PAYLOAD_SIZE',
  defaultValue: 65536,
);
const int _benchmarkWarmupRequests = int.fromEnvironment(
  'NEXA_HTTP_EXAMPLE_BENCHMARK_WARMUP_REQUESTS',
  defaultValue: 4,
);
const int _benchmarkTimeoutMillis = int.fromEnvironment(
  'NEXA_HTTP_EXAMPLE_BENCHMARK_TIMEOUT_MS',
  defaultValue: 10000,
);

typedef NexaHttpExampleClientFactory = NexaHttpClient Function();

void main() {
  runApp(const NexaHttpExampleApp());
}

class NexaHttpExampleApp extends StatelessWidget {
  const NexaHttpExampleApp({super.key, this.createClient});

  final NexaHttpExampleClientFactory? createClient;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: Color(0xFF105DFB),
        scaffoldBackgroundColor: Color(0xFFF4F6FB),
      ),
      home: NexaHttpExamplePage(createClient: createClient),
    );
  }
}

class NexaHttpExamplePage extends StatefulWidget {
  const NexaHttpExamplePage({super.key, this.createClient});

  final NexaHttpExampleClientFactory? createClient;

  @override
  State<NexaHttpExamplePage> createState() => _NexaHttpExamplePageState();
}

class _NexaHttpExamplePageState extends State<NexaHttpExamplePage> {
  ExampleDemoSection _section = ExampleDemoSection.playground;
  NexaHttpClient? _playgroundClient;
  Object? _clientCreationError;

  @override
  void initState() {
    super.initState();
    try {
      _playgroundClient = widget.createClient?.call() ??
          NexaHttpClientBuilder()
              .callTimeout(const Duration(seconds: 15))
              .userAgent('nexa_http_example/playground')
              .build();
    } catch (error) {
      _clientCreationError = error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final benchmarkDefaults = BenchmarkConfig(
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
              ),
          ],
        ),
      ),
    );
  }
}

enum ExampleDemoSection {
  playground,
  benchmark,
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
            Color(0xFF2E6BFF)
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
