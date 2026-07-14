import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

final class NexaHttpNativeWindowsAssetBundle {
  NexaHttpNativeWindowsAssetBundle._();

  static CodeAsset resolveFromFile({
    required String packageName,
    required File file,
  }) {
    return CodeAsset(
      package: packageName,
      name: nexaHttpNativeAssetName,
      linkMode: DynamicLoadingBundled(),
      file: file.uri,
    );
  }
}
