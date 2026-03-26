import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const rustNetNativeAssetName = 'src/native/rust_net_native_ffi.dart';

final class RustNetNativeMacosAssetBundle {
  RustNetNativeMacosAssetBundle._();

  static Future<CodeAsset> resolve(BuildInput input) async {
    final file = File.fromUri(
      input.packageRoot.resolve('macos/Libraries/librust_net_native.dylib'),
    );
    if (!await file.exists()) {
      throw StateError(
        'Missing packaged macOS native library at ${file.path}.',
      );
    }

    return CodeAsset(
      package: input.packageName,
      name: rustNetNativeAssetName,
      linkMode: DynamicLoadingBundled(),
      file: file.uri,
    );
  }
}
