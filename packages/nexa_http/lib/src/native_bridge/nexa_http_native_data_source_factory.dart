import 'dart:ffi';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import '../api/nexa_http_exception.dart';
import '../data/sources/ffi_nexa_http_native_data_source.dart';
import '../data/sources/nexa_http_native_data_source.dart';
import '../internal/errors/nexa_http_failures.dart';

typedef NexaHttpDynamicLibraryLoader = DynamicLibrary Function();
typedef NexaHttpNativeDataSourceCreator =
    NexaHttpNativeDataSource Function(DynamicLibrary library);

final class NexaHttpNativeDataSourceFactory {
  const NexaHttpNativeDataSourceFactory({
    this.loadDynamicLibrary = loadNexaHttpDynamicLibrary,
    this.createDataSource = _createFfiDataSource,
  });

  final NexaHttpDynamicLibraryLoader loadDynamicLibrary;
  final NexaHttpNativeDataSourceCreator createDataSource;

  NexaHttpNativeDataSource create() {
    final DynamicLibrary library;
    try {
      library = loadDynamicLibrary();
    } on NexaHttpException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        NexaHttpFailures.unavailable(
          message: 'The nexa_http native library is unavailable.',
          stage: 'native_library_open',
          error: error,
        ),
        stackTrace,
      );
    }

    try {
      return createDataSource(library);
    } on NexaHttpException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        NexaHttpFailures.unavailable(
          message: 'The nexa_http native bindings are unavailable.',
          stage: 'native_bindings_create',
          error: error,
        ),
        stackTrace,
      );
    }
  }

  static NexaHttpNativeDataSource _createFfiDataSource(DynamicLibrary library) {
    return FfiNexaHttpNativeDataSource(library: library);
  }
}
