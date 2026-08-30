part of 'game_save_data.dart';

class SavedPreferences {
  const SavedPreferences({
    required this.selectedStageNumber,
    required this.autoStartMode,
  });

  final int selectedStageNumber;
  final AutoStartMode autoStartMode;

  Map<String, Object?> toJson() {
    return {
      'selectedStageNumber': selectedStageNumber,
      'autoStartMode': autoStartMode.name,
    };
  }

  static SavedPreferences fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return SavedPreferences(
      selectedStageNumber: _intValue(map['selectedStageNumber'], fallback: 1),
      autoStartMode:
          _enumValue(AutoStartMode.values, map['autoStartMode']) ??
          AutoStartMode.pauseEachRound,
    );
  }
}

class SavedRunState {
  const SavedRunState({
    required this.gold,
    required this.gemShards,
    required this.nexusHp,
    required this.stageNumber,
    required this.mapSignature,
    required this.roundIndex,
    required this.completedRounds,
    required this.phase,
    required this.runUpgradeLevels,
    required this.killGoldFractionWallet,
    required this.gemInventory,
    required this.rewardOptions,
    required this.isPurchasedGemReward,
    this.economyRunId,
    this.pendingEconomyDiamonds = 0,
    this.rewardReturnPhase,
    this.runCoreCombatSkill = CoreCombatSkill.guardianBeam,
    this.runCoreCombatSkillStats = SavedCoreCombatSkillStats.empty,
    this.roundNexusHpLost = 0,
    this.emergencyChargeUsedThisRound = false,
    this.finalDefenseUsedThisRound = false,
    required this.turrets,
    required this.enemies,
    required this.spawnQueue,
  });

  final int gold;
  final int gemShards;
  final double nexusHp;
  final int stageNumber;
  final String? mapSignature;
  final int roundIndex;
  final int completedRounds;
  final GamePhase phase;
  final Map<RunUpgradeType, int> runUpgradeLevels;
  final double killGoldFractionWallet;
  final Map<GemType, int> gemInventory;
  final List<GemType> rewardOptions;
  final bool isPurchasedGemReward;
  final String? economyRunId;
  final int pendingEconomyDiamonds;
  final GamePhase? rewardReturnPhase;
  final CoreCombatSkill? runCoreCombatSkill;
  final SavedCoreCombatSkillStats runCoreCombatSkillStats;
  final double roundNexusHpLost;
  final bool emergencyChargeUsedThisRound;
  final bool finalDefenseUsedThisRound;
  final List<SavedTurret> turrets;
  final List<SavedEnemy> enemies;
  final List<SavedSpawnRequest> spawnQueue;

  bool get hasProgress {
    return phase == GamePhase.wave ||
        phase == GamePhase.reward ||
        roundIndex > 0 ||
        completedRounds > 0 ||
        runUpgradeLevels.isNotEmpty ||
        gemInventory.isNotEmpty ||
        turrets.isNotEmpty ||
        enemies.isNotEmpty ||
        spawnQueue.isNotEmpty ||
        killGoldFractionWallet > 0 ||
        rewardOptions.isNotEmpty;
  }

  Map<String, Object?> toJson() {
    return {
      'gold': gold,
      'gemShards': gemShards,
      'nexusHp': nexusHp,
      'stageNumber': stageNumber,
      'mapSignature': mapSignature,
      'roundIndex': roundIndex,
      'completedRounds': completedRounds,
      'phase': phase.name,
      'runUpgradeLevels': runUpgradeLevels.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'killGoldFractionWallet': killGoldFractionWallet,
      'gemInventory': gemInventory.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'rewardOptions': rewardOptions.map((type) => type.name).toList(),
      'isPurchasedGemReward': isPurchasedGemReward,
      'economyRunId': economyRunId,
      'pendingEconomyDiamonds': pendingEconomyDiamonds,
      'rewardReturnPhase': rewardReturnPhase?.name,
      'runCoreCombatSkill': runCoreCombatSkill?.name,
      'runCoreCombatSkillStats': runCoreCombatSkillStats.toJson(),
      'roundNexusHpLost': roundNexusHpLost,
      'emergencyChargeUsedThisRound': emergencyChargeUsedThisRound,
      'finalDefenseUsedThisRound': finalDefenseUsedThisRound,
      'turrets': turrets.map((turret) => turret.toJson()).toList(),
      'enemies': enemies.map((enemy) => enemy.toJson()).toList(),
      'spawnQueue': spawnQueue.map((request) => request.toJson()).toList(),
    };
  }

  static SavedRunState? fromJson(
    Object? json, {
    required CoreCombatSkill? missingRunCoreCombatSkill,
  }) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final phase =
        _enumValue(GamePhase.values, json['phase']) ?? GamePhase.preparation;
    final isPurchasedGemReward = json['isPurchasedGemReward'] == true;
    final enemies = _objectList(json['enemies'], SavedEnemy.fromJson);
    final spawnQueue = _objectList(
      json['spawnQueue'],
      SavedSpawnRequest.fromJson,
    );
    final rewardReturnPhase =
        _enumValue(GamePhase.values, json['rewardReturnPhase']) ??
        (phase == GamePhase.reward &&
                isPurchasedGemReward &&
                (enemies.isNotEmpty || spawnQueue.isNotEmpty)
            ? GamePhase.wave
            : null);
    return SavedRunState(
      gold: _intValue(json['gold']),
      gemShards: _intValue(json['gemShards']),
      nexusHp: _doubleValue(json['nexusHp']),
      stageNumber: _intValue(json['stageNumber'], fallback: 1),
      mapSignature: _stringValue(json['mapSignature']),
      roundIndex: _intValue(json['roundIndex']),
      completedRounds: _intValue(json['completedRounds']),
      phase: phase,
      runUpgradeLevels: _enumIntMap(
        RunUpgradeType.values,
        json['runUpgradeLevels'],
      ),
      killGoldFractionWallet: _doubleValue(json['killGoldFractionWallet']),
      gemInventory: _enumIntMap(GemType.values, json['gemInventory']),
      rewardOptions: _enumList(GemType.values, json['rewardOptions']),
      isPurchasedGemReward: isPurchasedGemReward,
      economyRunId: _stringValue(json['economyRunId']),
      pendingEconomyDiamonds: _intValue(
        json['pendingEconomyDiamonds'],
      ).clamp(0, 1000000),
      rewardReturnPhase: rewardReturnPhase,
      runCoreCombatSkill: _nullableCoreCombatSkillFromSave(
        json,
        key: 'runCoreCombatSkill',
        missingFallback: missingRunCoreCombatSkill,
      ),
      runCoreCombatSkillStats: SavedCoreCombatSkillStats.fromJson(
        json['runCoreCombatSkillStats'],
      ),
      roundNexusHpLost: _doubleValue(json['roundNexusHpLost']),
      emergencyChargeUsedThisRound: _boolValue(
        json['emergencyChargeUsedThisRound'],
      ),
      finalDefenseUsedThisRound: _boolValue(json['finalDefenseUsedThisRound']),
      turrets: _objectList(json['turrets'], SavedTurret.fromJson),
      enemies: enemies,
      spawnQueue: spawnQueue,
    );
  }
}
