import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../data/save/game_save_data.dart';
import '../../domain/gem/gem_type.dart';
import '../../domain/map/grid_point.dart';
import '../../domain/turret/attack_tag.dart';
import '../../domain/turret/damage_family.dart';
import '../../domain/turret/turret_definition.dart';
import '../../domain/turret/turret_target_priority.dart';
import '../../domain/turret/turret_trait_catalog.dart';
import '../../domain/turret/turret_trait_type.dart';
import '../../domain/turret/turret_type.dart';
import '../../domain/turret_module/turret_module_type.dart';
import '../rendering/turret_level_renderer.dart';
import '../rendering/turret_shape_renderer.dart';
import '../rendering/turret_visual_effect_renderer.dart';
import '../rune_nexus_game.dart';
import 'enemy_component.dart';
import 'lightning_charge_component.dart';
import 'projectile_component.dart';

class TurretComponent extends PositionComponent {
  static const double _visualSizeScale = 0.82;

  TurretComponent({
    required this.gridPoint,
    required this.definition,
    required this.game,
    required Vector2 center,
    required double tileSize,
    int? investedGold,
  }) : _tileSize = tileSize,
       _investedGold = investedGold ?? definition.cost,
       super(
         position: center,
         size: Vector2.all(tileSize * _visualSizeScale),
         anchor: Anchor.center,
       );

  final GridPoint gridPoint;
  final TurretDefinition definition;
  final RuneNexusGame game;
  final List<GemType?> _gemSlots = [null];
  final math.Random _cooldownRandom = math.Random();

  double _tileSize;
  double _cooldown = 0;
  double _aimAngle = -math.pi / 2;
  double _fireFeedbackTimer = 0;
  double _shapeAnimationTime = 0;
  double _gemRingPhase = 0;
  EnemyComponent? _aimTarget;
  double _aimProgress = 0;
  int _slotLimit = 1;
  int _level = 1;
  double _directDamageDealt = 0;
  double _splashDamageDealt = 0;
  double _chainDamageDealt = 0;
  double _burnDamageDealt = 0;
  int _investedGold;
  double _lastLightningBaseCooldown = 0;
  double _lightningAttackElapsed = 0;
  TurretTraitType? _primaryTrait;
  TurretTraitType? _secondaryTrait;
  EnemyComponent? _overheatTarget;
  int _overheatStacks = 0;
  EnemyComponent? _suppressiveTarget;
  int _suppressiveHits = 0;
  final TurretLevelRenderer _levelRenderer = TurretLevelRenderer();
  final Map<EnemyComponent, double> _recentHitTimers = {};
  double _chainCleanupTimer = 0;
  TurretTargetPriority _targetPriority = TurretTargetPriority.first;

  static const double _damageGrowthPerLevel = 0.2;
  static const double _rangeGrowthPerLevel = 0.033;
  static const double _attackRateGrowthPerLevel = 0.05;
  static const double _aimSpeedGrowthPerLevel = 0.08;
  static const double _cooldownVariance = 0.05;
  static const double _fireFeedbackDuration = 0.12;

  int get level => _level;
  int get maxLevel => 10;
  double get cooldown => _cooldown;
  double get directDamageDealt => _directDamageDealt;
  double get splashDamageDealt => _splashDamageDealt;
  double get chainDamageDealt => _chainDamageDealt;
  double get burnDamageDealt => _burnDamageDealt;
  TurretTraitType? get primaryTrait => _primaryTrait;
  TurretTraitType? get secondaryTrait => _secondaryTrait;
  TurretTargetPriority get targetPriority => _targetPriority;
  double get damageDealt =>
      _directDamageDealt +
      _splashDamageDealt +
      _chainDamageDealt +
      _burnDamageDealt;
  int get levelUpCost => _levelUpCostAt(_level);
  int get investedGold => _investedGold;

  int get _calculatedInvestedGold {
    var total = definition.cost;
    for (var level = 1; level < _level; level++) {
      total += _levelUpCostAt(level);
    }
    for (var slot = 2; slot <= _slotLimit; slot++) {
      total += _linkUpgradeCostForSlot(slot);
    }
    return total;
  }

  int get refundGold => investedGold * game.turretRefundPercent ~/ 100;
  bool get canLevelUp => _level < maxLevel;
  int get slotLimit => _slotLimit;
  int get maxSlotLimit => game.maxTurretLinkSlotLimit;
  bool get hasNextLinkUpgrade => _slotLimit < maxSlotLimit;
  int get nextSlotLimit => hasNextLinkUpgrade ? _slotLimit + 1 : _slotLimit;
  int get linkUpgradeRequiredLevel => nextSlotLimit >= 3 ? 5 : 1;
  int get linkUpgradeCost {
    if (!hasNextLinkUpgrade) {
      return 0;
    }
    return _linkUpgradeCostForSlot(nextSlotLimit);
  }

