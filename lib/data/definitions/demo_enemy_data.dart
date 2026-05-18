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
    maxHp: 35,
    maxArmor: 14,
    speed: 31.5,
    rewardGold: 5,
    coreDamage: 1,
    color: Color(0xFFC7CED6),
    resistanceProfile: EnemyResistanceProfile.neutral,
  ),
  EnemyType.fast: EnemyDefinition(
    type: EnemyType.fast,
    name: '빠름',
    maxHp: 22,
    maxArmor: 5.5,
    speed: 54.6,
    rewardGold: 5,
    coreDamage: 1,
    color: Color(0xFF9CEBFF),
    resistanceProfile: EnemyResistanceProfile(
      tagResistances: {AttackTag.light: -0.5, AttackTag.heavy: 0.5},
    ),
  ),
  EnemyType.tank: EnemyDefinition(
    type: EnemyType.tank,
    name: '탱커',
    maxHp: 104,
    maxArmor: 15.6,
    speed: 21,
    rewardGold: 9,
    coreDamage: 2,
    color: Color(0xFFA9856A),
    resistanceProfile: EnemyResistanceProfile(
      familyResistances: {DamageFamily.physical: 0.2},
      tagResistances: {AttackTag.light: 0.35, AttackTag.heavy: -0.2},
    ),
  ),
  EnemyType.boss: EnemyDefinition(
    type: EnemyType.boss,
    name: '보스',
    maxHp: 623,
    maxArmor: 49.84,
    speed: 16.8,
    rewardGold: 35,
    coreDamage: 8,
    color: Color(0xFFFF5A66),
    resistanceProfile: EnemyResistanceProfile(
      familyResistances: {
        DamageFamily.physical: 0.1,
        DamageFamily.magical: 0.1,
      },
    ),
  ),
};
