import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../hook/build.dart' as nexa_http_native_linux_build_hook;

void main() {
  test('emits the packaged Linux native library when present', () async {
    final libraryDir = Directory('linux/Libraries');
    await libraryDir.create(recursive: true);
    final libraryFile = File('${libraryDir.path}/libnexa_http_native.so');
    await libraryFile.writeAsBytes(const <int>[1, 2, 3, 4]);

    addTearDown(() async {
      if (await libraryFile.exists()) {
        await libraryFile.delete();
      }
    });

    await testCodeBuildHook(
      mainMethod: nexa_http_native_linux_build_hook.main,
      targetOS: OS.linux,
      targetArchitecture: Architecture.x64,
      check: (input, output) async {
        expect(output.assets.code, hasLength(1));
        final asset = output.assets.code.single;
        expect(
          asset.id,
          'package:nexa_http_native_linux/src/native/nexa_http_native_ffi.dart',
        );
        expect(asset.linkMode, isA<DynamicLoadingBundled>());
        expect(asset.file, isNotNull);
        expect(
          File.fromUri(asset.file!).path,
          endsWith('linux/Libraries/libnexa_http_native.so'),
        );
      },
    );
  });
}
