import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/domain/core/core_ability.dart';
import 'package:rune_nexus/game/systems/core_combat_skill_controller.dart';

void main() {
  test('run skill capture resets stats and null skill resets its cycle', () {
    final controller = _controller();
    controller
      ..recordDirectDamage(12)
      ..recordBonusDamage(7)
      ..activate(powerMultiplierForActivation: (_) => 1);

    controller.captureRunSkill(
      CoreCombatSkill.riftMark,
      cooldownRecoveryMultiplier: 1,
    );

    expect(controller.runSkill, CoreCombatSkill.riftMark);
    expect(controller.activationCount, 0);
    expect(controller.directDamageDealt, 0);
    expect(controller.bonusDamageDealt, 0);
    expect(controller.cooldownSeconds(cooldownRecoveryMultiplier: 1), 10);

    controller.captureRunSkill(null, cooldownRecoveryMultiplier: 1);
    expect(controller.isAvailable, isFalse);
    expect(controller.cooldownSeconds(cooldownRecoveryMultiplier: 1), 0);
    expect(_update(controller, 1, hasGuardianBeamTarget: true), isFalse);
    expect(controller.isAttackSyncActive, isFalse);
  });

  test('haste shortens guardian beam and rift mark cooldowns', () {
    final guardian = _controller();
    guardian.resetCycle(cooldownRecoveryMultiplier: 1.25);
    expect(guardian.cooldownInterval(cooldownRecoveryMultiplier: 1.25), 4);
    expect(_update(guardian, 3.99, hasGuardianBeamTarget: true), isFalse);
    expect(_update(guardian, 0.01, hasGuardianBeamTarget: true), isTrue);
    expect(guardian.activationCount, 1);

    final rift = _controller(initialSkill: CoreCombatSkill.riftMark);
    rift.resetCycle(cooldownRecoveryMultiplier: 1.25);
    var applications = 0;
    expect(rift.cooldownInterval(cooldownRecoveryMultiplier: 1.25), 8);
    expect(
      _update(
        rift,
        7.99,
        cooldownRecoveryMultiplier: 1.25,
        hasRiftMarkCandidate: true,
        applyRiftMark: () {
          applications++;
          return true;
        },
      ),
      isFalse,
    );
    expect(
      _update(
        rift,
        0.01,
        cooldownRecoveryMultiplier: 1.25,
        hasRiftMarkCandidate: true,
        applyRiftMark: () {
          applications++;
          return true;
        },
      ),
      isTrue,
    );
    expect(applications, 1);
    expect(rift.cooldownSeconds(cooldownRecoveryMultiplier: 1.25), 8);
  });

  test('activation updates count, attack sync, power, and actual stats', () {
    final controller = _controller();
    final ticks = <double>[];

    expect(
      _update(
        controller,
        5,
        hasGuardianBeamTarget: true,
        guardianBeamBaseDamage: () {
          expect(controller.isAttackSyncActive, isFalse);
          return 100;
        },
        powerMultiplierForActivation: (activationNumber) {
          expect(activationNumber, 1);
          expect(controller.activationCount, 1);
          expect(controller.isAttackSyncActive, isTrue);
          return 1.5;
        },
        applyGuardianBeamTick: ticks.add,
      ),
      isTrue,
    );

    expect(controller.activationCount, 1);
    expect(controller.isAttackSyncActive, isTrue);
    expect(controller.isGuardianBeamActive, isTrue);
    expect(ticks, hasLength(1));
    expect(ticks.single, closeTo(15, 0.0001));
    expect(
      controller.guardianBeamDamage(
        baseDamage: () => 999,
        powerMultiplierForActivation: (_) => 999,
      ),
      closeTo(150, 0.0001),
    );

    expect(controller.recordDirectDamage(12.5), isTrue);
    expect(controller.recordDirectDamage(0), isFalse);
    expect(controller.recordBonusDamage(7.25), isTrue);
    expect(controller.recordBonusDamage(-1), isFalse);
    expect(controller.directDamageDealt, 12.5);
    expect(controller.bonusDamageDealt, 7.25);

    _update(controller, 0.5);
    expect(controller.isAttackSyncActive, isTrue);
    _update(controller, 1.5);
    expect(controller.isAttackSyncActive, isFalse);
  });

  test('rift mark consumes its cycle only after an actual application', () {
    final controller = _controller(initialSkill: CoreCombatSkill.riftMark);
    var callbackCount = 0;

    expect(_update(controller, 10), isFalse);
    expect(controller.cooldownSeconds(cooldownRecoveryMultiplier: 1), 0);

    expect(
      _update(
        controller,
        0.1,
        hasRiftMarkCandidate: true,
        applyRiftMark: () {
          callbackCount++;
          return false;
        },
      ),
      isFalse,
    );
    expect(callbackCount, 1);
    expect(controller.activationCount, 0);
    expect(controller.cooldownSeconds(cooldownRecoveryMultiplier: 1), 0);

    expect(
      _update(
        controller,
        0.1,
        hasRiftMarkCandidate: true,
        applyRiftMark: () {
          callbackCount++;
          controller.activate(powerMultiplierForActivation: (_) => 1.25);
          return true;
        },
      ),
      isTrue,
    );
    expect(callbackCount, 2);
    expect(controller.activationCount, 1);
    expect(controller.isAttackSyncActive, isTrue);
    expect(controller.cooldownSeconds(cooldownRecoveryMultiplier: 1), 10);
  });

  test('restored stats are clamped and snapshots keep existing fields', () {
    final controller = _controller();
    controller.restoreRunSkill(
      CoreCombatSkill.guardianBeam,
      const SavedCoreCombatSkillStats(
        directDamageDealt: -4,
        bonusDamageDealt: 8.5,
        activationCount: -2,
      ),
      cooldownRecoveryMultiplier: 1,
    );

    expect(controller.directDamageDealt, 0);
    expect(controller.bonusDamageDealt, 8.5);
    expect(controller.activationCount, 0);
    final snapshot = controller.statsToSaveData();
    expect(snapshot.directDamageDealt, 0);
    expect(snapshot.bonusDamageDealt, 8.5);
    expect(snapshot.activationCount, 0);
  });

  test('emergency charge changes only an eligible inactive cooldown', () {
    final controller = _controller();

    expect(
      controller.applyEmergencyCharge(
        recoveryRate: 0,
        cooldownRecoveryMultiplier: 1,
      ),
      isFalse,
    );
    expect(
      controller.applyEmergencyCharge(
        recoveryRate: 0.35,
        cooldownRecoveryMultiplier: 1,
      ),
      isTrue,
    );
    expect(
      controller.cooldownSeconds(cooldownRecoveryMultiplier: 1),
      closeTo(3.25, 0.0001),
    );

    controller
      ..resetCycle(cooldownRecoveryMultiplier: 1)
      ..update(
        5,
        cooldownRecoveryMultiplier: 1,
        hasGuardianBeamTarget: () => true,
        guardianBeamBaseDamage: () => 100,
        powerMultiplierForActivation: (_) => 1,
        applyGuardianBeamTick: (_) {},
        hasRiftMarkCandidate: false,
        applyRiftMark: () => false,
      );
    expect(controller.isGuardianBeamActive, isTrue);
    expect(
      controller.applyEmergencyCharge(
        recoveryRate: 0.35,
        cooldownRecoveryMultiplier: 1,
      ),
      isFalse,
    );

    controller.captureRunSkill(null, cooldownRecoveryMultiplier: 1);
    expect(
      controller.applyEmergencyCharge(
        recoveryRate: 0.35,
        cooldownRecoveryMultiplier: 1,
      ),
      isFalse,
    );
  });
}

