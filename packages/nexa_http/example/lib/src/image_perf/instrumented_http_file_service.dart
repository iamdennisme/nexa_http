import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'image_perf_metrics.dart';

typedef ImageRequestSampleCallback = void Function(ImageRequestSample sample);

final class InstrumentedHttpFileService extends HttpFileService {
  InstrumentedHttpFileService({
    this.onSample,
  });

  final ImageRequestSampleCallback? onSample;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
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
          statusCode: statusCode,
          error: error,
        ),
      );
    }

    try {
      final response = await super.get(url, headers: headers);
      return MeasuredFileServiceResponse(
        content: response.content,
        contentLength: response.contentLength,
        statusCode: response.statusCode,
        validTill: response.validTill,
        eTag: response.eTag,
        fileExtension: response.fileExtension,
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

  bool _isSuccessfulStatus(int statusCode) {
    return statusCode >= 200 && statusCode < 400;
  }
}

typedef FileServiceReadFinishedCallback = void Function({
  required int bytes,
  Object? error,
  StackTrace? stackTrace,
});

final class MeasuredFileServiceResponse implements FileServiceResponse {
  MeasuredFileServiceResponse({
    required Stream<List<int>> content,
    required this.contentLength,
    required this.statusCode,
    required this.validTill,
    required this.fileExtension,
    required FileServiceReadFinishedCallback onReadFinished,
    this.eTag,
  }) : _content = _instrumentContent(content, onReadFinished);

  final Stream<List<int>> _content;

  @override
  Stream<List<int>> get content => _content;

  @override
  final int? contentLength;

  @override
  final int statusCode;

  @override
  final DateTime validTill;

  @override
  final String? eTag;

  @override
  final String fileExtension;

  static Stream<List<int>> _instrumentContent(
    Stream<List<int>> source,
    FileServiceReadFinishedCallback onReadFinished,
  ) {
    return Stream<List<int>>.multi((controller) {
      var bytes = 0;
      var finished = false;

      void finish({
        Object? error,
        StackTrace? stackTrace,
      }) {
        if (finished) {
          return;
        }
        finished = true;
        onReadFinished(
          bytes: bytes,
          error: error,
          stackTrace: stackTrace,
        );
      }

      final subscription = source.listen(
        (chunk) {
          bytes += chunk.length;
          controller.add(chunk);
        },
        onError: (Object error, StackTrace stackTrace) {
          finish(error: error, stackTrace: stackTrace);
          controller.addError(error, stackTrace);
        },
        onDone: () {
          finish();
          controller.close();
        },
      );

      controller.onPause = subscription.pause;
      controller.onResume = subscription.resume;
      controller.onCancel = () async {
        finish();
        await subscription.cancel();
      };
    });
  }
}
