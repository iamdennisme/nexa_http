import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import 'package:rust_net_native_windows/src/rust_net_native_windows_asset_bundle.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.windows) {
      return;
    }

    final file = File.fromUri(
      input.packageRoot.resolve('windows/Libraries/rust_net_native.dll'),
    );
    if (!await file.exists()) {
      return;
    }

    output.assets.code.add(await RustNetNativeWindowsAssetBundle.resolve(input));
  });
}
