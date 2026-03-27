import 'dart:ffi';
import 'dart:io';

import 'package:nexa_http/src/loader/nexa_http_platform_registry.dart';
import 'package:path/path.dart' as p;

final class NexaHttpNativeWindowsPlugin {
  NexaHttpNativeWindowsPlugin._();

  static void registerWith() {
    NexaHttpPlatformRegistry.instance ??= const _NexaHttpNativeWindowsRuntime();
  }
}

final class _NexaHttpNativeWindowsRuntime implements NexaHttpNativeRuntime {
  const _NexaHttpNativeWindowsRuntime();

  static const _environmentVariable = 'NEXA_HTTP_NATIVE_WINDOWS_LIB_PATH';
  static const _libraryFileName = 'nexa_http_native.dll';

  @override
  DynamicLibrary open() {
    final explicitPath = Platform.environment[_environmentVariable];
    if (explicitPath != null && explicitPath.trim().isNotEmpty) {
      return DynamicLibrary.open(explicitPath.trim());
    }

    final resolvedPath = _discoverPackagedLibrary() ?? _discoverWorkspaceLibrary();
    if (resolvedPath != null) {
      return DynamicLibrary.open(resolvedPath);
    }

    throw StateError(
      'Unable to locate the nexa_http Windows native library. '
      'Build nexa_http_native_windows or set $_environmentVariable.',
    );
  }

  String? _discoverPackagedLibrary() {
    final seeds = <String>{
      Directory.current.path,
      p.dirname(Platform.resolvedExecutable),
    };

    for (final seed in seeds) {
      var current = p.normalize(seed);
      while (true) {
        final candidate = p.join(
          current,
          'windows',
          'Libraries',
          _libraryFileName,
        );
        if (File(candidate).existsSync()) {
          return p.normalize(candidate);
        }

        final parent = p.dirname(current);
        if (parent == current) {
          break;
        }
        current = parent;
      }
    }
    return null;
  }

  String? _discoverWorkspaceLibrary() {
    final seeds = <String>{
      Directory.current.path,
      p.dirname(Platform.resolvedExecutable),
    };

    for (final seed in seeds) {
      var current = p.normalize(seed);
      while (true) {
        for (final mode in <String>['debug', 'release']) {
          final candidate = p.join(
            current,
            'target',
            'x86_64-pc-windows-gnu',
            mode,
            'nexa_http_native_windows_ffi.dll',
          );
          if (File(candidate).existsSync()) {
            return p.normalize(candidate);
          }

          final legacyCandidate = p.join(
            current,
            'packages',
            'nexa_http_native_windows',
            'native',
            'nexa_http_native_windows_ffi',
            'target',
            'x86_64-pc-windows-gnu',
            mode,
            'nexa_http_native.dll',
          );
          if (File(legacyCandidate).existsSync()) {
            return p.normalize(legacyCandidate);
          }
        }

        final parent = p.dirname(current);
        if (parent == current) {
          break;
        }
        current = parent;
      }
    }
    return null;
  }
}
