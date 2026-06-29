import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('release workflow publishes nexa_http native artifacts', () {
    final workflow = File('.github/workflows/release-native-assets.yml').readAsStringSync();
    expect(workflow, contains('nexa_http_native'));
    expect(
      workflow,
      contains('packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi'),
    );
  });
}
