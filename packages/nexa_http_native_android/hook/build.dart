import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http_native_android/src/nexa_http_native_android_asset_bundle.dart';
import 'package:nexa_http_distribution/nexa_http_distribution.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.android) {
      return;
    }

    final abi = switch (input.config.code.targetArchitecture) {
      Architecture.arm64 => 'arm64-v8a',
      Architecture.arm => 'armeabi-v7a',
      Architecture.x64 => 'x86_64',
      _ => null,
    };
    if (abi == null) {
      return;
    }

    final triple = switch (input.config.code.targetArchitecture) {
      Architecture.arm64 => 'aarch64-linux-android',
      Architecture.arm => 'armv7-linux-androideabi',
      Architecture.x64 => 'x86_64-linux-android',
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
      targetSdk: null,
      packagedRelativePath: 'android/src/main/jniLibs/$abi/libnexa_http_native.so',
      environment: Platform.environment,
      libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_ANDROID_LIB_PATH',
      sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_ANDROID_SOURCE_DIR',
      sourceDirCandidates: (sourceDir) => <String>[
        p.join(sourceDir, 'target', triple, 'debug', 'libnexa_http_native_android_ffi.so'),
        p.join(sourceDir, 'target', triple, 'release', 'libnexa_http_native_android_ffi.so'),
        p.normalize(
          p.join(sourceDir, '..', '..', '..', '..', 'target', triple, 'debug', 'libnexa_http_native_android_ffi.so'),
        ),
        p.normalize(
          p.join(sourceDir, '..', '..', '..', '..', 'target', triple, 'release', 'libnexa_http_native_android_ffi.so'),
        ),
      ],
    );

    output.assets.code.add(
      await NexaHttpNativeAndroidAssetBundle.resolveFromFile(
        packageName: input.packageName,
        file: file,
      ),
    );
  });
}
