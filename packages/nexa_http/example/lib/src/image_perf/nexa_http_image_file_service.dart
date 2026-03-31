import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:nexa_http/nexa_http.dart';

import 'buffered_file_service_response.dart';
import 'image_request_scheduler.dart';
import 'image_perf_metrics.dart';
import 'instrumented_http_file_service.dart';

const imageRequestPriorityHeaderName = 'x-nexa-http-image-priority';

final class NexaHttpImageFileService extends FileService {
  NexaHttpImageFileService({
    NexaHttpClient? client,
    ImageRequestScheduler? scheduler,
    this.onSample,
  }) : _client =
           client ??
           NexaHttpClientBuilder()
               .callTimeout(const Duration(seconds: 20))
               .userAgent('nexa_http_example/1.0.1')
               .build(),
       _scheduler =
           scheduler ??
           ImageRequestScheduler(
             maxConcurrentRequests: 6,
             maxLowPriorityConcurrency: 2,
           );

  final NexaHttpClient _client;
  final ImageRequestScheduler _scheduler;
  final ImageRequestSampleCallback? onSample;
  int _nextDispatchSequence = 0;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final priority = resolveImageRequestPriorityFromHeaders(headers);
    int? dispatchSequence;
    final requestHeaders = Map<String, String>.from(
      headers ?? const <String, String>{},
    );
    String? priorityHeaderKey;
    for (final key in requestHeaders.keys) {
      if (key.toLowerCase() == imageRequestPriorityHeaderName) {
        priorityHeaderKey = key;
        break;
      }
    }
    if (priorityHeaderKey != null) {
      requestHeaders.remove(priorityHeaderKey);
    }
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _scheduler.schedule<Response>(
        priority: priority,
        task: () async {
          dispatchSequence = _nextDispatchSequence;
          _nextDispatchSequence += 1;
          final requestBuilder = RequestBuilder().url(Uri.parse(url)).get();
          for (final entry in requestHeaders.entries) {
            requestBuilder.header(entry.key, entry.value);
          }
          final request = requestBuilder.build();
          return _client.newCall(request).execute();
        },
      );
      final bodyBytes = await response.body!.bytes();
      stopwatch.stop();
      onSample?.call(
        ImageRequestSample(
          url: url,
          elapsed: stopwatch.elapsed,
          bytes: bodyBytes.length,
          succeeded: _isSuccessfulStatus(response.statusCode),
          priority: priority,
          dispatchSequence: dispatchSequence,
          statusCode: response.statusCode,
          error: _isSuccessfulStatus(response.statusCode)
              ? null
              : 'HTTP ${response.statusCode}',
        ),
      );

      return BufferedFileServiceResponse(
        bodyBytes: bodyBytes,
        contentLength: _contentLengthFromHeaders(response) ?? bodyBytes.length,
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
          priority: priority,
          dispatchSequence: dispatchSequence,
          error: '$error',
        ),
      );
      rethrow;
    }
  }

  Future<void> close() async {}

  bool _isSuccessfulStatus(int statusCode) {
    return statusCode >= 200 && statusCode < 400;
  }

  String? _header(Response response, String name) => response.header(name);

  int? _contentLengthFromHeaders(Response response) {
    final header = _header(response, HttpHeaders.contentLengthHeader);
    if (header == null || header.isEmpty) {
      return null;
    }
    return int.tryParse(header);
  }

  DateTime _validTillFromResponse(Response response) {
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

  String _fileExtensionFromResponse(Response response) {
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

ImageRequestPriority resolveImageRequestPriorityFromHeaders(
  Map<String, String>? headers,
) {
  String? encodedPriority;
  for (final entry in headers?.entries ?? const <MapEntry<String, String>>[]) {
    if (entry.key.toLowerCase() == imageRequestPriorityHeaderName) {
      encodedPriority = entry.value;
      break;
    }
  }
  return switch (encodedPriority) {
    'medium' => ImageRequestPriority.medium,
    'low' => ImageRequestPriority.low,
    _ => ImageRequestPriority.high,
  };
}
