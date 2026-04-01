import 'package:nexa_http_distribution/nexa_http_distribution.dart';
import 'package:test/test.dart';

void main() {
  test('exports native artifact distribution helpers from its dedicated package', () {
    expect(resolveNexaHttpNativeArtifactFile, isA<Function>());
    expect(resolveNexaHttpNativeManifestUri, isA<Function>());
    expect(packageVersionForRoot, isA<Function>());
  });
}
