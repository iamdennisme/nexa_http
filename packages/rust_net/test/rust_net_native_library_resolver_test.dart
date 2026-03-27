import 'dart:io';

import 'package:rust_net/src/ffi/rust_net_native_library_resolver.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'rust-net-native-library-resolver-test-',
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('treats linux as a supported operating system', () {
    expect(
      RustNetNativeLibraryResolver.isSupportedOperatingSystem('linux'),
      isTrue,
    );
  });

  test('returns the linux shared library file name', () {
    expect(
      RustNetNativeLibraryResolver.libraryFileNameForOperatingSystem('linux'),
      'librust_net_native.so',
    );
  });

  test('discovers rust_net_native.framework inside a macOS app bundle', () {
    final executableDirectory = Directory(
      '${tempDir.path}/kino.app/Contents/MacOS',
    )..createSync(recursive: true);
    final frameworkBinary = File(
      '${tempDir.path}/kino.app/Contents/Frameworks/rust_net_native.framework/rust_net_native',
    )..createSync(recursive: true);

    final resolved = RustNetNativeLibraryResolver.discoverFromAppBundleForTest(
      operatingSystem: 'macos',
      executableDirectory: executableDirectory.path,
    );

    expect(resolved, frameworkBinary.path);
  });
}
