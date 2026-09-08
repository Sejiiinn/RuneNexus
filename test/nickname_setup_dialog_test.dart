import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/domain/account/account_profile.dart';
import 'package:rune_nexus/ui/account/nickname_setup_dialog.dart';
import 'package:rune_nexus/ui/game/game_modal.dart';

void main() {
  testWidgets(
    'nickname is mandatory, preserves failed input and prevents duplicate submission',
    (tester) async {
      final pending = Completer<AccountProfile>();
      var calls = 0;
      AccountProfile? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showGameDialog<AccountProfile>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => NicknameSetupDialog(
                    save: (nickname) async {
                      calls++;
                      expect(nickname, '룬기사');
                      if (calls == 1) throw StateError('offline');
                      return pending.future;
                    },
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(NicknameSetupDialog), findsOneWidget);
      await tester.tap(find.text('저장하고 시작하기'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      for (final nickname in ['xxAdMiN99', '룬운영자']) {
        await tester.enterText(find.byType(TextField), nickname);
        await tester.tap(find.text('저장하고 시작하기'));
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(find.textContaining('길이를 확인하고'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          nickname,
        );
      }
      await tester.enterText(find.byType(TextField), ' 룬기사 ');
      await tester.tap(find.text('저장하고 시작하기'));
      await tester.pumpAndSettle();
      expect(find.text('닉네임을 저장하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        ' 룬기사 ',
      );
      await tester.tap(find.text('저장하고 시작하기'));
      await tester.pump();
      await tester.tap(find.text('저장 중...'));
      await tester.tap(find.text('로그아웃'));
      await tester.pump();
      expect(calls, 2);
      expect(find.byType(NicknameSetupDialog), findsOneWidget);
      pending.complete(
        const AccountProfile(accountId: 'a', nickname: '룬기사', tag: '0038'),
      );
      await tester.pumpAndSettle();
      expect(result?.displayName, '룬기사#0038');
      expect(find.byType(NicknameSetupDialog), findsNothing);
    },
  );

  testWidgets('small keyboard viewport scrolls and explicit logout exits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.reset);
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showGameDialog<AccountProfile>(
                context: context,
                barrierDismissible: false,
                builder: (_) => NicknameSetupDialog(
                  save: (_) async => throw StateError('unused'),
                ),
              );
              expect(result, isNull);
              completed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
