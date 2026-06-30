import 'dart:ffi';
import 'dart:io';

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
    'stage=plugin registration; platform=${Platform.operatingSystem}; '
    'architecture=${Abi.current()}; sdk_ref=unknown; '
    'expected_action=depend on package:nexa_http, run flutter pub get, and build/run with the standard Flutter toolchain so the SDK platform package can register itself; '
    'underlying_error=Register a platform strategy first.',
  );
}
