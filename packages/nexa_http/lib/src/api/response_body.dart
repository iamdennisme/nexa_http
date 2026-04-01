import 'dart:async';
import 'dart:convert';

import '../internal/body/native_response_body_bytes.dart';
import 'media_type.dart';

ResponseBody adoptResponseBodyBytes(List<int> bytes, {MediaType? contentType}) {
  return ResponseBody._(
    bytes: bytes,
    contentType: contentType,
    copyBytes: false,
  );
}

final class ResponseBody {
  ResponseBody._({
    required List<int> bytes,
    this.contentType,
    bool copyBytes = true,
  }) : _bytes = copyBytes ? List<int>.unmodifiable(bytes) : bytes;

  final List<int> _bytes;
  final MediaType? contentType;
  bool _isClosed = false;

  factory ResponseBody.bytes(List<int> bytes, {MediaType? contentType}) {
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
      copyBytes: false,
    );
  }

  Future<List<int>> bytes() async {
    _ensureOpen();
    return _bytes;
  }

  Future<String> string() async {
    _ensureOpen();
    final resolvedEncoding = contentType?.encoding ?? utf8;
    return resolvedEncoding.decode(_bytes);
  }

  Stream<List<int>> byteStream() {
    _ensureOpen();
    return Stream<List<int>>.value(_bytes);
  }

  void close() {
    final bytes = _bytes;
    if (bytes case ClosableBodyBytes()) {
      bytes.release();
    }
    _isClosed = true;
  }

  void _ensureOpen() {
    if (_isClosed) {
      throw StateError('ResponseBody has already been closed.');
    }
  }
}
