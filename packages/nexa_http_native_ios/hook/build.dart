import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http/nexa_http_native_assets.dart';
import 'package:nexa_http_native_ios/src/nexa_http_native_ios_asset_bundle.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.iOS) {
      return;
    }

    final sdk = input.config.code.iOS.targetSdk.toString();
    final fileName = switch ((input.config.code.targetArchitecture, sdk)) {
      (Architecture.arm64, 'iphoneos') => 'libnexa_http_native-ios-arm64.dylib',
      (Architecture.arm64, 'iphonesimulator') =>
        'libnexa_http_native-ios-sim-arm64.dylib',
      (Architecture.x64, 'iphonesimulator') =>
        'libnexa_http_native-ios-sim-x64.dylib',
      _ => null,
    };
    if (fileName == null) {
      return;
    }

    final triple = switch ((input.config.code.targetArchitecture, sdk)) {
      (Architecture.arm64, 'iphoneos') => 'aarch64-apple-ios',
      (Architecture.arm64, 'iphonesimulator') => 'aarch64-apple-ios-sim',
      (Architecture.x64, 'iphonesimulator') => 'x86_64-apple-ios',
      _ => null,
    };
    if (triple == null) {
      return;
    }

    final file = await resolveNexaHttpNativeArtifactFile(
      packageRoot: input.packageRoot,
      cacheRoot: input.outputDirectoryShared,
      packageVersion: packageVersionForRoot(input.packageRoot),
      targetOS: input.config.code.targetOS.toString(),
      targetArchitecture: input.config.code.targetArchitecture.toString(),
      targetSdk: input.config.code.iOS.targetSdk.toString(),
      packagedRelativePath: 'ios/Frameworks/$fileName',
      environment: Platform.environment,
      libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_IOS_LIB_PATH',
      sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_IOS_SOURCE_DIR',
      sourceDirCandidates: (sourceDir) => <String>[
        p.join(sourceDir, 'target', triple, 'debug', 'libnexa_http_native_ios_ffi.dylib'),
        p.join(sourceDir, 'target', triple, 'release', 'libnexa_http_native_ios_ffi.dylib'),
        p.normalize(
          p.join(sourceDir, '..', '..', '..', '..', 'target', triple, 'debug', 'libnexa_http_native_ios_ffi.dylib'),
        ),
        p.normalize(
          p.join(sourceDir, '..', '..', '..', '..', 'target', triple, 'release', 'libnexa_http_native_ios_ffi.dylib'),
        ),
      ],
    );

    output.assets.code.add(
      await NexaHttpNativeIosAssetBundle.resolveFromFile(
        packageName: input.packageName,
        file: file,
      ),
    );
  });
}
