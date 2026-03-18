import 'package:flutter_test/flutter_test.dart';

import 'package:rust_net_dio_consumer/main.dart';

void main() {
  testWidgets('renders the Dio consumer shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const RustNetDioConsumerApp(autoInitialize: false),
    );

    expect(find.text('rust_net Dio Consumer'), findsOneWidget);
    expect(find.text('GET'), findsOneWidget);
    expect(find.text('POST'), findsOneWidget);
    expect(find.text('404'), findsOneWidget);
    expect(find.text('Timeout'), findsOneWidget);
  });
}
