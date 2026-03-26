import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import 'package:rust_net_native_android/src/rust_net_native_android_asset_bundle.dart';

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

    final file = File.fromUri(
      input.packageRoot.resolve('android/src/main/jniLibs/$abi/librust_net_native.so'),
    );
    if (!await file.exists()) {
      return;
    }

    output.assets.code.add(await RustNetNativeAndroidAssetBundle.resolve(input));
  });
}
