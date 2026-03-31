import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_http/nexa_http.dart';

import 'package:nexa_http_example/main.dart';

void main() {
  testWidgets('renders HTTP playground and benchmark demos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NexaHttpExampleApp());
    await tester.pump();

    expect(find.text('nexa_http Demo'), findsOneWidget);
    expect(find.text('HTTP Playground'), findsNWidgets(2));
    expect(find.text('Benchmark'), findsOneWidget);
    expect(find.text('Request Playground'), findsOneWidget);
    expect(find.text('Send Request'), findsOneWidget);
  });

  testWidgets('shows benchmark controls after switching demos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NexaHttpExampleApp());
    await tester.pump();

    await tester.tap(find.text('Benchmark'));
    await tester.pumpAndSettle();

    expect(find.text('Concurrent Benchmark'), findsOneWidget);
    expect(find.text('Scenario'), findsOneWidget);
    expect(find.text('Bytes'), findsOneWidget);
    expect(find.text('Image'), findsOneWidget);
    expect(find.text('Concurrency'), findsOneWidget);
    expect(find.text('Total Requests'), findsOneWidget);
    expect(find.text('Warmup Requests'), findsOneWidget);
    expect(find.text('Run Benchmark'), findsOneWidget);
    expect(find.text('nexa_http'), findsOneWidget);
    expect(find.text('Dart HttpClient'), findsOneWidget);
  });

  testWidgets('creates the lightweight client synchronously during build', (
    WidgetTester tester,
  ) async {
    var createClientCallCount = 0;

    await tester.pumpWidget(
      NexaHttpExampleApp(
        createClient: () {
          createClientCallCount += 1;
          return NexaHttpClient();
        },
      ),
    );

    expect(createClientCallCount, 1);
    expect(find.text('Transport initializes lazily on first request.'),
        findsOneWidget);
  });
}
