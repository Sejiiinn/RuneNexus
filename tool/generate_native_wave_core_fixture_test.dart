import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/domain/core/core_ability.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/domain/wave/wave_definition.dart';
import 'package:rune_nexus/game/systems/core_combat_skill_controller.dart';
import 'package:rune_nexus/game/systems/wave_spawner.dart';

// Explicit fixture generation, not part of the ordinary test directory.
void main() {
  test('capture original Dart wave/core timer transitions', () {
    const wave = WaveDefinition(
      round: 1,
      previewText: 'native timing reference',
      clearRewardGold: 0,
      groups: [
        SpawnGroup(enemyType: EnemyType.normal, count: 3, interval: 0.05),
        SpawnGroup(
          enemyType: EnemyType.fast,
          count: 2,
          interval: 0.1,
          startAfterPrevious: true,
          followDelay: 0.2,
        ),
        SpawnGroup(
          enemyType: EnemyType.boss,
          count: 1,
          interval: 1,
          startDelay: 1.0,
        ),
      ],
    );
    final spawner = WaveSpawner()..start(wave, initialDelay: 1.4);
    final schedule = spawner.toSaveData().map((v) => v.toJson()).toList();
    final waveFrames = <Map<String, Object?>>[];
    for (final dt in [0.0, 0.7, 0.69, 0.01, 0.18, 0.2, 0.5, 2.0]) {
      waveFrames.add({
        'dt': dt,
        'spawned': spawner.update(dt).map((v) => v.name).toList(),
        'remaining': spawner.toSaveData().map((v) => v.toJson()).toList(),
      });
    }
    final cores = <Map<String, Object?>>[];
    for (final skill in [
      CoreCombatSkill.guardianBeam,
      CoreCombatSkill.riftMark,
    ]) {
      final controller = CoreCombatSkillController(
        guardianBeamInterval: 5,
        guardianBeamDuration: 1,
        guardianBeamTickInterval: 0.1,
        riftMarkInterval: 10,
        attackSyncDuration: 2,
        initialSkill: skill,
      )..resetCycle(cooldownRecoveryMultiplier: 1.25);
      final frames = <Map<String, Object?>>[];
      // Empty field, exact readiness, activation, pause, clipped end, repeated
      // third activation, emergency eligibility and reset are all represented.
      final inputs = <Map<String, Object?>>[
        {'dt': 10.0, 'target': false},
        {'dt': 0.0, 'target': true},
        {'dt': 0.01, 'target': true},
        {'dt': 0.09, 'target': true},
        {'dt': 0.0, 'target': true},
        {'dt': 0.21, 'target': false},
        {'dt': 2.0, 'target': true},
        {'dt': 0.2, 'target': true, 'emergency': 0.35},
        {'dt': 10.0, 'target': true},
        {'dt': 1.1, 'target': false},
        {'dt': 10.0, 'target': true},
        {'dt': 0.1, 'target': true},
        {'dt': 0.2, 'target': false, 'reset': true},
      ];
      for (final input in inputs) {
        if (input['reset'] == true) {
          controller.resetCycle(cooldownRecoveryMultiplier: 1.25);
        }
        bool? emergency;
        if (input['emergency'] is double) {
          emergency = controller.applyEmergencyCharge(
            recoveryRate: input['emergency']! as double,
            cooldownRecoveryMultiplier: 1.25,
          );
        }
        final ticks = <double>[];
        final powers = <double>[];
        double power(int number) => 1.5 * (number % 3 == 0 ? 1.2 : 1.0);
        controller.update(
          input['dt']! as double,
          cooldownRecoveryMultiplier: 1.25,
          hasGuardianBeamTarget: () => input['target'] == true,
          guardianBeamBaseDamage: () => 100.0,
          powerMultiplierForActivation: power,
          applyGuardianBeamTick: ticks.add,
          hasRiftMarkCandidate: input['target'] == true,
          applyRiftMark: () {
            powers.add(
              controller.activate(powerMultiplierForActivation: power),
            );
            return true;
          },
        );
        frames.add({
          ...input,
          'state': controller.nativeRuntimeState(),
          'ticks': ticks,
          'powers': powers,
          'emergencyUsed': ?emergency,
        });
      }
      cores.add({'skill': skill.name, 'frames': frames});
    }
    final output = {
      'source': 'Dart WaveSpawner/CoreCombatSkillController',
      'baselineCommit': '0241ef6',
      'sourceFiles': [
        'lib/game/systems/wave_spawner.dart',
        'lib/game/systems/core_combat_skill_controller.dart',
      ],
      'schedule': schedule,
      'waveFrames': waveFrames,
      'cores': cores,
    };
    File('test/fixtures/native_wave_core_timing.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(output)}\n',
    );
  });
}
