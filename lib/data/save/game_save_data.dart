import '../../domain/combat/auto_start_mode.dart';
import '../../domain/combat/game_phase.dart';
import '../../domain/core/core_ability.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/gem/gem_type.dart';
import '../../domain/map/grid_point.dart';
import '../../domain/research/research_type.dart';
import '../../domain/run_upgrade/run_upgrade_type.dart';
import '../../domain/turret/turret_trait_type.dart';
import '../../domain/turret/turret_type.dart';
import '../../domain/turret/turret_target_priority.dart';

class GameSaveData {
  const GameSaveData({
    required this.version,
    required this.savedAtMillis,
    required this.gold,
    required this.gemShards,
    required this.nexusHp,
    required this.stageNumber,
    required this.mapSignature,
    required this.roundIndex,
    required this.completedRounds,
    required this.phase,
    required this.autoStartMode,
    required this.progression,
    required this.runUpgradeLevels,
    required this.killGoldFractionWallet,
    required this.gemInventory,
    required this.rewardOptions,
    required this.isPurchasedGemReward,
    this.rewardReturnPhase,
    this.runCoreCombatSkill = CoreCombatSkill.guardianBeam,
    this.runCorePassiveSlots = const [null, null],
    this.runCoreCombatSkillStats = SavedCoreCombatSkillStats.empty,
    required this.turrets,
    required this.enemies,
    required this.spawnQueue,
  });

  static const currentVersion = 1;

  final int version;
  final int savedAtMillis;
  final int gold;
  final int gemShards;
  final int nexusHp;
  final int stageNumber;
  final String? mapSignature;
  final int roundIndex;
  final int completedRounds;
  final GamePhase phase;
  final AutoStartMode autoStartMode;
  final SavedProgression progression;
  final Map<RunUpgradeType, int> runUpgradeLevels;
  final double killGoldFractionWallet;
  final Map<GemType, int> gemInventory;
  final List<GemType> rewardOptions;
  final bool isPurchasedGemReward;
  final GamePhase? rewardReturnPhase;
  final CoreCombatSkill? runCoreCombatSkill;
  final List<CorePassiveAbility?> runCorePassiveSlots;
  final SavedCoreCombatSkillStats runCoreCombatSkillStats;
  final List<SavedTurret> turrets;
  final List<SavedEnemy> enemies;
  final List<SavedSpawnRequest> spawnQueue;

  bool get hasActiveRun {
    return phase == GamePhase.wave ||
        phase == GamePhase.reward ||
        roundIndex > 0 ||
        completedRounds > 0 ||
        turrets.isNotEmpty ||
        enemies.isNotEmpty ||
        spawnQueue.isNotEmpty ||
        runUpgradeLevels.isNotEmpty ||
        killGoldFractionWallet > 0 ||
        gemShards > 0 ||
        gemInventory.isNotEmpty ||
        rewardOptions.isNotEmpty;
  }

  Map<String, Object?> toJson() {
    return {
      'version': version,
      'savedAtMillis': savedAtMillis,
      'gold': gold,
      'gemShards': gemShards,
      'nexusHp': nexusHp,
      'stageNumber': stageNumber,
      'mapSignature': mapSignature,
      'roundIndex': roundIndex,
      'completedRounds': completedRounds,
      'phase': phase.name,
      'autoStartMode': autoStartMode.name,
      'progression': progression.toJson(),
      'runUpgradeLevels': runUpgradeLevels.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'killGoldFractionWallet': killGoldFractionWallet,
      'gemInventory': gemInventory.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'rewardOptions': rewardOptions.map((type) => type.name).toList(),
      'isPurchasedGemReward': isPurchasedGemReward,
      'rewardReturnPhase': rewardReturnPhase?.name,
      'runCoreCombatSkill': runCoreCombatSkill?.name,
      'runCorePassiveSlots': runCorePassiveSlots
          .take(2)
          .map((ability) => ability?.name)
          .toList(),
      'runCoreCombatSkillStats': runCoreCombatSkillStats.toJson(),
      'turrets': turrets.map((turret) => turret.toJson()).toList(),
      'enemies': enemies.map((enemy) => enemy.toJson()).toList(),
      'spawnQueue': spawnQueue.map((request) => request.toJson()).toList(),
    };
  }

