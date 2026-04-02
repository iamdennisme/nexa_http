import 'package:nexa_http_distribution/nexa_http_distribution.dart';
import 'package:path/path.dart' as p;

import 'nexa_http_dynamic_library_candidates_shared.dart';

List<String> resolveNexaHttpIosDynamicLibraryCandidates({
  required String executableDirectory,
  required Set<String> seeds,
  required bool Function(String path) fileExists,
}) {
  final candidates = <String>[];

  addExistingDynamicLibraryCandidates(
    candidates,
    _iosAppBundleCandidates(executableDirectory),
    fileExists,
  );
  addExistingDynamicLibraryCandidates(
    candidates,
    _discoverPackagedIos(seeds),
    fileExists,
  );
  addExistingDynamicLibraryCandidates(
    candidates,
    _discoverWorkspaceIos(seeds),
    fileExists,
  );

  return dedupeDynamicLibraryCandidates(candidates);
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

Iterable<String> _discoverPackagedIos(Set<String> seeds) sync* {
  final relativePaths = nexaHttpSupportedNativeTargets
      .where((target) => target.targetOS == 'ios')
      .map((target) => target.packagedRelativePath)
      .toList(growable: false);
  for (final seed in seeds) {
    yield* walkUpDynamicLibraryCandidates(seed, relativePaths);
  }
}

Iterable<String> _discoverWorkspaceIos(Set<String> seeds) sync* {
  final relativePaths = nexaHttpSupportedNativeTargets
      .where((target) => target.targetOS == 'ios')
      .expand((target) => target.runtimeWorkspaceRelativePaths())
      .toList(growable: false);
  for (final seed in seeds) {
    yield* walkUpDynamicLibraryCandidates(seed, relativePaths);
  }
}
