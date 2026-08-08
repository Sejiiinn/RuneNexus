part of 'game_save_data.dart';

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
    this.laneOffsetRatio = 0,
    this.diamondReward = 0,
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
  final double laneOffsetRatio;
  final int diamondReward;
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
      'laneOffsetRatio': laneOffsetRatio,
      'diamondReward': diamondReward,
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
      laneOffsetRatio: _doubleValue(json['laneOffsetRatio']),
      diamondReward: type.isBoss
          ? 0
          : _intValue(json['diamondReward']).clamp(0, 3).toInt(),
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
