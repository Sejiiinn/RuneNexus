import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/app/rune_nexus_app.dart';

void main() {
  testWidgets('Rune Nexus app renders HUD', (tester) async {
    await tester.pumpWidget(const RuneNexusApp());
    await tester.pump();

    expect(find.text('골드'), findsOneWidget);
    expect(find.text('Nexus'), findsOneWidget);
    expect(find.text('라운드'), findsOneWidget);
  });
}
