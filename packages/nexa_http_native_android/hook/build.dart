import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;

import '../lib/src/nexa_http_native_android_asset_bundle.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.android) {
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
        'nexa_http_native_android_ffi',
      ),
    );
    final rustTargetTriple = target.rustTargetTriple;
    if (rustTargetTriple == null || rustTargetTriple.isEmpty) {
      throw StateError(
        'Android native target is missing rustTargetTriple for ${target.targetArchitecture}.',
      );
    }

    final workspaceRoot = p.normalize(p.join(sourceDir, '..', '..', '..', '..'));
    final buildScript = p.join(workspaceRoot, 'scripts', 'build_native_android.sh');
    final result = await Process.run('bash', <String>[buildScript, 'debug']);
    if (result.exitCode != 0) {
      throw ProcessException(
        'bash',
        <String>[buildScript, 'debug'],
        '${result.stdout}${result.stderr}',
        result.exitCode,
      );
    }

    final file = File(builtArtifactPathForTarget(sourceDir, target));
    if (!await file.exists()) {
      throw StateError('Missing Android native artifact: ${file.path}');
    }

    output.assets.code.add(
      await NexaHttpNativeAndroidAssetBundle.resolveFromFile(
        packageName: input.packageName,
        file: file,
      ),
    );
  });
}