  bool get canUpgradeLink =>
      hasNextLinkUpgrade && _level >= linkUpgradeRequiredLevel;
  TurretTraitSet get traitSet => turretTraitSetFor(definition.type);
  bool get supportsTraits => traitSet.hasChoices;
  List<TurretTraitType> get primaryTraitChoices => traitSet.primary;
  List<TurretTraitType> get secondaryTraitChoices => traitSet.secondary;
  bool get canChoosePrimaryTrait =>
      primaryTraitChoices.isNotEmpty && _primaryTrait == null && _level >= 3;
  bool get canChooseSecondaryTrait =>
      secondaryTraitChoices.isNotEmpty &&
      _primaryTrait != null &&
      _secondaryTrait == null &&
      _level >= 7;
  TurretModuleEffect get _moduleEffect =>
      game.turretModuleEffectFor(definition.type);
  double get _numericGemEffectMultiplier =>
      (1 + _moduleEffect.gemEffectIncreaseRate) *
      game.passiveNumericGemEffectMultiplier;

  double get damage => damageAtLevel(_level);

  double damageAtLevel(int level) {
    final targetLevel = level.clamp(1, maxLevel).toInt();
    final moduleEffect = _moduleEffect;
    final gemEffectMultiplier = _numericGemEffectMultiplier;
    var levelDamage =
        definition.damage *
        math.pow(1 + _damageGrowthPerLevel, targetLevel - 1).toDouble();
    if (definition.damageFamily == DamageFamily.physical &&
        hasGem(GemType.physicalDamage)) {
      levelDamage *= 1 + 0.4 * gemEffectMultiplier;
    }
    if (definition.damageFamily == DamageFamily.elemental &&
        hasGem(GemType.elementalDamage)) {
      levelDamage *= 1 + 0.4 * gemEffectMultiplier;
    }
    if (definition.attackTags.contains(AttackTag.light) &&
        hasGem(GemType.lightWeapon)) {
      levelDamage *= 1 + 0.2 * gemEffectMultiplier;
    }
    if (definition.attackTags.contains(AttackTag.heavy) &&
        hasGem(GemType.heavyWeapon)) {
      levelDamage *= 1 + 0.3 * gemEffectMultiplier;
    }
    if (_primaryTrait == TurretTraitType.spreadingChill) {
      levelDamage *= 0.9;
    }
    if (hasGem(GemType.damageAmplifier)) {
      levelDamage *= 1 + 0.25 * gemEffectMultiplier;
    }

    return levelDamage *
        (1 + moduleEffect.damageIncreaseRate) *
        game.towerDamageMultiplierFor(definition.damageFamily) *
        game.corePassiveTurretDamageMultiplier;
  }

  double get range => rangeAtLevel(_level);

  double rangeAtLevel(int level) {
    final targetLevel = level.clamp(1, maxLevel).toInt();
    final levelMultiplier = 1 + (targetLevel - 1) * _rangeGrowthPerLevel;
    final moduleEffect = _moduleEffect;
    return definition.range *
        levelMultiplier *
        (hasGem(GemType.range) ? 1 + 0.2 * _numericGemEffectMultiplier : 1) *
        (_primaryTrait == TurretTraitType.spreadingChill ? 1.15 : 1) *
        (1 + moduleEffect.rangeIncreaseRate) *
        game.boardDistanceScale;
  }

  double get attackRate => attackRateAtLevel(_level);

  double attackRateAtLevel(int level) {
    final targetLevel = level.clamp(1, maxLevel).toInt();
    final levelMultiplier = math
        .pow(1 + _attackRateGrowthPerLevel, targetLevel - 1)
        .toDouble();
    final moduleEffect = _moduleEffect;
    final gemEffectMultiplier = _numericGemEffectMultiplier;
    var rate =
        definition.attackRate *
        levelMultiplier *
        (hasGem(GemType.attackSpeed) ? 1 + 0.4 * gemEffectMultiplier : 1) *
        (definition.attackTags.contains(AttackTag.light) &&
                hasGem(GemType.lightWeapon)
            ? 1 + 0.2 * gemEffectMultiplier
            : 1) *
        (_primaryTrait == TurretTraitType.lightweightBarrel ? 1.1 : 1) *
        (_primaryTrait == TurretTraitType.compressedCharge ? 0.9 : 1) *
        (_primaryTrait == TurretTraitType.coolingCycle ? 1.2 : 1) *
        (1 + moduleEffect.attackRateIncreaseRate);
    if (_chainCleanupTimer > 0) {
      rate *= 1.4;
    }
    return rate * game.corePassiveTurretAttackRateMultiplier;
  }

  double get projectileSpeed =>
      definition.projectileSpeed *
      (_primaryTrait == TurretTraitType.lightweightBarrel ? 1.3 : 1) *
      (1 + _moduleEffect.projectileSpeedIncreaseRate) *
      game.boardDistanceScale;

