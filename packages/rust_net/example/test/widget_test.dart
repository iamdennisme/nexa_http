import 'package:flutter_test/flutter_test.dart';

import 'package:rust_net_example/main.dart';

void main() {
  testWidgets('renders HTTP and image performance demos',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RustNetExampleApp());
    await tester.pump();

    expect(find.text('rust_net Demo'), findsOneWidget);
    expect(find.text('HTTP test page'), findsOneWidget);
    expect(find.text('Image performance'), findsOneWidget);
    expect(find.text('Send GET'), findsOneWidget);
  });

  testWidgets('shows image performance controls after switching demos',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RustNetExampleApp());
    await tester.pump();

    await tester.tap(find.text('Image performance'));
    await tester.pumpAndSettle();

    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('rust_net'), findsOneWidget);
    expect(find.text('Run image test'), findsOneWidget);
    expect(find.text('Auto scroll'), findsOneWidget);
    expect(find.text('Clear caches'), findsOneWidget);
  });
}
