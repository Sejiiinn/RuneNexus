import 'dart:convert';
import 'dart:io';
import 'package:vector_math/vector_math_64.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_turret_data.dart';
import 'package:rune_nexus/domain/enemy/enemy_definition.dart';
import 'package:rune_nexus/domain/enemy/enemy_resistance_profile.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/domain/gem/gem_type.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/turret/attack_tag.dart';
import 'package:rune_nexus/domain/turret/damage_family.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/turret/turret_trait_type.dart';
import 'package:rune_nexus/game/components/enemy_component.dart';
import 'package:rune_nexus/game/components/turret_component.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import '../tool/combat/calculation_fixture.dart';
import '../tool/verify_combat_calculation.dart' as parity;

// Frozen pre-extraction formula, independent of the new pure implementation.
double legacyMultiplier(
  TurretAttackSnapshot attack,
  EnemyComponent enemy, [
  Set<AttackTag> extras = const {},
]) {
  final profile = enemy.definition.resistanceProfile;
  var family = profile.familyResistance(attack.definition.damageFamily);
  if (attack.definition.damageFamily == DamageFamily.physical) {
    family -=
        enemy.physicalResistanceReduction + attack.physicalResistanceReduction;
  }
  if (attack.definition.damageFamily == DamageFamily.elemental) {
    family -= enemy.elementalResistanceReduction;
  }
  double multiplier(double r) => 1 - (r > .9 ? .9 : r);
  var result = multiplier(family);
  for (final tag in {...attack.definition.attackTags, ...extras}) {
    result *= multiplier(profile.tagResistance(tag));
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final type in gameTurrets.keys) {
    test(
      'real upgraded ${type.name} snapshot keeps pure damage and status semantics',
      () {
        verifySnapshot(type);
      },
    );
  }
  test(
    'Godot agrees with real firing snapshots when executable is available',
    () async {
      final godot =
          Platform.environment['GODOT_BIN'] ??
          '${Directory.current.path}/build/godot-preview/tools/Godot.app/Contents/MacOS/Godot';
      if (!File(godot).existsSync()) {
        markTestSkipped(
          'Godot unavailable; run with GODOT_BIN for snapshot parity',
        );
        return;
      }
      final generated = gameTurrets.keys.map(verifySnapshot).toList();
      final directory = Directory.systemTemp.createTempSync(
        'snapshot-fixtures-',
      );
      try {
        final file = File('${directory.path}/fixtures.json')
          ..writeAsStringSync(jsonEncode(generated));
        await parity.main([godot, file.path]);
      } finally {
        directory.deleteSync(recursive: true);
      }
    },
  );
}

