import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:nexa_http_distribution/nexa_http_distribution.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../hook/build.dart' as nexa_http_native_macos_build_hook;

void main() {
  test(
    'workspace-dev resolves macOS artifact from source build output',
    () async {
      if (!Platform.isMacOS) {
        markTestSkipped('Requires macOS host.');
        return;
      }

      await _runInPackageRoot(() async {
        await testCodeBuildHook(
          mainMethod: nexa_http_native_macos_build_hook.main,
          targetOS: OS.macOS,
          targetArchitecture: Architecture.arm64,
          check: (input, output) async {
            expect(output.assets.code, hasLength(1));
            final asset = output.assets.code.single;
            expect(
              asset.id,
              'package:nexa_http_native_macos/src/native/nexa_http_native_ffi.dart',
            );
            expect(asset.linkMode, isA<DynamicLoadingBundled>());
            expect(asset.file, isNotNull);
            expect(
              File.fromUri(asset.file!).path,
              endsWith(
                '/target/aarch64-apple-darwin/debug/libnexa_http_native_macos_ffi.dylib',
              ),
            );
          },
        );
      });
    },
  );

  test('macOS x64 target candidates resolve to an architecture-specific path', () {
    final target = findNexaHttpNativeTarget(
      targetOS: 'macos',
      targetArchitecture: 'x64',
      targetSdk: null,
    );

    expect(target, isNotNull);
    expect(
      target!.sourceDirCandidates('/tmp/source').first,
      p.join(
        '/tmp/source',
        'target',
        'x86_64-apple-darwin',
        'debug',
        'libnexa_http_native_macos_ffi.dylib',
      ),
    );
  });

  test('cargo build arguments target the requested macOS architecture', () {
    final target = findNexaHttpNativeTarget(
      targetOS: 'macos',
      targetArchitecture: 'x64',
      targetSdk: null,
    );

    expect(target, isNotNull);
    expect(
      nexa_http_native_macos_build_hook
          .cargoBuildArgumentsForNexaHttpTarget('/tmp/source', target!),
      <String>[
        'build',
        '--manifest-path',
        p.join('/tmp/source', 'Cargo.toml'),
        '--target',
        'x86_64-apple-darwin',
      ],
    );
  });

  test('cross-arch macOS builds receive SDK environment overrides', () {
    final target = findNexaHttpNativeTarget(
      targetOS: 'macos',
      targetArchitecture: 'x64',
      targetSdk: null,
    );

    expect(target, isNotNull);
    expect(
      nexa_http_native_macos_build_hook.cargoBuildEnvironmentForNexaHttpTarget(
        target: target!,
        sdkRoot: '/tmp/MacOSX.sdk',
      ),
      <String, String>{
        'SDKROOT': '/tmp/MacOSX.sdk',
        'MACOSX_DEPLOYMENT_TARGET': '10.15',
      },
    );
  });
}

Future<T> _runInPackageRoot<T>(Future<T> Function() action) async {
  final originalDirectory = Directory.current;
  final packageDirectory =
      Directory('packages/nexa_http_native_macos').existsSync()
      ? Directory('packages/nexa_http_native_macos')
      : originalDirectory;
  Directory.current = packageDirectory.path;
  try {
    return await action();
  } finally {
    Directory.current = originalDirectory.path;
  }
}
