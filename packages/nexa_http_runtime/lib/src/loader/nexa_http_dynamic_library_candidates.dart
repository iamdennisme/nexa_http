import 'dart:io';

import 'package:path/path.dart' as p;

import 'nexa_http_host_platform.dart';

List<String> resolveNexaHttpDynamicLibraryCandidates({
  required NexaHttpHostPlatform platform,
  String? resolvedExecutable,
  String? currentDirectory,
  bool Function(String path)? fileExists,
}) {
  if (platform == NexaHttpHostPlatform.android) {
    return const <String>[
      'libnexa_http_native.so',
      'libnexa_http.so',
      'libnexa_http_native_android_ffi.so',
      'libnexa_http-native-android-arm64.so',
      'libnexa_http-native-android-arm.so',
      'libnexa_http-native-android-x64.so',
    ];
  }

  final executablePath = resolvedExecutable ?? Platform.resolvedExecutable;
  final executableDirectory = p.dirname(executablePath);
  final exists = fileExists ?? ((path) => File(path).existsSync());
  final seeds = <String>{
    p.normalize(currentDirectory ?? Directory.current.path),
    p.normalize(executableDirectory),
  };

  return switch (platform) {
    NexaHttpHostPlatform.ios => _resolveIosCandidates(
      executableDirectory: executableDirectory,
      seeds: seeds,
      fileExists: exists,
    ),
    NexaHttpHostPlatform.macos => _resolveMacosCandidates(
      executableDirectory: executableDirectory,
      seeds: seeds,
      fileExists: exists,
    ),
    NexaHttpHostPlatform.windows => _resolveWindowsCandidates(
      executableDirectory: executableDirectory,
      seeds: seeds,
      fileExists: exists,
    ),
    NexaHttpHostPlatform.android => const <String>[],
  };
}

List<String> _resolveIosCandidates({
  required String executableDirectory,
  required Set<String> seeds,
  required bool Function(String path) fileExists,
}) {
  final candidates = <String>[];

  _addExistingCandidates(
    candidates,
    _iosAppBundleCandidates(executableDirectory),
    fileExists,
  );
  _addExistingCandidates(candidates, _discoverPackagedIos(seeds), fileExists);
  _addExistingCandidates(candidates, _discoverWorkspaceIos(seeds), fileExists);

  return _dedupe(candidates);
}

List<String> _resolveMacosCandidates({
  required String executableDirectory,
  required Set<String> seeds,
  required bool Function(String path) fileExists,
}) {
  final candidates = <String>[];

  _addExistingCandidates(
    candidates,
    _macosAppBundleCandidates(executableDirectory),
    fileExists,
  );
  _addExistingCandidates(candidates, _discoverPackagedMacos(seeds), fileExists);
  _addExistingCandidates(candidates, _discoverWorkspaceMacos(seeds), fileExists);

  return _dedupe(candidates);
}

List<String> _resolveWindowsCandidates({
  required String executableDirectory,
  required Set<String> seeds,
  required bool Function(String path) fileExists,
}) {
  final candidates = <String>[];

  _addExistingCandidates(
    candidates,
    _windowsAppDirectoryCandidates(executableDirectory),
    fileExists,
  );
  _addExistingCandidates(
    candidates,
    _discoverPackagedWindows(seeds),
    fileExists,
  );
  _addExistingCandidates(
    candidates,
    _discoverWorkspaceWindows(seeds),
    fileExists,
  );

  return _dedupe(candidates);
}

Iterable<String> _iosAppBundleCandidates(String executableDirectory) sync* {
  yield p.join(
    executableDirectory,
    'Frameworks',
    'nexa_http.framework',
    'nexa_http',
  );
  yield p.join(
    executableDirectory,
    'Frameworks',
    'nexa_http_native_ios.framework',
    'nexa_http_native_ios',
  );
  yield p.join(
    executableDirectory,
    'Frameworks',
    'nexa_http_native_ios_ffi.framework',
    'nexa_http_native_ios_ffi',
  );
  yield p.join(
    executableDirectory,
    'Frameworks',
    'libnexa_http_native-ios-arm64.dylib',
  );
  yield p.join(
    executableDirectory,
    'Frameworks',
    'libnexa_http_native-ios-sim-arm64.dylib',
  );
  yield p.join(
    executableDirectory,
    'Frameworks',
    'libnexa_http_native-ios-sim-x64.dylib',
  );
  yield p.join(
    executableDirectory,
    'Frameworks',
    'nexa_http-native-ios-arm64.framework',
    'nexa_http-native-ios-arm64',
  );
  yield p.join(
    executableDirectory,
    'Frameworks',
    'nexa_http-native-ios-sim-arm64.framework',
    'nexa_http-native-ios-sim-arm64',
  );
  yield p.join(
    executableDirectory,
    'Frameworks',
    'nexa_http-native-ios-sim-x64.framework',
    'nexa_http-native-ios-sim-x64',
  );
}

