import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import 'package:rust_net/src/native/rust_net_native_asset_bundle.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final asset = await RustNetNativeAssetBundle.resolve(input);
    output.assets.code.add(asset);
  });
}
