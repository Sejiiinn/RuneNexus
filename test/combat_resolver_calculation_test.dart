import 'dart:convert';
import 'dart:io';
import 'package:flame/components.dart';
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
import 'package:rune_nexus/game/systems/combat_resolver.dart';
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
      'real upgraded ${type.name} snapshot keeps resolver and status semantics',
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
  final enemy =
      EnemyComponent(
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
        )
        ..applyPhysicalVulnerability(bonus: .35, duration: 4)
        ..applyElementalVulnerability(bonus: .1, duration: 4);
  const resolver = CombatResolver(
    chainJumpRange: 100,
    burnDamagePerSecondScale: .5,
    burnDurationSeconds: 2,
  );
  const extras = {AttackTag.heavy};
  final multiplier = legacyMultiplier(attack, enemy, extras);
  final burnMultiplier = legacyMultiplier(attack, enemy);
  final base = attack.damage * attack.criticalMultiplier;
  final hit = resolver.resolveAttackDamage(
    attack: attack,
    enemy: enemy,
    baseDamage: base,
    traitMultiplier: 1.3,
    extraTags: extras,
  );
  expect(hit.damage, closeTo(base * 1.3 * multiplier, 1e-10));
  expect(hit.resistanceMultiplier, closeTo(multiplier, 1e-10));
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
            attack.damageOverTimeDamageMultiplier,
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
    'damage': hit.damage,
    'resistanceMultiplier': hit.resistanceMultiplier,
    'effects': expectedEffects,
  };
  // Same snapshot and oracle feed standalone Godot comparison when requested.
  final serialInput = jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
  compareValues(evaluateFixture(serialInput), expected, type.name);
  resolver.applyAttackStatuses(
    attack: attack,
    enemy: enemy,
    damageScale: .75,
    activeSourceTurretPoint: attack.sourceTurretPoint,
  );
  expect(enemy.hp, 10000); // Resolver still does not own HP application.
  if (attack.hasDamageOverTime) {
    expect(
      enemy.totalBurnDamagePerSecond,
      closeTo(
        attack.damage *
            .5 *
            .75 *
            burnMultiplier *
            attack.damageOverTimeDamageMultiplier,
        1e-10,
      ),
    );
    expect(enemy.hasBurnFromSource(attack.sourceTurretPoint), isTrue);
  }
  if (attack.slowDuration > 0 && attack.slowMultiplier < 1) {
    expect(enemy.slowMultiplier, attack.slowMultiplier);
    expect(enemy.slowRemaining, attack.slowDuration);
  }
  if (attack.appliesFrostCrack) {
    expect(enemy.elementalResistanceReduction, .15);
    expect(
      resolver
          .resolveAttackDamage(attack: attack, enemy: enemy, baseDamage: base)
          .damage,
      closeTo(base * legacyMultiplier(attack, enemy), 1e-10),
    );
  }
  return {
    'name': 'snapshot-${type.name}',
    'input': input,
    'expected': expected,
  };
}
