import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http_native_windows/src/nexa_http_native_windows_asset_bundle.dart';
import 'package:nexa_http_distribution/nexa_http_distribution.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.windows) {
      return;
    }

    final file = await resolveNexaHttpNativeArtifactFile(
      packageRoot: input.packageRoot,
      cacheRoot: input.outputDirectoryShared,
      packageVersion: packageVersionForRoot(input.packageRoot),
      targetOS: input.config.code.targetOS.toString(),
      targetArchitecture: input.config.code.targetArchitecture.toString(),
      targetSdk: null,
      packagedRelativePath: 'windows/Libraries/nexa_http_native.dll',
      environment: Platform.environment,
      libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_WINDOWS_LIB_PATH',
      sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_WINDOWS_SOURCE_DIR',
      sourceDirCandidates: (sourceDir) => <String>[
        p.join(sourceDir, 'target', 'x86_64-pc-windows-gnu', 'debug', 'nexa_http_native_windows_ffi.dll'),
        p.join(sourceDir, 'target', 'x86_64-pc-windows-gnu', 'release', 'nexa_http_native_windows_ffi.dll'),
        p.normalize(
          p.join(sourceDir, '..', '..', '..', '..', 'target', 'x86_64-pc-windows-gnu', 'debug', 'nexa_http_native_windows_ffi.dll'),
        ),
        p.normalize(
          p.join(sourceDir, '..', '..', '..', '..', 'target', 'x86_64-pc-windows-gnu', 'release', 'nexa_http_native_windows_ffi.dll'),
        ),
      ],
    );

    output.assets.code.add(
      await NexaHttpNativeWindowsAssetBundle.resolveFromFile(
        packageName: input.packageName,
        file: file,
      ),
    );
  });
}