  TurretAttackSnapshot createAttackSnapshot({double criticalMultiplier = 1}) {
    return TurretAttackSnapshot(
      sourceTurretPoint: gridPoint,
      definition: definition,
      damage: damage,
      range: range,
      splashRadius: splashRadius,
      splashSecondaryDamageMultiplier: splashSecondaryDamageMultiplier,
      projectileSpeed: projectileSpeed,
      criticalMultiplier: criticalMultiplier,
      physicalResistanceReduction: physicalResistanceReduction,
      ignoresArmorReduction: ignoresArmorReduction,
      damageOverTimeDamageMultiplier: damageOverTimeDamageMultiplier,
      damageOverTimeDurationMultiplier: damageOverTimeDurationMultiplier,
      slowDuration: slowDuration,
      slowMultiplier: slowMultiplier,
      hasChain: hasGem(GemType.chain),
      appliesFrostCrack: appliesFrostCrack,
      appliesIgnitionBurst: appliesIgnitionBurst,
      spreadsChainIgnition: spreadsChainIgnition,
      appliesChainCleanup: _secondaryTrait == TurretTraitType.chainCleanup,
      appliesSuppressiveFire:
          _secondaryTrait == TurretTraitType.suppressiveFire,
      appliesExposedMark: _secondaryTrait == TurretTraitType.exposedMark,
      appliesOverheatMagazine:
          _primaryTrait == TurretTraitType.overheatMagazine,
      appliesCompressedCharge:
          _primaryTrait == TurretTraitType.compressedCharge,
      appliesFinishingShot: _secondaryTrait == TurretTraitType.finishingShot,
      appliesFocusedLightning:
          _primaryTrait == TurretTraitType.focusedLightning,
      lightningChainMaxJumps: lightningChainMaxJumps,
      lightningChainDamageMultiplier: lightningChainDamageMultiplier,
      lightningChainJumpRange:
          game.lightningChainJumpRange *
          (1 + _moduleEffect.lightningChainRangeIncreaseRate),
    );
  }

  double get damageOverTimeDamageMultiplier {
    if (!definition.attackTags.contains(AttackTag.damageOverTime)) {
      return 1;
    }
    var bonus = 0.0;
    if (hasGem(GemType.damageOverTime)) {
      bonus += 0.3 * _numericGemEffectMultiplier;
    }
    if (_primaryTrait == TurretTraitType.highHeatBurn) {
      bonus += 0.25;
    }
    bonus += _moduleEffect.damageOverTimeIncreaseRate;
    return 1 + bonus;
  }

  double get damageOverTimeDurationMultiplier {
    if (!definition.attackTags.contains(AttackTag.damageOverTime)) {
      return 1;
    }
    var bonus = 0.0;
    if (hasGem(GemType.damageOverTime)) {
      bonus += 0.3 * _numericGemEffectMultiplier;
    }
    if (_primaryTrait == TurretTraitType.lingeringEmbers) {
      bonus += 0.4;
    }
    bonus += _moduleEffect.burnDurationIncreaseRate;
    return 1 + bonus;
  }

  double get slowMultiplier {
    final strengthBonus = _moduleEffect.slowStrengthBonusRate;
    final base = _secondaryTrait == TurretTraitType.rapidCooling
        ? 0.62
        : definition.slowMultiplier;
    if (base <= 0) {
      return base;
    }
    return (base - strengthBonus).clamp(0.1, 1.0).toDouble();
  }

  double get slowDuration =>
      definition.slowDuration *
      (_primaryTrait == TurretTraitType.coolingCycle ? 0.85 : 1) *
      (1 + _moduleEffect.slowDurationIncreaseRate);

  bool get appliesFrostCrack => _secondaryTrait == TurretTraitType.frostCrack;
  bool get appliesIgnitionBurst =>
      _secondaryTrait == TurretTraitType.ignitionBurst;
  bool get spreadsChainIgnition =>
      _secondaryTrait == TurretTraitType.chainIgnition;
  double get physicalResistanceReduction =>
      _secondaryTrait == TurretTraitType.fractureImpact ? 0.2 : 0;

  double get splashSecondaryDamageMultiplier {
    final moduleBonus = _moduleEffect.splashSecondaryDamageBonusRate;
    if (_secondaryTrait == TurretTraitType.expandedBlastCore) {
      return definition.splashRadius > 0 ? 0.6 + moduleBonus : 1;
    }
    if (hasGem(GemType.explosion)) {
      return definition.splashRadius > 0
          ? 0.5 + moduleBonus
          : 0.35 + moduleBonus;
    }
    return definition.splashRadius > 0 ? 0.5 + moduleBonus : 1;
  }

  double get splashRadius {
    final heavyRadiusBonus =
        definition.attackTags.contains(AttackTag.heavy) &&
            hasGem(GemType.heavyWeapon)
        ? definition.splashRadius * 0.2 * _numericGemEffectMultiplier
        : 0.0;
    final traitRadiusBonus = _primaryTrait == TurretTraitType.shrapnelShell
        ? definition.splashRadius * 0.3
        : 0.0;
    final secondaryTraitRadiusBonus =
        _secondaryTrait == TurretTraitType.expandedBlastCore
        ? definition.splashRadius * 0.4
        : 0.0;
    final moduleRadiusBonus =
        definition.splashRadius * _moduleEffect.splashRadiusIncreaseRate;
    if (definition.splashRadius > 0) {
      final additiveRadius =
          definition.splashRadius +
          heavyRadiusBonus +
          traitRadiusBonus +
          secondaryTraitRadiusBonus +
          moduleRadiusBonus;
      return additiveRadius *
          (hasGem(GemType.explosion)
              ? 1 + 0.25 * _numericGemEffectMultiplier
              : 1) *
          game.boardDistanceScale;
    }
    return (hasGem(GemType.explosion) ? 34 * _numericGemEffectMultiplier : 0) *
        game.boardDistanceScale;
  }

