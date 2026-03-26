import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../hook/build.dart' as rust_net_native_android_build_hook;

void main() {
  test('emits the packaged arm64 Android native library', () async {
    final libraryDir = Directory('android/src/main/jniLibs/arm64-v8a');
    await libraryDir.create(recursive: true);
    final libraryFile = File('${libraryDir.path}/librust_net_native.so');
    await libraryFile.writeAsBytes(const <int>[1, 2, 3, 4]);

    addTearDown(() async {
      if (await libraryFile.exists()) {
        await libraryFile.delete();
      }
    });

    await testCodeBuildHook(
      mainMethod: rust_net_native_android_build_hook.main,
      targetOS: OS.android,
      targetArchitecture: Architecture.arm64,
      check: (input, output) async {
        expect(output.assets.code, hasLength(1));
        final asset = output.assets.code.single;
        expect(
          asset.id,
          'package:rust_net_native_android/src/native/rust_net_native_ffi.dart',
        );
        expect(asset.linkMode, isA<DynamicLoadingBundled>());
        expect(asset.file, isNotNull);
        expect(
          File.fromUri(asset.file!).path,
          endsWith('android/src/main/jniLibs/arm64-v8a/librust_net_native.so'),
        );
      },
    );
  });
}
