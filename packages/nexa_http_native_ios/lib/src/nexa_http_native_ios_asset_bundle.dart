import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const nexaHttpNativeAssetName = 'src/native/nexa_http_native_ffi.dart';

final class NexaHttpNativeIosAssetBundle {
  NexaHttpNativeIosAssetBundle._();

  static Future<CodeAsset> resolve(BuildInput input) async {
    final fileName = _iosLibraryName(
      input.config.code.targetArchitecture,
      input.config.code.iOS.targetSdk.toString(),
    );
    final file = File.fromUri(input.packageRoot.resolve('ios/Frameworks/$fileName'));
    if (!await file.exists()) {
      throw StateError(
        'Missing packaged iOS native library at ${file.path}.',
      );
    }

    return resolveFromFile(
      packageName: input.packageName,
      file: file,
    );
  }

  static Future<CodeAsset> resolveFromFile({
    required String packageName,
    required File file,
  }) async {
    return CodeAsset(
      package: packageName,
      name: nexaHttpNativeAssetName,
      linkMode: DynamicLoadingBundled(),
      file: file.uri,
    );
  }

  static String _iosLibraryName(
    Architecture architecture,
    String targetSdk,
  ) {
    final isSimulator = targetSdk == IOSSdk.iPhoneSimulator.toString();
    return switch ((architecture, isSimulator)) {
      (Architecture.arm64, false) => 'libnexa_http_native-ios-arm64.dylib',
      (Architecture.arm64, true) => 'libnexa_http_native-ios-sim-arm64.dylib',
      (Architecture.x64, true) => 'libnexa_http_native-ios-sim-x64.dylib',
      _ => throw UnsupportedError(
          'No iOS artifact mapping for architecture=$architecture sdk=$targetSdk.',
        ),
    };
  }
}