Iterable<String> _macosAppBundleCandidates(String executableDirectory) sync* {
  yield p.join(
    executableDirectory,
    '..',
    'Frameworks',
    'nexa_http.framework',
    'nexa_http',
  );
  yield p.join(
    executableDirectory,
    '..',
    'Frameworks',
    'nexa_http.framework',
    'Versions',
    'A',
    'nexa_http',
  );
  yield p.join(
    executableDirectory,
    '..',
    'Frameworks',
    'nexa_http_native.framework',
    'nexa_http_native',
  );
  yield p.join(
    executableDirectory,
    '..',
    'Frameworks',
    'nexa_http_native.framework',
    'Versions',
    'A',
    'nexa_http_native',
  );
  yield p.join(
    executableDirectory,
    '..',
    'Frameworks',
    'nexa_http_native_macos.framework',
    'nexa_http_native_macos',
  );
  yield p.join(
    executableDirectory,
    '..',
    'Frameworks',
    'nexa_http_native_macos.framework',
    'Versions',
    'A',
    'nexa_http_native_macos',
  );
  yield p.join(
    executableDirectory,
    '..',
    'Frameworks',
    'nexa_http_native.framework',
    'Versions',
    'A',
    'Resources',
    'nexa_http_native.bundle',
    'Contents',
    'Resources',
    'libnexa_http_native.dylib',
  );
  yield p.join(
    executableDirectory,
    '..',
    'Frameworks',
    'nexa_http_native_macos.framework',
    'Versions',
    'A',
    'Resources',
    'nexa_http_native.bundle',
    'Contents',
    'Resources',
    'libnexa_http_native.dylib',
  );
  yield p.join(
    executableDirectory,
    '..',
    'Resources',
    'nexa_http_native.bundle',
    'Contents',
    'Resources',
    'libnexa_http_native.dylib',
  );
  yield p.join(
    executableDirectory,
    '..',
    'Resources',
    'nexa_http_native.bundle',
    'libnexa_http_native.dylib',
  );
  yield p.join(
    executableDirectory,
    '..',
    'Frameworks',
    'libnexa_http_native.dylib',
  );
  yield p.join(
    executableDirectory,
    '..',
    'Frameworks',
    'nexa_http_native_macos_ffi.framework',
    'nexa_http_native_macos_ffi',
  );
  yield p.join(
    executableDirectory,
    '..',
    'Frameworks',
    'nexa_http_native_macos_ffi.framework',
    'Versions',
    'A',
    'nexa_http_native_macos_ffi',
  );
}

Iterable<String> _windowsAppDirectoryCandidates(
  String executableDirectory,
) sync* {
  yield p.join(executableDirectory, 'nexa_http.dll');
  yield p.join(executableDirectory, 'nexa_http_native.dll');
  yield p.join(executableDirectory, 'nexa_http_native_windows.dll');
  yield p.join(executableDirectory, 'nexa_http_native_windows_ffi.dll');
}

Iterable<String> _discoverPackagedIos(Set<String> seeds) sync* {
  for (final seed in seeds) {
    yield* _walkUp(seed, <String>[
      p.join('ios', 'Frameworks', 'libnexa_http_native-ios-arm64.dylib'),
      p.join('ios', 'Frameworks', 'libnexa_http_native-ios-sim-arm64.dylib'),
      p.join('ios', 'Frameworks', 'libnexa_http_native-ios-sim-x64.dylib'),
    ]);
  }
}

Iterable<String> _discoverPackagedMacos(Set<String> seeds) sync* {
  for (final seed in seeds) {
    yield* _walkUp(seed, <String>[
      p.join('macos', 'Libraries', 'libnexa_http_native.dylib'),
    ]);
  }
}