  bool hasGem(GemType type) => equippedGems.contains(type);
  bool get ignoresArmorReduction => hasGem(GemType.armorPiercing);
  int get lightningChainMaxTargets => lightningChainMaxJumps + 1;
  int get lightningChainMaxJumps {
    if (definition.type != TurretType.lightning) {
      return 0;
    }
    var jumps = 2;
    if (hasGem(GemType.chain)) {
      jumps += 2;
    }
    if (_primaryTrait == TurretTraitType.branchCurrent) {
      jumps += 1;
    }
    if (_primaryTrait == TurretTraitType.focusedLightning) {
      jumps -= 1;
    }
    return math.max(0, jumps);
  }

  double get lightningChainDamageMultiplier {
    final base = _secondaryTrait == TurretTraitType.currentAmplification
        ? 0.7
        : 0.5;
    return base * (1 + _moduleEffect.lightningChainDamageIncreaseRate);
  }

  bool get appliesLightningRecovery =>
      _secondaryTrait == TurretTraitType.lightningRecovery;

  Vector2 get lightningChargePosition {
    final offset = Vector2(math.cos(_aimAngle), math.sin(_aimAngle));
    return position + offset * (size.x * 0.58);
  }

  List<GemType> get equippedGems =>
      List.unmodifiable(_gemSlots.whereType<GemType>());
  List<GemType?> get equippedGemSlots =>
      List.unmodifiable(_gemSlots.take(_slotLimit));
  double get criticalChance {
    final bonus =
        (hasGem(GemType.criticalChance)
            ? 0.2 * _numericGemEffectMultiplier
            : 0.0) +
        game.criticalChanceProgressionBonusRate +
        _moduleEffect.criticalChanceBonusRate +
        (_primaryTrait == TurretTraitType.deadeyeFocus ? 0.2 : 0.0) -
        (_primaryTrait == TurretTraitType.quickScope ? 0.05 : 0.0);
    return (definition.criticalChance + bonus).clamp(0.0, 1.0).toDouble();
  }

  double get criticalDamageMultiplier =>
      definition.criticalDamageMultiplier +
      game.criticalDamageProgressionBonusRate +
      _moduleEffect.criticalDamageBonusRate;

  double get aimDuration {
    return aimDurationAtLevel(_level);
  }

  double aimDurationAtLevel(int level) {
    if (!definition.instantHit || definition.aimDuration <= 0) {
      return definition.aimDuration;
    }
    final targetLevel = level.clamp(1, maxLevel).toInt();
    final gemAimSpeedBonus = hasGem(GemType.aimSpeed)
        ? 0.75 * _numericGemEffectMultiplier
        : 0.0;
    final traitAimSpeedBonus = switch (_primaryTrait) {
      TurretTraitType.deadeyeFocus => -0.2,
      TurretTraitType.quickScope => 0.4,
      _ => 0.0,
    };
    final aimSpeedMultiplier =
        1 +
        (targetLevel - 1) * _aimSpeedGrowthPerLevel +
        gemAimSpeedBonus +
        _moduleEffect.aimSpeedIncreaseRate +
        traitAimSpeedBonus;
    return definition.aimDuration / math.max(0.1, aimSpeedMultiplier);
  }

  double get aimProgressRatio {
    final duration = aimDuration;
    if (!definition.instantHit || duration <= 0 || _aimTarget == null) {
      return 0;
    }
    return (_aimProgress / duration).clamp(0.0, 1.0);
  }

  bool canEquipGemAt(int slotIndex) {
    return slotIndex >= 0 && slotIndex < slotLimit;
  }

  bool rollCriticalHit() {
    final chance = criticalChance;
    return chance > 0 && _cooldownRandom.nextDouble() < chance;
  }

  void setTargetPriority(TurretTargetPriority priority) {
    _targetPriority = priority;
  }

  bool isEnemyBodyInRange(EnemyComponent enemy) {
    final enemyRadius = math.min(enemy.size.x, enemy.size.y) / 2;
    final rangeWithBody = range + enemyRadius;
    final dx = enemy.position.x - position.x;
    final dy = enemy.position.y - position.y;
    return dx * dx + dy * dy <= rangeWithBody * rangeWithBody;
  }

  SavedTurret toSaveData() {
    return SavedTurret(
      x: gridPoint.x,
      y: gridPoint.y,
      type: definition.type,
      level: _level,
      slotLimit: _slotLimit,
      cooldown: _cooldown,
      equippedGems: List.unmodifiable(equippedGems),
      equippedGemSlots: List.unmodifiable(equippedGemSlots),
      investedGold: _investedGold,
      damageDealt: damageDealt,
      directDamageDealt: _directDamageDealt,
      splashDamageDealt: _splashDamageDealt,
      chainDamageDealt: _chainDamageDealt,
      burnDamageDealt: _burnDamageDealt,
      targetPriority: _targetPriority,
      primaryTrait: _primaryTrait,
      secondaryTrait: _secondaryTrait,
    );
  }

