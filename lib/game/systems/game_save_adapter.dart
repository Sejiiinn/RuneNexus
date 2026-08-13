import 'dart:math' as math;

import '../../data/save/game_save_data.dart';
import '../../domain/combat/auto_start_mode.dart';
import '../../domain/combat/game_phase.dart';
import '../../domain/core/core_ability.dart';
import '../../domain/gem/gem_type.dart';
import '../../domain/map/map_definition.dart';
import '../../domain/run_upgrade/run_upgrade_type.dart';
import '../../domain/turret/turret_type.dart';
import 'run_progression.dart';

class GameSaveAdapter {
  const GameSaveAdapter();

  GameSaveData buildSaveData(GameSaveBuildState state) {
    // 파괴 연출은 런타임 전용이며 저장 시 확정된 패배로 기록한다.
    final savedPhase = switch (state.run.phase) {
      GamePhase.coreDestruction => GamePhase.failure,
      GamePhase.restored => state.run.restoredPhase ?? GamePhase.preparation,
      _ => state.run.phase,
    };
    final pendingSave = !state.savedDataLoaded
        ? state.pendingFullSaveData
        : null;
    final pendingRun = pendingSave?.activeRun;
    final run = SavedRunState(
      gold: state.run.gold,
      gemShards: state.run.gemShards,
      nexusHp: state.run.nexusHp,
      stageNumber: state.selectedStageNumber,
      mapSignature: pendingRun != null
          ? pendingRun.mapSignature
          : mapSignature(state.run.map),
      roundIndex: state.run.roundIndex,
      completedRounds: state.run.completedRounds,
      phase: savedPhase,
      runUpgradeLevels: Map.unmodifiable(state.run.runUpgradeLevels),
      killGoldFractionWallet: state.run.killGoldFractionWallet,
      gemInventory: Map.unmodifiable(state.run.gemInventory),
      rewardOptions: List.unmodifiable(state.run.rewardOptions),
      isPurchasedGemReward: state.run.isPurchasedGemReward,
      rewardReturnPhase: state.run.rewardReturnPhase,
      runCoreCombatSkill: pendingRun != null
          ? pendingRun.runCoreCombatSkill
          : state.run.runCoreCombatSkill,
      runCoreCombatSkillStats: pendingRun != null
          ? pendingRun.runCoreCombatSkillStats
          : state.run.runCoreCombatSkillStats,
      roundNexusHpLost: pendingRun != null
          ? pendingRun.roundNexusHpLost
          : state.run.roundNexusHpLost,
      emergencyChargeUsedThisRound: pendingRun != null
          ? pendingRun.emergencyChargeUsedThisRound
          : state.run.emergencyChargeUsedThisRound,
      finalDefenseUsedThisRound: pendingRun != null
          ? pendingRun.finalDefenseUsedThisRound
          : state.run.finalDefenseUsedThisRound,
      turrets: pendingRun?.turrets ?? state.run.turrets,
      enemies: pendingRun?.enemies ?? state.run.enemies,
      spawnQueue: pendingRun?.spawnQueue ?? state.run.spawnQueue,
    );

    return GameSaveData(
      savedAtMillis: state.savedAtMillis,
      preferences: SavedPreferences(
        selectedStageNumber: state.selectedStageNumber,
        autoStartMode: state.autoStartMode,
      ),
      progression: state.progression.toSaveData(),
      turretModules: state.progression.toTurretModuleSaveData(),
      activeRun: run.hasProgress ? run : null,
    );
  }

  bool hasSavedRunMapMismatch(SavedRunState data, MapDefinition map) {
    if (data.mapSignature != mapSignature(map)) {
      return true;
    }
    for (final savedTurret in data.turrets) {
      if (!map.canBuildAt(savedTurret.point)) {
        return true;
      }
    }
    return false;
  }

  SavedMapChangeRefund refundSavedTurretsForMapChange({
    required List<SavedTurret> savedTurrets,
    required int? Function(TurretType type) baseCostFor,
    required int primaryTraitCost,
    required int secondaryTraitCost,
    required double firstLinkUpgradeDiscountRate,
  }) {
    var gold = 0;
    var gemShards = 0;
    final gems = <GemType, int>{};

    for (final savedTurret in savedTurrets) {
      final baseCost = baseCostFor(savedTurret.type);
      if (baseCost != null) {
        gold += savedTurretInvestedGold(
          savedTurret,
          baseCost,
          firstLinkUpgradeDiscountRate: firstLinkUpgradeDiscountRate,
        );
      }
      for (final gem in savedTurret.equippedGems) {
        gems[gem] = (gems[gem] ?? 0) + 1;
      }
      if (savedTurret.primaryTrait != null) {
        gemShards += primaryTraitCost;
      }
      if (savedTurret.secondaryTrait != null) {
        gemShards += secondaryTraitCost;
      }
    }

    return SavedMapChangeRefund(
      gold: gold,
      gemInventory: Map.unmodifiable(gems),
      gemShards: gemShards,
    );
  }

