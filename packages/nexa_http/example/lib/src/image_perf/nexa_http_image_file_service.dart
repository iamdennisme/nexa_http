import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:nexa_http/nexa_http.dart';

import 'image_request_scheduler.dart';
import 'image_perf_metrics.dart';
import 'instrumented_http_file_service.dart';

const imageRequestPriorityHeaderName = 'x-nexa-http-image-priority';

final class NexaHttpImageFileService extends FileService {
  NexaHttpImageFileService({
    HttpExecutor? executor,
    ImageRequestScheduler? scheduler,
    this.onSample,
    NexaHttpClientConfig config = const NexaHttpClientConfig(
      timeout: Duration(seconds: 20),
      userAgent: 'nexa_http_example/1.0.0',
    ),
  })  : _ownsExecutor = executor == null,
        _executor = executor ?? NexaHttpClient(config: config),
        _scheduler = scheduler ??
            ImageRequestScheduler(
              maxConcurrentRequests: 6,
              maxLowPriorityConcurrency: 2,
            );

  final HttpExecutor _executor;
  final bool _ownsExecutor;
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
    var sampleRecorded = false;
    void recordSample({
      required int bytes,
      required bool succeeded,
      int? statusCode,
      String? error,
    }) {
      if (sampleRecorded) {
        return;
      }
      sampleRecorded = true;
      stopwatch.stop();
      onSample?.call(
        ImageRequestSample(
          url: url,
          elapsed: stopwatch.elapsed,
          bytes: bytes,
          succeeded: succeeded,
          priority: priority,
          dispatchSequence: dispatchSequence,
          statusCode: statusCode,
          error: error,
        ),
      );
    }

    try {
      final response = await _scheduler.schedule<NexaHttpStreamedResponse>(
        priority: priority,
        task: () {
          dispatchSequence = _nextDispatchSequence;
          _nextDispatchSequence += 1;
          return _executor.execute(
            NexaHttpRequest.get(uri: Uri.parse(url), headers: requestHeaders),
          );
        },
      );
      return MeasuredFileServiceResponse(
        content: response.bodyStream,
        contentLength: response.contentLength,
        statusCode: response.statusCode,
        validTill: _validTillFromResponse(response),
        eTag: _header(response, HttpHeaders.etagHeader),
        fileExtension: _fileExtensionFromResponse(response),
        onReadFinished: ({required bytes, error, stackTrace}) {
          recordSample(
            bytes: bytes,
            succeeded:
                _isSuccessfulStatus(response.statusCode) && error == null,
            statusCode: response.statusCode,
            error: error == null && _isSuccessfulStatus(response.statusCode)
                ? null
                : error?.toString() ?? 'HTTP ${response.statusCode}',
          );
        },
      );
    } catch (error) {
      recordSample(
        bytes: 0,
        succeeded: false,
        error: '$error',
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

  String? _header(NexaHttpStreamedResponse response, String name) {
    for (final entry in response.headers.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) {
        return entry.value.join(',');
      }
    }
    return null;
  }

  DateTime _validTillFromResponse(NexaHttpStreamedResponse response) {
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

  String _fileExtensionFromResponse(NexaHttpStreamedResponse response) {
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
