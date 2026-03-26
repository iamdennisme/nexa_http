import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import 'package:rust_net_native_macos/src/rust_net_native_macos_asset_bundle.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.macOS) {
      return;
    }

    final file = File.fromUri(
      input.packageRoot.resolve('macos/Libraries/librust_net_native.dylib'),
    );
    if (!await file.exists()) {
      return;
    }

    output.assets.code.add(await RustNetNativeMacosAssetBundle.resolve(input));
  });
}
