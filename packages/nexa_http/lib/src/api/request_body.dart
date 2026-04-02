import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'media_type.dart';

final class RequestBody {
  RequestBody._({
    required List<int> bytes,
    required List<int> transferBytes,
    this.contentType,
  }) : _bytes = bytes,
       _transferBytes = transferBytes;

  final List<int> _bytes;
  final List<int> _transferBytes;
  final MediaType? contentType;

  factory RequestBody.bytes(List<int> bytes, {MediaType? contentType}) {
    final ownedBytes = Uint8List.fromList(bytes);
    return RequestBody._(
      bytes: UnmodifiableListView<int>(ownedBytes),
      transferBytes: ownedBytes,
      contentType: contentType,
    );
  }

  factory RequestBody.fromString(
    String value, {
    MediaType? contentType,
    Encoding encoding = utf8,
  }) {
    final resolvedEncoding = contentType?.encoding ?? encoding;
    final encodedBytes = resolvedEncoding.encode(value);
    return RequestBody._(
      bytes: encodedBytes,
      transferBytes: encodedBytes,
      contentType: contentType,
    );
  }

  Future<List<int>> bytes() async => _bytes;

  Stream<List<int>> byteStream() => Stream<List<int>>.value(_bytes);

  int get contentLength => _bytes.length;

  List<int> get bytesValue => _bytes;

  List<int> get ffiTransferBytes => _transferBytes;
}
