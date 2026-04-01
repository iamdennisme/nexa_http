import 'dart:ffi';
import 'dart:io';

import '../nexa_http_native_runtime.dart';
import 'nexa_http_dynamic_library_candidates.dart';
import 'nexa_http_dynamic_library_override.dart';
import 'nexa_http_host_platform.dart';
import 'nexa_http_platform_registry.dart';

DynamicLibrary loadNexaHttpDynamicLibrary({String? explicitPath}) {
  return loadNexaHttpDynamicLibraryForTesting(
    explicitPath: explicitPath,
    platform: currentNexaHttpHostPlatform(),
    environment: Platform.environment,
    resolvedExecutable: Platform.resolvedExecutable,
    currentDirectory: Directory.current.path,
    fileExists: (path) => File(path).existsSync(),
    openDynamicLibrary: DynamicLibrary.open,
    registeredRuntime: NexaHttpPlatformRegistry.instanceOrNull,
  );
}

DynamicLibrary loadNexaHttpDynamicLibraryForTesting({
  required NexaHttpHostPlatform platform,
  required Map<String, String> environment,
  required String resolvedExecutable,
  required String currentDirectory,
  required bool Function(String path) fileExists,
  required DynamicLibrary Function(String path) openDynamicLibrary,
  NexaHttpNativeRuntime? registeredRuntime,
  String? explicitPath,
}) {
  final directPath = explicitPath?.trim();
  if (directPath != null && directPath.isNotEmpty) {
    return openDynamicLibrary(directPath);
  }

  final overridePath = resolveNexaHttpDynamicLibraryOverridePath(
    platform: platform,
    environment: environment,
  );
  if (overridePath != null) {
    return openDynamicLibrary(overridePath);
  }

  final errors = <String>[];
  for (final candidate in resolveNexaHttpDynamicLibraryCandidates(
    platform: platform,
    resolvedExecutable: resolvedExecutable,
    currentDirectory: currentDirectory,
    fileExists: fileExists,
  )) {
    try {
      return openDynamicLibrary(candidate);
    } on Object catch (error) {
      errors.add('$candidate => $error');
    }
  }

  if (registeredRuntime != null) {
    return registeredRuntime.open();
  }

  throw StateError(
    'Unable to locate the nexa_http native library for $platform. '
    'Tried ${errors.isEmpty ? 'no SDK candidates' : errors.join(' | ')}. '
    'Add the matching nexa_http_native_<platform> package or set the platform lib path override.',
  );
}
