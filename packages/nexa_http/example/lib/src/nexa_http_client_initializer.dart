// ignore_for_file: implementation_imports

import 'dart:ffi';

import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/data/dto/native_http_client_config_dto.dart';
import 'package:nexa_http/src/data/dto/native_http_request_dto.dart';
import 'package:nexa_http/src/data/sources/ffi_nexa_http_native_data_source.dart';
import 'package:nexa_http/src/data/sources/nexa_http_native_data_source.dart';
import 'package:nexa_http/src/loader/nexa_http_native_library_loader.dart';
import 'package:nexa_http/src/native_bridge/nexa_http_native_data_source_factory.dart';

typedef NexaHttpExampleClientFactory = NexaHttpClient Function();
typedef NexaHttpClientInitializationListener =
    void Function(NexaHttpClientInitializationTimings timings);

final class NexaHttpClientInitializationTimings {
  const NexaHttpClientInitializationTimings({
    required this.loadDynamicLibrary,
    required this.createDataSource,
    required this.createNativeClient,
    required this.total,
  });

  final Duration loadDynamicLibrary;
  final Duration createDataSource;
  final Duration createNativeClient;
  final Duration total;
}

NexaHttpClient createInstrumentedNexaHttpClient({
  required NexaHttpClientConfig config,
  String? nativeLibraryPath,
  NexaHttpClientInitializationListener? onTimings,
  NexaHttpDynamicLibraryLoader loadDynamicLibrary = loadNexaHttpDynamicLibrary,
  NexaHttpNativeDataSourceCreator createDataSource = _createFfiDataSource,
}) {
  var loadDynamicLibraryDuration = Duration.zero;
  var createDataSourceDuration = Duration.zero;
  var createNativeClientDuration = Duration.zero;
  final totalStopwatch = Stopwatch()..start();

  final client = NexaHttpClient(
    config: config,
    nativeLibraryPath: nativeLibraryPath,
    dataSourceFactory: NexaHttpNativeDataSourceFactory(
      loadDynamicLibrary: ({String? explicitPath}) {
        final stopwatch = Stopwatch()..start();
        final library = loadDynamicLibrary(explicitPath: explicitPath);
        stopwatch.stop();
        loadDynamicLibraryDuration = stopwatch.elapsed;
        return library;
      },
      createDataSource: (library) {
        final stopwatch = Stopwatch()..start();
        final dataSource = createDataSource(library);
        stopwatch.stop();
        createDataSourceDuration = stopwatch.elapsed;
        return _TimedNexaHttpNativeDataSource(
          delegate: dataSource,
          onCreateClient: (elapsed) {
            createNativeClientDuration = elapsed;
          },
        );
      },
    ),
  );

  totalStopwatch.stop();
  onTimings?.call(
    NexaHttpClientInitializationTimings(
      loadDynamicLibrary: loadDynamicLibraryDuration,
      createDataSource: createDataSourceDuration,
      createNativeClient: createNativeClientDuration,
      total: totalStopwatch.elapsed,
    ),
  );
  return client;
}

String formatNexaHttpInitializationTimings(
  NexaHttpClientInitializationTimings timings,
) {
  return [
    'total ${_formatDuration(timings.total)}',
    'load ${_formatDuration(timings.loadDynamicLibrary)}',
    'data source ${_formatDuration(timings.createDataSource)}',
    'createClient ${_formatDuration(timings.createNativeClient)}',
  ].join(' | ');
}

String _formatDuration(Duration duration) {
  return '${(duration.inMicroseconds / 1000).toStringAsFixed(3)} ms';
}

NexaHttpNativeDataSource _createFfiDataSource(DynamicLibrary library) {
  return FfiNexaHttpNativeDataSource(library: library);
}

final class _TimedNexaHttpNativeDataSource implements NexaHttpNativeDataSource {
  _TimedNexaHttpNativeDataSource({
    required this.delegate,
    required this.onCreateClient,
  });

  final NexaHttpNativeDataSource delegate;
  final void Function(Duration elapsed) onCreateClient;

  @override
  void closeClient(int clientId) {
    delegate.closeClient(clientId);
  }

  @override
  int createClient(NativeHttpClientConfigDto config) {
    final stopwatch = Stopwatch()..start();
    final clientId = delegate.createClient(config);
    stopwatch.stop();
    onCreateClient(stopwatch.elapsed);
    return clientId;
  }

  @override
  Future<NexaHttpResponse> execute(int clientId, NativeHttpRequestDto request) {
    return delegate.execute(clientId, request);
  }
}
