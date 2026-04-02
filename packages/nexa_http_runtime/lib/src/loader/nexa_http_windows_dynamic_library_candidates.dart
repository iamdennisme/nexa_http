import 'package:nexa_http_distribution/nexa_http_distribution.dart';
import 'package:path/path.dart' as p;

import 'nexa_http_dynamic_library_candidates_shared.dart';

List<String> resolveNexaHttpWindowsDynamicLibraryCandidates({
  required String executableDirectory,
  required Set<String> seeds,
  required bool Function(String path) fileExists,
}) {
  final candidates = <String>[];

  addExistingDynamicLibraryCandidates(
    candidates,
    _windowsAppDirectoryCandidates(executableDirectory),
    fileExists,
  );
  addExistingDynamicLibraryCandidates(
    candidates,
    _discoverPackagedWindows(seeds),
    fileExists,
  );
  addExistingDynamicLibraryCandidates(
    candidates,
    _discoverWorkspaceWindows(seeds),
    fileExists,
  );

  return dedupeDynamicLibraryCandidates(candidates);
}

Iterable<String> _windowsAppDirectoryCandidates(
  String executableDirectory,
) sync* {
  yield p.join(executableDirectory, 'nexa_http.dll');
  yield p.join(executableDirectory, 'nexa_http_native.dll');
  yield p.join(executableDirectory, 'nexa_http_native_windows.dll');
  yield p.join(executableDirectory, 'nexa_http_native_windows_ffi.dll');
}

Iterable<String> _discoverPackagedWindows(Set<String> seeds) sync* {
  for (final seed in seeds) {
    yield* walkUpDynamicLibraryCandidates(seed, <String>[
      p.join('windows', 'Libraries', 'nexa_http.dll'),
      p.join('windows', 'Libraries', 'nexa_http_native.dll'),
      p.join('windows', 'Libraries', 'nexa_http_native_windows_ffi.dll'),
    ]);
  }
}

Iterable<String> _discoverWorkspaceWindows(Set<String> seeds) sync* {
  final relativePaths = nexaHttpSupportedNativeTargets
      .where((target) => target.targetOS == 'windows')
      .expand((target) => target.runtimeWorkspaceRelativePaths())
      .toList(growable: false);
  for (final seed in seeds) {
    yield* walkUpDynamicLibraryCandidates(seed, relativePaths);
  }
}
