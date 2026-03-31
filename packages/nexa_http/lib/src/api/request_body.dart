import 'dart:async';
import 'dart:convert';

import 'media_type.dart';

final class RequestBody {
  RequestBody._({
    required List<int> bytes,
    this.contentType,
  }) : _bytes = List<int>.unmodifiable(bytes);

  final List<int> _bytes;
  final MediaType? contentType;

  factory RequestBody.bytes(
    List<int> bytes, {
    MediaType? contentType,
  }) {
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
    );
  }

  Future<List<int>> bytes() async => List<int>.from(_bytes);

  Stream<List<int>> byteStream() => Stream<List<int>>.value(List<int>.from(_bytes));

  int get contentLength => _bytes.length;

  List<int> get bytesValue => _bytes;
}
