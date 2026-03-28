import 'dart:async';
import 'dart:typed_data';

final class NexaHttpStreamedResponse {
  NexaHttpStreamedResponse({
    required this.statusCode,
    Map<String, List<String>> headers = const <String, List<String>>{},
    this.finalUri,
    this.contentLength,
    required Stream<Uint8List> bodyStream,
    void Function()? onClose,
  }) : headers = Map<String, List<String>>.unmodifiable(
         headers.map(
           (key, values) => MapEntry<String, List<String>>(
             key,
             List<String>.unmodifiable(values),
           ),
         ),
       ),
       _bodySource = bodyStream,
       _onClose = onClose;

  final int statusCode;
  final Map<String, List<String>> headers;
  final Uri? finalUri;
  final int? contentLength;
  final Stream<Uint8List> _bodySource;
  final void Function()? _onClose;

  bool _bodyConsumed = false;
  String? _bodyConsumer;
  bool _closed = false;

  late final Stream<Uint8List> bodyStream = _SingleConsumptionBodyStream(
    owner: this,
    source: _bodySource,
  );

  Future<Uint8List> readBytes() async {
    _claimBody('readBytes()');

    final builder = BytesBuilder(copy: false);
    await for (final chunk in _bodySource) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  void close() {
    if (_closed) {
      return;
    }

    _closed = true;
    _bodyConsumed = true;
    _bodyConsumer ??= 'close()';
    _onClose?.call();
  }

  void _claimBody(String consumer) {
    if (_bodyConsumed) {
      throw StateError(
        'Response body has already been consumed via ${_bodyConsumer ?? 'another reader'}.',
      );
    }

    _bodyConsumed = true;
    _bodyConsumer = consumer;
  }
}

final class _SingleConsumptionBodyStream extends Stream<Uint8List> {
  _SingleConsumptionBodyStream({required this.owner, required this.source});

  final NexaHttpStreamedResponse owner;
  final Stream<Uint8List> source;

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    owner._claimBody('bodyStream.listen(...)');
    return source.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
