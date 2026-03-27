import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('release workflow publishes nexa_http native artifacts', () {
    final workflow = File('.github/workflows/release-native-assets.yml').readAsStringSync();
    expect(workflow, contains('nexa_http_native'));
    expect(workflow, isNot(contains('packages/rust_net/native/rust_net_native')));
  });
}
