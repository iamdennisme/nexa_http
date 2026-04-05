import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
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

    final sourceDir = p.normalize(
      p.join(
        Directory.fromUri(input.packageRoot).path,
        'native',
        'nexa_http_native_windows_ffi',
      ),
    );
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

    final file = File(builtArtifactPathForTarget(sourceDir, target));
    if (!await file.exists()) {
      throw StateError('Missing Windows native artifact: ${file.path}');
    }

    output.assets.code.add(
      await NexaHttpNativeWindowsAssetBundle.resolveFromFile(
        packageName: input.packageName,
        file: file,
      ),
    );
  });
}
