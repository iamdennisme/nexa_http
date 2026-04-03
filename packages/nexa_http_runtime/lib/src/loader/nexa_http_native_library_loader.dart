import 'dart:ffi';

import '../nexa_http_native_runtime.dart';
import 'nexa_http_host_platform.dart';
import 'nexa_http_platform_registry.dart';

DynamicLibrary loadNexaHttpDynamicLibrary({String? explicitPath}) {
  return loadNexaHttpDynamicLibraryForTesting(
    explicitPath: explicitPath,
    platform: currentNexaHttpHostPlatform(),
    openDynamicLibrary: DynamicLibrary.open,
    registeredRuntime: NexaHttpPlatformRegistry.instanceOrNull,
  );
}

DynamicLibrary loadNexaHttpDynamicLibraryForTesting({
  required NexaHttpHostPlatform platform,
  required DynamicLibrary Function(String path) openDynamicLibrary,
  NexaHttpNativeRuntime? registeredRuntime,
  String? explicitPath,
}) {
  final directPath = explicitPath?.trim();
  if (directPath != null && directPath.isNotEmpty) {
    return openDynamicLibrary(directPath);
  }

  final runtime = registeredRuntime;
  if (runtime != null) {
    return runtime.open();
  }

  throw StateError(
    'No nexa_http native runtime is registered for ${platform.name}. '
    'Add the matching nexa_http_native_${platform.name} package through '
    'the supported integration path or pass an explicit library path for '
    'controlled testing.',
  );
}
