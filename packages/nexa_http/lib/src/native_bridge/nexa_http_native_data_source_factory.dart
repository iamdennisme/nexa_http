import 'dart:ffi';

import '../data/sources/ffi_nexa_http_native_data_source.dart';
import '../data/sources/nexa_http_native_data_source.dart';
import '../loader/nexa_http_native_library_loader.dart';

typedef NexaHttpDynamicLibraryLoader =
    DynamicLibrary Function({String? explicitPath});
typedef NexaHttpNativeDataSourceCreator =
    NexaHttpNativeDataSource Function(DynamicLibrary library);

final class NexaHttpNativeDataSourceFactory {
  const NexaHttpNativeDataSourceFactory({
    this.loadDynamicLibrary = loadNexaHttpDynamicLibrary,
    this.createDataSource = _createFfiDataSource,
  });

  final NexaHttpDynamicLibraryLoader loadDynamicLibrary;
  final NexaHttpNativeDataSourceCreator createDataSource;

  NexaHttpNativeDataSource create({String? libraryPath}) {
    final library = loadDynamicLibrary(explicitPath: libraryPath);
    return createDataSource(library);
  }

  static NexaHttpNativeDataSource _createFfiDataSource(DynamicLibrary library) {
    return FfiNexaHttpNativeDataSource(library: library);
  }
}