Iterable<String> _discoverPackagedWindows(Set<String> seeds) sync* {
  for (final seed in seeds) {
    yield* _walkUp(seed, <String>[
      p.join('windows', 'Libraries', 'nexa_http.dll'),
      p.join('windows', 'Libraries', 'nexa_http_native.dll'),
      p.join('windows', 'Libraries', 'nexa_http_native_windows_ffi.dll'),
    ]);
  }
}

Iterable<String> _discoverWorkspaceIos(Set<String> seeds) sync* {
  for (final seed in seeds) {
    yield* _walkUp(seed, <String>[
      p.join(
        'target',
        'aarch64-apple-ios',
        'debug',
        'libnexa_http_native_ios_ffi.dylib',
      ),
      p.join(
        'target',
        'aarch64-apple-ios',
        'release',
        'libnexa_http_native_ios_ffi.dylib',
      ),
      p.join(
        'target',
        'aarch64-apple-ios-sim',
        'debug',
        'libnexa_http_native_ios_ffi.dylib',
      ),
      p.join(
        'target',
        'aarch64-apple-ios-sim',
        'release',
        'libnexa_http_native_ios_ffi.dylib',
      ),
      p.join(
        'target',
        'x86_64-apple-ios',
        'debug',
        'libnexa_http_native_ios_ffi.dylib',
      ),
      p.join(
        'target',
        'x86_64-apple-ios',
        'release',
        'libnexa_http_native_ios_ffi.dylib',
      ),
      p.join(
        'packages',
        'nexa_http_native_ios',
        'ios',
        'Frameworks',
        'libnexa_http_native-ios-arm64.dylib',
      ),
      p.join(
        'packages',
        'nexa_http_native_ios',
        'ios',
        'Frameworks',
        'libnexa_http_native-ios-sim-arm64.dylib',
      ),
      p.join(
        'packages',
        'nexa_http_native_ios',
        'ios',
        'Frameworks',
        'libnexa_http_native-ios-sim-x64.dylib',
      ),
    ]);
  }
}

Iterable<String> _discoverWorkspaceMacos(Set<String> seeds) sync* {
  for (final seed in seeds) {
    yield* _walkUp(seed, <String>[
      p.join('target', 'debug', 'libnexa_http_native_macos_ffi.dylib'),
      p.join('target', 'release', 'libnexa_http_native_macos_ffi.dylib'),
      p.join(
        'packages',
        'nexa_http_native_macos',
        'native',
        'nexa_http_native_macos_ffi',
        'target',
        'debug',
        'libnexa_http_native.dylib',
      ),
      p.join(
        'packages',
        'nexa_http_native_macos',
        'native',
        'nexa_http_native_macos_ffi',
        'target',
        'release',
        'libnexa_http_native.dylib',
      ),
    ]);
  }
}

Iterable<String> _discoverWorkspaceWindows(Set<String> seeds) sync* {
  for (final seed in seeds) {
    yield* _walkUp(seed, <String>[
      p.join(
        'target',
        'x86_64-pc-windows-gnu',
        'debug',
        'nexa_http_native_windows_ffi.dll',
      ),
      p.join(
        'target',
        'x86_64-pc-windows-gnu',
        'release',
        'nexa_http_native_windows_ffi.dll',
      ),
      p.join(
        'target',
        'x86_64-pc-windows-msvc',
        'debug',
        'nexa_http_native_windows_ffi.dll',
      ),
      p.join(
        'target',
        'x86_64-pc-windows-msvc',
        'release',
        'nexa_http_native_windows_ffi.dll',
      ),
      p.join(
        'target',
        'aarch64-pc-windows-msvc',
        'debug',
        'nexa_http_native_windows_ffi.dll',
      ),
      p.join(
        'target',
        'aarch64-pc-windows-msvc',
        'release',
        'nexa_http_native_windows_ffi.dll',
      ),
    ]);
  }
}

Iterable<String> _walkUp(String seed, List<String> relativePaths) sync* {
  var current = p.normalize(seed);
  while (true) {
    for (final relativePath in relativePaths) {
      yield p.normalize(p.join(current, relativePath));
    }
    final parent = p.dirname(current);
    if (parent == current) {
      break;
    }
    current = parent;
  }
}

void _addExistingCandidates(
  List<String> output,
  Iterable<String> input,
  bool Function(String path) fileExists,
) {
  for (final candidate in input) {
    final normalized = p.normalize(candidate);
    if (fileExists(normalized)) {
      output.add(normalized);
    }
  }
}

List<String> _dedupe(List<String> values) {
  return values.toSet().toList(growable: false);
}
