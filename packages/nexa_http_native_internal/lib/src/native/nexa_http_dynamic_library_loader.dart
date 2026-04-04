import 'dart:ffi';
import 'dart:io';

import 'nexa_http_native_runtime.dart';
import 'nexa_http_platform_registry.dart';

enum NexaHttpHostPlatform { android, ios, macos, windows }

NexaHttpHostPlatform currentNexaHttpHostPlatform() {
  if (Platform.isAndroid) {
    return NexaHttpHostPlatform.android;
  }
  if (Platform.isIOS) {
    return NexaHttpHostPlatform.ios;
  }
  if (Platform.isMacOS) {
    return NexaHttpHostPlatform.macos;
  }
  if (Platform.isWindows) {
    return NexaHttpHostPlatform.windows;
  }

  throw UnsupportedError('Unsupported platform for nexa_http native loading.');
}

DynamicLibrary loadNexaHttpDynamicLibrary({String? explicitPath}) {
  return loadNexaHttpDynamicLibraryForTesting(
    platform: currentNexaHttpHostPlatform(),
    openDynamicLibrary: DynamicLibrary.open,
    registeredRuntime: NexaHttpPlatformRegistry.instanceOrNull,
    explicitPath: explicitPath,
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
    'No nexa_http native runtime is registered for \'${platform.name}\'. '
    'Provide an explicit library path or ensure the matching platform artifact is available.',
  );
}
