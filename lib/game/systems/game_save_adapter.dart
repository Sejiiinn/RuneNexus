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
    final savedPhase = state.phase == GamePhase.restored
        ? state.restoredPhase ?? GamePhase.preparation
        : state.phase;
    final pendingSave = !state.savedDataLoaded
        ? state.pendingFullSaveData
        : null;

    return GameSaveData(
      version: GameSaveData.currentVersion,
      savedAtMillis: state.savedAtMillis,
      gold: state.gold,
      gemShards: state.gemShards,
      nexusHp: state.nexusHp,
      stageNumber: state.currentStageNumber,
      mapSignature: pendingSave?.hasActiveRun == true
          ? pendingSave?.mapSignature
          : mapSignature(state.map),
      roundIndex: state.roundIndex,
      completedRounds: state.completedRounds,
      phase: savedPhase,
      autoStartMode: state.autoStartMode,
      progression: state.progression.toSaveData(),
      runUpgradeLevels: Map.unmodifiable(state.runUpgradeLevels),
      killGoldFractionWallet: state.killGoldFractionWallet,
      gemInventory: Map.unmodifiable(state.gemInventory),
      rewardOptions: List.unmodifiable(state.rewardOptions),
      isPurchasedGemReward: state.isPurchasedGemReward,
      runCoreCombatSkill: pendingSave?.hasActiveRun == true
          ? pendingSave?.runCoreCombatSkill
          : state.runCoreCombatSkill,
      runCorePassiveSlots: pendingSave?.hasActiveRun == true
          ? pendingSave!.runCorePassiveSlots
          : List.unmodifiable(state.runCorePassiveSlots.take(2)),
      turrets: pendingSave?.turrets ?? state.turrets,
      enemies: pendingSave?.enemies ?? state.enemies,
      spawnQueue: pendingSave?.spawnQueue ?? state.spawnQueue,
    );
  }

  bool hasSavedRunMapMismatch(GameSaveData data, MapDefinition map) {
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
  }) {
    var gold = 0;
    var gemShards = 0;
    final gems = <GemType, int>{};

    for (final savedTurret in savedTurrets) {
      final baseCost = baseCostFor(savedTurret.type);
      if (baseCost != null) {
        gold += savedTurretInvestedGold(savedTurret, baseCost);
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

  int savedTurretInvestedGold(SavedTurret savedTurret, int baseCost) {
    var total = baseCost;
    final level = savedTurret.level.clamp(1, 10).toInt();
    for (var currentLevel = 1; currentLevel < level; currentLevel++) {
      total += _turretLevelUpCostAt(baseCost, currentLevel);
    }
    final slotLimit = savedTurret.slotLimit.clamp(1, 4).toInt();
    for (var slot = 2; slot <= slotLimit; slot++) {
      total += _turretLinkUpgradeCostForSlot(baseCost, slot);
    }
    return total;
  }

  int _turretLevelUpCostAt(int baseCost, int level) {
    return (baseCost * (70 + (level - 1) * 45) + 50) ~/ 100;
  }

  int _turretLinkUpgradeCostForSlot(int baseCost, int slotLimit) {
    final costPercent = slotLimit == 2 ? 150 : 300;
    return (baseCost * costPercent + 50) ~/ 100;
  }
}

class GameSaveBuildState {
  const GameSaveBuildState({
    required this.savedAtMillis,
    required this.gold,
    required this.gemShards,
    required this.nexusHp,
    required this.currentStageNumber,
    required this.map,
    required this.roundIndex,
    required this.completedRounds,
    required this.phase,
    required this.restoredPhase,
    required this.autoStartMode,
    required this.progression,
    required this.runUpgradeLevels,
    required this.killGoldFractionWallet,
    required this.gemInventory,
    required this.rewardOptions,
    required this.isPurchasedGemReward,
    required this.runCoreCombatSkill,
    required this.runCorePassiveSlots,
    required this.turrets,
    required this.enemies,
    required this.spawnQueue,
    required this.savedDataLoaded,
    required this.pendingFullSaveData,
  });

  final int savedAtMillis;
  final int gold;
  final int gemShards;
  final int nexusHp;
  final int currentStageNumber;
  final MapDefinition map;
  final int roundIndex;
  final int completedRounds;
  final GamePhase phase;
  final GamePhase? restoredPhase;
  final AutoStartMode autoStartMode;
  final RunProgression progression;
  final Map<RunUpgradeType, int> runUpgradeLevels;
  final double killGoldFractionWallet;
  final Map<GemType, int> gemInventory;
  final List<GemType> rewardOptions;
  final bool isPurchasedGemReward;
  final CoreCombatSkill? runCoreCombatSkill;
  final List<CorePassiveAbility?> runCorePassiveSlots;
  final List<SavedTurret> turrets;
  final List<SavedEnemy> enemies;
  final List<SavedSpawnRequest> spawnQueue;
  final bool savedDataLoaded;
  final GameSaveData? pendingFullSaveData;
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