Map<String, Object?> verifySnapshot(TurretType type) {
  final game = RuneNexusGame();
  final turret =
      TurretComponent(
          gridPoint: const GridPoint(2, 3),
          definition: gameTurrets[type]!,
          game: game,
          center: Vector2.zero(),
          tileSize: 48,
        )
        ..upgradeLevel()
        ..upgradeLevel();
  if (type == TurretType.magic) {
    turret.choosePrimaryTrait(TurretTraitType.highHeatBurn);
    turret.equipGem(GemType.damageOverTime, 0);
    turret.equipGem(GemType.armorPiercing, 1);
  }
  if (type == TurretType.frost) {
    for (var i = 0; i < 4; i++) {
      turret.upgradeLevel();
    }
    turret.choosePrimaryTrait(TurretTraitType.coolingCycle);
    turret.chooseSecondaryTrait(TurretTraitType.frostCrack);
  }
  final attack = turret.createAttackSnapshot(criticalMultiplier: 1.65);
  // Changing the producer after firing must not alter the input snapshot.
  final snapshotDamage = attack.damage;
  turret.upgradeLevel();
  expect(attack.damage, snapshotDamage);
  final enemy = EnemyComponent(
    definition: const EnemyDefinition(
      type: EnemyType.normal,
      name: 'fixture',
      maxHp: 10000,
      speed: 1,
      rewardGold: 1,
      coreDamage: 1,
      color: Colors.white,
      resistanceProfile: EnemyResistanceProfile(
        familyResistances: {
          DamageFamily.physical: .2,
          DamageFamily.elemental: .3,
        },
        tagResistances: {
          AttackTag.light: .1,
          AttackTag.heavy: -.2,
          AttackTag.damageOverTime: .25,
          AttackTag.cooling: .9,
        },
      ),
    ),
    maxHp: 10000,
    path: [Vector2.zero(), Vector2(500, 0)],
    game: game,
  );
  enemy.applyNativeCombatState({
    ...enemy.toSaveData().toJson(),
    'physicalVulnerabilityBonus': .35,
    'physicalVulnerabilityRemaining': 4.0,
    'elementalVulnerabilityBonus': .1,
    'elementalVulnerabilityRemaining': 4.0,
  });
  const extras = {AttackTag.heavy};
  final multiplier = legacyMultiplier(attack, enemy, extras);
  final burnMultiplier = legacyMultiplier(attack, enemy);
  final base = attack.damage * attack.criticalMultiplier;
  final input = <String, Object?>{
    'baseDamage': base,
    'traitMultiplier': 1.3,
    'resistance': {
      'family': attack.definition.damageFamily.name,
      'familyResistance': enemy.definition.resistanceProfile.familyResistance(
        attack.definition.damageFamily,
      ),
      'tags': attack.definition.attackTags.map((tag) => tag.name).toList(),
      'extraTags': extras.map((tag) => tag.name).toList(),
      'tagResistances': {
        for (final e
            in enemy.definition.resistanceProfile.tagResistances.entries)
          e.key.name: e.value,
      },
      'enemyPhysicalReduction': enemy.physicalResistanceReduction,
      'attackPhysicalReduction': attack.physicalResistanceReduction,
      'enemyElementalReduction': enemy.elementalResistanceReduction,
    },
    'status': {
      'damage': attack.damage,
      'burnDamagePerSecondScale': .5,
      'burnDurationSeconds': 2,
      'hasDamageOverTime': attack.hasDamageOverTime,
      'damageScale': .75,
      'criticalMultiplier': attack.criticalMultiplier,
      'damageOverTimeDamageMultiplier': attack.damageOverTimeDamageMultiplier,
      'damageOverTimeDurationMultiplier':
          attack.damageOverTimeDurationMultiplier,
      'ignoresArmorReduction': attack.ignoresArmorReduction,
      'slowDuration': attack.slowDuration,
      'slowMultiplier': attack.slowMultiplier,
      'appliesFrostCrack': attack.appliesFrostCrack,
    },
  };
  final expectedEffects = <Map<String, Object?>>[
    if (attack.hasDamageOverTime)
      {
        'type': 'burn',
        'damagePerSecond':
            attack.damage *
            .5 *
            .75 *
            burnMultiplier *
            attack.damageOverTimeDamageMultiplier *
            (1 + (attack.criticalMultiplier - 1) * .5),
        'duration': 2 * attack.damageOverTimeDurationMultiplier,
        'damageMultiplier': burnMultiplier,
        'ignoreArmorReduction': attack.ignoresArmorReduction,
      },
    if (attack.slowDuration > 0 && attack.slowMultiplier < 1) ...[
      {
        'type': 'slow',
        'multiplier': attack.slowMultiplier,
        'duration': attack.slowDuration,
      },
      if (attack.appliesFrostCrack)
        {
          'type': 'elementalVulnerability',
          'bonus': .15,
          'duration': attack.slowDuration,
        },
    ],
  ];
  final expected = {
    'damage': base * 1.3 * multiplier,
    'resistanceMultiplier': multiplier,
    'effects': expectedEffects,
  };
  // Same snapshot and oracle feed standalone Godot comparison when requested.
  final serialInput = jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
  compareValues(evaluateFixture(serialInput), expected, type.name);
  // Status application is exercised by native runtime regression tests.
  return {
    'name': 'snapshot-${type.name}',
    'input': input,
    'expected': expected,
  };
}
