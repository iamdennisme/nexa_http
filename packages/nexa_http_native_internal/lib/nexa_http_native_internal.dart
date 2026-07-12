export 'src/native/nexa_http_native_carrier_artifact.dart';
export 'src/native/nexa_http_native_bindings.dart';
export 'src/native/nexa_http_native_types.dart';
export 'src/native/nexa_http_native_target_matrix.dart';
export 'src/native/nexa_http_native_release_manifest.dart';
export 'src/native/nexa_http_native_release_consumer.dart';
export 'src/native/nexa_http_workspace_package.dart';

import 'src/native/nexa_http_native_bindings.dart';

void registerNexaHttpNativeBindings(NexaHttpNativeBindingsFactory factory) {
  NexaHttpNativeBindingsRegistry.register(factory);
}

NexaHttpBindings resolveNexaHttpNativeBindings() {
  return NexaHttpNativeBindingsRegistry.resolve();
}

bool isNexaHttpNativeBindingsRegistered() {
  return NexaHttpNativeBindingsRegistry.isRegistered;
}

void resetNexaHttpNativeBindingsForTesting() {
  NexaHttpNativeBindingsRegistry.resetForTesting();
}
