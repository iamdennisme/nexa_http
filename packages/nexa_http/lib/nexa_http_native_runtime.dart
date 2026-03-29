import 'src/loader/nexa_http_platform_registry.dart';

export 'src/loader/nexa_http_native_runtime.dart';

void registerNexaHttpNativeRuntime(NexaHttpNativeRuntime runtime) {
  NexaHttpPlatformRegistry.register(runtime);
}

bool isNexaHttpNativeRuntimeRegistered() {
  return NexaHttpPlatformRegistry.isRegistered;
}
