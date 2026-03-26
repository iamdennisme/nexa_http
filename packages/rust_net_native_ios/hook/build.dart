import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import 'package:rust_net_native_ios/src/rust_net_native_ios_asset_bundle.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.iOS) {
      return;
    }

    final sdk = input.config.code.iOS.targetSdk.toString();
    final fileName = switch ((input.config.code.targetArchitecture, sdk)) {
      (Architecture.arm64, 'iphoneos') => 'librust_net_native-ios-arm64.dylib',
      (Architecture.arm64, 'iphonesimulator') =>
        'librust_net_native-ios-sim-arm64.dylib',
      (Architecture.x64, 'iphonesimulator') =>
        'librust_net_native-ios-sim-x64.dylib',
      _ => null,
    };
    if (fileName == null) {
      return;
    }

    final file = File.fromUri(input.packageRoot.resolve('ios/Frameworks/$fileName'));
    if (!await file.exists()) {
      return;
    }

    output.assets.code.add(await RustNetNativeIosAssetBundle.resolve(input));
  });
}
