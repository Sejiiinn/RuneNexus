import 'dart:math' as math;

import '../../data/save/game_save_data.dart';
import '../../domain/core/core_ability.dart';

class CoreCombatSkillController {
  CoreCombatSkillController({
    required this.guardianBeamInterval,
    required this.guardianBeamDuration,
    required this.guardianBeamTickInterval,
    required this.riftMarkInterval,
    required this.attackSyncDuration,
    CoreCombatSkill? initialSkill = CoreCombatSkill.guardianBeam,
  }) : _runSkill = initialSkill {
    resetCycle(cooldownRecoveryMultiplier: 1);
  }

  final double guardianBeamInterval;
  final double guardianBeamDuration;
  final double guardianBeamTickInterval;
  final double riftMarkInterval;
  final double attackSyncDuration;

  CoreCombatSkill? _runSkill;
  double _directDamageDealt = 0;
  double _bonusDamageDealt = 0;
  int _activationCount = 0;
  double _cooldown = 0;
  double _guardianBeamActiveRemaining = 0;
  double _guardianBeamTickTimer = 0;
  double _guardianBeamTickDamage = 0;
  double _attackSyncRemaining = 0;

  CoreCombatSkill? get runSkill => _runSkill;
  double get directDamageDealt => _directDamageDealt;
  double get bonusDamageDealt => _bonusDamageDealt;
  int get activationCount => _activationCount;
  bool get isAvailable => _runSkill != null;
  bool get isGuardianBeamActive =>
      _runSkill == CoreCombatSkill.guardianBeam &&
      _guardianBeamActiveRemaining > 0;
  bool get isAttackSyncActive => _attackSyncRemaining > 0;

  double cooldownInterval({required double cooldownRecoveryMultiplier}) {
    assert(cooldownRecoveryMultiplier > 0);
    return switch (_runSkill) {
      CoreCombatSkill.guardianBeam =>
        guardianBeamInterval / cooldownRecoveryMultiplier,
      CoreCombatSkill.riftMark => riftMarkInterval / cooldownRecoveryMultiplier,
      null => 0,
    };
  }

  double cooldownSeconds({required double cooldownRecoveryMultiplier}) {
    if (_runSkill == null || _guardianBeamActiveRemaining > 0) {
      return 0;
    }
    return _cooldown
        .clamp(
          0.0,
          cooldownInterval(
            cooldownRecoveryMultiplier: cooldownRecoveryMultiplier,
          ),
        )
        .toDouble();
  }

  double cooldownProgress({required double cooldownRecoveryMultiplier}) {
    if (_guardianBeamActiveRemaining > 0) {
      return 1;
    }
    final interval = cooldownInterval(
      cooldownRecoveryMultiplier: cooldownRecoveryMultiplier,
    );
    if (interval <= 0) {
      return 0;
    }
    return (1 - _cooldown / interval).clamp(0.0, 1.0).toDouble();
  }

  double guardianBeamDamage({
    required double Function() baseDamage,
    required double Function(int activationNumber) powerMultiplierForActivation,
  }) {
    if (_runSkill != CoreCombatSkill.guardianBeam) {
      return 0;
    }
    if (_guardianBeamActiveRemaining > 0) {
      return _guardianBeamTickDamage *
          (guardianBeamDuration / guardianBeamTickInterval);
    }
    return baseDamage() * powerMultiplierForActivation(_activationCount + 1);
  }

  void captureRunSkill(
    CoreCombatSkill? skill, {
    required double cooldownRecoveryMultiplier,
  }) {
    _runSkill = skill;
    resetStats();
    resetCycle(cooldownRecoveryMultiplier: cooldownRecoveryMultiplier);
  }

  void restoreRunSkill(
    CoreCombatSkill? skill,
    SavedCoreCombatSkillStats stats, {
    required double cooldownRecoveryMultiplier,
  }) {
    _runSkill = skill;
    restoreStats(stats);
    resetCycle(cooldownRecoveryMultiplier: cooldownRecoveryMultiplier);
  }

  void resetStats() {
    _directDamageDealt = 0;
    _bonusDamageDealt = 0;
    _activationCount = 0;
  }

  void restoreStats(SavedCoreCombatSkillStats stats) {
    _directDamageDealt = math.max(0, stats.directDamageDealt);
    _bonusDamageDealt = math.max(0, stats.bonusDamageDealt);
    _activationCount = math.max(0, stats.activationCount);
  }

  SavedCoreCombatSkillStats statsToSaveData() {
    return SavedCoreCombatSkillStats(
      directDamageDealt: _directDamageDealt,
      bonusDamageDealt: _bonusDamageDealt,
      activationCount: _activationCount,
    );
  }

  bool recordDirectDamage(double damage) {
    if (damage <= 0) {
      return false;
    }
    _directDamageDealt += damage;
    return true;
  }

  bool recordBonusDamage(double damage) {
    if (damage <= 0) {
      return false;
    }
    _bonusDamageDealt += damage;
    return true;
  }

