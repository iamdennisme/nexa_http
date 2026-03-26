import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const rustNetNativeAssetName = 'src/native/rust_net_native_ffi.dart';

final class RustNetNativeAndroidAssetBundle {
  RustNetNativeAndroidAssetBundle._();

  static Future<CodeAsset> resolve(BuildInput input) async {
    final abi = _androidAbi(input.config.code.targetArchitecture);
    final file = File.fromUri(
      input.packageRoot.resolve('android/src/main/jniLibs/$abi/librust_net_native.so'),
    );
    if (!await file.exists()) {
      throw StateError(
        'Missing packaged Android native library for ABI $abi at ${file.path}.',
      );
    }

    return CodeAsset(
      package: input.packageName,
      name: rustNetNativeAssetName,
      linkMode: DynamicLoadingBundled(),
      file: file.uri,
    );
  }

  static String _androidAbi(Architecture architecture) {
    return switch (architecture) {
      Architecture.arm64 => 'arm64-v8a',
      Architecture.arm => 'armeabi-v7a',
      Architecture.x64 => 'x86_64',
      _ => throw UnsupportedError(
          'No Android ABI mapping for architecture $architecture.',
        ),
    };
  }
}
