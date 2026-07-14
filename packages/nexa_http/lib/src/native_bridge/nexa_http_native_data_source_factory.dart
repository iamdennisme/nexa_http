import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import '../api/nexa_http_exception.dart';
import '../data/sources/ffi_nexa_http_native_data_source.dart';
import '../data/sources/nexa_http_native_data_source.dart';
import '../internal/errors/nexa_http_failures.dart';

typedef NexaHttpBindingsResolver = NexaHttpBindings Function();
typedef NexaHttpNativeDataSourceCreator =
    NexaHttpNativeDataSource Function(NexaHttpBindings bindings);

final class NexaHttpNativeDataSourceFactory {
  const NexaHttpNativeDataSourceFactory({
    this.resolveBindings = resolveNexaHttpNativeBindings,
    this.createDataSource = _createFfiDataSource,
  });

  final NexaHttpBindingsResolver resolveBindings;
  final NexaHttpNativeDataSourceCreator createDataSource;

  NexaHttpNativeDataSource create() {
    try {
      return createDataSource(resolveBindings());
    } on NexaHttpException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        NexaHttpFailures.unavailable(
          message: 'The nexa_http Native Asset bindings are unavailable.',
          stage: 'native_bindings_create',
          error: error,
        ),
        stackTrace,
      );
    }
  }

  static NexaHttpNativeDataSource _createFfiDataSource(
    NexaHttpBindings bindings,
  ) {
    return FfiNexaHttpNativeDataSource(bindings: bindings);
  }
}
