import 'package:rust_net/src/ffi/rust_net_native_library_resolver.dart';
import 'package:test/test.dart';

void main() {
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
}
