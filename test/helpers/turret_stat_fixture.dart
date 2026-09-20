import 'package:rune_nexus/domain/combat/attack_calculation.dart';
import 'package:flame/components.dart';
import 'package:rune_nexus/data/definitions/game_turret_data.dart';
import 'package:rune_nexus/data/definitions/game_gem_data.dart';
import 'package:rune_nexus/data/definitions/game_enemy_data.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/domain/combat/turret_stat_input.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/domain/gem/gem_type.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/turret/turret_definition.dart';
import 'package:rune_nexus/domain/turret/damage_family.dart';
import 'package:rune_nexus/domain/turret_module/turret_module_type.dart';
import 'package:rune_nexus/game/components/turret_component.dart';
import 'package:rune_nexus/game/components/enemy_component.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';

class StatFixtureGame extends RuneNexusGame {
  double boost = 0;
  double critBonus = 0;
  double scale = 1;
  @override
  int get maxTurretLinkSlotLimit => 3;
  @override
  double get boardDistanceScale => scale;
  @override
  double get passiveNumericGemEffectMultiplier => 1 + boost * .18;
  @override
  double towerDamageMultiplierFor(DamageFamily family) => 1 + boost * .37;
  @override
  double get corePassiveTurretDamageMultiplier => 1 + boost * .21;
  @override
  double get corePassiveTurretAttackRateMultiplier => 1 + boost * .16;
  @override
  double get criticalChanceProgressionBonusRate => critBonus;
  @override
  double get criticalDamageProgressionBonusRate => boost * .15;
  @override
  TurretModuleEffect turretModuleEffectFor(TurretType type) =>
      TurretModuleEffect(
        damageIncreaseRate: boost * 0.13,
        attackRateIncreaseRate: boost * 0.13,
        criticalChanceBonusRate: boost * 0.13,
        criticalDamageBonusRate: boost * 0.13,
        rangeIncreaseRate: boost * 0.13,
        gemEffectIncreaseRate: boost * 0.2,
        splashRadiusIncreaseRate: boost * 0.13,
        damageOverTimeIncreaseRate: boost * 0.13,
        burnDurationIncreaseRate: boost * 0.13,
        slowDurationIncreaseRate: boost * 0.13,
        slowStrengthBonusRate: boost * 0.13,
        lightningChainDamageIncreaseRate: boost * 0.13,
        projectileSpeedIncreaseRate: boost * 0.13,
        splashSecondaryDamageBonusRate: boost * 0.13,
        lightningChainRangeIncreaseRate: boost * 0.13,
        aimSpeedIncreaseRate: boost * 0.13,
      );
}

TurretStatInput fixtureInput(
  TurretComponent turret,
  StatFixtureGame game,
  bool cleanup,
) {
  final definition = turret.definition;
  return TurretStatInput(
    definition: TurretStatDefinition(
      type: definition.type,
      damageFamily: AttackDamageFamily.values.byName(
        definition.damageFamily.name,
      ),
      attackTags: definition.attackTags.map((tag) => tag.name).toSet(),
      damage: definition.damage,
      range: definition.range,
      attackRate: definition.attackRate,
      projectileSpeed: definition.projectileSpeed,
      projectileCount: definition.projectileCount,
      splashRadius: definition.splashRadius,
      centeredAreaAttack: definition.centeredAreaAttack,
      instantHit: definition.instantHit,
      aimDuration: definition.aimDuration,
      criticalChance: definition.criticalChance,
      criticalDamageMultiplier: definition.criticalDamageMultiplier,
      slowMultiplier: definition.slowMultiplier,
      slowDuration: definition.slowDuration,
    ),
    moduleEffect: game.turretModuleEffectFor(definition.type),
    gems: turret.equippedGems.toSet(),
    primaryTrait: turret.primaryTrait,
    secondaryTrait: turret.secondaryTrait,
    level: turret.level,
    chainCleanupActive: cleanup,
    passiveNumericGemEffectMultiplier: game.passiveNumericGemEffectMultiplier,
    towerDamageMultiplier: game.towerDamageMultiplierFor(
      definition.damageFamily,
    ),
    corePassiveTurretDamageMultiplier: game.corePassiveTurretDamageMultiplier,
    corePassiveTurretAttackRateMultiplier:
        game.corePassiveTurretAttackRateMultiplier,
    boardDistanceScale: game.boardDistanceScale,
    lightningChainJumpRange: game.lightningChainJumpRange,
    criticalChanceProgressionBonusRate: game.criticalChanceProgressionBonusRate,
    criticalDamageProgressionBonusRate: game.criticalDamageProgressionBonusRate,
    criticalChanceGemValue: gameGems[GemType.criticalChance]!.value,
    aimSpeedGemValue: gameGems[GemType.aimSpeed]!.value,
    explosionGemValue: gameGems[GemType.explosion]!.value,
  );
}

