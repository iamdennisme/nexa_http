import 'dart:async';
import 'dart:isolate';

import 'package:nexa_http/src/worker/nexa_http_worker_protocol.dart';
import 'package:nexa_http/src/worker/nexa_http_worker_proxy.dart';
import 'package:test/test.dart';

void main() {
  test('warmUp deduplicates concurrent worker startup', () async {
    final controller = StreamController<void>.broadcast();
    var spawnCount = 0;

    final proxy = NexaHttpWorkerProxy(
      spawnWorker: () async {
        spawnCount += 1;
        await controller.stream.first;
        return _FakeWorkerConnection();
      },
    );

    final firstWarmUp = proxy.warmUp();
    final secondWarmUp = proxy.warmUp();

    expect(identical(firstWarmUp, secondWarmUp), isTrue);
    expect(spawnCount, 1);

    controller.add(null);
    await Future.wait(<Future<void>>[firstWarmUp, secondWarmUp]);
    await controller.close();
  });

  test('shutdown tears down the shared connection and next warmUp restarts it', () async {
    var spawnCount = 0;
    final closedConnections = <_FakeWorkerConnection>[];

    Future<NexaHttpWorkerConnection> spawnWorker() async {
      spawnCount += 1;
      final connection = _FakeWorkerConnection();
      closedConnections.add(connection);
      return connection;
    }

    final proxy = NexaHttpWorkerProxy(spawnWorker: spawnWorker);

    await proxy.warmUp();
    await proxy.shutdown();
    await proxy.warmUp();

    expect(spawnCount, 2);
    expect(closedConnections.first.isClosed, isTrue);
    expect(closedConnections.last.isClosed, isFalse);
  });


  test('send forwards a request and resolves the matching worker response', () async {
    final connection = _FakeWorkerConnection();
    final proxy = NexaHttpWorkerProxy(spawnWorker: () async => connection);

    final responseFuture = proxy.send(
      const NexaHttpWarmUpWorkerRequest(requestId: 11),
    );

    await Future<void>.delayed(Duration.zero);

    expect(
      connection.sentMessages.single,
      <Object?>[
        connection.replyPort.sendPort,
        const NexaHttpWarmUpWorkerRequest(requestId: 11).toMessage(),
      ],
    );

    connection.emit(
      const NexaHttpWorkerSuccessResponse(
        requestId: 11,
        result: <String, Object?>{'state': 'ready'},
      ).toMessage(),
    );

    expect(
      await responseFuture,
      const NexaHttpWorkerSuccessResponse(
        requestId: 11,
        result: <String, Object?>{'state': 'ready'},
      ),
    );
  });

  test('protocol round-trips warm_up request and success response', () {
    final request = NexaHttpWorkerRequest.warmUp(requestId: 7);
    final encodedRequest = request.toMessage();

    expect(
      NexaHttpWorkerRequest.fromMessage(encodedRequest),
      request,
    );

    const response = NexaHttpWorkerSuccessResponse(
      requestId: 7,
      result: <String, Object?>{'state': 'ready'},
    );

    expect(
      NexaHttpWorkerResponse.fromMessage(response.toMessage()),
      response,
    );
  });
}

final class _FakeWorkerConnection implements NexaHttpWorkerConnection {
  _FakeWorkerConnection() : replyPort = ReceivePort();

  bool isClosed = false;
  final ReceivePort replyPort;
  final _messages = StreamController<Object?>.broadcast();
  final sentMessages = <Object?>[];

  @override
  SendPort get sendPort => replyPort.sendPort;

  @override
  Stream<Object?> get messages => _messages.stream;

  @override
  void postMessage(Map<String, Object?> message) {
    sentMessages.add(<Object?>[replyPort.sendPort, message]);
  }

  void emit(Object? message) {
    _messages.add(message);
  }

  @override
  Future<void> close() async {
    isClosed = true;
    replyPort.close();
    await _messages.close();
  }
}
