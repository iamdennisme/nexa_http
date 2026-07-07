import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import '../lib/src/nexa_http_native_android_asset_bundle.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.android) {
      return;
    }

    final packageRoot = Directory.fromUri(input.packageRoot).path;
    await prepareNexaHttpNativeCarrierArtifact(
      packageRoot: packageRoot,
      targetOS: 'android',
      targetArchitecture: _targetArchitecture(
        input.config.code.targetArchitecture,
      ),
      targetSdk: null,
    );

    output.assets.code.add(
      await NexaHttpNativeAndroidAssetBundle.resolve(input),
    );
  });
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
