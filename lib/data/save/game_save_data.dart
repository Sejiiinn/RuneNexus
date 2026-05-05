import '../../domain/combat/game_phase.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/gem/gem_type.dart';
import '../../domain/map/grid_point.dart';
import '../../domain/turret/turret_type.dart';

class GameSaveData {
  const GameSaveData({
    required this.version,
    required this.savedAtMillis,
    required this.gold,
    required this.nexusHp,
    required this.stageNumber,
    required this.roundIndex,
    required this.completedRounds,
    required this.phase,
    required this.progression,
    required this.gemInventory,
    required this.rewardOptions,
    required this.turrets,
    required this.enemies,
    required this.spawnQueue,
  });

  static const currentVersion = 1;

  final int version;
  final int savedAtMillis;
  final int gold;
  final int nexusHp;
  final int stageNumber;
  final int roundIndex;
  final int completedRounds;
  final GamePhase phase;
  final SavedProgression progression;
  final Map<GemType, int> gemInventory;
  final List<GemType> rewardOptions;
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
        gemInventory.isNotEmpty ||
        rewardOptions.isNotEmpty;
  }

  Map<String, Object?> toJson() {
    return {
      'version': version,
      'savedAtMillis': savedAtMillis,
      'gold': gold,
      'nexusHp': nexusHp,
      'stageNumber': stageNumber,
      'roundIndex': roundIndex,
      'completedRounds': completedRounds,
      'phase': phase.name,
      'progression': progression.toJson(),
      'gemInventory': gemInventory.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'rewardOptions': rewardOptions.map((type) => type.name).toList(),
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

    return GameSaveData(
      version: version,
      savedAtMillis: _intValue(json['savedAtMillis']),
      gold: _intValue(json['gold']),
      nexusHp: _intValue(json['nexusHp']),
      stageNumber: _intValue(json['stageNumber'], fallback: 1),
      roundIndex: _intValue(json['roundIndex']),
      completedRounds: _intValue(json['completedRounds']),
      phase:
          _enumValue(GamePhase.values, json['phase']) ?? GamePhase.preparation,
      progression: SavedProgression.fromJson(json['progression']),
      gemInventory: _enumIntMap(GemType.values, json['gemInventory']),
      rewardOptions: _enumList(GemType.values, json['rewardOptions']),
      turrets: _objectList(json['turrets'], SavedTurret.fromJson),
      enemies: _objectList(json['enemies'], SavedEnemy.fromJson),
      spawnQueue: _objectList(json['spawnQueue'], SavedSpawnRequest.fromJson),
    );
  }
}

class SavedProgression {
  const SavedProgression({
    required this.runes,
    required this.lastRunRuneReward,
    required this.startingGoldUpgradeLevel,
    required this.nexusHpUpgradeLevel,
    required this.unlockedStageCount,
  });

  final int runes;
  final int lastRunRuneReward;
  final int startingGoldUpgradeLevel;
  final int nexusHpUpgradeLevel;
  final int unlockedStageCount;

  Map<String, Object?> toJson() {
    return {
      'runes': runes,
      'lastRunRuneReward': lastRunRuneReward,
      'startingGoldUpgradeLevel': startingGoldUpgradeLevel,
      'nexusHpUpgradeLevel': nexusHpUpgradeLevel,
      'unlockedStageCount': unlockedStageCount,
    };
  }

  static SavedProgression fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return SavedProgression(
      runes: _intValue(map['runes']),
      lastRunRuneReward: _intValue(map['lastRunRuneReward']),
      startingGoldUpgradeLevel: _intValue(map['startingGoldUpgradeLevel']),
      nexusHpUpgradeLevel: _intValue(map['nexusHpUpgradeLevel']),
      unlockedStageCount: _intValue(map['unlockedStageCount'], fallback: 1),
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
  });

  final int x;
  final int y;
  final TurretType type;
  final int level;
  final int slotLimit;
  final double cooldown;
  final List<GemType> equippedGems;

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
    return SavedTurret(
      x: _intValue(json['x']),
      y: _intValue(json['y']),
      type: type,
      level: _intValue(json['level'], fallback: 1),
      slotLimit: _intValue(json['slotLimit'], fallback: 1),
      cooldown: _doubleValue(json['cooldown']),
      equippedGems: _enumList(GemType.values, json['equippedGems']),
    );
  }
}

class SavedEnemy {
  const SavedEnemy({
    required this.type,
    required this.maxHp,
    required this.hp,
    required this.distanceTravelled,
    required this.burnRemaining,
    required this.burnDamagePerSecond,
    required this.burnDamageMultiplier,
    required this.poisonRemaining,
    required this.poisonDamagePerSecond,
    required this.poisonDamageMultiplier,
    required this.poisonStacks,
    required this.slowRemaining,
    required this.slowMultiplier,
  });

  final EnemyType type;
  final double maxHp;
  final double hp;
  final double distanceTravelled;
  final double burnRemaining;
  final double burnDamagePerSecond;
  final double burnDamageMultiplier;
  final double poisonRemaining;
  final double poisonDamagePerSecond;
  final double poisonDamageMultiplier;
  final int poisonStacks;
  final double slowRemaining;
  final double slowMultiplier;

  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'maxHp': maxHp,
      'hp': hp,
      'distanceTravelled': distanceTravelled,
      'burnRemaining': burnRemaining,
      'burnDamagePerSecond': burnDamagePerSecond,
      'burnDamageMultiplier': burnDamageMultiplier,
      'poisonRemaining': poisonRemaining,
      'poisonDamagePerSecond': poisonDamagePerSecond,
      'poisonDamageMultiplier': poisonDamageMultiplier,
      'poisonStacks': poisonStacks,
      'slowRemaining': slowRemaining,
      'slowMultiplier': slowMultiplier,
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
    return SavedEnemy(
      type: type,
      maxHp: _doubleValue(json['maxHp']),
      hp: _doubleValue(json['hp']),
      distanceTravelled: _doubleValue(json['distanceTravelled']),
      burnRemaining: _doubleValue(json['burnRemaining']),
      burnDamagePerSecond: _doubleValue(json['burnDamagePerSecond']),
      burnDamageMultiplier: _doubleValue(
        json['burnDamageMultiplier'],
        fallback: 1,
      ),
      poisonRemaining: _doubleValue(json['poisonRemaining']),
      poisonDamagePerSecond: _doubleValue(json['poisonDamagePerSecond']),
      poisonDamageMultiplier: _doubleValue(
        json['poisonDamageMultiplier'],
        fallback: 1,
      ),
      poisonStacks: _intValue(json['poisonStacks']),
      slowRemaining: _doubleValue(json['slowRemaining']),
      slowMultiplier: _doubleValue(json['slowMultiplier'], fallback: 1),
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

double _doubleValue(Object? value, {double fallback = 0}) {
  return switch (value) {
    int() => value.toDouble(),
    double() => value,
    _ => fallback,
  };
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
