import 'package:flutter_test/flutter_test.dart';
import 'package:rust_net/src/ffi/rust_net_native_library_resolver.dart';

void main() {
  test('does not treat linux as a supported operating system', () {
    expect(
      RustNetNativeLibraryResolver.isSupportedOperatingSystem('linux'),
      isFalse,
    );
  });

  test('throws an unsupported error for linux library resolution metadata', () {
    expect(
      () => RustNetNativeLibraryResolver.libraryFileNameForOperatingSystem(
        'linux',
      ),
      throwsA(
        isA<UnsupportedError>().having(
          (error) => '$error',
          'message',
          contains('linux'),
        ),
      ),
    );
  });
}
