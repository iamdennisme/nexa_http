import 'package:flutter_test/flutter_test.dart';

import 'package:nexa_http_dio_consumer/main.dart';

void main() {
  testWidgets('renders the Dio consumer shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const NexaHttpDioConsumerApp(autoInitialize: false),
    );

    expect(find.text('nexa_http Dio Consumer'), findsOneWidget);
    expect(find.text('GET'), findsOneWidget);
    expect(find.text('POST'), findsOneWidget);
    expect(find.text('404'), findsOneWidget);
    expect(find.text('Timeout'), findsOneWidget);
  });
}