  static GameSaveData? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final version = _intValue(json['version']);
    if (version != currentVersion) {
      return null;
    }

    final progression = SavedProgression.fromJson(json['progression']);
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
    return GameSaveData(
      version: version,
      savedAtMillis: _intValue(json['savedAtMillis']),
      gold: _intValue(json['gold']),
      gemShards: _intValue(json['gemShards']),
      nexusHp: _intValue(json['nexusHp']),
      stageNumber: _intValue(json['stageNumber'], fallback: 1),
      mapSignature: _stringValue(json['mapSignature']),
      roundIndex: _intValue(json['roundIndex']),
      completedRounds: _intValue(json['completedRounds']),
      phase: phase,
      autoStartMode:
          _enumValue(AutoStartMode.values, json['autoStartMode']) ??
          AutoStartMode.pauseEachRound,
      progression: progression,
      runUpgradeLevels: _enumIntMap(
        RunUpgradeType.values,
        json['runUpgradeLevels'],
      ),
      killGoldFractionWallet: _doubleValue(json['killGoldFractionWallet']),
      gemInventory: _enumIntMap(GemType.values, json['gemInventory']),
      rewardOptions: _enumList(GemType.values, json['rewardOptions']),
      isPurchasedGemReward: isPurchasedGemReward,
      rewardReturnPhase: rewardReturnPhase,
      runCoreCombatSkill: _nullableCoreCombatSkillFromSave(
        json,
        key: 'runCoreCombatSkill',
        missingFallback: progression.coreCombatSkill,
      ),
      runCorePassiveSlots: _nullableCorePassiveSlotsFromSave(
        json,
        key: 'runCorePassiveSlots',
        missingFallback: progression.corePassiveSlots,
      ),
      runCoreCombatSkillStats: SavedCoreCombatSkillStats.fromJson(
        json['runCoreCombatSkillStats'],
      ),
      turrets: _objectList(json['turrets'], SavedTurret.fromJson),
      enemies: enemies,
      spawnQueue: spawnQueue,
    );
  }
}

class SavedCoreCombatSkillStats {
  const SavedCoreCombatSkillStats({
    required this.directDamageDealt,
    required this.bonusDamageDealt,
    required this.activationCount,
  });

  static const empty = SavedCoreCombatSkillStats(
    directDamageDealt: 0,
    bonusDamageDealt: 0,
    activationCount: 0,
  );

  final double directDamageDealt;
  final double bonusDamageDealt;
  final int activationCount;

  Map<String, Object?> toJson() {
    return {
      'directDamageDealt': directDamageDealt,
      'bonusDamageDealt': bonusDamageDealt,
      'activationCount': activationCount,
    };
  }

  static SavedCoreCombatSkillStats fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return empty;
    }
    return SavedCoreCombatSkillStats(
      directDamageDealt: _doubleValue(json['directDamageDealt']),
      bonusDamageDealt: _doubleValue(json['bonusDamageDealt']),
      activationCount: _intValue(json['activationCount']),
    );
  }
}

class SavedProgression {
  const SavedProgression({
    required this.runes,
    required this.lastRunRuneReward,
    required this.startingGoldUpgradeLevel,
    required this.nexusHpUpgradeLevel,
    required this.supplyUpgradeLevel,
    required this.fireTrainingUpgradeLevel,
    this.physicalDamageTrainingUpgradeLevel = 0,
    this.elementalDamageTrainingUpgradeLevel = 0,
    required this.criticalChanceUpgradeLevel,
    required this.criticalDamageUpgradeLevel,
    required this.killGoldUpgradeLevel,
    required this.emergencySaleUpgradeLevel,
    required this.unlockedStageCount,
    required this.bestRoundsByStage,
    required this.clearedStageNumbers,
    required this.researchLevels,
    required this.researchElapsedMillis,
    required this.activeResearches,
    this.coreCombatSkill = CoreCombatSkill.guardianBeam,
    this.corePassiveSlotTwoUnlocked = false,
    this.corePassiveSlots = const [null, null],
  });

