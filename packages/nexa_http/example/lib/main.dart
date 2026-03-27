import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:nexa_http/nexa_http.dart';

import 'src/image_perf/image_cache_transport_registry.dart';
import 'src/image_perf/image_perf_page.dart';

const String _exampleBaseUrl = String.fromEnvironment(
  'RUST_NET_EXAMPLE_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);
const String _imagePerfScenario = String.fromEnvironment(
  'RUST_NET_EXAMPLE_IMAGE_PERF_SCENARIO',
  defaultValue: '',
);
const String _imagePerfTransport = String.fromEnvironment(
  'RUST_NET_EXAMPLE_IMAGE_PERF_TRANSPORT',
  defaultValue: '',
);
const int _imagePerfImageCount = int.fromEnvironment(
  'RUST_NET_EXAMPLE_IMAGE_PERF_IMAGE_COUNT',
  defaultValue: 24,
);

void main() {
  runApp(const NexaHttpExampleApp());
}

class NexaHttpExampleApp extends StatelessWidget {
  const NexaHttpExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: NexaHttpExamplePage(),
    );
  }
}

class NexaHttpExamplePage extends StatefulWidget {
  const NexaHttpExamplePage({super.key});

  @override
  State<NexaHttpExamplePage> createState() => _NexaHttpExamplePageState();
}

class _NexaHttpExamplePageState extends State<NexaHttpExamplePage> {
  ExampleDemoSection _section = _autorunImagePerfEnabled
      ? ExampleDemoSection.images
      : ExampleDemoSection.http;

  static const _requestHeaders = <String, String>{
    'accept': 'application/json',
  };
  static const bool _autorunImagePerfEnabled = _imagePerfScenario != '';

