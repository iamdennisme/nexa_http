import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;

import '../lib/src/nexa_http_native_ios_asset_bundle.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets || input.config.code.targetOS != OS.iOS) {
      return;
    }

    final sdk = input.config.code.iOS.targetSdk.toString();
    final target = findNexaHttpNativeTarget(
      targetOS: input.config.code.targetOS.toString(),
      targetArchitecture: input.config.code.targetArchitecture.toString(),
      targetSdk: sdk,
    );
    if (target == null) {
      return;
    }

    final sourceDir = p.normalize(
      p.join(
        Directory.fromUri(input.packageRoot).path,
        'native',
        'nexa_http_native_ios_ffi',
      ),
    );
    final rustTargetTriple = target.rustTargetTriple;
    if (rustTargetTriple == null || rustTargetTriple.isEmpty) {
      throw StateError(
        'iOS native target is missing rustTargetTriple for ${target.targetArchitecture}/${target.targetSdk}.',
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

    final file = File(_builtArtifactPathForTarget(sourceDir, target));
    if (!await file.exists()) {
      throw StateError('Missing iOS native artifact: ${file.path}');
    }

    output.assets.code.add(
      await NexaHttpNativeIosAssetBundle.resolveFromFile(
        packageName: input.packageName,
        file: file,
      ),
    );
  });
}

String _builtArtifactPathForTarget(
  String sourceDir,
  NexaHttpNativeTarget target,
) {
  final workspaceRoot = p.normalize(p.join(sourceDir, '..', '..', '..', '..'));
  final rustTargetTriple = target.rustTargetTriple;
  if (rustTargetTriple == null || rustTargetTriple.isEmpty) {
    return p.join(workspaceRoot, 'target', 'debug', target.sourceArtifactFileName);
  }
  return p.join(
    workspaceRoot,
    'target',
    rustTargetTriple,
    'debug',
    target.sourceArtifactFileName,
  );
}