  final int runes;
  final int lastRunRuneReward;
  final int startingGoldUpgradeLevel;
  final int nexusHpUpgradeLevel;
  final int supplyUpgradeLevel;
  final int fireTrainingUpgradeLevel;
  final int physicalDamageTrainingUpgradeLevel;
  final int elementalDamageTrainingUpgradeLevel;
  final int criticalChanceUpgradeLevel;
  final int criticalDamageUpgradeLevel;
  final int killGoldUpgradeLevel;
  final int emergencySaleUpgradeLevel;
  final int unlockedStageCount;
  final Map<int, int> bestRoundsByStage;
  final Set<int> clearedStageNumbers;
  final Map<ResearchType, int> researchLevels;
  final Map<ResearchType, int> researchElapsedMillis;
  final List<SavedActiveResearch> activeResearches;
  final CoreCombatSkill? coreCombatSkill;
  final bool corePassiveSlotTwoUnlocked;
  final List<CorePassiveAbility?> corePassiveSlots;

  Map<String, Object?> toJson() {
    return {
      'runes': runes,
      'lastRunRuneReward': lastRunRuneReward,
      'startingGoldUpgradeLevel': startingGoldUpgradeLevel,
      'nexusHpUpgradeLevel': nexusHpUpgradeLevel,
      'supplyUpgradeLevel': supplyUpgradeLevel,
      'fireTrainingUpgradeLevel': fireTrainingUpgradeLevel,
      'physicalDamageTrainingUpgradeLevel': physicalDamageTrainingUpgradeLevel,
      'elementalDamageTrainingUpgradeLevel':
          elementalDamageTrainingUpgradeLevel,
      'criticalChanceUpgradeLevel': criticalChanceUpgradeLevel,
      'criticalDamageUpgradeLevel': criticalDamageUpgradeLevel,
      'killGoldUpgradeLevel': killGoldUpgradeLevel,
      'emergencySaleUpgradeLevel': emergencySaleUpgradeLevel,
      'unlockedStageCount': unlockedStageCount,
      'bestRoundsByStage': bestRoundsByStage.map(
        (key, value) => MapEntry('$key', value),
      ),
      'clearedStageNumbers': clearedStageNumbers.toList(),
      'researchLevels': researchLevels.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'researchElapsedMillis': researchElapsedMillis.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'activeResearches': activeResearches
          .map((research) => research.toJson())
          .toList(),
      'coreCombatSkill': coreCombatSkill?.name,
      'corePassiveSlotTwoUnlocked': corePassiveSlotTwoUnlocked,
      'corePassiveSlots': corePassiveSlots
          .take(2)
          .map((ability) => ability?.name)
          .toList(),
    };
  }

  static SavedProgression fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    final corePassiveSlots = _normalizeCorePassiveSlots(
      _nullableEnumList(CorePassiveAbility.values, map['corePassiveSlots']),
    );
    return SavedProgression(
      runes: _intValue(map['runes']),
      lastRunRuneReward: _intValue(map['lastRunRuneReward']),
      startingGoldUpgradeLevel: _intValue(map['startingGoldUpgradeLevel']),
      nexusHpUpgradeLevel: _intValue(map['nexusHpUpgradeLevel']),
      supplyUpgradeLevel: _intValue(map['supplyUpgradeLevel']),
      fireTrainingUpgradeLevel: _intValue(map['fireTrainingUpgradeLevel']),
      physicalDamageTrainingUpgradeLevel: _intValue(
        map['physicalDamageTrainingUpgradeLevel'],
      ),
      elementalDamageTrainingUpgradeLevel: _intValue(
        map['elementalDamageTrainingUpgradeLevel'],
      ),
      criticalChanceUpgradeLevel: _intValue(map['criticalChanceUpgradeLevel']),
      criticalDamageUpgradeLevel: _intValue(map['criticalDamageUpgradeLevel']),
      killGoldUpgradeLevel: _intValue(map['killGoldUpgradeLevel']),
      emergencySaleUpgradeLevel: _intValue(map['emergencySaleUpgradeLevel']),
      unlockedStageCount: _intValue(map['unlockedStageCount'], fallback: 1),
      bestRoundsByStage: _intIntMap(map['bestRoundsByStage']),
      clearedStageNumbers: _intSet(map['clearedStageNumbers']),
      researchLevels: _enumIntMap(ResearchType.values, map['researchLevels']),
      researchElapsedMillis: _enumIntMap(
        ResearchType.values,
        map['researchElapsedMillis'],
      ),
      activeResearches: _objectList(
        map['activeResearches'],
        SavedActiveResearch.fromJson,
      ),
      coreCombatSkill: _coreCombatSkillFromSave(map),
      corePassiveSlotTwoUnlocked: _boolValue(
        map['corePassiveSlotTwoUnlocked'],
        fallback: corePassiveSlots.length > 1 && corePassiveSlots[1] != null,
      ),
      corePassiveSlots: corePassiveSlots,
    );
  }
}

