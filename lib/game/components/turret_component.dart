import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';
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
import '../../domain/turret_module/turret_module_type.dart';
import '../rune_nexus_game.dart';

/// Build configuration, stat previews and acknowledged native combat mirrors.
class TurretComponent {
  static const double _visualSizeScale = 0.82;

  TurretComponent({
    required this.gridPoint,
    required this.definition,
    required this.game,
    required Vector2 center,
    required double tileSize,
    int? investedGold,
  }) : _investedGold = investedGold ?? definition.cost,
       position = center,
       size = Vector2.all(tileSize * _visualSizeScale);

  Vector2 position;
  Vector2 size;
  bool _attached = false;
  bool _removed = false;
  void Function()? _onRemove;

  /// Registration only: the coordinator owns the collection, Godot owns time.
  bool get isMounted => _attached;
  bool get isRemoving => _removed;
  void attach({void Function()? onRemove}) {
    _nativeGemRingClock ??= game.battlefieldEffectCombatClock;
    _attached = true;
    _removed = false;
    _onRemove = onRemove;
  }

  void detach() {
    _attached = false;
    _removed = true;
    _onRemove = null;
  }

  void removeFromParent() {
    if (_removed) return;
    final remove = _onRemove;
    detach();
    remove?.call();
  }

  final GridPoint gridPoint;
  final TurretDefinition definition;
  final RuneNexusGame game;
  final List<GemType?> _gemSlots = [null];

  double _cooldown = 0;
  double _aimAngle = -math.pi / 2;
  double _fireFeedbackTimer = 0;
  int _visualShotSequence = 0;
  final double _gemRingPhase = 0;
  double? _nativeGemRingClock;
  int _aimTargetId = 0;
  Offset? _aimTargetPosition;
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
  int _overheatTargetId = 0;
  int _overheatStacks = 0;
  int _suppressiveTargetId = 0;
  int _suppressiveHits = 0;
  final Map<String, double> _recentHitTimers = {};
  double _chainCleanupTimer = 0;
  TurretTargetPriority _targetPriority = TurretTargetPriority.first;

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
      definition.instantHit ? _aimTargetPosition : null;
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
    if (!definition.instantHit || duration <= 0 || _aimTargetId == 0) {
      return 0;
    }
    return (_aimProgress / duration).clamp(0.0, 1.0);
  }

  bool canEquipGemAt(int slotIndex) {
    return slotIndex >= 0 && slotIndex < slotLimit;
  }

  void setTargetPriority(TurretTargetPriority priority) {
    _targetPriority = priority;
  }

  Map<String, Object?> nativeCombatConfiguration(int id) => {
    'id': id,
    'position': [position.x, position.y],
    'statInput': TurretStatInput.capture(
      _ComponentTurretStatSource(this),
    ).toJson(),
    'state': toSaveData().toJson(),
    'aimProgress': _aimProgress,
    'aimTargetId': _aimTargetId,
    'aimAngle': _aimAngle,
    'overheatTarget': _overheatTargetId,
    'overheatStacks': _overheatStacks,
    'suppressiveTarget': _suppressiveTargetId,
    'suppressiveHits': _suppressiveHits,
    'cleanup': _chainCleanupTimer,
    'recent': {
      for (final entry in _recentHitTimers.entries) entry.key: entry.value,
    },
    'lastBaseCooldown': _lastLightningBaseCooldown,
    'lightningElapsed': _lightningAttackElapsed,
  };

  static int? _nativeId(Object? value) => value is num
      ? value.toInt()
      : value is String
      ? int.tryParse(value)
      : null;

  void applyNativeCombatState(Map<String, dynamic> state) {
    _aimTargetId = _nativeId(state['aimTargetId']) ?? _aimTargetId;
    _overheatTargetId = _nativeId(state['overheatTarget']) ?? _overheatTargetId;
    _overheatStacks =
        (state['overheatStacks'] as num?)?.toInt() ?? _overheatStacks;
    _suppressiveTargetId =
        _nativeId(state['suppressiveTarget']) ?? _suppressiveTargetId;
    _suppressiveHits =
        (state['suppressiveHits'] as num?)?.toInt() ?? _suppressiveHits;
    _chainCleanupTimer =
        (state['cleanup'] as num?)?.toDouble() ?? _chainCleanupTimer;
    _lastLightningBaseCooldown =
        (state['lastBaseCooldown'] as num?)?.toDouble() ??
        _lastLightningBaseCooldown;
    _lightningAttackElapsed =
        (state['lightningElapsed'] as num?)?.toDouble() ??
        _lightningAttackElapsed;
    _fireFeedbackTimer =
        (state['fireFeedback'] as num?)?.toDouble() ?? _fireFeedbackTimer;
    final recent = state['recent'];
    if (recent is Map) {
      _recentHitTimers.clear();
      for (final entry in recent.entries) {
        if (entry.value is num) {
          _recentHitTimers['${entry.key}'] = (entry.value as num).toDouble();
        }
      }
    }
    final aimPosition = state['aimTargetPosition'];
    if (aimPosition is List && aimPosition.length >= 2) {
      _aimTargetPosition = Offset(
        (aimPosition[0] as num).toDouble(),
        (aimPosition[1] as num).toDouble(),
      );
    } else if (_aimTargetId == 0) {
      _aimTargetPosition = null;
    }
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
    _overheatTargetId = 0;
    _overheatStacks = 0;
    _suppressiveTargetId = 0;
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
    _suppressiveTargetId = 0;
    _suppressiveHits = 0;
    _recentHitTimers.clear();
    _chainCleanupTimer = 0;
    _lastLightningBaseCooldown = 0;
    _lightningAttackElapsed = 0;
    return true;
  }

  void updateLayout({required Vector2 center, required double tileSize}) {
    position = center;
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

  int get visualShotSequence => _visualShotSequence;
  double get visualAimAngle => _aimAngle;
  double get visualFireFeedback =>
      (_fireFeedbackTimer / _fireFeedbackDuration).clamp(0.0, 1.0);

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
