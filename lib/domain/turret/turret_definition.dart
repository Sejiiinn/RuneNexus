import 'package:flutter/material.dart';

import 'attack_tag.dart';
import 'damage_family.dart';
import 'turret_type.dart';

class TurretDefinition {
  const TurretDefinition({
    required this.type,
    required this.name,
    required this.cost,
    required this.damage,
    required this.range,
    required this.attackRate,
    required this.projectileSpeed,
    required this.description,
    required this.damageFamily,
    required this.attackTags,
    required this.color,
    this.splashRadius = 0,
    this.centeredAreaAttack = false,
    this.instantHit = false,
    this.aimDuration = 0,
    this.criticalChance = 0,
    this.criticalDamageMultiplier = 1.5,
    this.slowMultiplier = 1,
    this.slowDuration = 0,
  });

  final TurretType type;
  final String name;
  final int cost;
  final double damage;
  final double range;
  final double attackRate;
  final double projectileSpeed;
  final String description;
  final DamageFamily damageFamily;
  final Set<AttackTag> attackTags;
  final Color color;
  final double splashRadius;
  final bool centeredAreaAttack;
  final bool instantHit;
  final double aimDuration;
  final double criticalChance;
  final double criticalDamageMultiplier;
  final double slowMultiplier;
  final double slowDuration;
}
