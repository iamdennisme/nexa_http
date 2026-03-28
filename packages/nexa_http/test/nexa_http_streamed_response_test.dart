import 'dart:async';
import 'dart:typed_data';

import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

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
    final executeBeforeHead = Completer<NexaHttpStreamedResponse>();
    final executor = _FakeStreamFirstExecutor(pending: executeBeforeHead.future);

    final executeFuture = executor.execute(
      NexaHttpRequest.get(uri: Uri.parse('https://example.com/head')),
    );
    await executor.close();

    executeBeforeHead.completeError(
      const NexaHttpException(code: 'client_closed', message: 'client closed'),
    );

    await expectLater(
      executeFuture,
      throwsA(
        isA<NexaHttpException>().having((error) => error.code, 'code',
            'client_closed'),
      ),
    );

    final bodyController = StreamController<Uint8List>();
    final activeReaderExecutor = _FakeStreamFirstExecutor(
      response: NexaHttpStreamedResponse(
        statusCode: 200,
        bodyStream: bodyController.stream,
      ),
    );

    final streamed = await activeReaderExecutor.execute(
      NexaHttpRequest.get(uri: Uri.parse('https://example.com/body')),
    );
    final bytesFuture = streamed.readBytes();
    await activeReaderExecutor.close();
    bodyController.addError(
      const NexaHttpException(code: 'client_closed', message: 'client closed'),
    );
    await bodyController.close();

    await expectLater(
      bytesFuture,
      throwsA(
        isA<NexaHttpException>().having((error) => error.code, 'code',
            'client_closed'),
      ),
    );
  });
}

final class _FakeStreamFirstExecutor implements HttpExecutor {
  _FakeStreamFirstExecutor({
    this.response,
    this.pending,
  });

  final NexaHttpStreamedResponse? response;
  final Future<NexaHttpStreamedResponse>? pending;

  @override
  Future<void> close() async {}

  @override
  Future<NexaHttpStreamedResponse> execute(NexaHttpRequest request) {
    return pending ?? Future<NexaHttpStreamedResponse>.value(response);
  }
}
