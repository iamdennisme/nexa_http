import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import '../lib/src/nexa_http_native_windows_asset_bundle.dart';

Future<void> main(
  List<String> args, {
  NexaHttpNativeArtifactPreparer prepareArtifact =
      prepareNexaHttpNativeCarrierArtifact,
}) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.windows) {
      return;
    }

    final packageRoot = Directory.fromUri(input.packageRoot).path;
    final preparedFile = await prepareArtifact(
      packageRoot: packageRoot,
      outputDirectory: Directory.fromUri(input.outputDirectory).path,
      targetOS: 'windows',
      targetArchitecture: _targetArchitecture(
        input.config.code.targetArchitecture,
      ),
      targetSdk: null,
      candidateDirectory: input.userDefines
          .path(nexaHttpNativeCandidateDirectoryDefine)
          ?.toFilePath(),
      candidateRef:
          input.userDefines[nexaHttpNativeCandidateRefDefine] as String?,
    );

    output.assets.code.add(
      await NexaHttpNativeWindowsAssetBundle.resolveFromFile(
        packageName: input.packageName,
        file: preparedFile,
      ),
    );
  });
}

String _targetArchitecture(Architecture architecture) {
  return switch (architecture) {
    Architecture.x64 => 'x64',
    _ => throw UnsupportedError(
      'No Windows target mapping for architecture $architecture.',
    ),
  };
}
