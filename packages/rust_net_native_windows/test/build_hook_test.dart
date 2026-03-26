import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../hook/build.dart' as rust_net_native_windows_build_hook;

void main() {
  test('emits the packaged Windows native library when present', () async {
    final libraryDir = Directory('windows/Libraries');
    await libraryDir.create(recursive: true);
    final libraryFile = File('${libraryDir.path}/rust_net_native.dll');
    await libraryFile.writeAsBytes(const <int>[1, 2, 3, 4]);

    addTearDown(() async {
      if (await libraryFile.exists()) {
        await libraryFile.delete();
      }
    });

    await testCodeBuildHook(
      mainMethod: rust_net_native_windows_build_hook.main,
      targetOS: OS.windows,
      targetArchitecture: Architecture.x64,
      check: (input, output) async {
        expect(output.assets.code, hasLength(1));
        final asset = output.assets.code.single;
        expect(
          asset.id,
          'package:rust_net_native_windows/src/native/rust_net_native_ffi.dart',
        );
        expect(asset.linkMode, isA<DynamicLoadingBundled>());
        expect(asset.file, isNotNull);
        expect(
          File.fromUri(asset.file!).path,
          endsWith('windows/Libraries/rust_net_native.dll'),
        );
      },
    );
  });
}
