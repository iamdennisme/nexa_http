import 'package:flutter_test/flutter_test.dart';

import 'package:rust_net_example/main.dart';

void main() {
  testWidgets('renders the request test page', (WidgetTester tester) async {
    await tester.pumpWidget(const RustNetExampleApp());
    await tester.pump();

    expect(find.text('rust_net Demo'), findsOneWidget);
    expect(find.text('HTTP test page'), findsOneWidget);
    expect(find.text('Send GET'), findsOneWidget);
  });
}
