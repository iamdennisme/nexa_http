import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const rustNetNativeAssetName = 'src/native/rust_net_native_ffi.dart';

final class RustNetNativeIosAssetBundle {
  RustNetNativeIosAssetBundle._();

  static Future<CodeAsset> resolve(BuildInput input) async {
    final fileName = _iosLibraryName(
      input.config.code.targetArchitecture,
      input.config.code.iOS.targetSdk.toString(),
    );
    final file = File.fromUri(
      input.packageRoot.resolve('ios/Frameworks/$fileName'),
    );
    if (!await file.exists()) {
      throw StateError(
        'Missing packaged iOS native library at ${file.path}.',
      );
    }

    return CodeAsset(
      package: input.packageName,
      name: rustNetNativeAssetName,
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
      (Architecture.arm64, false) => 'librust_net_native-ios-arm64.dylib',
      (Architecture.arm64, true) => 'librust_net_native-ios-sim-arm64.dylib',
      (Architecture.x64, true) => 'librust_net_native-ios-sim-x64.dylib',
      _ => throw UnsupportedError(
          'No iOS artifact mapping for architecture=$architecture sdk=$targetSdk.',
        ),
    };
  }
}
