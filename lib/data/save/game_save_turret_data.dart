part of 'game_save_data.dart';

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
    required this.investedGold,
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
  final int investedGold;
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
      'investedGold': investedGold,
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
      investedGold: _intValue(json['investedGold']),
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
