import 'package:flutter/material.dart';

import '../../domain/enemy/enemy_definition.dart';
import '../../domain/enemy/enemy_resistance_profile.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/turret/attack_tag.dart';
import '../../domain/turret/damage_family.dart';

const demoEnemies = <EnemyType, EnemyDefinition>{
  EnemyType.normal: EnemyDefinition(
    type: EnemyType.normal,
    name: '일반',
    maxHp: 45,
    speed: 31.5,
    rewardGold: 3,
    coreDamage: 1,
    color: Color(0xFFC7CED6),
    resistanceProfile: EnemyResistanceProfile.neutral,
  ),
  EnemyType.fast: EnemyDefinition(
    type: EnemyType.fast,
    name: '빠름',
    maxHp: 28,
    speed: 54.6,
    rewardGold: 3,
    coreDamage: 1,
    color: Color(0xFF9CEBFF),
    resistanceProfile: EnemyResistanceProfile(
      tagMultipliers: {AttackTag.light: 1.5, AttackTag.heavy: 0.5},
    ),
  ),
  EnemyType.tank: EnemyDefinition(
    type: EnemyType.tank,
    name: '탱커',
    maxHp: 135,
    speed: 21,
    rewardGold: 6,
    coreDamage: 2,
    color: Color(0xFFA9856A),
    resistanceProfile: EnemyResistanceProfile(
      familyMultipliers: {DamageFamily.physical: 0.8},
      tagMultipliers: {AttackTag.light: 0.65, AttackTag.heavy: 1.2},
    ),
  ),
  EnemyType.boss: EnemyDefinition(
    type: EnemyType.boss,
    name: '보스',
    maxHp: 900,
    speed: 16.8,
    rewardGold: 24,
    coreDamage: 8,
    color: Color(0xFFFF5A66),
    resistanceProfile: EnemyResistanceProfile(
      familyMultipliers: {
        DamageFamily.physical: 0.9,
        DamageFamily.magical: 0.9,
      },
      tagMultipliers: {AttackTag.damageOverTime: 0.75},
    ),
  ),
};
