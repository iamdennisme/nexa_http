import 'package:test/test.dart';

import '../scripts/native_payload_identity.dart';

void main() {
  test('Mach-O identity ignores file path and UUID output order', () {
    final first = machONativePayloadIdentitySha256('''
UUID: F90D5B1B-8F07-359B-A87B-D467518F31B4 (arm64) /prepared/library.dylib
UUID: A1F8EEBD-BFE6-37D7-A59B-C12D09A31D5D (x86_64) /prepared/library.dylib
''');
    final packaged = machONativePayloadIdentitySha256('''
UUID: A1F8EEBD-BFE6-37D7-A59B-C12D09A31D5D (x86_64) /App/Frameworks/native
UUID: F90D5B1B-8F07-359B-A87B-D467518F31B4 (arm64) /App/Frameworks/native
''');

    expect(packaged, first);
    expect(first, hasLength(64));
  });
}
