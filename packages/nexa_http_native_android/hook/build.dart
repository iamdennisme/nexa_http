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

    final packageRoot = Directory.fromUri(input.packageRoot).path;
    if (_isWorkspacePackage(packageRoot)) {
      await _prepareWorkspaceAndroidArtifacts(packageRoot);
    } else {
      await materializeNexaHttpNativeReleaseArtifact(
        packageRoot: packageRoot,
        targetOS: 'android',
        targetArchitecture: _targetArchitecture(input.config.code.targetArchitecture),
        targetSdk: null,
      );
    }

    output.assets.code.add(
      await NexaHttpNativeAndroidAssetBundle.resolve(input),
    );
  });
}

bool _isWorkspacePackage(String packageRoot) {
  final workspaceRoot = p.normalize(p.join(packageRoot, '..', '..'));
  return Directory(p.join(workspaceRoot, '.git')).existsSync();
}

Future<void> _prepareWorkspaceAndroidArtifacts(String packageRoot) async {
  final artifactsDir = Directory(p.join(packageRoot, 'android', 'src', 'main', 'jniLibs'));
  if (artifactsDir.existsSync()) {
    await artifactsDir.delete(recursive: true);
  }

  final workspaceRoot = p.normalize(p.join(packageRoot, '..', '..'));
  final script = p.join(workspaceRoot, 'scripts', 'build_native_android.sh');
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
    Architecture.arm => 'arm',
    Architecture.x64 => 'x64',
    _ => throw UnsupportedError(
        'No Android target mapping for architecture $architecture.',
      ),
  };
}