  void restoreFromSaveData(SavedTurret data) {
    _level = data.level.clamp(1, maxLevel).toInt();
    _slotLimit = data.slotLimit.clamp(1, maxSlotLimit).toInt();
    _investedGold = data.investedGold > 0
        ? data.investedGold
        : _calculatedInvestedGold;
    _cooldown = math.max(0, data.cooldown);
    _directDamageDealt = math.max(0, data.directDamageDealt);
    _splashDamageDealt = math.max(0, data.splashDamageDealt);
    _chainDamageDealt = math.max(0, data.chainDamageDealt);
    _burnDamageDealt = math.max(0, data.burnDamageDealt);
    _lastLightningBaseCooldown = 0;
    _lightningAttackElapsed = 0;
    _targetPriority = data.targetPriority;
    _primaryTrait = primaryTraitChoices.contains(data.primaryTrait)
        ? data.primaryTrait
        : null;
    _secondaryTrait =
        _primaryTrait != null &&
            secondaryTraitChoices.contains(data.secondaryTrait)
        ? data.secondaryTrait
        : null;
    if (damageDealt == 0 && data.damageDealt > 0) {
      _directDamageDealt = math.max(0, data.damageDealt);
    }
    final restoredSlots = data.equippedGemSlots.isEmpty
        ? data.equippedGems
        : data.equippedGemSlots;
    _gemSlots
      ..clear()
      ..addAll(restoredSlots.take(_slotLimit));
    _syncGemSlotLength();
  }

  void recordDamageDealt(double damage, TurretDamageKind kind) {
    if (damage <= 0) {
      return;
    }
    switch (kind) {
      case TurretDamageKind.direct:
        _directDamageDealt += damage;
      case TurretDamageKind.splash:
        _splashDamageDealt += damage;
      case TurretDamageKind.chain:
        _chainDamageDealt += damage;
      case TurretDamageKind.burn:
        _burnDamageDealt += damage;
    }
  }

  bool choosePrimaryTrait(TurretTraitType trait) {
    if (!canChoosePrimaryTrait || !primaryTraitChoices.contains(trait)) {
      return false;
    }
    _primaryTrait = trait;
    _secondaryTrait = null;
    _overheatTarget = null;
    _overheatStacks = 0;
    _suppressiveTarget = null;
    _suppressiveHits = 0;
    _recentHitTimers.clear();
    _chainCleanupTimer = 0;
    _lastLightningBaseCooldown = 0;
    _lightningAttackElapsed = 0;
    return true;
  }

  bool chooseSecondaryTrait(TurretTraitType trait) {
    if (!canChooseSecondaryTrait || !secondaryTraitChoices.contains(trait)) {
      return false;
    }
    _secondaryTrait = trait;
    _suppressiveTarget = null;
    _suppressiveHits = 0;
    _recentHitTimers.clear();
    _chainCleanupTimer = 0;
    _lastLightningBaseCooldown = 0;
    _lightningAttackElapsed = 0;
    return true;
  }

  double registerDirectHitTraits(
    EnemyComponent enemy, {
    TurretAttackSnapshot? attack,
  }) {
    final profile = attack ?? createAttackSnapshot();
    if (profile.appliesChainCleanup) {
      _recentHitTimers[enemy] = 1.5;
    }
    if (profile.appliesSuppressiveFire) {
      if (identical(_suppressiveTarget, enemy)) {
        _suppressiveHits++;
      } else {
        _suppressiveTarget = enemy;
        _suppressiveHits = 1;
      }
      if (_suppressiveHits >= 5) {
        enemy.applyPhysicalVulnerability(bonus: 0.2, duration: 2);
        _suppressiveHits = 0;
      }
    }
    if (profile.appliesExposedMark) {
      enemy.applyPhysicalVulnerability(bonus: 0.15, duration: 2);
    }
    var multiplier = 1.0;
    if (profile.appliesOverheatMagazine) {
      if (identical(_overheatTarget, enemy)) {
        _overheatStacks = math.min(15, _overheatStacks + 1);
      } else {
        _overheatTarget = enemy;
        _overheatStacks = 1;
      }
      multiplier *= 1 + _overheatStacks * 0.02;
    }
    if (profile.appliesCompressedCharge) {
      multiplier *= 1.35;
    }
    if (profile.appliesFocusedLightning) {
      multiplier *= 1.3;
    }
    if (profile.appliesFinishingShot && _durabilityRatio(enemy) <= 0.35) {
      multiplier *= 1.45;
    }
    return multiplier;
  }

  void recordLightningChainCompletion({
    required int usedJumps,
    required int maxJumps,
  }) {
    if (!appliesLightningRecovery) {
      _lastLightningBaseCooldown = 0;
      _lightningAttackElapsed = 0;
      return;
    }
    final unusedJumps = math.max(0, maxJumps - usedJumps);
    final baseCooldown = _lastLightningBaseCooldown > 0
        ? _lastLightningBaseCooldown
        : _cooldown;
    if (unusedJumps <= 0 || baseCooldown <= 0) {
      _lastLightningBaseCooldown = 0;
      _lightningAttackElapsed = 0;
      return;
    }
    final reloadEfficiency = unusedJumps * 0.15;
    final adjustedCooldown = baseCooldown / (1 + reloadEfficiency);
    _cooldown = math.min(
      _cooldown,
      math.max(0.0, adjustedCooldown - _lightningAttackElapsed),
    );
    _lastLightningBaseCooldown = 0;
    _lightningAttackElapsed = 0;
  }

  double _durabilityRatio(EnemyComponent enemy) {
    final maxDurability = enemy.maxHp + enemy.maxArmor + enemy.maxShield;
    if (maxDurability <= 0) {
      return 1;
    }
    final currentDurability =
        enemy.hp + math.max(0, enemy.armor) + math.max(0, enemy.shield);
    return (currentDurability / maxDurability).clamp(0.0, 1.0).toDouble();
  }