CoreCombatSkill? _coreCombatSkillFromSave(Map<String, Object?> map) {
  return _nullableCoreCombatSkillFromSave(
    map,
    key: 'coreCombatSkill',
    missingFallback: CoreCombatSkill.guardianBeam,
  );
}

CoreCombatSkill? _nullableCoreCombatSkillFromSave(
  Map<String, Object?> map, {
  required String key,
  required CoreCombatSkill? missingFallback,
}) {
  if (!map.containsKey(key)) {
    return missingFallback;
  }
  final value = map[key];
  if (value == null) {
    return null;
  }
  return _enumValue(CoreCombatSkill.values, value) ??
      CoreCombatSkill.guardianBeam;
}

List<CorePassiveAbility?> _nullableCorePassiveSlotsFromSave(
  Map<String, Object?> map, {
  required String key,
  required List<CorePassiveAbility?> missingFallback,
}) {
  if (!map.containsKey(key)) {
    return _normalizeCorePassiveSlots(missingFallback);
  }
  return _normalizeCorePassiveSlots(
    _nullableEnumList(CorePassiveAbility.values, map[key]),
  );
}

List<CorePassiveAbility?> _normalizeCorePassiveSlots(
  List<CorePassiveAbility?> slots,
) {
  return List<CorePassiveAbility?>.generate(
    2,
    (index) => index < slots.length ? slots[index] : null,
    growable: false,
  );
}

class SavedActiveResearch {
  const SavedActiveResearch({
    required this.type,
    required this.targetLevel,
    required this.startedAtMillis,
    required this.durationMillis,
    required this.initialElapsedMillis,
  });

  final ResearchType type;
  final int targetLevel;
  final int startedAtMillis;
  final int durationMillis;
  final int initialElapsedMillis;

  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'targetLevel': targetLevel,
      'startedAtMillis': startedAtMillis,
      'durationMillis': durationMillis,
      'initialElapsedMillis': initialElapsedMillis,
    };
  }

  static SavedActiveResearch? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final type = _enumValue(ResearchType.values, json['type']);
    if (type == null) {
      return null;
    }
    return SavedActiveResearch(
      type: type,
      targetLevel: _intValue(json['targetLevel'], fallback: 1),
      startedAtMillis: _intValue(json['startedAtMillis']),
      durationMillis: _intValue(json['durationMillis']),
      initialElapsedMillis: _intValue(json['initialElapsedMillis']),
    );
  }
}

class SavedTurret {
  const SavedTurret({
    required this.x,
    required this.y,
    required this.type,
    required this.level,
    required this.slotLimit,
    required this.cooldown,
    required this.equippedGems,
    required this.equippedGemSlots,
    required this.damageDealt,
    required this.directDamageDealt,
    required this.splashDamageDealt,
    required this.chainDamageDealt,
    required this.burnDamageDealt,
    required this.targetPriority,
    required this.primaryTrait,
    required this.secondaryTrait,
  });

  final int x;
  final int y;
  final TurretType type;
  final int level;
  final int slotLimit;
  final double cooldown;
  final List<GemType> equippedGems;
  final List<GemType?> equippedGemSlots;
  final double damageDealt;
  final double directDamageDealt;
  final double splashDamageDealt;
  final double chainDamageDealt;
  final double burnDamageDealt;
  final TurretTargetPriority targetPriority;
  final TurretTraitType? primaryTrait;
  final TurretTraitType? secondaryTrait;

