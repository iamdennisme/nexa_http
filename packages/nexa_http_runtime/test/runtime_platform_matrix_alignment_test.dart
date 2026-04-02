import 'package:nexa_http_distribution/nexa_http_distribution.dart';
import 'package:nexa_http_runtime/src/loader/nexa_http_ios_dynamic_library_candidates.dart';
import 'package:nexa_http_runtime/src/loader/nexa_http_macos_dynamic_library_candidates.dart';
import 'package:nexa_http_runtime/src/loader/nexa_http_windows_dynamic_library_candidates.dart';
import 'package:test/test.dart';

void main() {
  test('windows runtime workspace candidates align to the authoritative matrix',
      () {
    final actual = _workspaceTriples(
      resolveNexaHttpWindowsDynamicLibraryCandidates(
        executableDirectory: r'C:\demo',
        seeds: {r'C:\workspace'},
        fileExists: (_) => true,
      ),
    );

    final expected = nexaHttpSupportedNativeTargets
        .where((target) => target.targetOS == 'windows')
        .map((target) => target.rustTargetTriple)
        .nonNulls
        .toSet();

    expect(actual, expected);
  });

  test(
      'ios runtime packaged and workspace candidates align to the authoritative matrix',
      () {
    final candidates = resolveNexaHttpIosDynamicLibraryCandidates(
      executableDirectory: '/Applications/Demo.app',
      seeds: {'/workspace'},
      fileExists: (_) => true,
    );

    expect(
      _relativeCandidates(candidates, os: 'ios'),
      _expectedRelativeCandidates(os: 'ios'),
    );
  });

  test(
      'macos runtime packaged and workspace candidates align to the authoritative matrix',
      () {
    final candidates = resolveNexaHttpMacosDynamicLibraryCandidates(
      executableDirectory: '/Applications/Demo.app/Contents/MacOS',
      seeds: {'/workspace'},
      fileExists: (_) => true,
    );

    expect(
      _relativeCandidates(candidates, os: 'macos'),
      _expectedRelativeCandidates(os: 'macos'),
    );
  });
}

Set<String> _workspaceTriples(List<String> candidates) {
  return candidates
      .map((candidate) => candidate.replaceAll('\\', '/'))
      .where((candidate) => candidate.contains('/target/'))
      .map((candidate) {
    final segments = candidate.split('/');
    final targetIndex = segments.indexOf('target');
    if (targetIndex < 0 || targetIndex + 1 >= segments.length) {
      throw StateError('Unexpected workspace candidate: $candidate');
    }
    return segments[targetIndex + 1];
  }).toSet();
}

Set<String> _relativeCandidates(List<String> candidates, {required String os}) {
  return candidates
      .map((candidate) => candidate.replaceAll('\\', '/'))
      .where(
        (candidate) =>
            candidate.contains('/target/') ||
            candidate.contains('/packages/nexa_http_native_') ||
            candidate.contains('/$os/'),
      )
      .map((candidate) {
    if (candidate.contains('/packages/nexa_http_native_')) {
      return 'packages/${candidate.split('/packages/').last}';
    }
    if (candidate.contains('/target/')) {
      return 'target/${candidate.split('/target/').last}';
    }
    return '$os/${candidate.split('/$os/').last}';
  }).toSet();
}

Set<String> _expectedRelativeCandidates({required String os}) {
  return nexaHttpSupportedNativeTargets
      .where((target) => target.targetOS == os)
      .expand((target) => <String>[
            target.packagedRelativePath,
            ...target.runtimeWorkspaceRelativePaths(),
          ])
      .map((candidate) => candidate.replaceAll('\\', '/'))
      .toSet();
}
