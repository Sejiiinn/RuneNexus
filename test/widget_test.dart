import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/app/rune_nexus_app.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
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

    expect(find.text('스테이지 2 이용 가능'), findsOneWidget);
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
}

GameSnapshot _resultSnapshot({
  required GamePhase phase,
  required int currentStageNumber,
  int unlockedStageCount = 1,
  int completedRounds = 0,
  int runes = 0,
  int lastRunRuneReward = 0,
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
    previewText: '',
    rewardOptions: const [],
    gemInventory: const {},
    selectedBuildPoint: null,
    selectedBuildTurretType: null,
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
    selectedTurretDamage: 0,
    selectedTurretRange: 0,
    selectedTurretAttackRate: 0,
    selectedTurretBurnDamagePerSecond: 0,
    selectedTurretBurnDuration: 0,
    nextWaveEnemyTypes: const [],
    speedMultiplier: 1,
    runes: runes,
    lastRunRuneReward: lastRunRuneReward,
    completedRounds: completedRounds,
    startingGoldUpgradeLevel: 0,
    startingGoldUpgradeCost: 8,
    canUpgradeStartingGold: false,
    nexusHpUpgradeLevel: 0,
    nexusHpUpgradeCost: 6,
    canUpgradeNexusHp: false,
  );
}
