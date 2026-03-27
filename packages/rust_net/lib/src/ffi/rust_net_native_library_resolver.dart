import 'dart:io';

import 'package:path/path.dart' as p;

final class RustNetNativeLibraryResolver {
  const RustNetNativeLibraryResolver._();

  static const environmentVariable = 'RUST_NET_NATIVE_LIB_PATH';

  static String resolve({String? explicitPath}) {
    _ensureSupportedOperatingSystem(Platform.operatingSystem);

    for (final candidate in _configuredCandidates(explicitPath)) {
      final normalizedCandidate = _normalizeConfiguredCandidate(candidate);
      if (normalizedCandidate != null) {
        return normalizedCandidate;
      }
    }

    final discoveredPath = _discoverFromAppBundle() ??
        _discoverFromPackagedPlugin() ??
        _discoverFromWorkspace();
    if (discoveredPath != null) {
      return discoveredPath;
    }

    throw StateError(
      'Unable to locate the Rust native library. Build '
      '`native/rust_net_native` and/or set $environmentVariable.',
    );
  }

  static bool isSupportedOperatingSystem(String operatingSystem) {
    return switch (operatingSystem) {
      'android' || 'ios' || 'linux' || 'macos' || 'windows' => true,
      _ => false,
    };
  }

  static String libraryFileNameForOperatingSystem(String operatingSystem) {
    return switch (operatingSystem) {
      'linux' => 'librust_net_native.so',
      'macos' => 'librust_net_native.dylib',
      'android' => 'librust_net_native.so',
      'windows' => 'rust_net_native.dll',
      _ => throw UnsupportedError(
          'Unsupported platform for Rust native library resolution: '
          '$operatingSystem',
        ),
    };
  }

  static void _ensureSupportedOperatingSystem(String operatingSystem) {
    if (!isSupportedOperatingSystem(operatingSystem)) {
      throw UnsupportedError(
        'Unsupported platform for Rust native library resolution: '
        '$operatingSystem',
      );
    }
  }

  static Iterable<String> _configuredCandidates(String? explicitPath) sync* {
    if (explicitPath != null && explicitPath.trim().isNotEmpty) {
      yield explicitPath.trim();
    }
    final environmentPath = Platform.environment[environmentVariable];
    if (environmentPath != null && environmentPath.trim().isNotEmpty) {
      yield environmentPath.trim();
    }
  }

  static String? _normalizeConfiguredCandidate(String candidate) {
    final trimmed = candidate.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (_isPlatformLoadName(trimmed)) {
      return trimmed;
    }

    return File(trimmed).existsSync() ? p.normalize(trimmed) : null;
  }

  static bool _isPlatformLoadName(String candidate) {
    return !candidate.contains(Platform.pathSeparator) &&
        !candidate.contains('/') &&
        !candidate.contains('\\');
  }

  static String? _discoverFromAppBundle() {
    return _discoverFromAppBundleFor(
      operatingSystem: Platform.operatingSystem,
      executableDirectory: p.dirname(Platform.resolvedExecutable),
    );
  }

  static String? discoverFromAppBundleForTest({
    required String operatingSystem,
    required String executableDirectory,
  }) {
    return _discoverFromAppBundleFor(
      operatingSystem: operatingSystem,
      executableDirectory: executableDirectory,
    );
  }

  static String? _discoverFromAppBundleFor({
    required String operatingSystem,
    required String executableDirectory,
  }) {
    if (operatingSystem == 'ios') {
      return 'rust_net_native.framework/rust_net_native';
    }

    if (operatingSystem != 'macos') {
      return null;
    }

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
        'rust_net.framework',
        'Resources',
        _resourceBundleName,
        'Contents',
        'Resources',
        _libraryFileName,
      ),
      p.join(
        executableDirectory,
        '..',
        'Frameworks',
        'rust_net.framework',
        'Versions',
        'A',
        'Resources',
        _resourceBundleName,
        'Contents',
        'Resources',
        _libraryFileName,
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
      p.join(
        executableDirectory,
        '..',
        'Frameworks',
        'rust_net_native.framework',
        'rust_net_native',
      ),
      p.join(
        executableDirectory,
        '..',
        'Frameworks',
        'rust_net_native.framework',
        'Versions',
        'A',
        'rust_net_native',
      ),
      p.join(
        executableDirectory,
        '..',
        'Frameworks',
        'rust_net-native-macos-arm64.framework',
        'rust_net-native-macos-arm64',
      ),
      p.join(
        executableDirectory,
        '..',
        'Frameworks',
        'rust_net-native-macos-arm64.framework',
        'Versions',
        'A',
        'rust_net-native-macos-arm64',
      ),
      p.join(
        executableDirectory,
        '..',
        'Frameworks',
        'rust_net-native-macos-x64.framework',
        'rust_net-native-macos-x64',
      ),
      p.join(
        executableDirectory,
        '..',
        'Frameworks',
        'rust_net-native-macos-x64.framework',
        'Versions',
        'A',
        'rust_net-native-macos-x64',
      ),
      p.join(
        executableDirectory,
        '..',
        'Frameworks',
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

  static String? _discoverFromPackagedPlugin() {
    if (Platform.isAndroid) {
      return 'librust_net_native.so';
    }
    if (Platform.isWindows) {
      return 'rust_net_native.dll';
    }

    final seeds = <String>{
      Directory.current.path,
      p.dirname(Platform.script.toFilePath()),
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

  static String? _discoverFromWorkspace() {
    if (Platform.isAndroid) {
      return 'librust_net_native.so';
    }
    if (Platform.isIOS) {
      return 'rust_net_native.framework/rust_net_native';
    }
    if (Platform.isWindows) {
      return 'rust_net_native.dll';
    }

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
            'native',
            'rust_net_native',
            'target',
            mode,
            _libraryFileName,
          );
          if (File(candidate).existsSync()) {
            return p.normalize(candidate);
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

  static const _resourceBundleName = 'rust_net_native.bundle';

  static String get _libraryFileName {
    return libraryFileNameForOperatingSystem(Platform.operatingSystem);
  }
}
