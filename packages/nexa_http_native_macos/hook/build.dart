import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import '../lib/src/nexa_http_native_macos_asset_bundle.dart';

Future<void> main(
  List<String> args, {
  NexaHttpNativeArtifactPreparer prepareArtifact =
      prepareNexaHttpNativeCarrierArtifact,
}) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.macOS) {
      return;
    }

    final packageRoot = Directory.fromUri(input.packageRoot).path;
    final preparedFile = await prepareArtifact(
      packageRoot: packageRoot,
      outputDirectory: Directory.fromUri(input.outputDirectory).path,
      targetOS: 'macos',
      targetArchitecture: _targetArchitecture(
        input.config.code.targetArchitecture,
      ),
      targetSdk: null,
    );

    output.assets.code.add(
      await NexaHttpNativeMacosAssetBundle.resolveFromFile(
        packageName: input.packageName,
        file: preparedFile,
      ),
    );
  });
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