  String mapSignature(MapDefinition map) {
    final buffer = StringBuffer('${map.columns}x${map.rows}|');
    for (final row in map.tiles) {
      for (final tile in row) {
        buffer.write('${tile.name},');
      }
      buffer.write('/');
    }
    buffer.write('|');
    for (final point in map.path) {
      buffer.write('${point.x},${point.y};');
    }
    return buffer.toString();
  }

  int savedTurretInvestedGold(
    SavedTurret savedTurret,
    int baseCost, {
    double firstLinkUpgradeDiscountRate = 0,
  }) {
    if (savedTurret.investedGold > 0) {
      return savedTurret.investedGold;
    }
    var total = baseCost;
    final level = savedTurret.level.clamp(1, 10).toInt();
    for (var currentLevel = 1; currentLevel < level; currentLevel++) {
      total += _turretLevelUpCostAt(baseCost, currentLevel);
    }
    final slotLimit = savedTurret.slotLimit.clamp(1, 4).toInt();
    for (var slot = 2; slot <= slotLimit; slot++) {
      total += _turretLinkUpgradeCostForSlot(
        baseCost,
        slot,
        firstLinkUpgradeDiscountRate: firstLinkUpgradeDiscountRate,
      );
    }
    return total;
  }

  int _turretLevelUpCostAt(int baseCost, int level) {
    return (baseCost * (70 + (level - 1) * 45) + 50) ~/ 100;
  }

  int _turretLinkUpgradeCostForSlot(
    int baseCost,
    int slotLimit, {
    required double firstLinkUpgradeDiscountRate,
  }) {
    final costPercent = slotLimit == 2 ? 150 : 300;
    final linkCost = (baseCost * costPercent + 50) ~/ 100;
    if (slotLimit != 2) {
      return linkCost;
    }
    final discountRate = firstLinkUpgradeDiscountRate.clamp(0.0, 0.8);
    return math.max(1, (linkCost * (1 - discountRate)).round());
  }
}

class GameSaveBuildState {
  const GameSaveBuildState({
    required this.savedAtMillis,
    required this.selectedStageNumber,
    required this.autoStartMode,
    required this.progression,
    required this.run,
    required this.savedDataLoaded,
    required this.pendingFullSaveData,
  });

  final int savedAtMillis;
  final int selectedStageNumber;
  final AutoStartMode autoStartMode;
  final RunProgression progression;
  final GameRunSaveBuildState run;
  final bool savedDataLoaded;
  final GameSaveData? pendingFullSaveData;
}

class GameRunSaveBuildState {
  const GameRunSaveBuildState({
    required this.gold,
    required this.gemShards,
    required this.nexusHp,
    required this.map,
    required this.roundIndex,
    required this.completedRounds,
    required this.phase,
    required this.restoredPhase,
    required this.runUpgradeLevels,
    required this.killGoldFractionWallet,
    required this.gemInventory,
    required this.rewardOptions,
    required this.isPurchasedGemReward,
    required this.rewardReturnPhase,
    required this.runCoreCombatSkill,
    required this.runCoreCombatSkillStats,
    required this.roundNexusHpLost,
    required this.emergencyChargeUsedThisRound,
    required this.finalDefenseUsedThisRound,
    required this.turrets,
    required this.enemies,
    required this.spawnQueue,
  });

  final int gold;
  final int gemShards;
  final double nexusHp;
  final MapDefinition map;
  final int roundIndex;
  final int completedRounds;
  final GamePhase phase;
  final GamePhase? restoredPhase;
  final Map<RunUpgradeType, int> runUpgradeLevels;
  final double killGoldFractionWallet;
  final Map<GemType, int> gemInventory;
  final List<GemType> rewardOptions;
  final bool isPurchasedGemReward;
  final GamePhase? rewardReturnPhase;
  final CoreCombatSkill? runCoreCombatSkill;
  final SavedCoreCombatSkillStats runCoreCombatSkillStats;
  final double roundNexusHpLost;
  final bool emergencyChargeUsedThisRound;
  final bool finalDefenseUsedThisRound;
  final List<SavedTurret> turrets;
  final List<SavedEnemy> enemies;
  final List<SavedSpawnRequest> spawnQueue;
}

class SavedMapChangeRefund {
  const SavedMapChangeRefund({
    required this.gold,
    required this.gemInventory,
    required this.gemShards,
  });

  final int gold;
  final Map<GemType, int> gemInventory;
  final int gemShards;
}
