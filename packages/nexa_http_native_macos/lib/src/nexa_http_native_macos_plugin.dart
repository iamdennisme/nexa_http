import 'dart:ffi';
import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;

final class NexaHttpNativeMacosPlugin {
  NexaHttpNativeMacosPlugin._();

  static void registerWith() {
    registerNexaHttpNativeRuntime(const _NexaHttpNativeMacosRuntime());
  }
}

final class _NexaHttpNativeMacosRuntime implements NexaHttpNativeRuntime {
  const _NexaHttpNativeMacosRuntime();

  static const _environmentVariable = 'NEXA_HTTP_NATIVE_MACOS_LIB_PATH';
  static const _libraryFileName = 'libnexa_http_native.dylib';

  @override
  DynamicLibrary open() {
    final explicitPath = Platform.environment[_environmentVariable];
    if (explicitPath != null && explicitPath.trim().isNotEmpty) {
      return DynamicLibrary.open(explicitPath.trim());
    }

    final bundledPath = _resolveBundledLibraryPath();
    if (bundledPath != null) {
      return DynamicLibrary.open(bundledPath);
    }

    return DynamicLibrary.open(_libraryFileName);
  }
}

String? _resolveBundledLibraryPath() {
  final executableDir = File(Platform.resolvedExecutable).parent.path;
  final candidates = <String>[
    p.join(
      executableDir,
      '..',
      'Frameworks',
      'nexa_http_native_macos.framework',
      'Versions',
      'A',
      'Resources',
      'nexa_http_native.bundle',
      'Contents',
      'Resources',
      _NexaHttpNativeMacosRuntime._libraryFileName,
    ),
    p.join(
      executableDir,
      '..',
      'Frameworks',
      _NexaHttpNativeMacosRuntime._libraryFileName,
    ),
  ];

  for (final candidate in candidates) {
    final file = File(candidate);
    if (file.existsSync()) {
      return p.normalize(candidate);
    }
  }
  return null;
}