  late final TextEditingController _urlController;
  NexaHttpClient? _client;
  String? _requestInfo;
  String? _responseInfo;
  String? _errorInfo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: '$_exampleBaseUrl/get?source=nexa_http_example',
    );
    unawaited(_initializeClient());
  }

  @override
  void dispose() {
    _urlController.dispose();
    final client = _client;
    if (client != null) {
      unawaited(client.close());
    }
    super.dispose();
  }

  Future<void> _initializeClient() async {
    try {
      final client = NexaHttpClient(
        config: const NexaHttpClientConfig(
          timeout: Duration(seconds: 15),
          userAgent: 'nexa_http_example/0.1.1',
        ),
      );

      if (!mounted) {
        await client.close();
        return;
      }

      setState(() {
        _client = client;
        _errorInfo = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorInfo = 'Initialization failed\n$error';
      });
    }
  }

  Future<void> _sendRequest() async {
    final client = _client;
    if (client == null) {
      return;
    }

    final input = _urlController.text.trim();
    final uri = Uri.tryParse(input);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() {
        _errorInfo =
            'Request failed\nPlease enter a full URL such as $_exampleBaseUrl/get';
      });
      return;
    }

    final request = NexaHttpRequest.get(
      uri: uri,
      headers: _requestHeaders,
      timeout: const Duration(seconds: 15),
    );
    final stopwatch = Stopwatch()..start();

    setState(() {
      _isLoading = true;
      _errorInfo = null;
      _requestInfo = _formatRequest(request);
      _responseInfo = null;
    });

    try {
      final response = await client.execute(request);
      stopwatch.stop();

      if (!mounted) {
        return;
      }

      setState(() {
        _responseInfo = _formatResponse(response, stopwatch.elapsed);
      });
    } on NexaHttpException catch (error) {
      stopwatch.stop();

      if (!mounted) {
        return;
      }

      setState(() {
        _errorInfo = _formatNexaHttpError(error, stopwatch.elapsed);
      });
    } catch (error) {
      stopwatch.stop();

      if (!mounted) {
        return;
      }

      setState(() {
        _errorInfo = 'Request failed\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatRequest(NexaHttpRequest request) {
    return [
      'method: ${request.method.name.toUpperCase()}',
      'url: ${request.uri}',
      'timeout: ${request.timeout?.inMilliseconds ?? 0} ms',
      'headers:',
      _formatHeaderMap(request.headers),
    ].join('\n');
  }

  String _formatResponse(NexaHttpResponse response, Duration elapsed) {
    final body = response.bodyText;
    final preview = body.length > 4000
        ? '${body.substring(0, 4000)}\n...[truncated]'
        : body;

    return [
      'elapsed: ${elapsed.inMilliseconds} ms',
      'status: ${response.statusCode}',
      'final_uri: ${response.finalUri ?? '-'}',
      'headers:',
      _formatMultiHeaderMap(response.headers),
      'body:',
      preview.isEmpty ? '[empty]' : preview,
    ].join('\n');
  }

  String _formatNexaHttpError(NexaHttpException error, Duration elapsed) {
    return [
      'Request failed',
      'elapsed: ${elapsed.inMilliseconds} ms',
      'code: ${error.code}',
      'message: ${error.message}',
      'uri: ${error.uri ?? '-'}',
      'is_timeout: ${error.isTimeout}',
    ].join('\n');
  }

  String _formatHeaderMap(Map<String, String> headers) {
    if (headers.isEmpty) {
      return '  [none]';
    }

    return headers.entries
        .map((entry) => '  ${entry.key}: ${entry.value}')
        .join('\n');
  }

  String _formatMultiHeaderMap(Map<String, List<String>> headers) {
    if (headers.isEmpty) {
      return '  [none]';
    }

    return headers.entries
        .map((entry) => '  ${entry.key}: ${entry.value.join(', ')}')
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final autorunTransportMode = switch (_imagePerfTransport) {
      'nexa_http' => ImageTransportMode.rustNet,
      _ => ImageTransportMode.defaultHttp,
    };
    final autorunScenario = switch (_imagePerfScenario) {
      'image' => ImagePerfScenario.image,
      'autoscroll' => ImagePerfScenario.autoScroll,
      _ => null,
    };

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('nexa_http Demo'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            CupertinoSlidingSegmentedControl<ExampleDemoSection>(
              groupValue: _section,
              children: const <ExampleDemoSection, Widget>{
                ExampleDemoSection.http: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('HTTP'),
                ),
                ExampleDemoSection.images: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('Image performance'),
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
            const SizedBox(height: 12),
            if (_section == ExampleDemoSection.http) ...<Widget>[
              Text(
                'HTTP test page',
                style: theme.textTheme.navLargeTitleTextStyle,
              ),
              const SizedBox(height: 12),
              Text(
                _client == null
                    ? 'Initializing native runtime...'
                    : 'Native runtime: registered platform package',
                style: theme.textTheme.textStyle,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter a full URL and send a GET request.',
                style: theme.textTheme.textStyle.copyWith(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: _urlController,
                placeholder: 'https://example.com/path',
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
              ),
              const SizedBox(height: 12),
              CupertinoButton.filled(
                onPressed: _isLoading || _client == null ? null : _sendRequest,
                child: Text(_isLoading ? 'Requesting...' : 'Send GET'),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Request',
                content: _requestInfo ?? 'No request sent yet.',
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: _errorInfo == null ? 'Response' : 'Error',
                content: _errorInfo ?? _responseInfo ?? 'No response yet.',
                isError: _errorInfo != null,
              ),
            ] else ...<Widget>[
              ImagePerfPage(
                baseUrl: _exampleBaseUrl,
                initialMode: autorunTransportMode,
                autorunScenario: autorunScenario,
                imageCount: _imagePerfImageCount,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum ExampleDemoSection {
  http,
  images,
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.content,
    this.isError = false,
  });

  final String title;
  final String content;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError
              ? CupertinoColors.systemRed
                  .resolveFrom(context)
                  .withValues(alpha: 0.25)
              : CupertinoColors.separator.resolveFrom(context),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.navTitleTextStyle.copyWith(
                color: isError
                    ? CupertinoColors.systemRed.resolveFrom(context)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: theme.textTheme.textStyle.copyWith(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