  GridPoint get point => GridPoint(x, y);

  Map<String, Object?> toJson() {
    return {
      'x': x,
      'y': y,
      'type': type.name,
      'level': level,
      'slotLimit': slotLimit,
      'cooldown': cooldown,
      'equippedGems': equippedGems.map((type) => type.name).toList(),
      'equippedGemSlots': equippedGemSlots.map((type) => type?.name).toList(),
      'damageDealt': damageDealt,
      'directDamageDealt': directDamageDealt,
      'splashDamageDealt': splashDamageDealt,
      'chainDamageDealt': chainDamageDealt,
      'burnDamageDealt': burnDamageDealt,
      'targetPriority': targetPriority.name,
      'primaryTrait': primaryTrait?.name,
      'secondaryTrait': secondaryTrait?.name,
    };
  }

  static SavedTurret? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final type = _enumValue(TurretType.values, json['type']);
    if (type == null) {
      return null;
    }
    final equippedGems = _enumList(GemType.values, json['equippedGems']);
    final equippedGemSlots = json.containsKey('equippedGemSlots')
        ? _nullableEnumList(GemType.values, json['equippedGemSlots'])
        : equippedGems;
    return SavedTurret(
      x: _intValue(json['x']),
      y: _intValue(json['y']),
      type: type,
      level: _intValue(json['level'], fallback: 1),
      slotLimit: _intValue(json['slotLimit'], fallback: 1),
      cooldown: _doubleValue(json['cooldown']),
      equippedGems: equippedGems,
      equippedGemSlots: equippedGemSlots,
      damageDealt: _doubleValue(json['damageDealt']),
      directDamageDealt: _doubleValue(json['directDamageDealt']),
      splashDamageDealt: _doubleValue(json['splashDamageDealt']),
      chainDamageDealt: _doubleValue(json['chainDamageDealt']),
      burnDamageDealt: _doubleValue(json['burnDamageDealt']),
      targetPriority:
          _enumValue(TurretTargetPriority.values, json['targetPriority']) ??
          TurretTargetPriority.first,
      primaryTrait: _enumValue(TurretTraitType.values, json['primaryTrait']),
      secondaryTrait: _enumValue(
        TurretTraitType.values,
        json['secondaryTrait'],
      ),
    );
  }
}

class SavedBurnInstance {
  const SavedBurnInstance({
    required this.remaining,
    required this.damagePerSecond,
    required this.damageMultiplier,
    required this.sourceX,
    required this.sourceY,
    required this.ignoreArmorReduction,
  });

  final double remaining;
  final double damagePerSecond;
  final double damageMultiplier;
  final int? sourceX;
  final int? sourceY;
  final bool ignoreArmorReduction;

  GridPoint? get sourcePoint {
    final x = sourceX;
    final y = sourceY;
    return x == null || y == null ? null : GridPoint(x, y);
  }

  Map<String, Object?> toJson() {
    return {
      'remaining': remaining,
      'damagePerSecond': damagePerSecond,
      'damageMultiplier': damageMultiplier,
      'sourceX': sourceX,
      'sourceY': sourceY,
      'ignoreArmorReduction': ignoreArmorReduction,
    };
  }

  static SavedBurnInstance? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final remaining = _doubleValue(json['remaining']);
    final damagePerSecond = _doubleValue(json['damagePerSecond']);
    if (remaining <= 0 || damagePerSecond <= 0) {
      return null;
    }
    return SavedBurnInstance(
      remaining: remaining,
      damagePerSecond: damagePerSecond,
      damageMultiplier: _doubleValue(json['damageMultiplier'], fallback: 1),
      sourceX: _nullableIntValue(json['sourceX']),
      sourceY: _nullableIntValue(json['sourceY']),
      ignoreArmorReduction: _boolValue(json['ignoreArmorReduction']),
    );
  }
}

