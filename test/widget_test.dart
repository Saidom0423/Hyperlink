import 'package:flutter_test/flutter_test.dart';
import 'package:hyperlink/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HyperlinkApp());
  });
}