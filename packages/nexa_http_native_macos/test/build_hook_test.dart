import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../hook/build.dart' as nexa_http_native_macos_build_hook;

void main() {
  test('emits a bundled code asset from the packaged macOS native library', () async {
    final libraryDir = Directory('macos/Libraries');
    await libraryDir.create(recursive: true);
    final libraryFile = File('${libraryDir.path}/libnexa_http_native.dylib');
    await libraryFile.writeAsBytes(const <int>[1, 2, 3, 4]);

    addTearDown(() async {
      if (await libraryFile.exists()) {
        await libraryFile.delete();
      }
    });

    await testCodeBuildHook(
      mainMethod: nexa_http_native_macos_build_hook.main,
      targetOS: OS.macOS,
      targetArchitecture: Architecture.arm64,
      check: (input, output) async {
        expect(output.assets.code, hasLength(1));
        final asset = output.assets.code.single;
        expect(
          asset.id,
          'package:nexa_http_native_macos/src/native/nexa_http_native_ffi.dart',
        );
        expect(asset.linkMode, isA<DynamicLoadingBundled>());
        expect(asset.file, isNotNull);
        expect(
          File.fromUri(asset.file!).path,
          endsWith('macos/Libraries/libnexa_http_native.dylib'),
        );
      },
    );
  });
}
