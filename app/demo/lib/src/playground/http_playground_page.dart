import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:nexa_http/nexa_http.dart';

class HttpPlaygroundPage extends StatefulWidget {
  const HttpPlaygroundPage({
    super.key,
    required this.client,
    required this.initialUrl,
    this.clientCreationError,
  });

  final NexaHttpClient? client;
  final String initialUrl;
  final Object? clientCreationError;

  @override
  State<HttpPlaygroundPage> createState() => _HttpPlaygroundPageState();
}

class _HttpPlaygroundPageState extends State<HttpPlaygroundPage> {
  static const int _maxPreviewBytes = 4096;
  static const int _maxBinaryPreviewBytes = 32;
  static const Map<String, String> _methodDescriptions = <String, String>{
    'GET': 'Fetch JSON or bytes from the fixture server.',
    'POST': 'Send a request body to /echo.',
    'PUT': 'Update through the echo endpoint.',
    'PATCH': 'Patch through the echo endpoint.',
    'DELETE': 'Delete against /delete.',
    'HEAD': 'Inspect headers only.',
    'OPTIONS': 'Inspect allowed methods.',
  };

  late final TextEditingController _urlController;
  late final TextEditingController _headersController;
  late final TextEditingController _bodyController;

  String _method = 'GET';
  bool _isLoading = false;
  String? _requestPreview;
  String? _responsePreview;
  String? _errorPreview;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _headersController = TextEditingController(
      text: 'accept: application/json\nx-demo: nexa_http_demo',
    );
    _bodyController = TextEditingController(
      text: '{\n  "hello": "nexa_http"\n}',
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _headersController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool get _supportsRequestBody {
    switch (_method) {
      case 'POST':
      case 'PUT':
      case 'PATCH':
      case 'DELETE':
        return true;
      default:
        return false;
    }
  }

  Future<void> _sendRequest() async {
    final client = widget.client;
    if (client == null) {
      setState(() {
        _errorPreview = 'Client creation failed\n${widget.clientCreationError}';
      });
      return;
    }

    final uri = Uri.tryParse(_urlController.text.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() {
        _errorPreview =
            'Request failed\nEnter a full URL such as '
            'http://127.0.0.1:8080/get?source=playground';
      });
      return;
    }

    final request = _buildRequest(uri);
    final stopwatch = Stopwatch()..start();

    setState(() {
      _isLoading = true;
      _errorPreview = null;
      _responsePreview = null;
      _requestPreview = _formatRequestPreview(request);
    });

    try {
      final response = await client.newCall(request).execute();
      stopwatch.stop();
      final bodyPreview = response.body == null
          ? '[empty]'
          : await _formatBodyPreview(response.body!);

      if (!mounted) {
        return;
      }

      setState(() {
        _responsePreview = _formatResponsePreview(
          response: response,
          bodyPreview: bodyPreview,
          elapsed: stopwatch.elapsed,
        );
      });
    } on NexaHttpException catch (error) {
      stopwatch.stop();
      if (!mounted) {
        return;
      }

      setState(() {
        _errorPreview = [
          'Request failed',
          'elapsed: ${stopwatch.elapsed.inMilliseconds} ms',
          'code: ${error.code}',
          'message: ${error.message}',
          'status: ${error.statusCode ?? '-'}',
          'uri: ${error.uri ?? '-'}',
          'is_timeout: ${error.isTimeout}',
        ].join('\n');
      });
    } catch (error) {
      stopwatch.stop();
      if (!mounted) {
        return;
      }

      setState(() {
        _errorPreview = 'Request failed\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Request _buildRequest(Uri uri) {
    final builder = RequestBuilder()
      ..url(uri)
      ..timeout(const Duration(seconds: 15));

    for (final MapEntry<String, String> entry in _parseHeaders().entries) {
      builder.addHeader(entry.key, entry.value);
    }

    switch (_method) {
      case 'GET':
        builder.get();
        break;
      case 'POST':
        builder.post(_requestBody());
        break;
      case 'PUT':
        builder.put(_requestBody());
        break;
      case 'PATCH':
        builder.patch(_requestBody());
        break;
      case 'DELETE':
        final body = _bodyController.text.trim().isEmpty
            ? null
            : _requestBody();
        builder.delete(body);
        break;
      case 'HEAD':
        builder.head();
        break;
      case 'OPTIONS':
        builder.method('OPTIONS');
        break;
      default:
        builder.method(_method);
        break;
    }

    return builder.build();
  }

  RequestBody _requestBody() {
    return RequestBody.text(
      _bodyController.text,
      contentType: MediaType.parse('application/json; charset=utf-8'),
    );
  }

  Map<String, String> _parseHeaders() {
    final headers = <String, String>{};
    for (final rawLine in _headersController.text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      final separator = line.indexOf(':');
      if (separator <= 0 || separator == line.length - 1) {
        continue;
      }
      final name = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      headers[name] = value;
    }
    return headers;
  }

  String _formatRequestPreview(Request request) {
    final buffer = StringBuffer()
      ..writeln('RequestBuilder()')
      ..writeln("  ..url(Uri.parse('${request.url}'))");

    for (final MapEntry<String, List<String>> entry
        in request.headers.toMultimap().entries) {
      for (final value in entry.value) {
        buffer.writeln("  ..addHeader('${entry.key}', '$value')");
      }
    }

    if (request.timeout != null) {
      buffer.writeln(
        '  ..timeout(const Duration(milliseconds: '
        '${request.timeout!.inMilliseconds}))',
      );
    }

    final body = request.body;
    switch (request.method) {
      case 'GET':
        buffer.writeln('  ..get()');
        break;
      case 'POST':
      case 'PUT':
      case 'PATCH':
        buffer.writeln(
          "  ..${request.method.toLowerCase()}("
          "RequestBody.text('${_bodyController.text.replaceAll('\n', '\\n')}'))",
        );
        break;
      case 'DELETE':
        buffer.writeln(
          body == null ? '  ..delete()' : '  ..delete(RequestBody.text(...))',
        );
        break;
      case 'HEAD':
        buffer.writeln('  ..head()');
        break;
      default:
        buffer.writeln("  ..method('${request.method}')");
        break;
    }

    buffer.writeln('  ..build();');
    return buffer.toString();
  }

  String _formatResponsePreview({
    required Response response,
    required String bodyPreview,
    required Duration elapsed,
  }) {
    return [
      'elapsed: ${elapsed.inMilliseconds} ms',
      'status: ${response.statusCode}',
      'final_url: ${response.finalUrl}',
      'headers:',
      _formatHeaders(response.headers.toMultimap()),
      'body:',
      bodyPreview,
    ].join('\n');
  }

  Future<String> _formatBodyPreview(ResponseBody body) async {
    final bytes = await body.bytes();
    if (bytes.isEmpty) {
      return '[empty]';
    }

    final previewBytes = bytes.length <= _maxPreviewBytes
        ? bytes
        : bytes.sublist(0, _maxPreviewBytes);

    if (_isProbablyText(body.contentType)) {
      final previewText = _decodePreview(previewBytes, body.contentType);
      if (bytes.length <= _maxPreviewBytes) {
        return previewText;
      }
      return '$previewText\n...[truncated ${bytes.length - _maxPreviewBytes} bytes]';
    }

    final binaryPreviewLength = bytes.length < _maxBinaryPreviewBytes
        ? bytes.length
        : _maxBinaryPreviewBytes;
    final hexPreview = bytes
        .take(binaryPreviewLength)
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    final contentType =
        body.contentType?.toString() ?? 'application/octet-stream';
    final suffix = bytes.length > binaryPreviewLength ? ' ...' : '';
    return '[binary $contentType, ${bytes.length} bytes]\n$hexPreview$suffix';
  }

  String _decodePreview(List<int> bytes, MediaType? contentType) {
    final encoding = contentType?.encoding;
    if (encoding == null || identical(encoding, utf8)) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    return encoding.decode(bytes);
  }

  bool _isProbablyText(MediaType? contentType) {
    if (contentType == null) {
      return true;
    }

    if (contentType.type == 'text') {
      return true;
    }

    return switch ('${contentType.type}/${contentType.subtype}'.toLowerCase()) {
      'application/json' ||
      'application/problem+json' ||
      'application/xml' ||
      'application/xhtml+xml' ||
      'application/x-www-form-urlencoded' ||
      'application/javascript' => true,
      _ => false,
    };
  }

  String _formatHeaders(Map<String, List<String>> headers) {
    if (headers.isEmpty) {
      return '  [none]';
    }
    return headers.entries
        .map((entry) => '  ${entry.key}: ${entry.value.join(', ')}')
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Request Playground',
          style: textTheme.navTitleTextStyle.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.client == null
              ? 'Client creation failed.'
              : 'Transport initializes lazily on first request.',
          style: textTheme.textStyle,
        ),
        const SizedBox(height: 6),
        Text(
          'Exercise the public OkHttp-style API with a real endpoint. '
          'Switch methods, edit headers, and inspect the response body.',
          style: textTheme.textStyle.copyWith(
            color: secondaryColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'HTTP Playground',
                style: textTheme.navTitleTextStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Method',
                style: textTheme.textStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _methodDescriptions.keys.map((method) {
                  final selected = method == _method;
                  return CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    borderRadius: BorderRadius.circular(999),
                    color: selected
                        ? const Color(0xFF105DFB)
                        : const Color(0xFFE8EDF8),
                    onPressed: () {
                      setState(() {
                        _method = method;
                      });
                    },
                    child: Text(
                      method,
                      style: textTheme.textStyle.copyWith(
                        color: selected
                            ? CupertinoColors.white
                            : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                _methodDescriptions[_method] ?? '',
                style: textTheme.textStyle.copyWith(color: secondaryColor),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'URL',
                child: CupertinoTextField(
                  controller: _urlController,
                  placeholder: 'http://127.0.0.1:8080/get?source=playground',
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                ),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Headers',
                child: CupertinoTextField(
                  controller: _headersController,
                  placeholder: 'accept: application/json',
                  maxLines: 4,
                  autocorrect: false,
                  enableSuggestions: false,
                ),
              ),
              if (_supportsRequestBody) ...<Widget>[
                const SizedBox(height: 14),
                _LabeledField(
                  label: 'Body',
                  child: CupertinoTextField(
                    controller: _bodyController,
                    maxLines: 6,
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: _isLoading ? null : _sendRequest,
                child: Text(_isLoading ? 'Requesting...' : 'Send Request'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SurfaceCard(
          child: _PreviewBlock(
            title: 'Request Preview',
            content:
                _requestPreview ??
                'Build a request and send it to inspect the generated call chain.',
          ),
        ),
        const SizedBox(height: 14),
        _SurfaceCard(
          child: _PreviewBlock(
            title: _errorPreview == null ? 'Response Preview' : 'Error',
            content:
                _errorPreview ??
                _responsePreview ??
                'No response yet. Start with GET /get or HEAD /healthz.',
            isError: _errorPreview != null,
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

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

class _PreviewBlock extends StatelessWidget {
  const _PreviewBlock({
    required this.title,
    required this.content,
    this.isError = false,
  });

  final String title;
  final String content;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: textTheme.navTitleTextStyle.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: isError ? const Color(0xFFFFF1F2) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              content,
              style: textTheme.textStyle.copyWith(
                color: isError
                    ? const Color(0xFF9F1239)
                    : const Color(0xFFE5EEF9),
                fontFamily: '.SF Mono',
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
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
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}
