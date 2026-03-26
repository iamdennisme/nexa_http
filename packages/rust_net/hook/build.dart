import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import 'package:rust_net/src/native/rust_net_native_asset_bundle.dart';

const _manifestPathUserDefine = 'rust_net_manifest_path';
const _manifestUrlUserDefine = 'rust_net_manifest_url';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final hasExplicitManifest =
        input.userDefines.path(_manifestPathUserDefine) != null ||
        (input.userDefines[_manifestUrlUserDefine] is String &&
            (input.userDefines[_manifestUrlUserDefine] as String)
                .trim()
                .isNotEmpty);

    if (!hasExplicitManifest) {
      return;
    }

    final asset = await RustNetNativeAssetBundle.resolve(input);
    output.assets.code.add(asset);
  });
}
