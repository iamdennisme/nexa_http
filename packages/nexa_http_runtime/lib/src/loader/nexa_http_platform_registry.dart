import '../nexa_http_native_runtime.dart';

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
        'Add package:nexa_http to your app and ensure the matching platform implementation is available.',
      );
    }
    return runtime;
  }
}
