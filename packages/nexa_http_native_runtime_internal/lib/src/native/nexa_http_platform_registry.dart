import 'nexa_http_native_runtime.dart';

final class NexaHttpNativeLibraryStrategyRegistry {
  NexaHttpNativeLibraryStrategyRegistry._();

  static NexaHttpNativeLibraryStrategy? instance;
  static NexaHttpNativeLibraryStrategy? get instanceOrNull => instance;

  static bool get isRegistered => instance != null;

  static void register(NexaHttpNativeLibraryStrategy strategy) {
    instance ??= strategy;
  }

  static void reset() {
    instance = null;
  }
}
