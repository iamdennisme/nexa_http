import 'dart:isolate';

import 'nexa_http_worker_protocol.dart';
import 'nexa_http_worker_runtime.dart';

void nexaHttpWorkerMain(SendPort hostSendPort) {
  final runtime = NexaHttpWorkerRuntime();
  final commandPort = ReceivePort();
  hostSendPort.send(commandPort.sendPort);

  commandPort.listen((message) async {
    if (message is! List<Object?> || message.length != 2) {
      return;
    }

    final replyPort = message[0];
    final payload = message[1];
    if (replyPort is! SendPort || payload is! Map<Object?, Object?>) {
      return;
    }

    final request = NexaHttpWorkerRequest.fromMessage(payload);
    final response = await runtime.handleAsync(request);
    replyPort.send(response.toMessage());

    if (request is NexaHttpShutdownWorkerRequest) {
      commandPort.close();
    }
  });
}
