import 'package:flutter/material.dart';

import 'enemy_resistance_profile.dart';
import 'enemy_type.dart';

const double defaultArmorReductionRate = 0.05;
const double defaultArmorMinimumDamageRate = 0.25;

class EnemyDefinition {
  const EnemyDefinition({
    required this.type,
    required this.name,
    required this.maxHp,
    this.maxShield = 0,
    this.shieldRegenRate = 0,
    this.maxArmor = 0,
    this.armorReductionRate = defaultArmorReductionRate,
    this.armorMinimumDamageRate = defaultArmorMinimumDamageRate,
    required this.speed,
    required this.rewardGold,
    required this.coreDamage,
    required this.color,
    required this.resistanceProfile,
  });

  final EnemyType type;
  final String name;
  final double maxHp;
  final double maxShield;
  final double shieldRegenRate;
  final double maxArmor;
  final double armorReductionRate;
  final double armorMinimumDamageRate;
  final double speed;
  final int rewardGold;
  final int coreDamage;
  final Color color;
  final EnemyResistanceProfile resistanceProfile;
}
