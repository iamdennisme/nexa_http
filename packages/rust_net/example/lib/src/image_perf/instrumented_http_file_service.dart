import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'buffered_file_service_response.dart';
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
    try {
      final response = await super.get(url, headers: headers);
      final bodyBytes = await response.content.expand((chunk) => chunk).toList();
      stopwatch.stop();

      onSample?.call(
        ImageRequestSample(
          url: url,
          elapsed: stopwatch.elapsed,
          bytes: bodyBytes.length,
          succeeded: _isSuccessfulStatus(response.statusCode),
          statusCode: response.statusCode,
          error: _isSuccessfulStatus(response.statusCode)
              ? null
              : 'HTTP ${response.statusCode}',
        ),
      );

      return BufferedFileServiceResponse(
        bodyBytes: bodyBytes,
        contentLength: response.contentLength ?? bodyBytes.length,
        statusCode: response.statusCode,
        validTill: response.validTill,
        eTag: response.eTag,
        fileExtension: response.fileExtension,
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

  bool _isSuccessfulStatus(int statusCode) {
    return statusCode >= 200 && statusCode < 400;
  }
}
