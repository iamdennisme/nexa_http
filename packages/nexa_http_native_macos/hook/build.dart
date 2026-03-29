import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:nexa_http/nexa_http_native_assets.dart';
import 'package:nexa_http_native_macos/src/nexa_http_native_macos_asset_bundle.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.macOS) {
      return;
    }

    final file = await resolveNexaHttpNativeArtifactFile(
      packageRoot: input.packageRoot,
      cacheRoot: input.outputDirectoryShared,
      packageVersion: packageVersionForRoot(input.packageRoot),
      targetOS: input.config.code.targetOS.toString(),
      targetArchitecture: input.config.code.targetArchitecture.toString(),
      targetSdk: null,
      packagedRelativePath: 'macos/Libraries/libnexa_http_native.dylib',
      environment: Platform.environment,
      libPathEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_LIB_PATH',
      sourceDirEnvironmentVariable: 'NEXA_HTTP_NATIVE_MACOS_SOURCE_DIR',
      defaultSourceDir: p.normalize(
        p.join(
          Directory.fromUri(input.packageRoot).path,
          'native',
          'nexa_http_native_macos_ffi',
        ),
      ),
      buildDefaultSourceDir: (sourceDir) async {
        final result = await Process.run(
          'cargo',
          <String>[
            'build',
            '--manifest-path',
            p.join(sourceDir, 'Cargo.toml'),
          ],
        );
        if (result.exitCode != 0) {
          throw ProcessException(
            'cargo',
            <String>['build', '--manifest-path', p.join(sourceDir, 'Cargo.toml')],
            '${result.stdout}${result.stderr}',
            result.exitCode,
          );
        }
      },
      sourceDirCandidates: (sourceDir) => <String>[
        p.join(sourceDir, 'target', 'debug', 'libnexa_http_native_macos_ffi.dylib'),
        p.join(sourceDir, 'target', 'release', 'libnexa_http_native_macos_ffi.dylib'),
        p.normalize(
          p.join(sourceDir, '..', '..', '..', '..', 'target', 'debug', 'libnexa_http_native_macos_ffi.dylib'),
        ),
        p.normalize(
          p.join(sourceDir, '..', '..', '..', '..', 'target', 'release', 'libnexa_http_native_macos_ffi.dylib'),
        ),
      ],
    );

    output.assets.code.add(
      await NexaHttpNativeMacosAssetBundle.resolveFromFile(
        packageName: input.packageName,
        file: file,
      ),
    );
  });
}
