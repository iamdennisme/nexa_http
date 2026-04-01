import 'package:path/path.dart' as p;

import 'nexa_http_dynamic_library_candidates_shared.dart';

List<String> resolveNexaHttpMacosDynamicLibraryCandidates({
  required String executableDirectory,
  required Set<String> seeds,
  required bool Function(String path) fileExists,
}) {
  final candidates = <String>[];

  addExistingDynamicLibraryCandidates(
    candidates,
    _macosAppBundleCandidates(executableDirectory),
    fileExists,
  );
  addExistingDynamicLibraryCandidates(
    candidates,
    _discoverPackagedMacos(seeds),
    fileExists,
  );
  addExistingDynamicLibraryCandidates(
    candidates,
    _discoverWorkspaceMacos(seeds),
    fileExists,
  );

  return dedupeDynamicLibraryCandidates(candidates);
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

Iterable<String> _discoverPackagedMacos(Set<String> seeds) sync* {
  for (final seed in seeds) {
    yield* walkUpDynamicLibraryCandidates(seed, <String>[
      p.join('macos', 'Libraries', 'libnexa_http_native.dylib'),
    ]);
  }
}

Iterable<String> _discoverWorkspaceMacos(Set<String> seeds) sync* {
  for (final seed in seeds) {
    yield* walkUpDynamicLibraryCandidates(seed, <String>[
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
