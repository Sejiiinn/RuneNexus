import 'helpers/widget_test_helpers.dart';

void main() {
  testWidgets('gem reward choices stay in one row on narrow combat width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    final snapshot = resultSnapshot(
      phase: GamePhase.reward,
      currentStageNumber: 1,
      completedRounds: 1,
      gemShards: 12,
      rewardOptions: const [
        GemType.chain,
        GemType.heavyWeapon,
        GemType.attackSpeed,
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF07111D),
          body: HudRewardOverlay(game: game, snapshot: snapshot),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chainTop = tester.getTopLeft(find.text('연쇄')).dy;
    final heavyTop = tester.getTopLeft(find.text('중화기 증폭')).dy;
    final speedTop = tester.getTopLeft(find.text('가속')).dy;
    expect(heavyTop, closeTo(chainTop, 0.1));
    expect(speedTop, closeTo(chainTop, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('combat HUD shows total turret DPS under the home button', (
    tester,
  ) async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF07111D),
          body: GameHud(game: game),
        ),
      ),
    );
    await pumpGameFrames(tester, frameCount: 10);

    expect(find.byTooltip('배치 포탑 전체 DPS'), findsOneWidget);
    expect(find.text('전투력'), findsOneWidget);

    game.tryBuildTurret(const GridPoint(2, 0));
    await pumpGameFrames(tester);

    expect(game.snapshotNotifier.value.totalTurretDps, closeTo(15.89, 0.001));
    expect(find.text('15.9'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('core tile selection shows combat skill contribution in HUD', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF07111D),
          body: GameHud(game: game),
        ),
      ),
    );
    await pumpGameFrames(tester, frameCount: 10);
    game.debugSetClearedStageCount(5);
    expect(game.equipCoreCombatSkill(CoreCombatSkill.riftMark), isTrue);
    game.restartRun();
    await pumpGameFrames(tester);

    await tester.tapAt(const Offset(305, 474));
    await pumpGameFrames(tester);

    expect(
      game.snapshotNotifier.value.selectedCorePoint,
      const GridPoint(6, 9),
    );
    expect(
      game.snapshotNotifier.value.selectedRunPanelTab,
      RunPanelTab.turrets,
    );
    expect(find.text('넥서스 코어'), findsOneWidget);
    expect(find.text('내구도'), findsOneWidget);
    expect(find.text('전투 스킬'), findsOneWidget);
    expect(find.text('균열 낙인'), findsOneWidget);
    expect(find.text('내구도 높은 적 4명에게 받는 피해 25% 증가 낙인 부여'), findsOneWidget);
    expect(find.text('코어'), findsNothing);
    expect(find.text('패시브 트리'), findsOneWidget);
    expect(find.text('0 / 0pt'), findsOneWidget);
    expect(find.text('다음 효과 +25%'), findsOneWidget);
    expect(find.text('총 추가 피해 0.00'), findsOneWidget);
    expect(find.text('발동 0회'), findsNothing);
    expect(find.text('포탈 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selected turret panel gates target priority selector by research',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF07111D),
            body: GameHud(game: game),
          ),
        ),
      );
      await pumpGameFrames(tester, frameCount: 10);
      game.tryBuildTurret(const GridPoint(2, 0));
      await pumpGameFrames(tester);

      expect(find.text('공격 명령'), findsNothing);
      expect(find.text('선두 적'), findsNothing);
      expect(tester.takeException(), isNull);

      final unlockedRepository = MemorySaveRepository()
        ..data = saveWithResearch(
          clearedStageNumbers: const {3},
          researchLevels: const {ResearchType.turretTargetPriority: 1},
        );
      final unlockedGame = RuneNexusGame(saveRepository: unlockedRepository);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF07111D),
            body: GameHud(game: unlockedGame),
          ),
        ),
      );
      await pumpGameFrames(tester, frameCount: 10);
      unlockedGame.tryBuildTurret(const GridPoint(2, 0));
      await pumpGameFrames(tester);

      expect(find.text('공격 명령'), findsOneWidget);
      expect(find.text('선두 적'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('turret-target-priority-selector')),
      );
      await pumpGameFrames(tester);

      expect(find.text('후방 적'), findsOneWidget);
      expect(find.text('강한 적'), findsOneWidget);
      expect(find.text('약한 적'), findsOneWidget);
      expect(find.text('가까운 적'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await pumpGameFrames(tester);
      expect(
        find.byKey(const ValueKey('turret-target-priority-selector')),
        findsOneWidget,
      );
      await tester.tap(find.text('젬 · 링크'));
      await pumpGameFrames(tester);

      expect(
        find.byKey(const ValueKey('turret-target-priority-selector')),
        findsNothing,
      );
      expect(find.text('공격 명령'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('trait dialog uses compact tier panel on narrow combat width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF07111D),
          body: GameHud(game: game),
        ),
      ),
    );
    await pumpGameFrames(tester, frameCount: 10);
    game.debugAddGold(1000);
    game.tryBuildTurret(const GridPoint(2, 0));
    for (
      var level = game.snapshotNotifier.value.selectedTurretLevel;
      level < 3;
      level++
    ) {
      game.levelUpSelectedTurret();
    }
    expect(game.snapshotNotifier.value.selectedTurretLevel, 3);
    await pumpGameFrames(tester);

    await tester.tap(find.byTooltip('특성'));
    await pumpGameFrames(tester);

    expect(find.text('기관총 특성'), findsOneWidget);
    expect(find.text('무기 개조'), findsNWidgets(2));
    expect(find.text('전투 교리'), findsOneWidget);
    expect(find.text('과열 탄창'), findsOneWidget);
    expect(find.text('경량 총열'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('전투 교리'));
    await pumpGameFrames(tester);

    expect(find.text('제압 사격'), findsOneWidget);
    expect(find.text('연쇄 소탕'), findsOneWidget);
    expect(find.text('1차 특성 선택 후 후보 카드가 열립니다.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trait dialog previews first tap and confirms second tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {},
        researchLevels: const {},
        gold: 1000,
        gemShards: RuneNexusGame.primaryTraitCost,
        roundIndex: 1,
        mapSignature: const GameSaveAdapter().mapSignature(gameMap),
      );
    final game = RuneNexusGame(saveRepository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF07111D),
          body: GameHud(game: game),
        ),
      ),
    );
    await pumpGameFrames(tester, frameCount: 10);
    game.tryBuildTurret(const GridPoint(2, 0));
    for (
      var level = game.snapshotNotifier.value.selectedTurretLevel;
      level < 3;
      level++
    ) {
      game.levelUpSelectedTurret();
    }
    expect(game.snapshotNotifier.value.selectedTurretLevel, 3);
    await pumpGameFrames(tester);

    await tester.tap(find.byTooltip('특성'));
    await pumpGameFrames(tester);
    await tester.tap(find.text('과열 탄창'));
    await pumpGameFrames(tester);

    expect(find.text('선택'), findsOneWidget);
    expect(find.text('기관총 특성'), findsOneWidget);
    expect(game.snapshotNotifier.value.selectedTurretPrimaryTrait, isNull);
    expect(
      game.snapshotNotifier.value.gemShards,
      RuneNexusGame.primaryTraitCost,
    );

    await tester.tap(find.text('과열 탄창'));
    await pumpGameFrames(tester);

    expect(
      game.snapshotNotifier.value.selectedTurretPrimaryTrait,
      TurretTraitType.overheatMagazine,
    );
    expect(game.snapshotNotifier.value.gemShards, 0);
  });
}
