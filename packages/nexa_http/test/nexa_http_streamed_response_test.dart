import 'dart:async';
import 'dart:typed_data';

import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

const _clientClosedException = NexaHttpException(
  code: 'client_closed',
  message: 'client closed',
);

void main() {
  test('execute returns a streamed response with single-consumption body',
      () async {
    final executor = _FakeStreamFirstExecutor(
      response: NexaHttpStreamedResponse(
        statusCode: 200,
        bodyStream: Stream<Uint8List>.fromIterable(
          <Uint8List>[
            Uint8List.fromList(<int>[1, 2]),
            Uint8List.fromList(<int>[3]),
          ],
        ),
      ),
    );

    final response = await executor.execute(
      NexaHttpRequest.get(uri: Uri.parse('https://example.com/stream')),
    );

    final chunks = await response.bodyStream.toList();
    expect(chunks.expand((chunk) => chunk), orderedEquals(<int>[1, 2, 3]));
    await expectLater(response.readBytes(), throwsStateError);
  });

  test('close fails execute-before-head and active body readers with client_closed',
      () async {
    final executor = _FakeStreamFirstExecutor.pendingHead();

    final executeFuture = executor.execute(
      NexaHttpRequest.get(uri: Uri.parse('https://example.com/head')),
    );
    await executor.close();

    await expectLater(
      executeFuture,
      throwsA(
        isA<NexaHttpException>()
            .having((error) => error.code, 'code', 'client_closed'),
      ),
    );

    final activeReaderExecutor = _FakeStreamFirstExecutor.streamingBody();

    final streamed = await activeReaderExecutor.execute(
      NexaHttpRequest.get(uri: Uri.parse('https://example.com/body')),
    );
    final bytesFuture = streamed.readBytes();
    await activeReaderExecutor.bodyReaderAttached;
    await activeReaderExecutor.close();

    await expectLater(
      bytesFuture,
      throwsA(
        isA<NexaHttpException>()
            .having((error) => error.code, 'code', 'client_closed'),
      ),
    );
  });
}

final class _FakeStreamFirstExecutor implements HttpExecutor {
  _FakeStreamFirstExecutor({
    this.response,
    this.pending,
    this.bodyController,
    Future<void>? bodyReaderAttached,
  }) : bodyReaderAttached = bodyReaderAttached ?? Completer<void>().future;

  factory _FakeStreamFirstExecutor.pendingHead() {
    return _FakeStreamFirstExecutor(
      pending: Completer<NexaHttpStreamedResponse>(),
    );
  }

  factory _FakeStreamFirstExecutor.streamingBody() {
    final bodyReaderAttached = Completer<void>();
    final bodyController = StreamController<Uint8List>(
      onListen: bodyReaderAttached.complete,
    );
    return _FakeStreamFirstExecutor(
      response: NexaHttpStreamedResponse(
        statusCode: 200,
        bodyStream: bodyController.stream,
      ),
      bodyController: bodyController,
      bodyReaderAttached: bodyReaderAttached.future,
    );
  }

  final NexaHttpStreamedResponse? response;
  final Completer<NexaHttpStreamedResponse>? pending;
  final StreamController<Uint8List>? bodyController;
  final Future<void> bodyReaderAttached;

  @override
  Future<void> close() async {
    if (pending case final pending? when !pending.isCompleted) {
      pending.completeError(_clientClosedException);
    }

    if (bodyController case final controller?) {
      controller.addError(_clientClosedException);
      await controller.close();
    }
  }

  @override
  Future<NexaHttpStreamedResponse> execute(NexaHttpRequest request) {
    return pending?.future ?? Future<NexaHttpStreamedResponse>.value(response);
  }
}
