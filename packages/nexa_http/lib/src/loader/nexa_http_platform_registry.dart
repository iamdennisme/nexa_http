export 'nexa_http_native_runtime.dart';

import 'nexa_http_native_runtime.dart';

final class NexaHttpPlatformRegistry {
  NexaHttpPlatformRegistry._();

  static NexaHttpNativeRuntime? instance;
  static NexaHttpNativeRuntime? get instanceOrNull => instance;

  static bool get isRegistered => instance != null;

  static void register(NexaHttpNativeRuntime runtime) {
    instance ??= runtime;
  }

  static void reset() {
    instance = null;
  }

  static NexaHttpNativeRuntime requireInstance() {
    final runtime = instance;
    if (runtime == null) {
      throw StateError(
        'No nexa_http native runtime is registered. '
        'Add the matching nexa_http_native_<platform> package to your app.',
      );
    }
    return runtime;
  }
}
