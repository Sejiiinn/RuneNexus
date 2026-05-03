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
}
