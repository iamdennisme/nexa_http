import 'dart:ffi';

import 'nexa_http_native_runtime.dart';
import 'nexa_http_platform_registry.dart';

final class NexaHttpNativeLibraryFactory {
  const NexaHttpNativeLibraryFactory();

  DynamicLibrary open() {
    return loadNexaHttpDynamicLibraryForTesting(
      registeredStrategy: NexaHttpNativeLibraryStrategyRegistry.instanceOrNull,
    );
  }
}

DynamicLibrary loadNexaHttpDynamicLibrary() {
  return const NexaHttpNativeLibraryFactory().open();
}

DynamicLibrary loadNexaHttpDynamicLibraryForTesting({
  NexaHttpNativeLibraryStrategy? registeredStrategy,
}) {
  final strategy = registeredStrategy;
  if (strategy != null) {
    return strategy.open();
  }

  throw StateError(
    'No nexa_http native library strategy is registered. '
    'Register a platform strategy first.',
  );
}
