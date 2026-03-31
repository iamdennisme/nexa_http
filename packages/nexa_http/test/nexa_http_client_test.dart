import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/internal/engine/nexa_http_engine_manager.dart';
import 'package:nexa_http/src/worker/nexa_http_worker_protocol.dart';
import 'package:nexa_http/src/worker/nexa_http_worker_proxy.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() {
    NexaHttpEngineManager.resetForTesting();
  });

  test('constructs synchronously and exposes configured defaults', () {
    final client = NexaHttpClientBuilder()
        .baseUrl(Uri.parse('https://api.example.com/'))
        .callTimeout(const Duration(seconds: 3))
        .userAgent('test-agent')
        .header('x-sdk', 'nexa_http')
        .build();

    expect(client, isA<NexaHttpClient>());
    expect(client.baseUrl, Uri.parse('https://api.example.com/'));
    expect(client.callTimeout, const Duration(seconds: 3));
    expect(client.userAgent, 'test-agent');
    expect(client.defaultHeaders['x-sdk'], 'nexa_http');
  });

  test('newCall lazily opens a worker lease on first execute', () async {
    final proxy = _FakeWorkerProxy(
      responses: <NexaHttpWorkerResponse>[
        const NexaHttpWorkerSuccessResponse(
          requestId: 1,
          result: <String, Object?>{'leaseId': 41},
        ),
        const NexaHttpWorkerSuccessResponse(
          requestId: 2,
          result: <String, Object?>{
            'statusCode': 200,
            'headers': <String, Object?>{
              'content-type': <Object?>['application/json; charset=utf-8'],
            },
            'bodyBytes': <Object?>[104, 105],
            'finalUri': 'https://example.com/ok',
          },
        ),
      ],
    );
    NexaHttpEngineManager.installForTesting(
      NexaHttpEngineManager(workerProxy: proxy),
    );
    final client = NexaHttpClientBuilder()
        .callTimeout(const Duration(seconds: 1))
        .userAgent('test-agent')
        .build();

    final call = client.newCall(
      RequestBuilder().url(Uri.parse('https://example.com/ok')).get().build(),
    );

    expect(proxy.requests, isEmpty);

    final response = await call.execute();

    expect(response.statusCode, 200);
    expect(await response.body!.string(), 'hi');
    expect(response.finalUrl, Uri.parse('https://example.com/ok'));
    expect(proxy.requests[0], isA<NexaHttpOpenClientWorkerRequest>());
    final openRequest = proxy.requests[0] as NexaHttpOpenClientWorkerRequest;
    expect(openRequest.config['timeout_ms'], 1000);
    expect(openRequest.config['user_agent'], 'test-agent');

    expect(proxy.requests[1], isA<NexaHttpExecuteWorkerRequest>());
    final executeRequest = proxy.requests[1] as NexaHttpExecuteWorkerRequest;
    expect(executeRequest.leaseId, 41);
    expect(executeRequest.request['method'], 'GET');
    expect(executeRequest.request['url'], 'https://example.com/ok');
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
