import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_http/nexa_http.dart';
import 'package:nexa_http/src/data/dto/native_http_client_config_dto.dart';
import 'package:nexa_http/src/data/dto/native_http_request_dto.dart';
import 'package:nexa_http/src/data/sources/nexa_http_native_data_source.dart';

import 'package:nexa_http_example/main.dart';

void main() {
  testWidgets('renders HTTP and image performance demos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NexaHttpExampleApp());
    await tester.pump();

    expect(find.text('nexa_http Demo'), findsOneWidget);
    expect(find.text('HTTP test page'), findsOneWidget);
    expect(find.text('Image performance'), findsOneWidget);
    expect(find.text('Send GET'), findsOneWidget);
  });

  testWidgets('shows image performance controls after switching demos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NexaHttpExampleApp());
    await tester.pump();

    await tester.tap(find.text('Image performance'));
    await tester.pumpAndSettle();

    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('nexa_http'), findsOneWidget);
    expect(find.text('Metrics'), findsOneWidget);
    expect(find.text('Preview Grid'), findsOneWidget);
    expect(find.text('Run image test'), findsOneWidget);
    expect(find.text('Auto scroll'), findsOneWidget);
    expect(find.text('Clear caches'), findsOneWidget);
  });

  testWidgets('defers native client initialization until after first frame', (
    WidgetTester tester,
  ) async {
    var createClientCallCount = 0;

    await tester.pumpWidget(
      NexaHttpExampleApp(
        createClient: () {
          createClientCallCount += 1;
          return NexaHttpClient(dataSource: _FakeNexaHttpNativeDataSource());
        },
      ),
    );

    expect(createClientCallCount, 0);
    expect(find.text('Initializing native runtime...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));

    expect(createClientCallCount, 1);
  });
}

final class _FakeNexaHttpNativeDataSource implements NexaHttpNativeDataSource {
  @override
  void closeClient(int clientId) {}

  @override
  int createClient(NativeHttpClientConfigDto config) => 1;

  @override
  Future<NexaHttpResponse> execute(int clientId, NativeHttpRequestDto request) {
    throw UnimplementedError();
  }
}
