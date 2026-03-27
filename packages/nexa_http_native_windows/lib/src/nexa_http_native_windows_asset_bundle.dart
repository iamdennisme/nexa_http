import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const nexaHttpNativeAssetName = 'src/native/nexa_http_native_ffi.dart';

final class NexaHttpNativeWindowsAssetBundle {
  NexaHttpNativeWindowsAssetBundle._();

  static Future<CodeAsset> resolve(BuildInput input) async {
    final file = File.fromUri(
      input.packageRoot.resolve('windows/Libraries/nexa_http_native.dll'),
    );
    if (!await file.exists()) {
      throw StateError(
        'Missing packaged Windows native library at ${file.path}.',
      );
    }

    return resolveFromFile(
      packageName: input.packageName,
      file: file,
    );
  }

  static Future<CodeAsset> resolveFromFile({
    required String packageName,
    required File file,
  }) async {
    return CodeAsset(
      package: packageName,
      name: nexaHttpNativeAssetName,
      linkMode: DynamicLoadingBundled(),
      file: file.uri,
    );
  }
}
