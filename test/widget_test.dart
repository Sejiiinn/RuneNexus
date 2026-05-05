import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/app/rune_nexus_app.dart';

void main() {
  testWidgets('Rune Nexus app renders main menu', (tester) async {
    await tester.pumpWidget(const RuneNexusApp());
    await tester.pump();

    expect(find.text('Rune Nexus'), findsOneWidget);
    expect(find.text('스테이지'), findsOneWidget);
    expect(find.text('스테이지 1'), findsOneWidget);
    expect(find.text('스테이지 5'), findsOneWidget);
    expect(find.text('잠김'), findsNWidgets(4));
    expect(find.text('영구 업그레이드'), findsOneWidget);
  });
}
