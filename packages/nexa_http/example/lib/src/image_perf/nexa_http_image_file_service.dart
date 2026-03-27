import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:nexa_http/nexa_http.dart';

import 'buffered_file_service_response.dart';
import 'image_perf_metrics.dart';
import 'instrumented_http_file_service.dart';

final class NexaHttpImageFileService extends FileService {
  NexaHttpImageFileService({
    HttpExecutor? executor,
    this.onSample,
    NexaHttpClientConfig config = const NexaHttpClientConfig(
      timeout: Duration(seconds: 20),
      userAgent: 'nexa_http_example/1.0.0',
    ),
  })  : _ownsExecutor = executor == null,
        _executor = executor ?? NexaHttpClient(config: config);

  final HttpExecutor _executor;
  final bool _ownsExecutor;
  final ImageRequestSampleCallback? onSample;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _executor.execute(
        NexaHttpRequest.get(
          uri: Uri.parse(url),
          headers: headers ?? const <String, String>{},
        ),
      );
      stopwatch.stop();
      onSample?.call(
        ImageRequestSample(
          url: url,
          elapsed: stopwatch.elapsed,
          bytes: response.bodyBytes.length,
          succeeded: _isSuccessfulStatus(response.statusCode),
          statusCode: response.statusCode,
          error: _isSuccessfulStatus(response.statusCode)
              ? null
              : 'HTTP ${response.statusCode}',
        ),
      );

      return BufferedFileServiceResponse(
        bodyBytes: response.bodyBytes,
        contentLength: _contentLengthFromHeaders(response) ??
            response.bodyBytes.length,
        statusCode: response.statusCode,
        validTill: _validTillFromResponse(response),
        eTag: _header(response, HttpHeaders.etagHeader),
        fileExtension: _fileExtensionFromResponse(response),
      );
    } catch (error) {
      stopwatch.stop();
      onSample?.call(
        ImageRequestSample(
          url: url,
          elapsed: stopwatch.elapsed,
          bytes: 0,
          succeeded: false,
          error: '$error',
        ),
      );
      rethrow;
    }
  }

  Future<void> close() async {
    if (_ownsExecutor) {
      await _executor.close();
    }
  }

  bool _isSuccessfulStatus(int statusCode) {
    return statusCode >= 200 && statusCode < 400;
  }

  String? _header(NexaHttpResponse response, String name) {
    for (final entry in response.headers.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) {
        return entry.value.join(',');
      }
    }
    return null;
  }

  int? _contentLengthFromHeaders(NexaHttpResponse response) {
    final header = _header(response, HttpHeaders.contentLengthHeader);
    if (header == null || header.isEmpty) {
      return null;
    }
    return int.tryParse(header);
  }

  DateTime _validTillFromResponse(NexaHttpResponse response) {
    var ageDuration = const Duration(days: 7);
    final controlHeader = _header(response, HttpHeaders.cacheControlHeader);
    if (controlHeader != null) {
      final controlSettings = controlHeader.split(',');
      for (final setting in controlSettings) {
        final sanitized = setting.trim().toLowerCase();
        if (sanitized == 'no-cache') {
          ageDuration = Duration.zero;
        }
        if (sanitized.startsWith('max-age=')) {
          final validSeconds = int.tryParse(sanitized.split('=').last) ?? 0;
          if (validSeconds > 0) {
            ageDuration = Duration(seconds: validSeconds);
          }
        }
      }
    }
    return DateTime.now().add(ageDuration);
  }

  String _fileExtensionFromResponse(NexaHttpResponse response) {
    final contentTypeHeader = _header(response, HttpHeaders.contentTypeHeader);
    if (contentTypeHeader == null || contentTypeHeader.isEmpty) {
      return '';
    }

    final mimeType = contentTypeHeader.split(';').first.trim().toLowerCase();
    if (mimeType.isEmpty || !mimeType.contains('/')) {
      return '';
    }

    final subtype = mimeType.split('/').last;
    switch (subtype) {
      case 'jpeg':
        return 'jpg';
      case 'svg+xml':
        return 'svg';
      case 'x-icon':
        return 'ico';
      default:
        return subtype;
    }
  }
}
