export 'src/native/nexa_http_dynamic_library_loader.dart';
export 'src/native/nexa_http_native_runtime.dart';
export 'src/native/nexa_http_platform_registry.dart';
export 'src/native/nexa_http_native_target_matrix.dart';
export 'src/native/nexa_http_native_release_manifest.dart';

import 'src/native/nexa_http_native_runtime.dart';
import 'src/native/nexa_http_platform_registry.dart';

void registerNexaHttpNativeRuntime(NexaHttpNativeRuntime runtime) {
  NexaHttpNativeLibraryStrategyRegistry.register(runtime);
}

bool isNexaHttpNativeRuntimeRegistered() {
  return NexaHttpNativeLibraryStrategyRegistry.isRegistered;
}
