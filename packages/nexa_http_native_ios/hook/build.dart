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

    final packageRoot = Directory.fromUri(input.packageRoot).path;
    if (_isWorkspacePackage(packageRoot)) {
      await _prepareWorkspaceIosArtifacts(packageRoot);
    } else {
      await materializeNexaHttpNativeReleaseArtifact(
        packageRoot: packageRoot,
        targetOS: 'ios',
        targetArchitecture: _targetArchitecture(input.config.code.targetArchitecture),
        targetSdk: _targetSdk(input.config.code.iOS.targetSdk),
      );
    }

    output.assets.code.add(
      await NexaHttpNativeIosAssetBundle.resolve(input),
    );
  });
}

bool _isWorkspacePackage(String packageRoot) {
  final workspaceRoot = p.normalize(p.join(packageRoot, '..', '..'));
  return Directory(p.join(workspaceRoot, '.git')).existsSync();
}

Future<void> _prepareWorkspaceIosArtifacts(String packageRoot) async {
  final artifactsDir = Directory(p.join(packageRoot, 'ios', 'Frameworks'));
  if (artifactsDir.existsSync()) {
    await artifactsDir.delete(recursive: true);
  }

  final workspaceRoot = p.normalize(p.join(packageRoot, '..', '..'));
  final script = p.join(workspaceRoot, 'scripts', 'build_native_ios.sh');
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
        'No iOS target mapping for architecture $architecture.',
      ),
  };
}

String _targetSdk(IOSSdk sdk) {
  return switch (sdk) {
    IOSSdk.iPhoneOS => 'iphoneos',
    IOSSdk.iPhoneSimulator => 'iphonesimulator',
    _ => throw UnsupportedError('No iOS target SDK mapping for $sdk.'),
  };
}
