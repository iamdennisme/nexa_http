import 'package:flutter_test/flutter_test.dart';
import 'package:rust_net/src/data/mappers/native_http_request_mapper.dart';
import 'package:rust_net_core/rust_net_core.dart';

void main() {
  test('keeps request body as raw bytes and excludes it from request json', () {
    final dto = NativeHttpRequestMapper.toDto(
      clientConfig: const RustNetClientConfig(),
      request: RustNetRequest(
        method: RustNetMethod.post,
        uri: Uri.parse('https://example.com/upload'),
        bodyBytes: <int>[1, 2, 3, 4],
      ),
    );

    expect(dto.bodyBytes, const <int>[1, 2, 3, 4]);
    expect(dto.toJson().containsKey('body_base64'), isFalse);
  });
}
