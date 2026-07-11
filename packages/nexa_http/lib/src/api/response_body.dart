import 'dart:convert';
import 'dart:typed_data';

import '../internal/body/response_body_owner.dart';
import 'media_type.dart';

typedef ResponseBodyByteCopier = Uint8List Function(Uint8List source);
typedef ResponseBodyStringDecoder =
    String Function(Encoding encoding, Uint8List source);

final class ResponseBody {
  ResponseBody._({required _ResponseBodyStorage storage, this.contentType})
    : _storage = storage;

  _ResponseBodyStorage? _storage;
  final MediaType? contentType;

  factory ResponseBody.bytes(List<int> bytes, {MediaType? contentType}) {
    return ResponseBody._(
      storage: _ResponseBodyStorage(
        DartResponseBodyOwner(Uint8List.fromList(bytes)),
      ),
      contentType: contentType,
    );
  }

  factory ResponseBody.fromString(
    String value, {
    MediaType? contentType,
    Encoding encoding = utf8,
  }) {
    final resolvedEncoding = contentType?.encoding ?? encoding;
    final encodedBytes = resolvedEncoding.encode(value);
    return ResponseBody._(
      storage: _ResponseBodyStorage(
        DartResponseBodyOwner(
          encodedBytes is Uint8List
              ? encodedBytes
              : Uint8List.fromList(encodedBytes),
        ),
      ),
      contentType: contentType,
    );
  }

  Future<Uint8List> bytes() async => _takeStorage().takeBytes();

  Future<String> string() async {
    final resolvedEncoding = contentType?.encoding ?? utf8;
    return _takeStorage().decode(resolvedEncoding);
  }

  void close() {
    final storage = _storage;
    if (storage == null) {
      return;
    }
    _storage = null;
    storage.close();
  }

  _ResponseBodyStorage _takeStorage() {
    final storage = _storage;
    if (storage == null) {
      throw StateError('ResponseBody has already been consumed or closed.');
    }
    _storage = null;
    return storage;
  }
}

final class ResponseBodyTransportAccess {
  const ResponseBodyTransportAccess._();

  static ResponseBody adopt(
    ResponseBodyOwner owner, {
    MediaType? contentType,
    ResponseBodyByteCopier copyBytes = _copyBytes,
    ResponseBodyStringDecoder decodeBytes = _decodeBytes,
  }) {
    return ResponseBody._(
      storage: _ResponseBodyStorage(
        owner,
        copyBytes: copyBytes,
        decodeBytes: decodeBytes,
      ),
      contentType: contentType,
    );
  }
}

final class _ResponseBodyStorage {
  _ResponseBodyStorage(
    this._owner, {
    this.copyBytes = _copyBytes,
    this.decodeBytes = _decodeBytes,
  });

  ResponseBodyOwner? _owner;
  final ResponseBodyByteCopier copyBytes;
  final ResponseBodyStringDecoder decodeBytes;

  Uint8List takeBytes() {
    final owner = _takeOwner();
    try {
      if (owner.isNative) {
        return copyBytes(owner.view);
      }
      return owner.view;
    } finally {
      owner.release();
    }
  }

  String decode(Encoding encoding) {
    final owner = _takeOwner();
    try {
      return decodeBytes(encoding, owner.view);
    } finally {
      owner.release();
    }
  }

  void close() {
    final owner = _owner;
    _owner = null;
    owner?.release();
  }

  ResponseBodyOwner _takeOwner() {
    final owner = _owner;
    if (owner == null) {
      throw StateError('Response body storage has already been consumed.');
    }
    _owner = null;
    return owner;
  }
}

Uint8List _copyBytes(Uint8List source) => Uint8List.fromList(source);

String _decodeBytes(Encoding encoding, Uint8List source) =>
    encoding.decode(source);