  void handleEnemyKilled(EnemyComponent enemy) {
    if (_secondaryTrait != TurretTraitType.chainCleanup) {
      return;
    }
    if ((_recentHitTimers[enemy] ?? 0) <= 0) {
      return;
    }
    _chainCleanupTimer = 3;
    _recentHitTimers.remove(enemy);
  }

  void updateLayout({required Vector2 center, required double tileSize}) {
    position = center;
    _tileSize = tileSize;
    size = Vector2.all(tileSize * _visualSizeScale);
  }

  GemType? equipGem(GemType type, int slotIndex) {
    if (!canEquipGemAt(slotIndex)) {
      return null;
    }

    _syncGemSlotLength();
    final previous = _gemSlots[slotIndex];
    _gemSlots[slotIndex] = type;
    return previous;
  }

  GemType? removeGemAt(int slotIndex) {
    if (!canEquipGemAt(slotIndex)) {
      return null;
    }
    _syncGemSlotLength();
    final removed = _gemSlots[slotIndex];
    _gemSlots[slotIndex] = null;
    return removed;
  }

  bool upgradeLevel({int? paidGold}) {
    if (!canLevelUp) {
      return false;
    }
    _investedGold += paidGold ?? levelUpCost;
    _level++;
    return true;
  }

  bool upgradeLink({int? paidGold}) {
    if (!canUpgradeLink) {
      return false;
    }
    _investedGold += paidGold ?? linkUpgradeCost;
    _slotLimit++;
    _syncGemSlotLength();
    return true;
  }

  int _levelUpCostAt(int level) {
    final baseCost = (definition.cost * (70 + (level - 1) * 45) + 50) ~/ 100;
    final moduleEffect = _moduleEffect;
    final discountRate =
        (moduleEffect.levelUpCostDiscountRate +
                (level >= 5
                    ? moduleEffect.highLevelUpgradeCostDiscountRate
                    : 0.0))
            .clamp(0.0, 0.8);
    return math.max(
      1,
      (baseCost *
              (1 - discountRate) *
              game.passiveTurretLevelUpCostMultiplier *
              game.permanentTurretLevelUpCostMultiplier)
          .round(),
    );
  }

