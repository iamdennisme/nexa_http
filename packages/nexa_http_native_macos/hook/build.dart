import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;

import '../lib/src/nexa_http_native_macos_asset_bundle.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.macOS) {
      return;
    }

    final packageRoot = Directory.fromUri(input.packageRoot).path;
    if (_isWorkspacePackage(packageRoot)) {
      await _prepareWorkspaceMacosArtifacts(packageRoot);
    } else {
      await materializeNexaHttpNativeReleaseArtifact(
        packageRoot: packageRoot,
        targetOS: 'macos',
        targetArchitecture:
            _targetArchitecture(input.config.code.targetArchitecture),
        targetSdk: null,
      );
    }

    output.assets.code.add(
      await NexaHttpNativeMacosAssetBundle.resolve(input),
    );
  });
}

bool _isWorkspacePackage(String packageRoot) {
  return isNexaHttpNativeWorkspacePackage(packageRoot);
}

Future<void> _prepareWorkspaceMacosArtifacts(String packageRoot) async {
  await prepareNexaHttpNativeWorkspaceArtifactsDirectory(
    p.join(packageRoot, 'macos', 'Libraries'),
  );

  final workspaceRoot = p.normalize(p.join(packageRoot, '..', '..'));
  final script = p.join(workspaceRoot, 'scripts', 'build_native_macos.sh');
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

String _targetArchitecture(Architecture architecture) {
  return switch (architecture) {
    Architecture.arm64 => 'arm64',
    Architecture.x64 => 'x64',
    _ => throw UnsupportedError(
        'No macOS target mapping for architecture $architecture.',
      ),
  };
}
