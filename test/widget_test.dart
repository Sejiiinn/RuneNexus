import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/app/rune_nexus_app.dart';
import 'package:rune_nexus/domain/combat/auto_start_mode.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
import 'package:rune_nexus/domain/combat/run_panel_tab.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/game/game_snapshot.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/ui/menu/result_overlay.dart';

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

  testWidgets('main menu keeps tabs on bottom and hides logo on upgrades', (
    tester,
  ) async {
    await tester.pumpWidget(const RuneNexusApp());
    await tester.pump();

    expect(find.text('Rune Nexus'), findsOneWidget);

    await tester.tap(find.text('영구 업그레이드'));
    await tester.pumpAndSettle();

    expect(find.text('Rune Nexus'), findsNothing);
    expect(find.text('시작 골드 Lv.0/20'), findsOneWidget);
    expect(find.text('현재 +0G'), findsAtLeastNWidgets(1));
    expect(find.text('다음 +5G'), findsOneWidget);
    expect(find.text('새 런을 시작할 때 보유하는 골드가 영구적으로 증가합니다.'), findsOneWidget);
    expect(find.text('웨이브를 클리어할 때마다 추가 골드를 받습니다.'), findsOneWidget);
    expect(find.text('레벨업'), findsNWidgets(4));
    expect(find.text('8'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('스테이지'), findsOneWidget);
    expect(find.text('영구 업그레이드'), findsOneWidget);

    await tester.tap(find.text('스테이지'));
    await tester.pumpAndSettle();

    expect(find.text('Rune Nexus'), findsOneWidget);
  });

  testWidgets('stage cards fit on narrow menu width', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const RuneNexusApp());
    await tester.pump();

    expect(find.text('스테이지 1 클리어 필요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permanent upgrade rows fit on narrow menu width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const RuneNexusApp());
    await tester.pump();

    await tester.tap(find.text('영구 업그레이드'));
    await tester.pumpAndSettle();

    expect(find.text('레벨업'), findsNWidgets(4));
    expect(find.text('25'), findsOneWidget);
    expect(find.text('웨이브를 클리어할 때마다 추가 골드를 받습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('result overlay exposes next stage and growth actions', (
    tester,
  ) async {
    int? startedStage;

    await tester.pumpWidget(
      MaterialApp(
        home: ResultOverlay(
          game: RuneNexusGame(),
          snapshot: _resultSnapshot(
            phase: GamePhase.success,
            currentStageNumber: 1,
            unlockedStageCount: 2,
            completedRounds: 50,
            runes: 140,
            lastRunRuneReward: 140,
            lastRunPreviousBestRound: 20,
            lastRunWasNewBestRound: true,
            lastRunUnlockedStageNumber: 2,
            bestRoundsByStage: const {1: 50},
            clearedStageNumbers: const {1},
          ),
          onOpenStageSelect: () {},
          onOpenPermanentUpgrades: () {},
          onStartStage: (stageNumber) {
            startedStage = stageNumber;
          },
        ),
      ),
    );

    expect(find.text('스테이지 2 신규 해금'), findsOneWidget);
    expect(find.text('신기록'), findsOneWidget);
    expect(find.text('20R → 50R'), findsOneWidget);
    expect(find.text('신규 해금'), findsOneWidget);
    expect(find.text('스테이지 2 시작'), findsOneWidget);
    expect(find.text('업그레이드'), findsOneWidget);
    expect(find.text('현재 스테이지 재도전'), findsOneWidget);

    await tester.tap(find.text('스테이지 2 시작'));

    expect(startedStage, 2);
  });

  testWidgets('failed result keeps stage selection and retry actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultOverlay(
          game: RuneNexusGame(),
          snapshot: _resultSnapshot(
            phase: GamePhase.failure,
            currentStageNumber: 1,
            completedRounds: 12,
            runes: 24,
            lastRunRuneReward: 24,
            bestRoundsByStage: const {1: 12},
          ),
          onOpenStageSelect: () {},
          onOpenPermanentUpgrades: () {},
          onStartStage: (_) {},
        ),
      ),
    );

    expect(find.text('기록 최고 12R'), findsOneWidget);
    expect(find.text('스테이지 2 시작'), findsNothing);
    expect(find.text('스테이지'), findsWidgets);
    expect(find.text('현재 스테이지 재도전'), findsOneWidget);
  });

  testWidgets('home button opens stage menu with end confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const RuneNexusApp());
    await tester.pump();

    await tester.tap(find.text('스테이지 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();

    expect(find.text('스테이지 메뉴'), findsOneWidget);
    expect(find.text('메인화면으로 이동'), findsOneWidget);
    expect(find.text('종료 시 보상'), findsOneWidget);
    expect(find.text('+1 룬'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('스테이지 종료'));
    await tester.pumpAndSettle();

    expect(find.text('정말 종료할까요?'), findsOneWidget);
    expect(find.textContaining('+1 룬'), findsOneWidget);
  });

  testWidgets('debug panel button is hidden by default', (tester) async {
    await tester.pumpWidget(const RuneNexusApp());
    await tester.pump();

    await tester.tap(find.text('스테이지 1'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.diamond_outlined), findsNothing);
    expect(find.text('테스트 라운드'), findsNothing);
  });
}

GameSnapshot _resultSnapshot({
  required GamePhase phase,
  required int currentStageNumber,
  int unlockedStageCount = 1,
  int completedRounds = 0,
  int runes = 0,
  int lastRunRuneReward = 0,
  int lastRunPreviousBestRound = 0,
  bool lastRunWasNewBestRound = false,
  int? lastRunUnlockedStageNumber,
  Map<int, int> bestRoundsByStage = const {},
  Set<int> clearedStageNumbers = const {},
}) {
  return GameSnapshot(
    gold: 0,
    nexusHp: 0,
    maxNexusHp: 20,
    round: completedRounds,
    maxRound: 50,
    phase: phase,
    restoredPhase: null,
    hasStageProgress: false,
    placedTurretCount: 0,
    currentStageNumber: currentStageNumber,
    unlockedStageCount: unlockedStageCount,
    bestRoundsByStage: bestRoundsByStage,
    clearedStageNumbers: clearedStageNumbers,
    selectedTurretType: TurretType.arrow,
    selectedRunPanelTab: RunPanelTab.turrets,
    previewText: '',
    rewardOptions: const [],
    gemInventory: const {},
    selectedBuildPoint: null,
    selectedBuildTurretType: null,
    selectedPortalPoint: null,
    selectedTurretPoint: null,
    selectedTurretName: null,
    selectedTurretGems: const [],
    selectedTurretGemSlotIndex: null,
    selectedTurretSlotLimit: 0,
    selectedTurretHasLinkUpgrade: false,
    selectedTurretCanUpgradeLink: false,
    selectedTurretLinkUpgradeCost: 0,
    selectedTurretNextSlotLimit: 0,
    selectedTurretLinkUpgradeRequiredLevel: 0,
    selectedTurretLevel: 0,
    selectedTurretMaxLevel: 0,
    selectedTurretCanLevelUp: false,
    selectedTurretLevelUpCost: 0,
    selectedTurretRefundGold: 0,
    selectedTurretDamage: 0,
    selectedTurretRange: 0,
    selectedTurretAttackRate: 0,
    selectedTurretBurnDamagePerSecond: 0,
    selectedTurretBurnDuration: 0,
    selectedTurretDamageDealt: 0,
    selectedTurretDirectDamageDealt: 0,
    selectedTurretSplashDamageDealt: 0,
    selectedTurretChainDamageDealt: 0,
    selectedTurretBurnDamageDealt: 0,
    topDamageTurretName: null,
    topDamageTurretDamageDealt: 0,
    nextWaveEnemyTypes: const [],
    nextWaveEnemyCounts: const {},
    autoStartMode: AutoStartMode.pauseEachRound,
    speedMultiplier: 1,
    killGoldFractionWallet: 0,
    runUpgradeLevels: const {},
    towerDamageRunBonusRate: 0,
    killGoldRunBonusRate: 0,
    waveClearGoldRunBonus: 0,
    runes: runes,
    lastRunRuneReward: lastRunRuneReward,
    projectedFailureRuneReward: completedRounds * 2,
    lastRunPreviousBestRound: lastRunPreviousBestRound,
    lastRunWasNewBestRound: lastRunWasNewBestRound,
    lastRunUnlockedStageNumber: lastRunUnlockedStageNumber,
    completedRounds: completedRounds,
    startingGoldUpgradeLevel: 0,
    startingGoldUpgradeCost: 8,
    canUpgradeStartingGold: false,
    nexusHpUpgradeLevel: 0,
    nexusHpUpgradeCost: 25,
    canUpgradeNexusHp: false,
    supplyUpgradeLevel: 0,
    supplyUpgradeCost: 12,
    canUpgradeSupply: false,
    waveClearGoldProgressionBonus: 0,
    fireTrainingUpgradeLevel: 0,
    fireTrainingUpgradeCost: 18,
    canUpgradeFireTraining: false,
    fireTrainingDamageBonusRate: 0,
  );
}