  int _linkUpgradeCostForSlot(int slotLimit) {
    final costPercent = slotLimit == 2 ? 150 : 300;
    final baseCost = (definition.cost * costPercent + 50) ~/ 100;
    final discountRate =
        (_moduleEffect.linkUpgradeCostDiscountRate +
                (slotLimit == 2 ? game.firstLinkUpgradeDiscountRate : 0.0))
            .clamp(0.0, 0.8);
    return math.max(
      1,
      (baseCost *
              (1 - discountRate) *
              game.passiveTurretLinkCostMultiplier *
              game.permanentTurretLinkCostMultiplier)
          .round(),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _fireFeedbackTimer = math.max(0, _fireFeedbackTimer - dt);
    _shapeAnimationTime = (_shapeAnimationTime + dt) % 1000;
    if (_lastLightningBaseCooldown > 0 && _cooldown > 0) {
      _lightningAttackElapsed += dt;
    }
    _cooldown = math.max(0, _cooldown - dt);
    _chainCleanupTimer = math.max(0, _chainCleanupTimer - dt);
    _gemRingPhase = (_gemRingPhase + dt * 0.45) % (math.pi * 2);
    if (_recentHitTimers.isNotEmpty) {
      _recentHitTimers.updateAll((_, timer) => timer - dt);
      _recentHitTimers.removeWhere(
        (enemy, remaining) => remaining <= 0 || enemy.isDead,
      );
    }
    if (!game.isWaveRunning) {
      _clearAim();
      return;
    }
    if (_cooldown > 0) {
      _clearAim();
      return;
    }

    if (definition.instantHit) {
      _updateInstantHitAttack(dt);
      return;
    }

    if (definition.centeredAreaAttack) {
      final targets = _findTargetsInRange();
      if (targets.isEmpty) {
        return;
      }

      _cooldown = (1 / attackRate) * _nextCooldownVarianceMultiplier();
      final leadTarget = targets.reduce(
        (a, b) => a.distanceTravelled >= b.distanceTravelled ? a : b,
      );
      _aimAngle = math.atan2(
        leadTarget.position.y - position.y,
        leadTarget.position.x - position.x,
      );
      _triggerFireFeedback();
      game.resolveCenteredAreaAttack(
        owner: this,
        attack: createAttackSnapshot(),
        targets: targets,
      );
      return;
    }

    if (definition.type == TurretType.lightning) {
      _updateLightningAttack();
      return;
    }

    final target = _findTarget();
    if (target == null) {
      return;
    }

    _cooldown = (1 / attackRate) * _nextCooldownVarianceMultiplier();
    _aimAngle = math.atan2(
      target.position.y - position.y,
      target.position.x - position.x,
    );
    _triggerFireFeedback();
    final projectileOrigin = definition.type == TurretType.magic
        ? (() {
            final origin = fireballOriginForTurret(
              center: Offset(position.x, position.y),
              size: size.y,
              aimAngle: _aimAngle,
            );
            return Vector2(origin.dx, origin.dy);
          })()
        : position.clone();
    final attack = createAttackSnapshot(
      criticalMultiplier: rollCriticalHit() ? criticalDamageMultiplier : 1.0,
    );
    game.add(
      ProjectileComponent(
        origin: projectileOrigin,
        targetPosition: target.position.clone(),
        owner: this,
        attack: attack,
        game: game,
      ),
    );
  }

  void _updateLightningAttack() {
    final target = _findTarget();
    if (target == null) {
      return;
    }

    final attack = createAttackSnapshot(
      criticalMultiplier: rollCriticalHit() ? criticalDamageMultiplier : 1.0,
    );
    final baseCooldown = (1 / attackRate) * _nextCooldownVarianceMultiplier();
    _cooldown = baseCooldown;
    _lastLightningBaseCooldown = baseCooldown;
    _lightningAttackElapsed = 0;
    _aimAngle = math.atan2(
      target.position.y - position.y,
      target.position.x - position.x,
    );
    _triggerFireFeedback();
    game.add(
      LightningChargeComponent(
        chargePosition: () => lightningChargePosition,
        isActive: () => isMounted,
        onRelease: () => releaseLightningCharge(attack),
        color: definition.color,
        visualScale: game.boardDistanceScale,
      ),
    );
  }

  void releaseLightningCharge(TurretAttackSnapshot attack) {
    final target = _findTarget();
    if (target == null) {
      recordLightningChainCompletion(
        usedJumps: 0,
        maxJumps: attack.lightningChainMaxJumps,
      );
      return;
    }

    _aimAngle = math.atan2(
      target.position.y - position.y,
      target.position.x - position.x,
    );
    _triggerFireFeedback();
    game.resolveLightningChainAttack(
      owner: this,
      target: target,
      attack: attack,
    );
  }

  void _updateInstantHitAttack(double dt) {
    var target = _aimTarget;
    if (target == null || !_isValidAimTarget(target)) {
      target = _findTarget();
      _aimTarget = target;
      _aimProgress = 0;
    }
    if (target == null) {
      return;
    }

    _aimAngle = math.atan2(
      target.position.y - position.y,
      target.position.x - position.x,
    );
    _aimProgress += dt;
    if (_aimProgress < aimDuration) {
      return;
    }

    final attack = createAttackSnapshot(
      criticalMultiplier: rollCriticalHit() ? criticalDamageMultiplier : 1.0,
    );
    _cooldown = (1 / attackRate) * _nextCooldownVarianceMultiplier();
    _triggerFireFeedback();
    game.resolveInstantHit(owner: this, target: target, attack: attack);
    _clearAim();
  }

  EnemyComponent? _findTarget() {
    EnemyComponent? selectedTarget;
    var selectedDistanceSquared = double.infinity;
    var selectedDurability = 0.0;
    for (final enemy in game.enemies) {
      if (enemy.isDead || !isEnemyBodyInRange(enemy)) {
        continue;
      }
      final distanceSquared = _distanceSquaredTo(enemy);
      final durability =
          enemy.hp + math.max(0, enemy.armor) + math.max(0, enemy.shield);
      if (_isPreferredTarget(
        candidate: enemy,
        current: selectedTarget,
        candidateDistanceSquared: distanceSquared,
        currentDistanceSquared: selectedDistanceSquared,
        candidateDurability: durability,
        currentDurability: selectedDurability,
      )) {
        selectedTarget = enemy;
        selectedDistanceSquared = distanceSquared;
        selectedDurability = durability;
      }
    }
    return selectedTarget;
  }

  bool _isPreferredTarget({
    required EnemyComponent candidate,
    required EnemyComponent? current,
    required double candidateDistanceSquared,
    required double currentDistanceSquared,
    required double candidateDurability,
    required double currentDurability,
  }) {
    if (current == null) {
      return true;
    }
    return switch (_targetPriority) {
      TurretTargetPriority.first =>
        candidate.distanceTravelled > current.distanceTravelled ||
            (candidate.distanceTravelled == current.distanceTravelled &&
                candidateDistanceSquared < currentDistanceSquared),
      TurretTargetPriority.last =>
        candidate.distanceTravelled < current.distanceTravelled ||
            (candidate.distanceTravelled == current.distanceTravelled &&
                candidateDistanceSquared < currentDistanceSquared),
      TurretTargetPriority.strongest =>
        candidateDurability > currentDurability ||
            (candidateDurability == currentDurability &&
                candidate.distanceTravelled > current.distanceTravelled),
      TurretTargetPriority.weakest =>
        candidateDurability < currentDurability ||
            (candidateDurability == currentDurability &&
                candidate.distanceTravelled > current.distanceTravelled),
      TurretTargetPriority.nearest =>
        candidateDistanceSquared < currentDistanceSquared ||
            (candidateDistanceSquared == currentDistanceSquared &&
                candidate.distanceTravelled > current.distanceTravelled),
    };
  }

  double _distanceSquaredTo(EnemyComponent enemy) {
    final dx = enemy.position.x - position.x;
    final dy = enemy.position.y - position.y;
    return dx * dx + dy * dy;
  }

  List<EnemyComponent> _findTargetsInRange() {
    final targets = <EnemyComponent>[];
    for (final enemy in game.enemies) {
      if (!enemy.isDead && isEnemyBodyInRange(enemy)) {
        targets.add(enemy);
      }
    }
    return targets;
  }

  bool _isValidAimTarget(EnemyComponent enemy) {
    return (enemy.isMounted || game.enemies.contains(enemy)) &&
        !enemy.isDead &&
        isEnemyBodyInRange(enemy);
  }

  double _nextCooldownVarianceMultiplier() {
    return 1 -
        _cooldownVariance +
        _cooldownRandom.nextDouble() * 2 * _cooldownVariance;
  }

  void _triggerFireFeedback() {
    _fireFeedbackTimer = _fireFeedbackDuration;
  }

  void _clearAim() {
    _aimTarget = null;
    _aimProgress = 0;
  }

  @override
  void render(Canvas canvas) {
    final selected = game.isTurretSelected(gridPoint);
    final center = Offset(size.x / 2, size.y / 2);
    drawTurretRangeIndicator(
      canvas,
      center: center,
      color: definition.color,
      range: range,
      selected: selected,
      previewRange: selected ? game.levelUpPreviewRangeFor(gridPoint) : null,
    );

    if (selected) {
      drawTurretSelectionHighlight(
        canvas,
        center: center,
        tileSize: _tileSize,
        color: definition.color,
      );
    }

    _levelRenderer.drawPowerAura(
      canvas,
      center: center,
      tileSize: _tileSize,
      level: _level,
    );
    _syncGemSlotLength();
    final gems = equippedGems;
    if (gems.isNotEmpty) {
      final visibleGemCount = math.min(gems.length, maxSlotLimit);
      drawTurretGemReactionRing(
        canvas,
        center: center,
        tileSize: _tileSize,
        animationPhase: _gemRingPhase,
        gemColors: [
          for (var i = 0; i < visibleGemCount; i++) game.colorForGem(gems[i]),
        ],
      );
    }
    final aimTarget = _aimTarget;
    if (aimTarget != null && definition.instantHit) {
      drawTurretAimBeam(
        canvas,
        center: center,
        target: Offset(
          center.dx + aimTarget.position.x - position.x,
          center.dy + aimTarget.position.y - position.y,
        ),
        color: definition.color,
        tileSize: _tileSize,
        progress: aimProgressRatio,
        animationPhase: _gemRingPhase,
      );
    }

    drawTurretShape(
      canvas,
      size: Size(size.x, size.y),
      type: definition.type,
      color: definition.color,
      aimAngle: _aimAngle,
      fireFeedback: (_fireFeedbackTimer / _fireFeedbackDuration).clamp(
        0.0,
        1.0,
      ),
      animationTime: _shapeAnimationTime,
      strokeWidth: size.x * 0.05,
    );

    _levelRenderer.drawBadge(
      canvas,
      center: center,
      tileSize: _tileSize,
      level: _level,
    );
  }

  void _syncGemSlotLength() {
    while (_gemSlots.length < _slotLimit) {
      _gemSlots.add(null);
    }
    if (_gemSlots.length > _slotLimit) {
      _gemSlots.removeRange(_slotLimit, _gemSlots.length);
    }
  }
}

enum TurretDamageKind { direct, splash, chain, burn }

class TurretAttackSnapshot {
  const TurretAttackSnapshot({
    required this.sourceTurretPoint,
    required this.definition,
    required this.damage,
    required this.range,
    required this.splashRadius,
    required this.splashSecondaryDamageMultiplier,
    required this.projectileSpeed,
    required this.criticalMultiplier,
    required this.physicalResistanceReduction,
    required this.ignoresArmorReduction,
    required this.damageOverTimeDamageMultiplier,
    required this.damageOverTimeDurationMultiplier,
    required this.slowDuration,
    required this.slowMultiplier,
    required this.hasChain,
    required this.appliesFrostCrack,
    required this.appliesIgnitionBurst,
    required this.spreadsChainIgnition,
    required this.appliesChainCleanup,
    required this.appliesSuppressiveFire,
    required this.appliesExposedMark,
    required this.appliesOverheatMagazine,
    required this.appliesCompressedCharge,
    required this.appliesFinishingShot,
    required this.appliesFocusedLightning,
    required this.lightningChainMaxJumps,
    required this.lightningChainDamageMultiplier,
    required this.lightningChainJumpRange,
  });

  final GridPoint sourceTurretPoint;
  final TurretDefinition definition;
  final double damage;
  final double range;
  final double splashRadius;
  final double splashSecondaryDamageMultiplier;
  final double projectileSpeed;
  final double criticalMultiplier;
  final double physicalResistanceReduction;
  final bool ignoresArmorReduction;
  final double damageOverTimeDamageMultiplier;
  final double damageOverTimeDurationMultiplier;
  final double slowDuration;
  final double slowMultiplier;
  final bool hasChain;
  final bool appliesFrostCrack;
  final bool appliesIgnitionBurst;
  final bool spreadsChainIgnition;
  final bool appliesChainCleanup;
  final bool appliesSuppressiveFire;
  final bool appliesExposedMark;
  final bool appliesOverheatMagazine;
  final bool appliesCompressedCharge;
  final bool appliesFinishingShot;
  final bool appliesFocusedLightning;
  final int lightningChainMaxJumps;
  final double lightningChainDamageMultiplier;
  final double lightningChainJumpRange;

  bool get hasDamageOverTime =>
      definition.attackTags.contains(AttackTag.damageOverTime);
}
