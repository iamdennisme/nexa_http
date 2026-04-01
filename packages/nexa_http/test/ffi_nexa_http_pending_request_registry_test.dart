import 'package:nexa_http/src/data/sources/ffi_nexa_http_pending_request_registry.dart';
import 'package:nexa_http/src/internal/transport/transport_response.dart';
import 'package:test/test.dart';

void main() {
  test('tracks pending requests and closes after dispose when drained', () async {
    var closeCount = 0;
    final registry = FfiNexaHttpPendingRequestRegistry(
      onDrainedAfterDispose: () {
        closeCount += 1;
      },
    );

    final firstId = registry.nextRequestId();
    final completer = registry.register(firstId);

    expect(registry.take(firstId), same(completer));
    expect(registry.take(firstId), isNull);

    registry.register(firstId);
    registry.dispose();
    expect(closeCount, 0);

    final pending = registry.take(firstId);
    pending!.complete(const TransportResponse(statusCode: 204));
    registry.didCompletePendingRequest();

    expect(closeCount, 1);
    registry.dispose();
    expect(closeCount, 1);
  });
}
