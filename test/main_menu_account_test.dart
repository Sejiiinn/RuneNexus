import 'package:rune_nexus/ui/game/game_image_assets.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  testWidgets('게스트 계정 화면에서 연결 수단을 선택할 수 있다', (tester) async {
    var playGamesConnectCount = 0;
    var googleConnectCount = 0;

    await _pumpAccountMenu(
      tester,
      session: const AccountSession.guest(),
      onConnectPlayGames: () => playGamesConnectCount += 1,
      onConnectGoogle: () => googleConnectCount += 1,
    );

    expect(
      find.byKey(const ValueKey('main-menu-account-button')),
      findsOneWidget,
    );

    await _openAccountDialog(tester);

    expect(find.text('게스트로 플레이 중'), findsOneWidget);
    expect(find.text('진행 상황이 현재 기기에만 저장됩니다.'), findsOneWidget);
    expect(find.text('Play Games로 연결'), findsOneWidget);
    expect(find.text('Google 계정으로 연결'), findsOneWidget);
    expect(find.text('계정을 연결해도 현재 진행을 확인 없이 덮어쓰지 않습니다.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('account-connect-google-button')),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(googleConnectCount, 1);
    expect(playGamesConnectCount, 0);
    expect(find.text('계정 및 저장'), findsNothing);

    await _openAccountDialog(tester);
    await tester.tap(
      find.byKey(const ValueKey('account-connect-playGames-button')),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(playGamesConnectCount, 1);
  });

  testWidgets('연결된 계정 화면에 identity와 동기화 상태를 표시한다', (tester) async {
    var syncCount = 0;
    var signOutCount = 0;
    final session = AccountSession.authenticated(
      accountId: '0198a3dc-71e0-7eb2-a2bc-b67ce264a311',
      identities: const [
        AccountIdentity(
          provider: AccountIdentityProvider.playGames,
          displayName: 'NexusPlayer',
        ),
        AccountIdentity(
          provider: AccountIdentityProvider.google,
          displayName: 'se***@gmail.com',
        ),
      ],
      syncStatus: OnlineSaveSyncStatus.offline,
      lastSyncedAt: DateTime(2026, 8, 18, 14, 32),
      pendingSaveCount: 2,
    );

    await _pumpAccountMenu(
      tester,
      session: session,
      onSyncAccount: () => syncCount += 1,
      onSignOut: () => signOutCount += 1,
    );
    await _openAccountDialog(tester);

    expect(find.text('온라인 계정 연결됨'), findsOneWidget);
    expect(find.text('NexusPlayer'), findsOneWidget);
    expect(find.text('se***@gmail.com'), findsOneWidget);
    expect(find.text('연결됨'), findsNWidgets(2));
    expect(find.text('클라우드 저장'), findsOneWidget);
    expect(find.text('마지막 동기화 2026.08.18 14:32'), findsOneWidget);
    expect(find.text('저장 2건 전송 대기'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-sync-now')));
    await pumpGameFrames(tester);

    expect(syncCount, 1);
    expect(signOutCount, 0);

    await _openAccountDialog(tester);
    await tester.tap(find.byKey(const ValueKey('account-sign-out')));
    await pumpGameFrames(tester);

    expect(find.text('이 계정에서 로그아웃할까요?'), findsOneWidget);
    expect(find.text('계정 진행 데이터는 이 기기의 별도 저장 공간에 그대로 보관됩니다.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-sign-out-confirm')));
    await pumpGameFrames(tester);

    expect(signOutCount, 1);
  });

  testWidgets('게스트에게 기존 카카오 브라우저 진행 이전 진입점을 표시한다', (tester) async {
    var transferCount = 0;
    await _pumpAccountMenu(
      tester,
      session: const AccountSession.guest(),
      onCreateLegacyTransfer: () => transferCount += 1,
    );

    await _openAccountDialog(tester);

    expect(find.byKey(const ValueKey('legacy-transfer-card')), findsOneWidget);
    expect(find.text('카카오 브라우저 진행 옮기기'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('legacy-transfer-start')));
    await pumpGameFrames(tester);
    expect(transferCount, 1);
  });

  testWidgets('좁은 화면에서도 계정 버튼이 로고와 겹치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpAccountMenu(tester, session: const AccountSession.guest());

    final accountRect = tester.getRect(
      find.byKey(const ValueKey('main-menu-account-button')),
    );
    final questRect = tester.getRect(
      find.byKey(const ValueKey('daily-quest-entry-button')),
    );
    final logoRect = tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == gameLogoAsset,
      ),
    );

    expect(accountRect.overlaps(questRect), isFalse);
    expect(accountRect.overlaps(logoRect), isFalse);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpAccountMenu(
  WidgetTester tester, {
  required AccountSession session,
  VoidCallback? onConnectPlayGames,
  VoidCallback? onConnectGoogle,
  VoidCallback? onCreateLegacyTransfer,
  VoidCallback? onSyncAccount,
  VoidCallback? onSignOut,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: const [
        RuneNexusLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: RuneNexusLocalizations.supportedLocales,
      home: MainMenuScreen(
        game: RuneNexusGame(),
        snapshot: resultSnapshot(
          phase: GamePhase.preparation,
          currentStageNumber: 1,
        ),
        selectedTab: MainMenuTab.stage,
        onSelectTab: (_) {},
        onStartStage: (_) {},
        accountSession: session,
        onConnectPlayGames: onConnectPlayGames,
        onConnectGoogle: onConnectGoogle,
        onCreateLegacyTransfer: onCreateLegacyTransfer,
        onSyncAccount: onSyncAccount,
        onSignOut: onSignOut,
      ),
    ),
  );
  await pumpGameFrames(tester);
}

Future<void> _openAccountDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('main-menu-account-button')));
  await tester.pump(const Duration(milliseconds: 250));
}
