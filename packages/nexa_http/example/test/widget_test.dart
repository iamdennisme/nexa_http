import 'package:flutter_test/flutter_test.dart';

import 'package:nexa_http_example/main.dart';

void main() {
  testWidgets('renders HTTP and image performance demos',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NexaHttpExampleApp());
    await tester.pump();

    expect(find.text('nexa_http Demo'), findsOneWidget);
    expect(find.text('HTTP test page'), findsOneWidget);
    expect(find.text('Image performance'), findsOneWidget);
    expect(find.text('Send GET'), findsOneWidget);
  });

  testWidgets('shows image performance controls after switching demos',
      (WidgetTester tester) async {
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
}
