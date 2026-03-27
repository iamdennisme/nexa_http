import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http/src/native_asset/nexa_http_native_artifact_resolver.dart';
import 'package:nexa_http_native_linux/src/nexa_http_native_linux_asset_bundle.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.linux) {
      return;
    }

    final file = await resolveNexaHttpNativeArtifactFile(
      packageRoot: input.packageRoot,
      cacheRoot: input.outputDirectoryShared,
      packageVersion: packageVersionForRoot(input.packageRoot),
      targetOS: input.config.code.targetOS.toString(),
      targetArchitecture: input.config.code.targetArchitecture.toString(),
      targetSdk: null,
      packagedRelativePath: 'linux/Libraries/libnexa_http_native.so',
      environment: Platform.environment,
      libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_LINUX_LIB_PATH',
      sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_LINUX_SOURCE_DIR',
      sourceDirCandidates: (sourceDir) => <String>[
        p.join(sourceDir, 'target', 'debug', 'libnexa_http_native_linux_ffi.so'),
        p.join(sourceDir, 'target', 'release', 'libnexa_http_native_linux_ffi.so'),
        p.normalize(
          p.join(sourceDir, '..', '..', '..', '..', 'target', 'debug', 'libnexa_http_native_linux_ffi.so'),
        ),
        p.normalize(
          p.join(sourceDir, '..', '..', '..', '..', 'target', 'release', 'libnexa_http_native_linux_ffi.so'),
        ),
      ],
    );

    output.assets.code.add(
      await NexaHttpNativeLinuxAssetBundle.resolveFromFile(
        packageName: input.packageName,
        file: file,
      ),
    );
  });
}
