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
}