Map<String, Object?> snapshotOutput(TurretAttackSnapshot a) => {
  'damage': a.damage,
  'range': a.range,
  'effectAreaMultiplier': a.effectAreaMultiplier,
  'centeredAreaRadius': a.centeredAreaRadius,
  'chainCount': a.chainCount,
  'splashRadius': a.splashRadius,
  'splashSecondaryDamageMultiplier': a.splashSecondaryDamageMultiplier,
  'projectileSpeed': a.projectileSpeed,
  'criticalMultiplier': a.criticalMultiplier,
  'physicalResistanceReduction': a.physicalResistanceReduction,
  'ignoresArmorReduction': a.ignoresArmorReduction,
  'damageOverTimeDamageMultiplier': a.damageOverTimeDamageMultiplier,
  'damageOverTimeDurationMultiplier': a.damageOverTimeDurationMultiplier,
  'slowDuration': a.slowDuration,
  'slowMultiplier': a.slowMultiplier,
  'hasChain': a.hasChain,
  'appliesFrostCrack': a.appliesFrostCrack,
  'appliesIgnitionBurst': a.appliesIgnitionBurst,
  'spreadsChainIgnition': a.spreadsChainIgnition,
  'appliesChainCleanup': a.appliesChainCleanup,
  'appliesSuppressiveFire': a.appliesSuppressiveFire,
  'appliesExposedMark': a.appliesExposedMark,
  'appliesOverheatMagazine': a.appliesOverheatMagazine,
  'appliesCompressedCharge': a.appliesCompressedCharge,
  'appliesFinishingShot': a.appliesFinishingShot,
  'appliesFocusedLightning': a.appliesFocusedLightning,
  'lightningChainMaxJumps': a.lightningChainMaxJumps,
  'lightningChainDamageMultiplier': a.lightningChainDamageMultiplier,
  'lightningChainJumpRange': a.lightningChainJumpRange,
  'hasDamageOverTime': a.hasDamageOverTime,
};
Map<String, Object?> componentOutput(TurretComponent t) => {
  'damage': t.damage,
  'range': t.range,
  'attackRate': t.attackRate,
  'projectileSpeed': t.projectileSpeed,
  'projectileCount': t.projectileCount,
  'damageOverTimeDamageMultiplier': t.damageOverTimeDamageMultiplier,
  'damageOverTimeDurationMultiplier': t.damageOverTimeDurationMultiplier,
  'slowMultiplier': t.slowMultiplier,
  'slowDuration': t.slowDuration,
  'appliesFrostCrack': t.appliesFrostCrack,
  'appliesIgnitionBurst': t.appliesIgnitionBurst,
  'spreadsChainIgnition': t.spreadsChainIgnition,
  'physicalResistanceReduction': t.physicalResistanceReduction,
  'effectAreaMultiplier': t.effectAreaMultiplier,
  'centeredAreaRadius': t.centeredAreaRadius,
  'splashSecondaryDamageMultiplier': t.splashSecondaryDamageMultiplier,
  'splashRadius': t.splashRadius,
  'chainCount': t.chainCount,
  'ignoresArmorReduction': t.ignoresArmorReduction,
  'lightningChainMaxJumps': t.lightningChainMaxJumps,
  'lightningChainDamageMultiplier': t.lightningChainDamageMultiplier,
  'appliesLightningRecovery': t.appliesLightningRecovery,
  'criticalChance': t.criticalChance,
  'criticalDamageMultiplier': t.criticalDamageMultiplier,
  'aimDuration': t.aimDuration,
  'levels': {
    for (final level in [-4, 1, 3, 7, 10, 99])
      '$level': {
        'damage': t.damageAtLevel(level),
        'range': t.rangeAtLevel(level),
        'attackRate': t.attackRateAtLevel(level),
        'slowMultiplier': t.slowMultiplierAtLevel(level),
        'aimDuration': t.aimDurationAtLevel(level),
      },
  },
  'snapshot': snapshotOutput(t.createAttackSnapshot(criticalMultiplier: 1.65)),
};

({TurretComponent turret, StatFixtureGame game, bool cleanup}) buildFixture(
  Map<String, dynamic> config,
) {
  final game = StatFixtureGame()
    ..boost = (config['boost'] as num).toDouble()
    ..critBonus = (config['critBonus'] as num).toDouble()
    ..scale = (config['scale'] as num).toDouble();
  final type = TurretType.values.byName(config['type'] as String);
  final d = gameTurrets[type]!;
  final definition = TurretDefinition(
    type: d.type,
    damageFamily: d.damageFamily,
    attackTags: d.attackTags,
    damage: d.damage,
    range: d.range,
    attackRate: d.attackRate,
    projectileSpeed: d.projectileSpeed,
    projectileCount: d.projectileCount,
    splashRadius: d.splashRadius,
    centeredAreaAttack: d.centeredAreaAttack,
    instantHit: d.instantHit,
    aimDuration: (config['baseAim'] as num?)?.toDouble() ?? d.aimDuration,
    criticalChance: d.criticalChance,
    criticalDamageMultiplier: d.criticalDamageMultiplier,
    slowMultiplier:
        (config['baseSlow'] as num?)?.toDouble() ?? d.slowMultiplier,
    slowDuration: d.slowDuration,
    name: d.name,
    cost: d.cost,
    description: d.description,
    color: d.color,
  );
  final t = TurretComponent(
    gridPoint: const GridPoint(2, 3),
    definition: definition,
    game: game,
    center: Vector2.zero(),
    tileSize: 48,
  );
  final save = t.toSaveData().toJson();
  save['level'] = config['level'];
  save['slotLimit'] = 3;
  save['equippedGemSlots'] = config['gems'];
  save['primaryTrait'] = config['primary'];
  save['secondaryTrait'] = config['secondary'];
  t.restoreFromSaveData(SavedTurret.fromJson(save)!);
  final cleanup = config['cleanup'] as bool;
  if (cleanup) {
    final e = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    );
    t.registerDirectHitTraits(e);
    t.handleEnemyKilled(e);
  }
  return (turret: t, game: game, cleanup: cleanup);
}
