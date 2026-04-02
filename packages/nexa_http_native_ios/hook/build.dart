import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http_native_ios/src/nexa_http_native_ios_asset_bundle.dart';
import 'package:nexa_http_distribution/nexa_http_distribution.dart';
import 'package:path/path.dart' as p;

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

    final file = await resolveNexaHttpNativeArtifactFile(
      packageRoot: input.packageRoot,
      cacheRoot: input.outputDirectoryShared,
      mode: resolveNexaHttpNativeArtifactResolutionMode(
        environment: Platform.environment,
        defaultMode: defaultNexaHttpNativeArtifactResolutionMode(
          packageRoot: input.packageRoot,
          defaultSourceDir: p.normalize(
            p.join(
              Directory.fromUri(input.packageRoot).path,
              'native',
              'nexa_http_native_ios_ffi',
            ),
          ),
        ),
      ),
      packageVersion: packageVersionForRoot(input.packageRoot),
      targetOS: target.targetOS,
      targetArchitecture: target.targetArchitecture,
      targetSdk: target.targetSdk,
      packagedRelativePath: target.packagedRelativePath,
      environment: Platform.environment,
      libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_IOS_LIB_PATH',
      sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_IOS_SOURCE_DIR',
      defaultSourceDir: p.normalize(
        p.join(
          Directory.fromUri(input.packageRoot).path,
          'native',
          'nexa_http_native_ios_ffi',
        ),
      ),
      sourceDirCandidates: target.sourceDirCandidates,
    );

    output.assets.code.add(
      await NexaHttpNativeIosAssetBundle.resolveFromFile(
        packageName: input.packageName,
        file: file,
      ),
    );
  });
}
