import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../domain/combat/attack_rules.dart';
import '../../domain/map/grid_point.dart';
import '../components/enemy_component.dart';
import '../components/impact_effect_component.dart';
import '../components/lightning_chain_beam_component.dart';
import '../components/turret_component.dart';
import 'combat_resolver.dart';

typedef AttackDamageFeedback =
    void Function({
      required Vector2 position,
      required double damage,
      required Color color,
      required Vector2 sourcePosition,
      required double damageMultiplier,
    });

typedef AttackImpactFeedback =
    void Function({
      required TurretComponent owner,
      required TurretAttackSnapshot attack,
      required Vector2 position,
      required double areaScale,
    });

/// 공격 스냅샷의 명중·상태 적용과 후속 피해 실행. 런 진행과 보상은 호출자 책임.
class CombatExecutionController {
  CombatExecutionController({
    required CombatResolver resolver,
    required List<EnemyComponent> enemies,
    required bool Function(TurretComponent) isActiveTurret,
    required TurretComponent? Function(GridPoint) turretForPoint,
    required void Function(TurretComponent, double, TurretDamageKind)
    recordTurretDamage,
    required AttackDamageFeedback showDamageNumber,
    required AttackImpactFeedback showImpact,
    required void Function(Component) addEffect,
    required double burnDurationSeconds,
  }) : _resolver = resolver,
       _enemies = enemies,
       _isActiveTurret = isActiveTurret,
       _turretForPoint = turretForPoint,
       _recordTurretDamage = recordTurretDamage,
       _showDamageNumber = showDamageNumber,
       _showImpact = showImpact,
       _addEffect = addEffect,
       _burnDurationSeconds = burnDurationSeconds;

  static const double _ignitionBurstDurationRate = 0.3;
  static const double _chainIgnitionDurationRate = 0.6;

  final CombatResolver _resolver;
  // 복사본 대신 실행 중인 목록 참조: 처치·생성 직후 상태 반영.
  final List<EnemyComponent> _enemies;
  final bool Function(TurretComponent) _isActiveTurret;
  final TurretComponent? Function(GridPoint) _turretForPoint;
  final void Function(TurretComponent, double, TurretDamageKind)
  _recordTurretDamage;
  final AttackDamageFeedback _showDamageNumber;
  final AttackImpactFeedback _showImpact;
  final void Function(Component) _addEffect;
  final double _burnDurationSeconds;

  // 명중별 독립 폭발 판정: 과거 피격 이력은 직접 연쇄 대상에만 사용.
  void resolveAttackImpact({
    required TurretComponent owner,
    required TurretAttackSnapshot attack,
    required EnemyComponent target,
    required Vector2 hitPosition,
    double damageScale = 1,
    double areaScale = 1,
    TurretDamageKind directKind = TurretDamageKind.direct,
  }) {
    final impacted = <EnemyComponent>{if (!target.isDead) target};
    final splashRadius = attack.splashRadius * areaScale;
    if (splashRadius > 0) {
      final radiusSquared = splashRadius * splashRadius;
      for (final enemy in _enemies.toList()) {
        if (!enemy.isDead &&
            enemy.position.distanceToSquared(hitPosition) <= radiusSquared) {
          impacted.add(enemy);
        }
      }
    }
    _showImpact(
      owner: owner,
      attack: attack,
      position: hitPosition,
      areaScale: areaScale,
    );
    final isChain = directKind == TurretDamageKind.chain;
    for (final enemy in impacted) {
      if (enemy.isDead) continue;
      final isPrimaryTarget = identical(enemy, target);
      final triggerDirectTraits = isPrimaryTarget && !isChain;
      final ignitionBurstDamage = triggerDirectTraits
          ? _ignitionBurstDamage(owner, attack, enemy)
          : 0.0;
      final traitMultiplier = triggerDirectTraits
          ? owner.registerDirectHitTraits(enemy, attack: attack)
          : 1.0;
      final hitMultiplier = isPrimaryTarget
          ? 1.0
          : attack.splashSecondaryDamageMultiplier;
      _applyAttackHit(
        owner: owner,
        attack: attack,
        enemy: enemy,
        sourcePosition: hitPosition,
        kind: isPrimaryTarget ? directKind : TurretDamageKind.splash,
        baseDamage:
            attack.damage *
            attack.criticalMultiplier *
            damageScale *
            hitMultiplier,
        traitMultiplier: traitMultiplier,
        statusDamageScale: damageScale * hitMultiplier,
      );
      if (ignitionBurstDamage > 0 && !enemy.isDead) {
        enemy.showHitFlash(owner.definition.color);
        final actualBurstDamage = enemy.receiveDamage(
          ignitionBurstDamage,
          burnTransfer: _burnTransferForHit(owner, attack, enemy),
          ignoreArmorReduction: attack.ignoresArmorReduction,
        );
        _showDamageNumber(
          position: enemy.position.clone(),
          damage: actualBurstDamage,
          color: owner.definition.color,
          sourcePosition: hitPosition,
          damageMultiplier: 1,
        );
        _recordTurretDamage(owner, actualBurstDamage, TurretDamageKind.direct);
      }
    }
  }

