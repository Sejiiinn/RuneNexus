import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/legacy_save_transfer_api.dart';
import 'package:rune_nexus/ui/account/legacy_save_transfer_dialog.dart';
import 'package:rune_nexus/ui/game/game_modal.dart';

void main() {
  testWidgets('기존 진행 이전 링크와 외부 브라우저 안내를 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showGameDialog<void>(
              context: context,
              builder: (_) => LegacySaveTransferDialog(
                createTransfer: () async => LegacySaveTransferDraft(
                  token: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
                  expiresAt: DateTime(2026, 8, 29, 3, 15),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('기존 진행 옮기기'), findsOneWidget);
    expect(find.textContaining('서버에 백업한 뒤'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('legacy-transfer-create')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('legacy-transfer-copy')), findsOneWidget);
    expect(find.byKey(const ValueKey('legacy-transfer-open')), findsOneWidget);
    expect(find.textContaining('#legacy-transfer='), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
