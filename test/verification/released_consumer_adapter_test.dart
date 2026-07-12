import 'package:test/test.dart';

import '../../scripts/verification/released_consumer_adapter.dart';

void main() {
  test('released consumer uses one explicit git ref and public packages', () {
    final pubspec = buildReleasedConsumerPubspec(
      repoUrl: 'https://github.com/example/nexa_http.git',
      ref: 'v2.0.0',
      targetOS: 'macos',
    );

    expect(pubspec, contains('path: packages/nexa_http'));
    expect(pubspec, contains('path: packages/nexa_http_native_macos'));
    expect(RegExp(r'ref: v2\.0\.0').allMatches(pubspec), hasLength(2));
    expect(pubspec, isNot(contains('nexa_http_native_internal:')));
  });

  test('released consumer rejects placeholder refs', () {
    expect(
      () => buildReleasedConsumerPubspec(
        repoUrl: 'https://github.com/example/nexa_http.git',
        ref: 'vX.Y.Z',
        targetOS: 'macos',
      ),
      throwsStateError,
    );
  });
}
