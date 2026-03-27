import 'package:flutter_cache_manager/flutter_cache_manager.dart';

final class BufferedFileServiceResponse implements FileServiceResponse {
  BufferedFileServiceResponse({
    required List<int> bodyBytes,
    required this.statusCode,
    required this.validTill,
    required this.fileExtension,
    this.contentLength,
    this.eTag,
  }) : _bodyBytes = List<int>.unmodifiable(bodyBytes);

  final List<int> _bodyBytes;

  @override
  Stream<List<int>> get content => Stream<List<int>>.value(_bodyBytes);

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
}
