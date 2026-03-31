import 'dart:async';
import 'dart:isolate';

import 'nexa_http_worker_entrypoint.dart';
import 'nexa_http_worker_protocol.dart';

abstract interface class NexaHttpWorkerProxyClient {
  Future<void> warmUp();

  Future<NexaHttpWorkerResponse> send(NexaHttpWorkerRequest request);

  Future<void> shutdown();
}

typedef NexaHttpWorkerSpawner = Future<NexaHttpWorkerConnection> Function();

abstract interface class NexaHttpWorkerConnection {
  SendPort get sendPort;

  Stream<Object?> get messages;

  void postMessage(Map<String, Object?> message);

  Future<void> close();
}

final class NexaHttpWorkerProxy implements NexaHttpWorkerProxyClient {
  NexaHttpWorkerProxy({NexaHttpWorkerSpawner? spawnWorker})
    : _spawnWorker = spawnWorker ?? _spawnWorkerIsolate;

  static final NexaHttpWorkerProxy shared = NexaHttpWorkerProxy();

  final NexaHttpWorkerSpawner _spawnWorker;
  final _pendingResponses = <int, Completer<NexaHttpWorkerResponse>>{};
  StreamSubscription<Object?>? _messageSubscription;
  Future<NexaHttpWorkerConnection>? _startupFuture;

  @override
  Future<void> warmUp() => _ensureStarted();

  @override
  Future<NexaHttpWorkerResponse> send(NexaHttpWorkerRequest request) async {
    final connection = await _ensureStarted();
    final completer = Completer<NexaHttpWorkerResponse>();
    _pendingResponses[request.requestId] = completer;
    connection.postMessage(request.toMessage());
    return completer.future;
  }

  @override
  Future<void> shutdown() async {
    final startupFuture = _startupFuture;
    if (startupFuture == null) {
      return;
    }

    final connection = await startupFuture;
    _startupFuture = null;
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    _pendingResponses.clear();
    await connection.close();
  }

  Future<NexaHttpWorkerConnection> _ensureStarted() {
    final existing = _startupFuture;
    if (existing != null) {
      return existing;
    }

    final startup = _spawnWorker().then((connection) {
      _messageSubscription = connection.messages.listen(_handleMessage);
      return connection;
    }, onError: (Object error, StackTrace stackTrace) {
      _startupFuture = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
    _startupFuture = startup;
    return startup;
  }

  void _handleMessage(Object? message) {
    if (message is! Map<Object?, Object?>) {
      return;
    }

    final response = NexaHttpWorkerResponse.fromMessage(message);
    final completer = _pendingResponses.remove(response.requestId);
    if (completer == null || completer.isCompleted) {
      return;
    }
    completer.complete(response);
  }

  static Future<NexaHttpWorkerConnection> _spawnWorkerIsolate() async {
    final readyPort = ReceivePort();
    final isolate = await Isolate.spawn<SendPort>(
      nexaHttpWorkerMain,
      readyPort.sendPort,
    );
    final sendPort = await readyPort.first as SendPort;
    readyPort.close();

    final messagePort = ReceivePort();
    return _IsolateNexaHttpWorkerConnection(
      isolate: isolate,
      sendPort: sendPort,
      messagePort: messagePort,
    );
  }
}

final class _IsolateNexaHttpWorkerConnection implements NexaHttpWorkerConnection {
  _IsolateNexaHttpWorkerConnection({
    required this.isolate,
    required this.sendPort,
    required ReceivePort messagePort,
  }) : _messagePort = messagePort;

  final Isolate isolate;
  @override
  final SendPort sendPort;
  final ReceivePort _messagePort;

  @override
  Stream<Object?> get messages => _messagePort;

  @override
  void postMessage(Map<String, Object?> message) {
    sendPort.send(<Object?>[_messagePort.sendPort, message]);
  }

  @override
  Future<void> close() async {
    isolate.kill(priority: Isolate.immediate);
    _messagePort.close();
  }
}
