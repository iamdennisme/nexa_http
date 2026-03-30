import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/data/dto/native_http_client_config_dto.dart';
import 'package:nexa_http/src/data/dto/native_http_request_dto.dart';
import 'package:nexa_http/src/data/sources/nexa_http_native_data_source.dart';
import 'package:nexa_http_example/src/nexa_http_client_initializer.dart';

void main() {
  test(
    'captures initialization timings for library load and client creation',
    () async {
      final fakeDataSource = _FakeNexaHttpNativeDataSource();
      NexaHttpClientInitializationTimings? capturedTimings;
      var loadCallCount = 0;
      var createDataSourceCallCount = 0;

      final client = createInstrumentedNexaHttpClient(
        config: const NexaHttpClientConfig(
          timeout: Duration(seconds: 15),
          userAgent: 'nexa_http_example_test/0.0.1',
        ),
        loadDynamicLibrary: ({String? explicitPath}) {
          loadCallCount += 1;
          expect(explicitPath, isNull);
          return DynamicLibrary.process();
        },
        createDataSource: (library) {
          createDataSourceCallCount += 1;
          expect(library, isNotNull);
          return fakeDataSource;
        },
        onTimings: (timings) {
          capturedTimings = timings;
        },
      );

      addTearDown(client.close);

      expect(loadCallCount, 1);
      expect(createDataSourceCallCount, 1);
      expect(fakeDataSource.createClientCallCount, 1);
      expect(capturedTimings, isNotNull);
      expect(capturedTimings!.total, isNot(Duration.zero));
      expect(
        capturedTimings!.total >= capturedTimings!.loadDynamicLibrary,
        isTrue,
      );
      expect(
        capturedTimings!.total >= capturedTimings!.createNativeClient,
        isTrue,
      );
    },
  );
}

final class _FakeNexaHttpNativeDataSource implements NexaHttpNativeDataSource {
  var createClientCallCount = 0;

  @override
  void closeClient(int clientId) {}

  @override
  int createClient(NativeHttpClientConfigDto config) {
    createClientCallCount += 1;
    return 1;
  }

  @override
  Future<NexaHttpResponse> execute(int clientId, NativeHttpRequestDto request) {
    throw UnimplementedError();
  }
}
