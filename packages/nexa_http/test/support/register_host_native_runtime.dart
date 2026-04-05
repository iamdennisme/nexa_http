import 'dart:ffi';
import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;

Future<void> registerHostNativeRuntimeForTests() async {
  if (!Platform.isMacOS) {
    return;
  }

  final hostLibraryFile = await _resolveHostLibraryFile();
  registerNexaHttpNativeRuntime(
    _HostTestRuntime(
      hostLibraryFile,
    ),
  );
}

Future<String> _resolveHostLibraryFile() async {
  final candidates = _libraryCandidates();

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return p.normalize(candidate);
    }
  }

  final sourceDir = p.join(
    Directory.current.path,
    '..',
    'nexa_http_native_macos',
    'native',
    'nexa_http_native_macos_ffi',
  );
  final result = await Process.run(
    'cargo',
    <String>['build', '--manifest-path', p.join(sourceDir, 'Cargo.toml')],
  );
  if (result.exitCode == 0) {
    for (final candidate in _libraryCandidates()) {
      if (File(candidate).existsSync()) {
        return p.normalize(candidate);
      }
    }
  }

  throw StateError(
    'Unable to locate the host nexa_http macOS test library. '
    'Run ./scripts/build_native_macos.sh debug first.',
  );
}

List<String> _libraryCandidates() {
  return <String>[
    p.join(
      Directory.current.path,
      '..',
      '..',
      'target',
      'debug',
      'libnexa_http_native_macos_ffi.dylib',
    ),
    p.join(
      Directory.current.path,
      '..',
      '..',
      'target',
      'release',
      'libnexa_http_native_macos_ffi.dylib',
    ),
    p.join(
      Directory.current.path,
      '..',
      'nexa_http_native_macos',
      'macos',
      'Libraries',
      'libnexa_http_native.dylib',
    ),
    p.join(
      Directory.current.path,
      '..',
      'nexa_http_native_macos',
      'target',
      'debug',
      'libnexa_http_native.dylib',
    ),
    p.join(
      Directory.current.path,
      '..',
      'nexa_http_native_macos',
      'target',
      'release',
      'libnexa_http_native.dylib',
    ),
  ];
}

final class _HostTestRuntime implements NexaHttpNativeRuntime {
  const _HostTestRuntime(this.hostLibraryFile);

  final String hostLibraryFile;

  @override
  DynamicLibrary open() => DynamicLibrary.open(hostLibraryFile);
}
