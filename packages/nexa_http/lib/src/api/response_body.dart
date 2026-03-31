import 'dart:async';
import 'dart:convert';

import 'media_type.dart';

final class ResponseBody {
  ResponseBody._({
    required List<int> bytes,
    this.contentType,
  }) : _bytes = List<int>.unmodifiable(bytes);

  final List<int> _bytes;
  final MediaType? contentType;
  bool _isClosed = false;

  factory ResponseBody.bytes(
    List<int> bytes, {
    MediaType? contentType,
  }) {
    return ResponseBody._(bytes: bytes, contentType: contentType);
  }

  factory ResponseBody.fromString(
    String value, {
    MediaType? contentType,
    Encoding encoding = utf8,
  }) {
    final resolvedEncoding = contentType?.encoding ?? encoding;
    return ResponseBody._(
      bytes: resolvedEncoding.encode(value),
      contentType: contentType,
    );
  }

  Future<List<int>> bytes() async {
    _ensureOpen();
    return List<int>.from(_bytes);
  }

  Future<String> string() async {
    _ensureOpen();
    final resolvedEncoding = contentType?.encoding ?? utf8;
    return resolvedEncoding.decode(_bytes);
  }

  Stream<List<int>> byteStream() {
    _ensureOpen();
    return Stream<List<int>>.value(List<int>.from(_bytes));
  }

  void close() {
    _isClosed = true;
  }

  void _ensureOpen() {
    if (_isClosed) {
      throw StateError('ResponseBody has already been closed.');
    }
  }
}
