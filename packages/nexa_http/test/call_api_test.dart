import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/internal/engine/nexa_http_engine_manager.dart';
import 'package:nexa_http/src/worker/nexa_http_worker_protocol.dart';
import 'package:nexa_http/src/worker/nexa_http_worker_proxy.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() {
    NexaHttpEngineManager.resetForTesting();
  });

  test('clone preserves request semantics', () {
    final client = NexaHttpClient();
    final request = RequestBuilder()
        .url(Uri.parse('https://example.com/items'))
        .header('x-request-id', 'abc')
        .post(
          RequestBody.fromString(
            '{"hello":"world"}',
            contentType: MediaType.parse('application/json; charset=utf-8'),
          ),
        )
        .build();

    final original = client.newCall(request);
    final clone = original.clone();

    expect(clone.request.method, request.method);
    expect(clone.request.url, request.url);
    expect(clone.request.headers['x-request-id'], 'abc');
    expect(clone.request.body, same(request.body));
  });

  test('cancel marks the call canceled and blocks execute before start', () {
    final client = NexaHttpClient();
    final call = client.newCall(
      RequestBuilder().url(Uri.parse('https://example.com/cancel')).get().build(),
    );

    call.cancel();

    expect(call.isCanceled, isTrue);
    expect(call.execute(), throwsA(isA<StateError>()));
  });

  test('execute is single-shot and clone returns a fresh call', () async {
    final proxy = _FakeWorkerProxy(
      responses: <NexaHttpWorkerResponse>[
        const NexaHttpWorkerSuccessResponse(
          requestId: 1,
          result: <String, Object?>{'leaseId': 9},
        ),
        const NexaHttpWorkerSuccessResponse(
          requestId: 2,
          result: <String, Object?>{'statusCode': 204},
        ),
        const NexaHttpWorkerSuccessResponse(
          requestId: 3,
          result: <String, Object?>{'statusCode': 204},
        ),
      ],
    );
    NexaHttpEngineManager.installForTesting(
      NexaHttpEngineManager(workerProxy: proxy),
    );
    final client = NexaHttpClient();
    final request = RequestBuilder()
        .url(Uri.parse('https://example.com/no-content'))
        .get()
        .build();
    final call = client.newCall(request);

    final firstResponse = await call.execute();

    expect(firstResponse.statusCode, 204);
    expect(call.isExecuted, isTrue);
    expect(call.execute(), throwsA(isA<StateError>()));

    final clonedCall = call.clone();
    final clonedResponse = await clonedCall.execute();
    expect(clonedResponse.statusCode, 204);
  });
}

final class _FakeWorkerProxy implements NexaHttpWorkerProxyClient {
  _FakeWorkerProxy({required List<NexaHttpWorkerResponse> responses})
      : _responses = responses;

  final List<NexaHttpWorkerRequest> requests = <NexaHttpWorkerRequest>[];
  final List<NexaHttpWorkerResponse> _responses;

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<NexaHttpWorkerResponse> send(NexaHttpWorkerRequest request) async {
    requests.add(request);
    return _responses[requests.length - 1];
  }
}