  void resolveInstantHit({
    required TurretComponent owner,
    required EnemyComponent target,
    TurretAttackSnapshot? attack,
    double criticalMultiplier = 1,
  }) {
    final profile =
        attack ??
        owner.createAttackSnapshot(criticalMultiplier: criticalMultiplier);
    if ((!target.isMounted && !_enemies.contains(target)) ||
        target.isDead ||
        !isEnemyBodyInAttackRange(owner, profile, target)) {
      return;
    }
    resolveAttackImpact(
      owner: owner,
      attack: profile,
      target: target,
      hitPosition: target.position.clone(),
    );
  }

  EnemyComponent? nextLightningChainTarget({
    required Vector2 sourcePosition,
    required Set<EnemyComponent> excluded,
    required TurretAttackSnapshot attack,
  }) {
    final jumpRange = attack.lightningChainJumpRange;
    final jumpRangeSquared = jumpRange * jumpRange;
    EnemyComponent? selected;
    var selectedDistanceSquared = double.infinity;
    var selectedProgress = -double.infinity;
    for (final enemy in _enemies) {
      if ((!enemy.isMounted && !_enemies.contains(enemy)) ||
          enemy.isDead ||
          excluded.contains(enemy)) {
        continue;
      }
      final dx = enemy.position.x - sourcePosition.x;
      final dy = enemy.position.y - sourcePosition.y;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared > jumpRangeSquared) {
        continue;
      }
      final isFurtherAhead = enemy.distanceTravelled > selectedProgress;
      final isTieButCloser =
          enemy.distanceTravelled == selectedProgress &&
          distanceSquared < selectedDistanceSquared;
      if (isFurtherAhead || isTieButCloser) {
        selected = enemy;
        selectedDistanceSquared = distanceSquared;
        selectedProgress = enemy.distanceTravelled;
      }
    }
    return selected;
  }

  void resolveLightningChainJump({
    required TurretComponent owner,
    required TurretAttackSnapshot attack,
    required Vector2 sourcePosition,
    required EnemyComponent target,
    required double boardDistanceScale,
  }) {
    if ((!target.isMounted && !_enemies.contains(target)) || target.isDead) {
      return;
    }

    _addEffect(
      LightningChainBeamComponent(
        sourcePosition: sourcePosition,
        target: target,
        color: owner.definition.color,
        visualScale: boardDistanceScale,
      ),
    );
    resolveAttackImpact(
      owner: owner,
      attack: attack,
      target: target,
      hitPosition: target.position.clone(),
      damageScale: attack.lightningChainDamageMultiplier,
      areaScale: AttackRules.chainAreaMultiplier,
      directKind: TurretDamageKind.chain,
    );
  }

  void resolveCenteredAreaAttack({
    required TurretComponent owner,
    TurretAttackSnapshot? attack,
    required Iterable<EnemyComponent> targets,
  }) {
    final profile =
        attack ??
        owner.createAttackSnapshot(
          criticalMultiplier: owner.rollCriticalHit()
              ? owner.criticalDamageMultiplier
              : 1.0,
        );
    final impacted = targets
        .where(
          (enemy) =>
              !enemy.isDead &&
              owner.position.distanceToSquared(enemy.position) <=
                  math.pow(
                    profile.centeredAreaRadius + enemy.collisionRadius,
                    2,
                  ),
        )
        .toList();
    if (impacted.isEmpty) {
      return;
    }

    _addEffect(
      ImpactEffectComponent(
        position: owner.position.clone(),
        color: owner.definition.color,
        style: ImpactEffectStyle.frost,
        radius: profile.centeredAreaRadius,
      ),
    );

    for (final enemy in impacted) {
      _applyAttackHit(
        owner: owner,
        attack: profile,
        enemy: enemy,
        sourcePosition: owner.position,
        kind: TurretDamageKind.splash,
        baseDamage: profile.damage * profile.criticalMultiplier,
      );
    }
  }

  void _applyAttackHit({
    required TurretComponent owner,
    required TurretAttackSnapshot attack,
    required EnemyComponent enemy,
    required Vector2 sourcePosition,
    required TurretDamageKind kind,
    required double baseDamage,
    double traitMultiplier = 1,
    double statusDamageScale = 1,
  }) {
    // 이번 명중 피해 확정 후 상태이상 적용: 새 취약 효과의 소급 적용 방지.
    final resolvedDamage = _resolver.resolveAttackDamage(
      attack: attack,
      enemy: enemy,
      baseDamage: baseDamage,
      traitMultiplier: traitMultiplier,
    );
    _resolver.applyAttackStatuses(
      attack: attack,
      enemy: enemy,
      // 지속피해에는 타격의 치명타·직접 명중 특성 배율을 적용하지 않음.
      damageScale: statusDamageScale,
      activeSourceTurretPoint: _isActiveTurret(owner) ? owner.gridPoint : null,
    );
    enemy.showHitFlash(owner.definition.color);
    final actualDamage = enemy.receiveDamage(
      resolvedDamage.damage,
      burnTransfer: _burnTransferForHit(owner, attack, enemy),
      ignoreArmorReduction: attack.ignoresArmorReduction,
    );
    _showDamageNumber(
      position: enemy.position.clone(),
      damage: actualDamage,
      color: owner.definition.color,
      sourcePosition: sourcePosition,
      damageMultiplier:
          resolvedDamage.resistanceMultiplier * attack.criticalMultiplier,
    );
    _recordTurretDamage(owner, actualDamage, kind);
  }

  bool isEnemyBodyInAttackRange(
    TurretComponent owner,
    TurretAttackSnapshot attack,
    EnemyComponent enemy,
  ) {
    final enemyRadius = math.min(enemy.size.x, enemy.size.y) / 2;
    final rangeWithBody = attack.range + enemyRadius;
    final dx = enemy.position.x - owner.position.x;
    final dy = enemy.position.y - owner.position.y;
    return dx * dx + dy * dy <= rangeWithBody * rangeWithBody;
  }

  double _ignitionBurstDamage(
    TurretComponent owner,
    TurretAttackSnapshot attack,
    EnemyComponent enemy,
  ) {
    if (!attack.appliesIgnitionBurst ||
        !attack.hasDamageOverTime ||
        !_isActiveTurret(owner) ||
        !enemy.hasBurnFromSource(owner.gridPoint)) {
      return 0;
    }
    final burnDamagePerSecond = enemy.strongestBurnDamagePerSecondFromSource(
      owner.gridPoint,
    );
    final burnDuration =
        _burnDurationSeconds * attack.damageOverTimeDurationMultiplier;
    return burnDamagePerSecond * burnDuration * _ignitionBurstDurationRate;
  }

  BurnTransferPayload? _burnTransferForHit(
    TurretComponent owner,
    TurretAttackSnapshot attack,
    EnemyComponent enemy,
  ) {
    if (!attack.spreadsChainIgnition ||
        !attack.hasDamageOverTime ||
        !_isActiveTurret(owner)) {
      return null;
    }
    return enemy.burnTransferPayloadFromSource(owner.gridPoint);
  }

  void spreadChainIgnition({
    required EnemyComponent source,
    required BurnTransferPayload burnTransfer,
    required double boardDistanceScale,
  }) {
    final sourcePoint = burnTransfer.sourceTurretPoint;
    if (sourcePoint == null ||
        burnTransfer.remaining <= 0 ||
        burnTransfer.damagePerSecond <= 0) {
      return;
    }
    final turret = _turretForPoint(sourcePoint);
    if (turret == null ||
        !turret.spreadsChainIgnition ||
        !_isActiveTurret(turret)) {
      return;
    }
    final transferDuration =
        burnTransfer.remaining * _chainIgnitionDurationRate;
    if (transferDuration <= 0) {
      return;
    }
    final target = _resolver.chainIgnitionTarget(
      enemies: _enemies,
      source: source,
      boardDistanceScale: boardDistanceScale,
    );
    if (target == null) {
      return;
    }
    target.applyBurn(
      damagePerSecond: burnTransfer.damagePerSecond,
      duration: transferDuration,
      damageMultiplier: burnTransfer.damageMultiplier,
      sourceTurretPoint: sourcePoint,
      ignoreArmorReduction: burnTransfer.ignoreArmorReduction,
    );
    target.showHitFlash(turret.definition.color);
  }
}
