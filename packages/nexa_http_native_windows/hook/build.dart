import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as p;

import '../lib/src/nexa_http_native_windows_asset_bundle.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.windows) {
      return;
    }

    final packageRoot = Directory.fromUri(input.packageRoot).path;
    if (_isWorkspacePackage(packageRoot)) {
      await _prepareWorkspaceWindowsArtifacts(packageRoot);
    }

    output.assets.code.add(
      await NexaHttpNativeWindowsAssetBundle.resolve(input),
    );
  });
}

bool _isWorkspacePackage(String packageRoot) {
  final workspaceRoot = p.normalize(p.join(packageRoot, '..', '..'));
  return Directory(p.join(workspaceRoot, '.git')).existsSync();
}

Future<void> _prepareWorkspaceWindowsArtifacts(String packageRoot) async {
  final artifactsDir = Directory(p.join(packageRoot, 'windows', 'Libraries'));
  if (artifactsDir.existsSync()) {
    await artifactsDir.delete(recursive: true);
  }

  final workspaceRoot = p.normalize(p.join(packageRoot, '..', '..'));
  final script = p.join(workspaceRoot, 'scripts', 'build_native_windows.sh');
  final result = await Process.run('bash', <String>[script, 'debug']);
  if (result.exitCode != 0) {
    throw ProcessException(
      'bash',
      <String>[script, 'debug'],
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
}
