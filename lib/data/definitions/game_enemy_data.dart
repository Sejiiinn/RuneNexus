import 'package:flutter/material.dart';

import '../../domain/enemy/enemy_definition.dart';
import '../../domain/enemy/enemy_resistance_profile.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/turret/attack_tag.dart';
import '../../domain/turret/damage_family.dart';

const gameEnemies = <EnemyType, EnemyDefinition>{
  EnemyType.normal: EnemyDefinition(
    type: EnemyType.normal,
    name: '일반',
    maxHp: 35,
    speed: 31.5,
    rewardGold: 5,
    coreDamage: 1,
    color: Color(0xFFC7CED6),
    resistanceProfile: EnemyResistanceProfile.neutral,
  ),
  EnemyType.armored: EnemyDefinition(
    type: EnemyType.armored,
    name: '장갑병',
    maxHp: 40,
    maxArmor: 28,
    speed: 28,
    rewardGold: 7,
    coreDamage: 1,
    color: Color(0xFFF0D878),
    resistanceProfile: EnemyResistanceProfile.neutral,
  ),
  EnemyType.shielded: EnemyDefinition(
    type: EnemyType.shielded,
    name: '보호막병',
    maxHp: 36,
    maxShield: 42,
    shieldRegenRate: 0.04,
    speed: 29,
    rewardGold: 8,
    coreDamage: 1,
    color: Color(0xFF62D9FF),
    resistanceProfile: EnemyResistanceProfile.neutral,
  ),
  EnemyType.fast: EnemyDefinition(
    type: EnemyType.fast,
    name: '빠름',
    maxHp: 22,
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
    speed: 16.8,
    rewardGold: 35,
    coreDamage: 8,
    color: Color(0xFFFF5A66),
    resistanceProfile: EnemyResistanceProfile.neutral,
  ),
  EnemyType.shieldBoss: EnemyDefinition(
    type: EnemyType.shieldBoss,
    name: '균열 방벽체',
    maxHp: 820,
    maxShield: 360,
    shieldRegenRate: 0.025,
    speed: 15,
    rewardGold: 48,
    coreDamage: 10,
    color: Color(0xFF9B8CFF),
    resistanceProfile: EnemyResistanceProfile.neutral,
  ),
  EnemyType.forgeBoss: EnemyDefinition(
    type: EnemyType.forgeBoss,
    name: '용광로 파쇄자',
    maxHp: 760,
    maxArmor: 520,
    speed: 13.5,
    rewardGold: 58,
    coreDamage: 12,
    color: Color(0xFF62E8D6),
    resistanceProfile: EnemyResistanceProfile.neutral,
  ),
};
