import 'helpers/widget_test_helpers.dart';

void main() {
  testWidgets('home button opens stage menu with end confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 854);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpLoadedApp(tester);

    await tapStageCard(tester, '스테이지 1');
    await pumpUntilFound(tester, find.text('시작하기'));
    await tester.tap(find.text('시작하기'));
    await pumpUntilFound(tester, find.text('시작'));
    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await pumpGameFrames(tester);

    expect(find.text('스테이지 메뉴'), findsOneWidget);
    expect(find.text('메인화면으로 이동'), findsOneWidget);
    expect(find.text('종료 시 보상'), findsNothing);
    expect(find.text('+0 룬'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('스테이지 종료'));
    await pumpGameFrames(tester);

    expect(find.text('정말 종료할까요?'), findsOneWidget);
    expect(find.text('종료 시 보상'), findsOneWidget);
    expect(find.text('0웨이브 기준'), findsOneWidget);
    expect(find.textContaining('+0 룬'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(RuneCurrencyIcon),
      ),
      findsWidgets,
    );
  });

  testWidgets('main menu return preserves active run as restore flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpLoadedApp(tester);

    await tapStageCard(tester, '스테이지 1');
    await pumpUntilFound(tester, find.text('시작하기'));
    await tester.tap(find.text('시작하기'));
    await pumpUntilFound(tester, find.text('시작'));
    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await pumpGameFrames(tester);
    await tester.tap(find.text('메인화면으로 이동'));
    await pumpGameFrames(tester);

    expect(find.text('진행 중 · 스테이지 1'), findsNothing);
    expect(find.text('진행 중'), findsWidgets);
    expect(find.text('스테이지 1'), findsWidgets);
    expect(find.text('저장된 전투'), findsNothing);
    expect(find.text('이어서 진행'), findsOneWidget);

    await tester.tap(find.text('이어서 진행'));
    await pumpGameFrames(tester);

    expect(find.text('저장된 진행 발견'), findsOneWidget);
    expect(find.text('이전 진행을 이어갈까요?'), findsOneWidget);
    expect(find.text('새로 시작'), findsNothing);
    expect(find.text('메인 메뉴'), findsOneWidget);
    expect(find.text('재개'), findsOneWidget);

    await tester.tap(find.text('메인 메뉴'));
    await pumpGameFrames(tester);

    expect(find.text('저장된 진행 발견'), findsNothing);
    expect(find.text('저장된 전투'), findsNothing);
    expect(find.text('이어서 진행'), findsOneWidget);
  });

  testWidgets('active run can settle and switch to another stage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    game.debugSetClearedStageCount(1);

    await tester.pumpWidget(RuneNexusApp(game: game));
    await pumpUntilFound(tester, find.text('Rune Nexus'));

    await tapStageCard(tester, '스테이지 1');
    await pumpUntilFound(tester, find.text('시작하기'));
    await tester.tap(find.text('시작하기'));
    await pumpUntilFound(tester, find.text('시작'));
    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await pumpGameFrames(tester);
    await tester.tap(find.text('메인화면으로 이동'));
    await pumpGameFrames(tester);

    await tester.tap(find.byKey(const ValueKey('stage-selection-row-2')));
    await pumpGameFrames(tester);
    await tester.tap(find.text('시작하기'));
    await pumpGameFrames(tester);

    expect(find.text('진행 중인 스테이지 종료'), findsOneWidget);
    expect(find.text('현재 보상 0룬 정산 후 스테이지 2 시작'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(RuneCurrencyIcon),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('정산 후 시작'));
    await pumpGameFrames(tester);

    expect(game.snapshotNotifier.value.currentStageNumber, 2);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

  testWidgets(
    'main menu return before first wave does not create restore flow',
    (tester) async {
      tester.view.physicalSize = const Size(411, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());

      await tester.pumpWidget(RuneNexusApp(game: game));
      await pumpUntilFound(tester, find.text('Rune Nexus'));

      await tapStageCard(tester, '스테이지 1');
      await pumpGameFrames(tester);
      await tester.tap(find.text('시작하기'));
      await pumpGameFrames(tester);
      expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
      expect(game.snapshotNotifier.value.hasStageProgress, isFalse);

      await tester.tap(find.byIcon(Icons.home_outlined));
      await pumpGameFrames(tester);
      await tester.tap(find.text('메인화면으로 이동'));
      await pumpGameFrames(tester);

      expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
      expect(game.snapshotNotifier.value.hasStageProgress, isFalse);
      expect(find.text('진행 중'), findsNothing);
      expect(find.text('저장된 전투'), findsNothing);
      expect(find.text('이어서 진행'), findsNothing);
      expect(find.text('스테이지 1'), findsWidgets);
    },
  );

  testWidgets('debug panel button is hidden by default', (tester) async {
    await pumpLoadedApp(tester);

    await tapStageCard(tester, '스테이지 1');
    await pumpGameFrames(tester);

    expect(find.text('테스트 라운드'), findsNothing);
  });
}