CoreCombatSkillController _controller({
  CoreCombatSkill? initialSkill = CoreCombatSkill.guardianBeam,
}) {
  return CoreCombatSkillController(
    guardianBeamInterval: 5,
    guardianBeamDuration: 1,
    guardianBeamTickInterval: 0.1,
    riftMarkInterval: 10,
    attackSyncDuration: 2,
    initialSkill: initialSkill,
  );
}

bool _update(
  CoreCombatSkillController controller,
  double dt, {
  double cooldownRecoveryMultiplier = 1,
  bool hasGuardianBeamTarget = false,
  double Function()? guardianBeamBaseDamage,
  double Function(int activationNumber)? powerMultiplierForActivation,
  void Function(double tickDamage)? applyGuardianBeamTick,
  bool hasRiftMarkCandidate = false,
  bool Function()? applyRiftMark,
}) {
  return controller.update(
    dt,
    cooldownRecoveryMultiplier: cooldownRecoveryMultiplier,
    hasGuardianBeamTarget: () => hasGuardianBeamTarget,
    guardianBeamBaseDamage: guardianBeamBaseDamage ?? () => 100,
    powerMultiplierForActivation: powerMultiplierForActivation ?? (_) => 1,
    applyGuardianBeamTick: applyGuardianBeamTick ?? (_) {},
    hasRiftMarkCandidate: hasRiftMarkCandidate,
    applyRiftMark: applyRiftMark ?? () => false,
  );
}
