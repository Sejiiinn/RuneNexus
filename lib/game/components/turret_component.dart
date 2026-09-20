import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../data/definitions/game_gem_data.dart';
import '../../data/save/game_save_data.dart';
import '../../domain/combat/attack_calculation.dart';
import '../../domain/combat/turret_stat_input.dart';
import '../../domain/combat/turret_stat_calculation.dart';
import '../../domain/gem/gem_equip_rules.dart';
import '../../domain/gem/gem_type.dart';
import '../../domain/map/grid_point.dart';
import '../../domain/turret/attack_tag.dart';
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
  int _visualShotSequence = 0;
  double _shapeAnimationTime = 0;
  double _gemRingPhase = 0;
  double? _nativeGemRingClock;
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

  static const double _cooldownVariance = 0.05;
  static const double _fireFeedbackDuration = 0.12;

  int get level => _level;
  double get visualGemRingPhase =>
      (_gemRingPhase +
          (_nativeGemRingClock == null
              ? 0
              : (game.battlefieldEffectCombatClock - _nativeGemRingClock!) *
                    0.45)) %
      (math.pi * 2);
  double get visualGemRingPhaseOrigin =>
      _gemRingPhase -
      (_nativeGemRingClock ?? game.battlefieldEffectCombatClock) * 0.45;
  Offset? get visualAimTargetPosition =>
      definition.instantHit && _aimTarget != null
      ? Offset(_aimTarget!.position.x, _aimTarget!.position.y)
      : null;
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
  late final TurretStatCalculation _stats = TurretStatCalculation(
    _ComponentTurretStatSource(this),
  );

  double get damage => _stats.damage;
  int get projectileCount => _stats.projectileCount;
  double get range => _stats.range;
  double get attackRate => _stats.attackRate;
  double get projectileSpeed => _stats.projectileSpeed;
  double damageAtLevel(int level) => _stats.damageAtLevel(level);
  double rangeAtLevel(int level) => _stats.rangeAtLevel(level);
  double attackRateAtLevel(int level) => _stats.attackRateAtLevel(level);

  TurretAttackSnapshot createAttackSnapshot({double criticalMultiplier = 1}) {
    final stats = _stats.createFiringStats(
      criticalMultiplier: criticalMultiplier,
    );
    return TurretAttackSnapshot(
      sourceTurretPoint: gridPoint,
      definition: definition,
      damage: stats.damage,
      range: stats.range,
      effectAreaMultiplier: stats.effectAreaMultiplier,
      centeredAreaRadius: stats.centeredAreaRadius,
      chainCount: stats.chainCount,
      splashRadius: stats.splashRadius,
      splashSecondaryDamageMultiplier: stats.splashSecondaryDamageMultiplier,
      projectileSpeed: stats.projectileSpeed,
      criticalMultiplier: stats.criticalMultiplier,
      physicalResistanceReduction: stats.physicalResistanceReduction,
      ignoresArmorReduction: stats.ignoresArmorReduction,
      damageOverTimeDamageMultiplier: stats.damageOverTimeDamageMultiplier,
      damageOverTimeDurationMultiplier: stats.damageOverTimeDurationMultiplier,
      slowDuration: stats.slowDuration,
      slowMultiplier: stats.slowMultiplier,
      hasChain: stats.hasChain,
      appliesFrostCrack: stats.appliesFrostCrack,
      appliesIgnitionBurst: stats.appliesIgnitionBurst,
      spreadsChainIgnition: stats.spreadsChainIgnition,
      appliesChainCleanup: stats.appliesChainCleanup,
      appliesSuppressiveFire: stats.appliesSuppressiveFire,
      appliesExposedMark: stats.appliesExposedMark,
      appliesOverheatMagazine: stats.appliesOverheatMagazine,
      appliesCompressedCharge: stats.appliesCompressedCharge,
      appliesFinishingShot: stats.appliesFinishingShot,
      appliesFocusedLightning: stats.appliesFocusedLightning,
      lightningChainMaxJumps: stats.lightningChainMaxJumps,
      lightningChainDamageMultiplier: stats.lightningChainDamageMultiplier,
      lightningChainJumpRange: stats.lightningChainJumpRange,
    );
  }

  double get damageOverTimeDamageMultiplier =>
      _stats.damageOverTimeDamageMultiplier;
  double get damageOverTimeDurationMultiplier =>
      _stats.damageOverTimeDurationMultiplier;
  double get slowMultiplier => _stats.slowMultiplier;
  double get slowDuration => _stats.slowDuration;
  bool get appliesFrostCrack => _stats.appliesFrostCrack;
  bool get appliesIgnitionBurst => _stats.appliesIgnitionBurst;
  bool get spreadsChainIgnition => _stats.spreadsChainIgnition;
  double get physicalResistanceReduction => _stats.physicalResistanceReduction;
  double get effectAreaMultiplier => _stats.effectAreaMultiplier;
  double get centeredAreaRadius => _stats.centeredAreaRadius;
  double get splashSecondaryDamageMultiplier =>
      _stats.splashSecondaryDamageMultiplier;
  double get splashRadius => _stats.splashRadius;
  int get chainCount => _stats.chainCount;
  bool get ignoresArmorReduction => _stats.ignoresArmorReduction;
  int get lightningChainMaxJumps => _stats.lightningChainMaxJumps;
  double get lightningChainDamageMultiplier =>
      _stats.lightningChainDamageMultiplier;
  bool get appliesLightningRecovery => _stats.appliesLightningRecovery;
  double slowMultiplierAtLevel(int level) =>
      _stats.slowMultiplierAtLevel(level);
  bool hasGem(GemType type) => equippedGems.contains(type);
  int get lightningChainMaxTargets => lightningChainMaxJumps + 1;

  Vector2 get lightningChargePosition {
    final offset = Vector2(math.cos(_aimAngle), math.sin(_aimAngle));
    return position + offset * (size.x * 0.58);
  }

  List<GemType> get equippedGems =>
      List.unmodifiable(_gemSlots.whereType<GemType>());
  List<GemType?> get equippedGemSlots =>
      List.unmodifiable(_gemSlots.take(_slotLimit));
  double get criticalChance => _stats.criticalChance;
  double get criticalDamageMultiplier => _stats.criticalDamageMultiplier;
  double get aimDuration => _stats.aimDuration;
  double aimDurationAtLevel(int level) => _stats.aimDurationAtLevel(level);

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
    return _isEnemyBodyInRange(enemy, range);
  }

  bool _isEnemyBodyInRange(EnemyComponent enemy, double attackRange) {
    final enemyRadius = math.min(enemy.size.x, enemy.size.y) / 2;
    final rangeWithBody = attackRange + enemyRadius;
    final dx = enemy.position.x - position.x;
    final dy = enemy.position.y - position.y;
    return dx * dx + dy * dy <= rangeWithBody * rangeWithBody;
  }

  Map<String, Object?> nativeCombatConfiguration(int id) => {
    'id': id,
    'position': [position.x, position.y],
    'statInput': TurretStatInput.capture(
      _ComponentTurretStatSource(this),
    ).toJson(),
    'state': toSaveData().toJson(),
    'aimProgress': _aimProgress,
    'aimTargetId': _aimTarget == null
        ? 0
        : game.nativeCombatEntityId(_aimTarget!),
    'aimAngle': _aimAngle,
    'overheatTarget': _overheatTarget == null
        ? 0
        : game.nativeCombatEntityId(_overheatTarget!),
    'overheatStacks': _overheatStacks,
    'suppressiveTarget': _suppressiveTarget == null
        ? 0
        : game.nativeCombatEntityId(_suppressiveTarget!),
    'suppressiveHits': _suppressiveHits,
    'cleanup': _chainCleanupTimer,
    'recent': {
      for (final entry in _recentHitTimers.entries)
        '${game.nativeCombatEntityId(entry.key)}': entry.value,
    },
    'lastBaseCooldown': _lastLightningBaseCooldown,
    'lightningElapsed': _lightningAttackElapsed,
  };

  void applyNativeCombatState(Map<String, dynamic> state) {
    _cooldown = (state['cooldown'] as num?)?.toDouble() ?? _cooldown;
    _aimProgress = (state['aimProgress'] as num?)?.toDouble() ?? _aimProgress;
    _aimAngle = (state['aimAngle'] as num?)?.toDouble() ?? _aimAngle;
    _visualShotSequence =
        (state['shotSequence'] as num?)?.toInt() ?? _visualShotSequence;
    _directDamageDealt =
        (state['directDamageDealt'] as num?)?.toDouble() ?? _directDamageDealt;
    _splashDamageDealt =
        (state['splashDamageDealt'] as num?)?.toDouble() ?? _splashDamageDealt;
    _chainDamageDealt =
        (state['chainDamageDealt'] as num?)?.toDouble() ?? _chainDamageDealt;
    _burnDamageDealt =
        (state['burnDamageDealt'] as num?)?.toDouble() ?? _burnDamageDealt;
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
      ..addAll(
        restoredSlots
            .take(_slotLimit)
            .map(
              (gem) => gem != null && canEquipGemOnTurret(gem, definition)
                  ? gem
                  : null,
            ),
      );
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
    if (!canEquipGemAt(slotIndex) || !canEquipGemOnTurret(type, definition)) {
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
    if (game.nativeCombatOwned) return;
    super.update(dt);
    _fireFeedbackTimer = math.max(0, _fireFeedbackTimer - dt);
    _shapeAnimationTime = (_shapeAnimationTime + dt) % 1000;
    if (_lastLightningBaseCooldown > 0 && _cooldown > 0) {
      _lightningAttackElapsed += dt;
    }
    _cooldown = math.max(0, _cooldown - dt);
    _chainCleanupTimer = math.max(0, _chainCleanupTimer - dt);
    if (game.usesNativeSelectionAnimation) {
      _nativeGemRingClock ??= game.battlefieldEffectCombatClock - dt;
    } else {
      if (_nativeGemRingClock != null) {
        _gemRingPhase = visualGemRingPhase;
        _nativeGemRingClock = null;
      } else {
        _gemRingPhase = (_gemRingPhase + dt * 0.45) % (math.pi * 2);
      }
    }
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
        attack: createAttackSnapshot(
          criticalMultiplier: rollCriticalHit()
              ? criticalDamageMultiplier
              : 1.0,
        ),
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
    final direction = target.position - projectileOrigin;
    final centerAngle = math.atan2(direction.y, direction.x);
    for (var index = 0; index < projectileCount; index++) {
      // 조준선을 중심으로 10도 간격의 대칭 산개
      final angle =
          centerAngle + (index - (projectileCount - 1) / 2) * math.pi / 18;
      game.add(
        ProjectileComponent(
          origin: projectileOrigin.clone(),
          targetPosition:
              projectileOrigin + Vector2(math.cos(angle), math.sin(angle)),
          owner: this,
          attack: attack,
          game: game,
        ),
      );
    }
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
        owner: this,
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
    final attackRange = range;
    EnemyComponent? selectedTarget;
    var selectedDistanceSquared = double.infinity;
    var selectedDurability = 0.0;
    for (final enemy in game.enemies) {
      if (enemy.isDead || !_isEnemyBodyInRange(enemy, attackRange)) {
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
    final attackRange = centeredAreaRadius;
    final targets = <EnemyComponent>[];
    for (final enemy in game.enemies) {
      if (!enemy.isDead && _isEnemyBodyInRange(enemy, attackRange)) {
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
    _visualShotSequence++;
  }

  void _clearAim() {
    _aimTarget = null;
    _aimProgress = 0;
  }

  int get visualShotSequence => _visualShotSequence;
  double get visualAimAngle => _aimAngle;
  double get visualFireFeedback =>
      (_fireFeedbackTimer / _fireFeedbackDuration).clamp(0.0, 1.0);

  void renderBattlefieldLevel(Canvas canvas) {
    _levelRenderer.drawBadge(
      canvas,
      center: Offset(size.x / 2, size.y / 2),
      tileSize: _tileSize,
      level: _level,
    );
  }

  @override
  void render(Canvas canvas) {
    final selected = game.isTurretSelected(gridPoint);
    final center = Offset(size.x / 2, size.y / 2);
    if (!game.isGemRewardTargeting &&
        (selected || game.isTurretPlacementActive)) {
      final previewRange = selected
          ? game.levelUpPreviewRangeFor(gridPoint)
          : null;
      // 중심 광역 공격은 사거리 수치와 별개인 실제 효과 반경 표시.
      final indicatorMultiplier = definition.centeredAreaAttack
          ? effectAreaMultiplier
          : 1.0;
      drawTurretRangeIndicator(
        canvas,
        center: center,
        color: definition.color,
        range: range * indicatorMultiplier,
        selected: selected,
        previewRange: previewRange == null
            ? null
            : previewRange * indicatorMultiplier,
      );
    }

    if (selected && !game.isGemRewardTargeting) {
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
        animationPhase: visualGemRingPhase,
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
        animationPhase: visualGemRingPhase,
      );
    }

    if (game.battlefieldProjection == null) {
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
    this.effectAreaMultiplier = 1,
    double? centeredAreaRadius,
    int? chainCount,
  }) : centeredAreaRadius = centeredAreaRadius ?? range,
       chainCount = chainCount ?? (hasChain ? 2 : 0);

  final GridPoint sourceTurretPoint;
  final TurretDefinition definition;
  final double damage;
  final double range;
  final double effectAreaMultiplier;
  final double centeredAreaRadius;
  final int chainCount;
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

/// Allocation-free per-stat adapter; progression and module caches remain owned
/// by the game. Mutable firing state contributes values, never ownership.
class _ComponentTurretStatSource implements TurretStatSource {
  @override
  bool hasGem(GemType type) => turret._gemSlots.contains(type);
  _ComponentTurretStatSource(this.turret);
  final TurretComponent turret;
  RuneNexusGame get game => turret.game;
  @override
  late final TurretStatDefinition definition = TurretStatDefinition(
    type: turret.definition.type,
    damageFamily: AttackDamageFamily.values.byName(
      turret.definition.damageFamily.name,
    ),
    attackTags: turret.definition.attackTags.map((tag) => tag.name).toSet(),
    damage: turret.definition.damage,
    range: turret.definition.range,
    attackRate: turret.definition.attackRate,
    projectileSpeed: turret.definition.projectileSpeed,
    projectileCount: turret.definition.projectileCount,
    splashRadius: turret.definition.splashRadius,
    centeredAreaAttack: turret.definition.centeredAreaAttack,
    instantHit: turret.definition.instantHit,
    aimDuration: turret.definition.aimDuration,
    criticalChance: turret.definition.criticalChance,
    criticalDamageMultiplier: turret.definition.criticalDamageMultiplier,
    slowMultiplier: turret.definition.slowMultiplier,
    slowDuration: turret.definition.slowDuration,
  );
  @override
  TurretModuleEffect get moduleEffect => turret._moduleEffect;
  @override
  Set<GemType> get gems => turret.equippedGems.toSet();
  @override
  TurretTraitType? get primaryTrait => turret.primaryTrait;
  @override
  TurretTraitType? get secondaryTrait => turret.secondaryTrait;
  @override
  int get level => turret.level;
  @override
  bool get chainCleanupActive => turret._chainCleanupTimer > 0;
  @override
  double get passiveNumericGemEffectMultiplier =>
      game.passiveNumericGemEffectMultiplier;
  @override
  double get towerDamageMultiplier =>
      game.towerDamageMultiplierFor(turret.definition.damageFamily);
  @override
  double get corePassiveTurretDamageMultiplier =>
      game.corePassiveTurretDamageMultiplier;
  @override
  double get corePassiveTurretAttackRateMultiplier =>
      game.corePassiveTurretAttackRateMultiplier;
  @override
  double get boardDistanceScale => game.boardDistanceScale;
  @override
  double get lightningChainJumpRange => game.lightningChainJumpRange;
  @override
  double get criticalChanceProgressionBonusRate =>
      game.criticalChanceProgressionBonusRate;
  @override
  double get criticalDamageProgressionBonusRate =>
      game.criticalDamageProgressionBonusRate;
  @override
  double get criticalChanceGemValue => gameGems[GemType.criticalChance]!.value;
  @override
  double get aimSpeedGemValue => gameGems[GemType.aimSpeed]!.value;
  @override
  double get explosionGemValue => gameGems[GemType.explosion]!.value;
}
