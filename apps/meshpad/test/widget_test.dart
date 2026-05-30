import 'package:flutter_test/flutter_test.dart';
import 'package:meshpad/app.dart';

void main() {
  testWidgets('app shell renders title', (tester) async {
    await tester.pumpWidget(const MeshPadApp());
    expect(find.text('MeshPad'), findsOneWidget);
  });
}