  void resetCycle({required double cooldownRecoveryMultiplier}) {
    _cooldown = cooldownInterval(
      cooldownRecoveryMultiplier: cooldownRecoveryMultiplier,
    );
    _guardianBeamActiveRemaining = 0;
    _guardianBeamTickTimer = 0;
    _guardianBeamTickDamage = 0;
    _attackSyncRemaining = 0;
  }

  /// 전투 통계 publish가 필요한 상태 전이 여부.
  bool update(
    double dt, {
    required double cooldownRecoveryMultiplier,
    required bool Function() hasGuardianBeamTarget,
    required double Function() guardianBeamBaseDamage,
    required double Function(int activationNumber) powerMultiplierForActivation,
    required void Function(double tickDamage) applyGuardianBeamTick,
    required bool hasRiftMarkCandidate,
    required bool Function() applyRiftMark,
  }) {
    if (dt <= 0) {
      return false;
    }
    _attackSyncRemaining = math.max(0, _attackSyncRemaining - dt);
    if (_runSkill == null) {
      resetCycle(cooldownRecoveryMultiplier: cooldownRecoveryMultiplier);
      return false;
    }
    if (_runSkill == CoreCombatSkill.riftMark) {
      return _updateRiftMark(
        dt,
        cooldownRecoveryMultiplier: cooldownRecoveryMultiplier,
        hasCandidate: hasRiftMarkCandidate,
        applyRiftMark: applyRiftMark,
      );
    }
    if (_runSkill != CoreCombatSkill.guardianBeam) {
      return false;
    }
    if (_guardianBeamActiveRemaining > 0) {
      return _updateActiveGuardianBeam(
        dt,
        cooldownRecoveryMultiplier: cooldownRecoveryMultiplier,
        applyTick: applyGuardianBeamTick,
      );
    }

    _cooldown = math.max(0, _cooldown - dt);
    if (_cooldown > 0 || !hasGuardianBeamTarget()) {
      return false;
    }

    _guardianBeamActiveRemaining = guardianBeamDuration;
    _guardianBeamTickTimer = 0;
    final baseDamage = guardianBeamBaseDamage();
    final powerMultiplier = activate(
      powerMultiplierForActivation: powerMultiplierForActivation,
    );
    _guardianBeamTickDamage =
        baseDamage *
        powerMultiplier /
        (guardianBeamDuration / guardianBeamTickInterval);
    _updateActiveGuardianBeam(
      0,
      cooldownRecoveryMultiplier: cooldownRecoveryMultiplier,
      applyTick: applyGuardianBeamTick,
    );
    return true;
  }

  double activate({
    required double Function(int activationNumber) powerMultiplierForActivation,
  }) {
    _activationCount++;
    _attackSyncRemaining = attackSyncDuration;
    return powerMultiplierForActivation(_activationCount);
  }

  bool applyEmergencyCharge({
    required double recoveryRate,
    required double cooldownRecoveryMultiplier,
  }) {
    if (_runSkill == null ||
        _guardianBeamActiveRemaining > 0 ||
        _cooldown <= 0) {
      return false;
    }
    final interval = cooldownInterval(
      cooldownRecoveryMultiplier: cooldownRecoveryMultiplier,
    );
    if (recoveryRate <= 0 || interval <= 0) {
      return false;
    }
    _cooldown = math.max(0, _cooldown - interval * recoveryRate);
    return true;
  }

  bool _updateActiveGuardianBeam(
    double dt, {
    required double cooldownRecoveryMultiplier,
    required void Function(double tickDamage) applyTick,
  }) {
    _guardianBeamActiveRemaining = math.max(
      0,
      _guardianBeamActiveRemaining - dt,
    );
    _guardianBeamTickTimer -= dt;
    while (_guardianBeamTickTimer <= 0 && _guardianBeamActiveRemaining > 0) {
      _guardianBeamTickTimer += guardianBeamTickInterval;
      applyTick(_guardianBeamTickDamage);
    }

    if (_guardianBeamActiveRemaining > 0) {
      return false;
    }
    _cooldown = cooldownInterval(
      cooldownRecoveryMultiplier: cooldownRecoveryMultiplier,
    );
    _guardianBeamTickTimer = 0;
    _guardianBeamTickDamage = 0;
    return true;
  }

  bool _updateRiftMark(
    double dt, {
    required double cooldownRecoveryMultiplier,
    required bool hasCandidate,
    required bool Function() applyRiftMark,
  }) {
    _guardianBeamActiveRemaining = 0;
    _guardianBeamTickTimer = 0;
    _guardianBeamTickDamage = 0;
    _cooldown = math.max(0, _cooldown - dt);
    if (_cooldown > 0 || !hasCandidate) {
      return false;
    }

    if (!applyRiftMark()) {
      return false;
    }
    _cooldown = cooldownInterval(
      cooldownRecoveryMultiplier: cooldownRecoveryMultiplier,
    );
    return true;
  }
}
