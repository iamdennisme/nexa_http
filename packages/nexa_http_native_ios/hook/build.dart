import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import '../lib/src/nexa_http_native_ios_asset_bundle.dart';

Future<void> main(
  List<String> args, {
  NexaHttpNativeArtifactPreparer prepareArtifact =
      prepareNexaHttpNativeCarrierArtifact,
}) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets || input.config.code.targetOS != OS.iOS) {
      return;
    }

    final packageRoot = Directory.fromUri(input.packageRoot).path;
    final preparedFile = await prepareArtifact(
      packageRoot: packageRoot,
      outputDirectory: Directory.fromUri(input.outputDirectory).path,
      targetOS: 'ios',
      targetArchitecture: _targetArchitecture(
        input.config.code.targetArchitecture,
      ),
      targetSdk: _targetSdk(input.config.code.iOS.targetSdk),
      candidateDirectory: input.userDefines
          .path(nexaHttpNativeCandidateDirectoryDefine)
          ?.toFilePath(),
      candidateRef:
          input.userDefines[nexaHttpNativeCandidateRefDefine] as String?,
    );

    output.assets.code.add(
      await NexaHttpNativeIosAssetBundle.resolveFromFile(
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
