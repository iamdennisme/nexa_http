import 'dart:ffi';
import 'dart:io';

import 'package:nexa_http/nexa_http_native_runtime.dart';
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
  static const _resourceBundleName = 'nexa_http_native.bundle';

  @override
  DynamicLibrary open() {
    final explicitPath = Platform.environment[_environmentVariable];
    if (explicitPath != null && explicitPath.trim().isNotEmpty) {
      return DynamicLibrary.open(explicitPath.trim());
    }

    final resolvedPath = _discoverFromAppBundle() ??
        _discoverFromPackagedPlugin() ??
        _discoverFromWorkspace();
    if (resolvedPath != null) {
      return DynamicLibrary.open(resolvedPath);
    }

    throw StateError(
      'Unable to locate the nexa_http macOS native library. '
      'Build nexa_http_native_macos or set $_environmentVariable.',
    );
  }

  String? _discoverFromAppBundle() {
    final executableDirectory = p.dirname(Platform.resolvedExecutable);
    final candidates = <String>[
      p.join(
        executableDirectory,
        '..',
        'Resources',
        _resourceBundleName,
        _libraryFileName,
      ),
      p.join(
        executableDirectory,
        '..',
        'Frameworks',
        _libraryFileName,
      ),
      p.join(
        executableDirectory,
        '..',
        'Frameworks',
        'nexa_http_native.framework',
        'nexa_http_native',
      ),
      p.join(
        executableDirectory,
        '..',
        'Frameworks',
        'App.framework',
        'Resources',
        _resourceBundleName,
        _libraryFileName,
      ),
    ];

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return p.normalize(candidate);
      }
    }

    return null;
  }

  String? _discoverFromPackagedPlugin() {
    final seeds = <String>{
      Directory.current.path,
      p.dirname(Platform.resolvedExecutable),
    };

    for (final seed in seeds) {
      var current = p.normalize(seed);
      while (true) {
        final candidate = p.join(
          current,
          'macos',
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

  String? _discoverFromWorkspace() {
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
            mode,
            'libnexa_http_native_macos_ffi.dylib',
          );
          if (File(candidate).existsSync()) {
            return p.normalize(candidate);
          }

          final legacyCandidate = p.join(
            current,
            'packages',
            'nexa_http_native_macos',
            'native',
            'nexa_http_native_macos_ffi',
            'target',
            mode,
            'libnexa_http_native.dylib',
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
