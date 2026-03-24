import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';
import 'package:test/test.dart';

import '../hook/build.dart' as rust_net_build_hook;

void main() {
  group('rust_net build hook', () {
    test('emits a bundled code asset from a local manifest override', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'rust_net_build_hook_manifest',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final libraryFile = File.fromUri(
        tempDir.uri.resolve(Platform.isWindows
            ? 'rust_net_native.dll'
            : 'librust_net_native.dylib'),
      );
      await libraryFile.writeAsBytes(const <int>[1, 2, 3, 4]);

      final manifestFile = File.fromUri(tempDir.uri.resolve('manifest.json'));
      await manifestFile.writeAsString(
        jsonEncode(<String, Object?>{
          'package': 'rust_net',
          'package_version': _packageVersion(),
          'assets': <Map<String, Object?>>[
            <String, Object?>{
              'target_os': 'macos',
              'target_architecture': 'arm64',
              'file_name': libraryFile.uri.pathSegments.last,
              'source_url': libraryFile.uri.toString(),
              'sha256': sha256.convert(await libraryFile.readAsBytes()).toString(),
            },
          ],
        }),
      );

      await testCodeBuildHook(
        mainMethod: rust_net_build_hook.main,
        userDefines: PackageUserDefines(
          workspacePubspec: PackageUserDefinesSource(
            defines: <String, Object?>{
              'rust_net_manifest_path': manifestFile.path,
            },
            basePath: Directory.current.uri,
          ),
        ),
        check: (input, output) async {
          expect(output.assets.code, hasLength(1));
          final asset = output.assets.code.single;
          expect(
            asset.id,
            'package:rust_net/src/native/rust_net_native_ffi.dart',
          );
          expect(asset.linkMode, isA<DynamicLoadingBundled>());
          expect(asset.file, isNotNull);
          expect(await File.fromUri(asset.file!).readAsBytes(), <int>[1, 2, 3, 4]);
        },
      );
    });

    test('selects the iOS simulator asset when the target sdk is simulator', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'rust_net_build_hook_ios',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final deviceLibrary = File.fromUri(
        tempDir.uri.resolve('librust_net_native-ios-arm64.dylib'),
      );
      final simulatorLibrary = File.fromUri(
        tempDir.uri.resolve('librust_net_native-ios-sim-arm64.dylib'),
      );
      await deviceLibrary.writeAsBytes(const <int>[9, 9, 9]);
      await simulatorLibrary.writeAsBytes(const <int>[7, 7, 7]);

      final manifestFile = File.fromUri(tempDir.uri.resolve('manifest.json'));
      await manifestFile.writeAsString(
        jsonEncode(<String, Object?>{
          'package': 'rust_net',
          'package_version': _packageVersion(),
          'assets': <Map<String, Object?>>[
            <String, Object?>{
              'target_os': 'ios',
              'target_architecture': 'arm64',
              'target_sdk': 'iphoneos',
              'file_name': deviceLibrary.uri.pathSegments.last,
              'source_url': deviceLibrary.uri.toString(),
              'sha256': sha256.convert(await deviceLibrary.readAsBytes()).toString(),
            },
            <String, Object?>{
              'target_os': 'ios',
              'target_architecture': 'arm64',
              'target_sdk': 'iphonesimulator',
              'file_name': simulatorLibrary.uri.pathSegments.last,
              'source_url': simulatorLibrary.uri.toString(),
              'sha256': sha256
                  .convert(await simulatorLibrary.readAsBytes())
                  .toString(),
            },
          ],
        }),
      );

      await testCodeBuildHook(
        mainMethod: rust_net_build_hook.main,
        targetOS: OS.iOS,
        targetArchitecture: Architecture.arm64,
        targetIOSSdk: IOSSdk.iPhoneSimulator,
        userDefines: PackageUserDefines(
          workspacePubspec: PackageUserDefinesSource(
            defines: <String, Object?>{
              'rust_net_manifest_path': manifestFile.path,
            },
            basePath: Directory.current.uri,
          ),
        ),
        check: (input, output) async {
          expect(output.assets.code, hasLength(1));
          final asset = output.assets.code.single;
          expect(await File.fromUri(asset.file!).readAsBytes(), <int>[7, 7, 7]);
        },
      );
    });
  });
}

String _packageVersion() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final versionLine = pubspec
      .split('\n')
      .firstWhere((line) => line.startsWith('version:'));
  return versionLine.split(':').last.trim();
}
