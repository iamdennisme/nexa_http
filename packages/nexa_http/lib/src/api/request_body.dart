import 'dart:convert';
import 'dart:typed_data';

import 'media_type.dart';

final class RequestBody {
  RequestBody._({required Uint8List bytes, this.contentType}) : _bytes = bytes;

  final Uint8List _bytes;
  final MediaType? contentType;

  factory RequestBody.bytes(Uint8List bytes, {MediaType? contentType}) {
    return RequestBody._(bytes: bytes, contentType: contentType);
  }

  factory RequestBody.text(
    String value, {
    MediaType? contentType,
    Encoding encoding = utf8,
  }) {
    final resolvedEncoding = contentType?.encoding ?? encoding;
    final encodedBytes = resolvedEncoding.encode(value);
    return RequestBody._(
      bytes: encodedBytes is Uint8List
          ? encodedBytes
          : Uint8List.fromList(encodedBytes),
      contentType: contentType,
    );
  }

  Future<Uint8List> bytes() async => _bytes;

  Stream<Uint8List> byteStream() => Stream<Uint8List>.value(_bytes);

  int get contentLength => _bytes.length;

  Uint8List get payloadBytes => _bytes;
}
