import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http_distribution/nexa_http_distribution.dart';
import 'package:path/path.dart' as p;

import '../lib/src/nexa_http_native_windows_asset_bundle.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.windows) {
      return;
    }

    final target = findNexaHttpNativeTarget(
      targetOS: input.config.code.targetOS.toString(),
      targetArchitecture: input.config.code.targetArchitecture.toString(),
      targetSdk: null,
    );
    if (target == null) {
      return;
    }

    final defaultSourceDir = p.normalize(
      p.join(
        Directory.fromUri(input.packageRoot).path,
        'native',
        'nexa_http_native_windows_ffi',
      ),
    );
    final mode = resolveNexaHttpNativeArtifactResolutionMode(
      environment: Platform.environment,
      defaultMode: defaultNexaHttpNativeArtifactResolutionMode(
        packageRoot: input.packageRoot,
        defaultSourceDir: defaultSourceDir,
      ),
    );

    final file = await resolveNexaHttpNativeArtifactFile(
      packageRoot: input.packageRoot,
      cacheRoot: input.outputDirectoryShared,
      mode: mode,
      releaseIdentity: null,
      targetOS: target.targetOS,
      targetArchitecture: target.targetArchitecture,
      targetSdk: null,
      packagedRelativePath: target.packagedRelativePath,
      environment: Platform.environment,
      libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_WINDOWS_LIB_PATH',
      sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_WINDOWS_SOURCE_DIR',
      defaultSourceDir: p.normalize(
        p.join(
          Directory.fromUri(input.packageRoot).path,
          'native',
          'nexa_http_native_windows_ffi',
        ),
      ),
      buildDefaultSourceDir: (sourceDir) async {
        final rustTargetTriple = target.rustTargetTriple;
        if (rustTargetTriple == null || rustTargetTriple.isEmpty) {
          throw StateError(
            'Windows native target is missing rustTargetTriple for ${target.targetArchitecture}.',
          );
        }

        final result = await Process.run('cargo', <String>[
          'build',
          '--manifest-path',
          p.join(sourceDir, 'Cargo.toml'),
          '--target',
          rustTargetTriple,
        ]);
        if (result.exitCode != 0) {
          throw ProcessException(
            'cargo',
            <String>[
              'build',
              '--manifest-path',
              p.join(sourceDir, 'Cargo.toml'),
              '--target',
              rustTargetTriple,
            ],
            '${result.stdout}${result.stderr}',
            result.exitCode,
          );
        }
      },
      sourceDirCandidates: target.sourceDirCandidates,
    );

    output.assets.code.add(
      await NexaHttpNativeWindowsAssetBundle.resolveFromFile(
        packageName: input.packageName,
        file: file,
      ),
    );
  });
}
