import '../../domain/combat/auto_start_mode.dart';
import '../../domain/combat/game_phase.dart';
import '../../data/definitions/game_core_passive_tree_data.dart' as core_tree;
import '../../domain/core/core_ability.dart';
import '../../domain/core/core_passive_tree.dart';
import '../../domain/daily_quest/daily_quest_type.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/gem/gem_type.dart';
import '../../domain/map/grid_point.dart';
import '../../domain/research/research_type.dart';
import '../../domain/run_upgrade/run_upgrade_type.dart';
import '../../domain/turret/turret_trait_type.dart';
import '../../domain/turret/turret_type.dart';
import '../../domain/turret/turret_target_priority.dart';
import '../../domain/turret_module/turret_module_type.dart';

part 'game_save_enemy_data.dart';
part 'game_save_progression_data.dart';
part 'game_save_turret_data.dart';

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
    this.runCoreCombatSkillStats = SavedCoreCombatSkillStats.empty,
    this.roundNexusHpLost = 0,
    this.emergencyChargeUsedThisRound = false,
    this.finalDefenseUsedThisRound = false,
    required this.turrets,
    required this.enemies,
    required this.spawnQueue,
  });

  static const currentVersion = 1;

  final int version;
  final int savedAtMillis;
  final int gold;
  final int gemShards;
  final double nexusHp;
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
  final SavedCoreCombatSkillStats runCoreCombatSkillStats;
  final double roundNexusHpLost;
  final bool emergencyChargeUsedThisRound;
  final bool finalDefenseUsedThisRound;
  final List<SavedTurret> turrets;
  final List<SavedEnemy> enemies;
  final List<SavedSpawnRequest> spawnQueue;

  bool get hasActiveRun {
    return phase == GamePhase.wave ||
        phase == GamePhase.reward ||
        roundIndex > 0 ||
        completedRounds > 0 ||
        runUpgradeLevels.isNotEmpty ||
        turrets.isNotEmpty ||
        enemies.isNotEmpty ||
        spawnQueue.isNotEmpty ||
        killGoldFractionWallet > 0 ||
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
      'runCoreCombatSkillStats': runCoreCombatSkillStats.toJson(),
      'roundNexusHpLost': roundNexusHpLost,
      'emergencyChargeUsedThisRound': emergencyChargeUsedThisRound,
      'finalDefenseUsedThisRound': finalDefenseUsedThisRound,
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
      nexusHp: _doubleValue(json['nexusHp']),
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

int _nonNegativeInt(Object? value) {
  final parsed = _intValue(value);
  return parsed < 0 ? 0 : parsed;
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

Set<String> _stringSet(Object? json) {
  if (json is! List) {
    return {};
  }
  return {
    for (final item in json)
      if (item is String && item.isNotEmpty) item,
  };
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

Set<T> _enumSet<T extends Enum>(List<T> values, Object? json) {
  if (json is! List) {
    return {};
  }
  final result = <T>{};
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