class SavedEnemy {
  const SavedEnemy({
    required this.type,
    required this.maxHp,
    required this.hp,
    required this.shield,
    required this.shieldBroken,
    required this.armor,
    required this.distanceTravelled,
    required this.burnRemaining,
    required this.burnDamagePerSecond,
    required this.burnDamageMultiplier,
    required this.burnInstances,
    required this.poisonRemaining,
    required this.poisonDamagePerSecond,
    required this.poisonDamageMultiplier,
    required this.poisonStacks,
    required this.slowRemaining,
    required this.slowMultiplier,
    required this.physicalVulnerabilityRemaining,
    required this.physicalVulnerabilityBonus,
    required this.elementalVulnerabilityRemaining,
    required this.elementalVulnerabilityBonus,
    this.riftMarkRemaining = 0,
    this.riftMarkDamageAmplification = 0,
  });

  final EnemyType type;
  final double maxHp;
  final double hp;
  final double shield;
  final bool shieldBroken;
  final double armor;
  final double distanceTravelled;
  final double burnRemaining;
  final double burnDamagePerSecond;
  final double burnDamageMultiplier;
  final List<SavedBurnInstance> burnInstances;
  final double poisonRemaining;
  final double poisonDamagePerSecond;
  final double poisonDamageMultiplier;
  final int poisonStacks;
  final double slowRemaining;
  final double slowMultiplier;
  final double physicalVulnerabilityRemaining;
  final double physicalVulnerabilityBonus;
  final double elementalVulnerabilityRemaining;
  final double elementalVulnerabilityBonus;
  final double riftMarkRemaining;
  final double riftMarkDamageAmplification;

  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'maxHp': maxHp,
      'hp': hp,
      'shield': shield,
      'shieldBroken': shieldBroken,
      'armor': armor,
      'distanceTravelled': distanceTravelled,
      'burnRemaining': burnRemaining,
      'burnDamagePerSecond': burnDamagePerSecond,
      'burnDamageMultiplier': burnDamageMultiplier,
      'burnInstances': burnInstances
          .map((instance) => instance.toJson())
          .toList(),
      'poisonRemaining': poisonRemaining,
      'poisonDamagePerSecond': poisonDamagePerSecond,
      'poisonDamageMultiplier': poisonDamageMultiplier,
      'poisonStacks': poisonStacks,
      'slowRemaining': slowRemaining,
      'slowMultiplier': slowMultiplier,
      'physicalVulnerabilityRemaining': physicalVulnerabilityRemaining,
      'physicalVulnerabilityBonus': physicalVulnerabilityBonus,
      'elementalVulnerabilityRemaining': elementalVulnerabilityRemaining,
      'elementalVulnerabilityBonus': elementalVulnerabilityBonus,
      'riftMarkRemaining': riftMarkRemaining,
      'riftMarkDamageAmplification': riftMarkDamageAmplification,
    };
  }

  static SavedEnemy? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final type = _enumValue(EnemyType.values, json['type']);
    if (type == null) {
      return null;
    }
    final burnInstances = _objectList(
      json['burnInstances'],
      SavedBurnInstance.fromJson,
    );
    final legacyBurnRemaining = _doubleValue(json['burnRemaining']);
    final legacyBurnDamagePerSecond = _doubleValue(json['burnDamagePerSecond']);
    if (burnInstances.isEmpty &&
        legacyBurnRemaining > 0 &&
        legacyBurnDamagePerSecond > 0) {
      burnInstances.add(
        SavedBurnInstance(
          remaining: legacyBurnRemaining,
          damagePerSecond: legacyBurnDamagePerSecond,
          damageMultiplier: _doubleValue(
            json['burnDamageMultiplier'],
            fallback: 1,
          ),
          sourceX: null,
          sourceY: null,
          ignoreArmorReduction: false,
        ),
      );
    }
    return SavedEnemy(
      type: type,
      maxHp: _doubleValue(json['maxHp']),
      hp: _doubleValue(json['hp']),
      shield: _doubleValue(json['shield']),
      shieldBroken: _boolValue(json['shieldBroken']),
      armor: _doubleValue(json['armor']),
      distanceTravelled: _doubleValue(json['distanceTravelled']),
      burnRemaining: legacyBurnRemaining,
      burnDamagePerSecond: legacyBurnDamagePerSecond,
      burnDamageMultiplier: _doubleValue(
        json['burnDamageMultiplier'],
        fallback: 1,
      ),
      burnInstances: List.unmodifiable(burnInstances),
      poisonRemaining: _doubleValue(json['poisonRemaining']),
      poisonDamagePerSecond: _doubleValue(json['poisonDamagePerSecond']),
      poisonDamageMultiplier: _doubleValue(
        json['poisonDamageMultiplier'],
        fallback: 1,
      ),
      poisonStacks: _intValue(json['poisonStacks']),
      slowRemaining: _doubleValue(json['slowRemaining']),
      slowMultiplier: _doubleValue(json['slowMultiplier'], fallback: 1),
      physicalVulnerabilityRemaining: _doubleValue(
        json['physicalVulnerabilityRemaining'],
      ),
      physicalVulnerabilityBonus: _doubleValue(
        json['physicalVulnerabilityBonus'],
      ),
      elementalVulnerabilityRemaining: _doubleValue(
        json['elementalVulnerabilityRemaining'],
      ),
      elementalVulnerabilityBonus: _doubleValue(
        json['elementalVulnerabilityBonus'],
      ),
      riftMarkRemaining: _doubleValue(json['riftMarkRemaining']),
      riftMarkDamageAmplification: _doubleValue(
        json['riftMarkDamageAmplification'],
      ),
    );
  }
}

