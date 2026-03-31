import 'dart:async';
import 'dart:convert';

import 'media_type.dart';

final class RequestBody {
  RequestBody._({
    required List<int> bytes,
    this.contentType,
    bool copyBytes = true,
  }) : _bytes = copyBytes ? List<int>.unmodifiable(bytes) : bytes;

  final List<int> _bytes;
  final MediaType? contentType;

  factory RequestBody.bytes(List<int> bytes, {MediaType? contentType}) {
    return RequestBody._(bytes: bytes, contentType: contentType);
  }

  factory RequestBody.fromString(
    String value, {
    MediaType? contentType,
    Encoding encoding = utf8,
  }) {
    final resolvedEncoding = contentType?.encoding ?? encoding;
    return RequestBody._(
      bytes: resolvedEncoding.encode(value),
      contentType: contentType,
      copyBytes: false,
    );
  }

  Future<List<int>> bytes() async => _bytes;

  Stream<List<int>> byteStream() => Stream<List<int>>.value(_bytes);

  int get contentLength => _bytes.length;

  List<int> get bytesValue => _bytes;
}
