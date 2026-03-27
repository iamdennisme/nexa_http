import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../hook/build.dart' as nexa_http_native_ios_build_hook;

void main() {
  test('emits the packaged iOS simulator native library when present', () async {
    final frameworksDir = Directory('ios/Frameworks');
    await frameworksDir.create(recursive: true);
    final libraryFile = File(
      '${frameworksDir.path}/libnexa_http_native-ios-sim-arm64.dylib',
    );
    await libraryFile.writeAsBytes(const <int>[1, 2, 3, 4]);

    addTearDown(() async {
      if (await libraryFile.exists()) {
        await libraryFile.delete();
      }
    });

    await testCodeBuildHook(
      mainMethod: nexa_http_native_ios_build_hook.main,
      targetOS: OS.iOS,
      targetArchitecture: Architecture.arm64,
      targetIOSSdk: IOSSdk.iPhoneSimulator,
      check: (input, output) async {
        expect(output.assets.code, hasLength(1));
        final asset = output.assets.code.single;
        expect(
          asset.id,
          'package:nexa_http_native_ios/src/native/nexa_http_native_ffi.dart',
        );
        expect(asset.linkMode, isA<DynamicLoadingBundled>());
        expect(asset.file, isNotNull);
        expect(
          File.fromUri(asset.file!).path,
          endsWith('ios/Frameworks/libnexa_http_native-ios-sim-arm64.dylib'),
        );
      },
    );
  });
}