class SavedSpawnRequest {
  const SavedSpawnRequest({required this.enemyType, required this.delay});

  final EnemyType enemyType;
  final double delay;

  Map<String, Object?> toJson() {
    return {'enemyType': enemyType.name, 'delay': delay};
  }

  static SavedSpawnRequest? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final enemyType = _enumValue(EnemyType.values, json['enemyType']);
    if (enemyType == null) {
      return null;
    }
    return SavedSpawnRequest(
      enemyType: enemyType,
      delay: _doubleValue(json['delay']),
    );
  }
}

int _intValue(Object? value, {int fallback = 0}) {
  return switch (value) {
    int() => value,
    double() => value.toInt(),
    _ => fallback,
  };
}

int? _nullableIntValue(Object? value) {
  return switch (value) {
    int() => value,
    double() => value.toInt(),
    _ => null,
  };
}

double _doubleValue(Object? value, {double fallback = 0}) {
  return switch (value) {
    int() => value.toDouble(),
    double() => value,
    _ => fallback,
  };
}

bool _boolValue(Object? value, {bool fallback = false}) {
  return value is bool ? value : fallback;
}

String? _stringValue(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

T? _enumValue<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) {
    return null;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}

Map<T, int> _enumIntMap<T extends Enum>(List<T> values, Object? json) {
  if (json is! Map<String, Object?>) {
    return {};
  }
  final result = <T, int>{};
  for (final entry in json.entries) {
    final key = _enumValue(values, entry.key);
    if (key != null) {
      result[key] = _intValue(entry.value);
    }
  }
  return result;
}

Map<int, int> _intIntMap(Object? json) {
  if (json is! Map<String, Object?>) {
    return {};
  }
  final result = <int, int>{};
  for (final entry in json.entries) {
    final key = int.tryParse(entry.key);
    final value = _intValue(entry.value);
    if (key != null && key > 0 && value > 0) {
      result[key] = value;
    }
  }
  return result;
}

Set<int> _intSet(Object? json) {
  if (json is! List) {
    return {};
  }
  final result = <int>{};
  for (final item in json) {
    final value = _intValue(item);
    if (value > 0) {
      result.add(value);
    }
  }
  return result;
}

List<T> _enumList<T extends Enum>(List<T> values, Object? json) {
  if (json is! List) {
    return [];
  }
  final result = <T>[];
  for (final item in json) {
    final value = _enumValue(values, item);
    if (value != null) {
      result.add(value);
    }
  }
  return result;
}

List<T?> _nullableEnumList<T extends Enum>(List<T> values, Object? json) {
  if (json is! List) {
    return [];
  }
  final result = <T?>[];
  for (final item in json) {
    result.add(_enumValue(values, item));
  }
  return result;
}

List<T> _objectList<T>(Object? json, T? Function(Object?) parse) {
  if (json is! List) {
    return [];
  }
  final result = <T>[];
  for (final item in json) {
    final value = parse(item);
    if (value != null) {
      result.add(value);
    }
  }
  return result;
}
