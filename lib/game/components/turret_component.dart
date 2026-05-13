import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../data/save/game_save_data.dart';
import '../../domain/gem/gem_type.dart';
import '../../domain/map/grid_point.dart';
import '../../domain/turret/attack_tag.dart';
import '../../domain/turret/damage_family.dart';
import '../../domain/turret/turret_definition.dart';
import '../../domain/turret/turret_trait_catalog.dart';
import '../../domain/turret/turret_trait_type.dart';
import '../../domain/turret/turret_type.dart';
import '../rendering/turret_shape_renderer.dart';
import '../rune_nexus_game.dart';
import 'enemy_component.dart';
import 'projectile_component.dart';

enum TurretTargetPriority { first, last, nearest }

class TurretComponent extends PositionComponent {
  static const double _visualSizeScale = 0.82;

  TurretComponent({
    required this.gridPoint,
    required this.definition,
    required this.game,
    required Vector2 center,
    required double tileSize,
  }) : _tileSize = tileSize,
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
  double _gemRingPhase = 0;
  int _slotLimit = 1;
  int _level = 1;
  double _directDamageDealt = 0;
  double _splashDamageDealt = 0;
  double _chainDamageDealt = 0;
  double _burnDamageDealt = 0;
  TurretTraitType? _primaryTrait;
  TurretTraitType? _secondaryTrait;
  EnemyComponent? _overheatTarget;
  int _overheatStacks = 0;
  EnemyComponent? _suppressiveTarget;
  int _suppressiveHits = 0;
  final Map<EnemyComponent, double> _recentHitTimers = {};
  double _chainCleanupTimer = 0;
  TurretTargetPriority _targetPriority = TurretTargetPriority.first;

  static const double _damageGrowthPerLevel = 0.2;
  static const double _rangeGrowthPerLevel = 0.033;
  static const double _attackRateGrowthPerLevel = 0.05;
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
  int get levelUpCost =>
      (definition.cost * (70 + (_level - 1) * 45) + 50) ~/ 100;
  int get investedGold {
    var total = definition.cost;
    for (var level = 1; level < _level; level++) {
      total += _levelUpCostAt(level);
    }
    if (_slotLimit >= 2) {
      total += _linkUpgradeCostForSlot(2);
    }
    if (_slotLimit >= 3) {
      total += _linkUpgradeCostForSlot(3);
    }
    return total;
  }

  int get refundGold => investedGold * 75 ~/ 100;
  bool get canLevelUp => _level < maxLevel;
  int get slotLimit => _slotLimit;
  int get maxSlotLimit => 3;
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

  double get damage {
    var levelDamage =
        definition.damage *
        math.pow(1 + _damageGrowthPerLevel, _level - 1).toDouble();
    if (definition.damageFamily == DamageFamily.physical &&
        hasGem(GemType.physicalDamage)) {
      levelDamage *= 1.4;
    }
    if (definition.damageFamily == DamageFamily.magical &&
        hasGem(GemType.magicalDamage)) {
      levelDamage *= 1.4;
    }
    if (definition.attackTags.contains(AttackTag.light) &&
        hasGem(GemType.lightWeapon)) {
      levelDamage *= 1.2;
    }
    if (definition.attackTags.contains(AttackTag.heavy) &&
        hasGem(GemType.heavyWeapon)) {
      levelDamage *= 1.3;
    }
    if (_primaryTrait == TurretTraitType.spreadingChill) {
      levelDamage *= 0.9;
    }

    return levelDamage * game.towerDamageRunMultiplier;
  }

  double get range {
    final levelMultiplier = 1 + (_level - 1) * _rangeGrowthPerLevel;
    return definition.range *
        levelMultiplier *
        (hasGem(GemType.range) ? 1.2 : 1) *
        (_primaryTrait == TurretTraitType.spreadingChill ? 1.15 : 1) *
        game.boardDistanceScale;
  }

  double get attackRate {
    final levelMultiplier = math
        .pow(1 + _attackRateGrowthPerLevel, _level - 1)
        .toDouble();
    var rate =
        definition.attackRate *
        levelMultiplier *
        (hasGem(GemType.attackSpeed) ? 1.4 : 1) *
        (definition.attackTags.contains(AttackTag.light) &&
                hasGem(GemType.lightWeapon)
            ? 1.2
            : 1) *
        (_primaryTrait == TurretTraitType.lightweightBarrel ? 1.1 : 1) *
        (_primaryTrait == TurretTraitType.compressedCharge ? 0.9 : 1) *
        (_primaryTrait == TurretTraitType.coolingCycle ? 1.2 : 1);
    if (_chainCleanupTimer > 0) {
      rate *= 1.4;
    }
    return rate;
  }

  double get projectileSpeed =>
      definition.projectileSpeed *
      (_primaryTrait == TurretTraitType.lightweightBarrel ? 1.3 : 1) *
      game.boardDistanceScale;

  double get damageOverTimeDamageMultiplier {
    if (!definition.attackTags.contains(AttackTag.damageOverTime)) {
      return 1;
    }
    var bonus = 0.0;
    if (hasGem(GemType.damageOverTime)) {
      bonus += 0.3;
    }
    if (_primaryTrait == TurretTraitType.highHeatBurn) {
      bonus += 0.25;
    }
    return 1 + bonus;
  }

  double get damageOverTimeDurationMultiplier {
    if (!definition.attackTags.contains(AttackTag.damageOverTime)) {
      return 1;
    }
    var bonus = 0.0;
    if (hasGem(GemType.damageOverTime)) {
      bonus += 0.3;
    }
    if (_primaryTrait == TurretTraitType.lingeringEmbers) {
      bonus += 0.4;
    }
    return 1 + bonus;
  }

  double get slowMultiplier {
    if (_secondaryTrait == TurretTraitType.rapidCooling) {
      return 0.62;
    }
    return definition.slowMultiplier;
  }

  double get slowDuration =>
      definition.slowDuration *
      (_primaryTrait == TurretTraitType.coolingCycle ? 0.85 : 1);

  bool get appliesFrostCrack => _secondaryTrait == TurretTraitType.frostCrack;
  bool get appliesIgnitionBurst =>
      _secondaryTrait == TurretTraitType.ignitionBurst;
  bool get spreadsChainIgnition =>
      _secondaryTrait == TurretTraitType.chainIgnition;

  double get splashSecondaryDamageMultiplier {
    if (hasGem(GemType.explosion)) {
      return definition.splashRadius > 0 ? 0.5 : 0.35;
    }
    if (_primaryTrait == TurretTraitType.shrapnelShell) {
      return definition.splashRadius > 0 ? 0.6 : 1;
    }
    return definition.splashRadius > 0 ? 0.5 : 1;
  }

  double get splashRadius {
    final heavyMultiplier =
        definition.attackTags.contains(AttackTag.heavy) &&
            hasGem(GemType.heavyWeapon)
        ? 1.2
        : 1.0;
    if (definition.splashRadius > 0) {
      return definition.splashRadius *
          (hasGem(GemType.explosion) ? 1.25 : 1) *
          (_primaryTrait == TurretTraitType.shrapnelShell ? 1.2 : 1) *
          heavyMultiplier *
          game.boardDistanceScale;
    }
    return (hasGem(GemType.explosion) ? 34 : 0) *
        heavyMultiplier *
        game.boardDistanceScale;
  }

  bool hasGem(GemType type) => equippedGems.contains(type);
  List<GemType> get equippedGems =>
      List.unmodifiable(_gemSlots.whereType<GemType>());
  List<GemType?> get equippedGemSlots =>
      List.unmodifiable(_gemSlots.take(_slotLimit));

  bool canEquipGemAt(int slotIndex) {
    return slotIndex >= 0 && slotIndex < slotLimit;
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
      damageDealt: damageDealt,
      directDamageDealt: _directDamageDealt,
      splashDamageDealt: _splashDamageDealt,
      chainDamageDealt: _chainDamageDealt,
      burnDamageDealt: _burnDamageDealt,
      primaryTrait: _primaryTrait,
      secondaryTrait: _secondaryTrait,
    );
  }

  void restoreFromSaveData(SavedTurret data) {
    _level = data.level.clamp(1, maxLevel).toInt();
    _slotLimit = data.slotLimit.clamp(1, maxSlotLimit).toInt();
    _cooldown = math.max(0, data.cooldown);
    _directDamageDealt = math.max(0, data.directDamageDealt);
    _splashDamageDealt = math.max(0, data.splashDamageDealt);
    _chainDamageDealt = math.max(0, data.chainDamageDealt);
    _burnDamageDealt = math.max(0, data.burnDamageDealt);
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
    return true;
  }

  double registerDirectHitTraits(EnemyComponent enemy) {
    if (_secondaryTrait == TurretTraitType.chainCleanup) {
      _recentHitTimers[enemy] = 1.5;
    }
    if (_secondaryTrait == TurretTraitType.suppressiveFire) {
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
    if (_primaryTrait == TurretTraitType.overheatMagazine) {
      if (identical(_overheatTarget, enemy)) {
        _overheatStacks = math.min(15, _overheatStacks + 1);
      } else {
        _overheatTarget = enemy;
        _overheatStacks = 1;
      }
      return 1 + _overheatStacks * 0.02;
    }
    if (_primaryTrait == TurretTraitType.compressedCharge) {
      return 1.35;
    }
    return 1;
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

  bool upgradeLevel() {
    if (!canLevelUp) {
      return false;
    }
    _level++;
    return true;
  }

  bool upgradeLink() {
    if (!canUpgradeLink) {
      return false;
    }
    _slotLimit++;
    _syncGemSlotLength();
    return true;
  }

  int _levelUpCostAt(int level) {
    return (definition.cost * (70 + (level - 1) * 45) + 50) ~/ 100;
  }

  int _linkUpgradeCostForSlot(int slotLimit) {
    final costPercent = slotLimit == 2 ? 150 : 300;
    return (definition.cost * costPercent + 50) ~/ 100;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _fireFeedbackTimer = math.max(0, _fireFeedbackTimer - dt);
    _cooldown = math.max(0, _cooldown - dt);
    _chainCleanupTimer = math.max(0, _chainCleanupTimer - dt);
    _gemRingPhase = (_gemRingPhase + dt * 0.45) % (math.pi * 2);
    if (_recentHitTimers.isNotEmpty) {
      for (final entry in _recentHitTimers.entries.toList()) {
        final remaining = entry.value - dt;
        if (remaining <= 0 || entry.key.isDead) {
          _recentHitTimers.remove(entry.key);
        } else {
          _recentHitTimers[entry.key] = remaining;
        }
      }
    }
    if (_cooldown > 0 || !game.isWaveRunning) {
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
      game.resolveCenteredAreaAttack(owner: this, targets: targets);
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
            );
            return Vector2(origin.dx, origin.dy);
          })()
        : position.clone();
    game.add(
      ProjectileComponent(
        origin: projectileOrigin,
        targetPosition: target.position.clone(),
        owner: this,
        game: game,
      ),
    );
  }

  EnemyComponent? _findTarget() {
    EnemyComponent? selectedTarget;
    var selectedDistanceSquared = double.infinity;
    for (final enemy in game.enemies) {
      if (!enemy.isMounted || enemy.isDead || !isEnemyBodyInRange(enemy)) {
        continue;
      }
      final distanceSquared = _targetPriority == TurretTargetPriority.nearest
          ? _distanceSquaredTo(enemy)
          : double.infinity;
      if (_isPreferredTarget(
        candidate: enemy,
        current: selectedTarget,
        candidateDistanceSquared: distanceSquared,
        currentDistanceSquared: selectedDistanceSquared,
      )) {
        selectedTarget = enemy;
        selectedDistanceSquared = distanceSquared;
      }
    }
    return selectedTarget;
  }

  bool _isPreferredTarget({
    required EnemyComponent candidate,
    required EnemyComponent? current,
    required double candidateDistanceSquared,
    required double currentDistanceSquared,
  }) {
    if (current == null) {
      return true;
    }
    return switch (_targetPriority) {
      TurretTargetPriority.first =>
        candidate.distanceTravelled > current.distanceTravelled,
      TurretTargetPriority.last =>
        candidate.distanceTravelled < current.distanceTravelled,
      TurretTargetPriority.nearest =>
        candidateDistanceSquared < currentDistanceSquared,
    };
  }

  double _distanceSquaredTo(EnemyComponent enemy) {
    final dx = enemy.position.x - position.x;
    final dy = enemy.position.y - position.y;
    return dx * dx + dy * dy;
  }

  List<EnemyComponent> _findTargetsInRange() {
    return game.enemies.where((enemy) {
      return enemy.isMounted && !enemy.isDead && isEnemyBodyInRange(enemy);
    }).toList();
  }

  double _nextCooldownVarianceMultiplier() {
    return 1 -
        _cooldownVariance +
        _cooldownRandom.nextDouble() * 2 * _cooldownVariance;
  }

  void _triggerFireFeedback() {
    _fireFeedbackTimer = _fireFeedbackDuration;
  }

  @override
  void render(Canvas canvas) {
    final selected = game.isTurretSelected(gridPoint);
    final center = Offset(size.x / 2, size.y / 2);
    final rangePaint = Paint()
      ..color = definition.color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, range, rangePaint);
    if (selected) {
      final rangeStroke = Paint()
        ..color = definition.color.withValues(alpha: 0.48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawCircle(center, range, rangeStroke);
    }

    if (selected) {
      _drawSelectionHighlight(canvas, center);
    }

    _drawLevelPowerAura(canvas, center);
    _syncGemSlotLength();
    _drawGemReactionRing(canvas, center);

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
    );

    _drawLevelGlyph(canvas, center);
  }

  void _syncGemSlotLength() {
    while (_gemSlots.length < _slotLimit) {
      _gemSlots.add(null);
    }
    if (_gemSlots.length > _slotLimit) {
      _gemSlots.removeRange(_slotLimit, _gemSlots.length);
    }
  }

  void _drawGemReactionRing(Canvas canvas, Offset center) {
    final gems = equippedGems;
    if (gems.isEmpty) {
      return;
    }

    final ringRect = Rect.fromCircle(center: center, radius: _tileSize * 0.43);
    final pulse = 0.88 + math.sin(_gemRingPhase * 2.4) * 0.12;
    final baseStroke = _tileSize * 0.03;
    final glowStroke = _tileSize * 0.1;
    canvas.drawOval(
      ringRect,
      Paint()
        ..color = const Color(0xFF020812).withValues(alpha: 0.76)
        ..style = PaintingStyle.stroke
        ..strokeWidth = baseStroke * 2.1,
    );

    final count = math.min(gems.length, maxSlotLimit);
    final gap = count == 1 ? 0.0 : 0.22;
    final segmentSweep = count == 1
        ? math.pi * 1.64
        : (math.pi * 2 / count) - gap;
    final startOffset =
        -math.pi / 2 - (count == 1 ? segmentSweep / 2 : 0) + _gemRingPhase;
    for (var i = 0; i < count; i++) {
      final gemColor = game.colorForGem(gems[i]);
      final ringColor = Color.lerp(gemColor, const Color(0xFFFFFFFF), 0.12)!;
      final start = count == 1
          ? startOffset
          : startOffset + i * math.pi * 2 / count + gap / 2;

      canvas.drawArc(
        ringRect,
        start,
        segmentSweep,
        false,
        Paint()
          ..color = ringColor.withValues(alpha: 0.34 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = glowStroke,
      );
      canvas.drawArc(
        ringRect,
        start,
        segmentSweep,
        false,
        Paint()
          ..color = ringColor.withValues(alpha: 0.96 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = baseStroke,
      );
      final midAngle = start + segmentSweep / 2;
      final tickStart = Offset(
        center.dx + math.cos(midAngle) * _tileSize * 0.39,
        center.dy + math.sin(midAngle) * _tileSize * 0.39,
      );
      final tickEnd = Offset(
        center.dx + math.cos(midAngle) * _tileSize * 0.47,
        center.dy + math.sin(midAngle) * _tileSize * 0.47,
      );
      canvas.drawLine(
        tickStart,
        tickEnd,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.72 * pulse)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _tileSize * 0.011,
      );
    }
  }

  void _drawSelectionHighlight(Canvas canvas, Offset center) {
    final tileRect = Rect.fromCenter(
      center: center,
      width: _tileSize - 4,
      height: _tileSize - 4,
    );
    final radius = Radius.circular(_tileSize * 0.09);
    final outerPaint = Paint()
      ..color = definition.color.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;
    final glowPaint = Paint()
      ..color = definition.color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    final innerPaint = Paint()
      ..color = const Color(0xEEFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawRRect(RRect.fromRectAndRadius(tileRect, radius), glowPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(tileRect, radius), outerPaint);
    canvas.drawCircle(center, _tileSize * 0.42, outerPaint);
    canvas.drawCircle(center, _tileSize * 0.32, innerPaint);
  }

  void _drawLevelPowerAura(Canvas canvas, Offset center) {
    if (_level <= 1) {
      return;
    }

    final tier = _levelVisualTier;
    final ringRadius = _tileSize * (0.27 + tier * 0.018);
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD45A).withValues(alpha: 0.06 + tier * 0.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _tileSize * (0.045 + tier * 0.006);
    final ringPaint = Paint()
      ..color = const Color(0xFFFFE78C).withValues(alpha: 0.18 + tier * 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 + tier * 0.35;

    canvas.drawCircle(center, ringRadius, glowPaint);
    canvas.drawCircle(center, ringRadius, ringPaint);

    if (tier < 3) {
      return;
    }

    final sparkPaint = Paint()
      ..color = const Color(
        0xFFFFF0B0,
      ).withValues(alpha: tier >= 4 ? 0.95 : 0.72)
      ..strokeWidth = tier >= 4 ? 2.0 : 1.5
      ..strokeCap = StrokeCap.round;
    for (final angle in const [-math.pi / 2, 0.0, math.pi / 2, math.pi]) {
      final start = Offset(
        center.dx + math.cos(angle) * ringRadius,
        center.dy + math.sin(angle) * ringRadius,
      );
      final end = Offset(
        center.dx + math.cos(angle) * (ringRadius + _tileSize * 0.035),
        center.dy + math.sin(angle) * (ringRadius + _tileSize * 0.035),
      );
      canvas.drawLine(start, end, sparkPaint);
    }
  }

  void _drawLevelGlyph(Canvas canvas, Offset center) {
    if (_level <= 1) {
      return;
    }

    final tier = _levelVisualTier;
    final glyphCenter = center.translate(0, _tileSize * 0.27);
    final outline = Paint()
      ..color = const Color(0xFF050A12).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final shadowFill = Paint()
      ..color = const Color(0xFF050A12).withValues(alpha: 0.68);
    final glowStroke = Paint()
      ..color = const Color(0xFFFFD45A).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    if (tier >= 4) {
      final starRadius = _tileSize * 0.135;
      final star = _levelStarPath(glyphCenter, starRadius);
      canvas.drawPath(star.shift(Offset(0, _tileSize * 0.014)), shadowFill);
      canvas.drawPath(star, glowStroke);
      canvas.drawPath(
        star,
        Paint()..color = const Color(0xFFFFF0B0).withValues(alpha: 0.98),
      );
      canvas.drawPath(star, outline);
    }

    if (tier >= 3) {
      final ringRadius = _tileSize * 0.128;
      canvas.drawCircle(glyphCenter, ringRadius, glowStroke);
      canvas.drawCircle(
        glyphCenter,
        ringRadius,
        Paint()
          ..color = const Color(0xFF050A12).withValues(alpha: 0.74)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      for (final direction in const [
        Offset(0, -1),
        Offset(1, 0),
        Offset(0, 1),
        Offset(-1, 0),
      ]) {
        canvas.drawLine(
          glyphCenter.translate(
            direction.dx * _tileSize * 0.115,
            direction.dy * _tileSize * 0.115,
          ),
          glyphCenter.translate(
            direction.dx * _tileSize * 0.155,
            direction.dy * _tileSize * 0.155,
          ),
          Paint()
            ..color = const Color(0xFFFFF0B0).withValues(alpha: 0.9)
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    if (tier >= 2) {
      final width = _tileSize * (tier >= 3 ? 0.38 : 0.34);
      final height = _tileSize * 0.11;
      final wing = _levelWingPath(glyphCenter, width, height);
      final wingFill = tier >= 3
          ? const Color(0xFFFFF6DA)
          : const Color(0xFFFFEBC1);
      canvas.drawPath(wing.shift(Offset(0, _tileSize * 0.014)), shadowFill);
      canvas.drawPath(wing, Paint()..color = wingFill.withValues(alpha: 0.98));
      canvas.drawPath(wing, outline);
    }

    final coreRadius =
        _tileSize *
        switch (tier) {
          1 => 0.12,
          2 => 0.125,
          3 => 0.13,
          _ => 0.116,
        };
    final core = _levelDiamondPath(glyphCenter, coreRadius);
    canvas.drawPath(core.shift(Offset(0, _tileSize * 0.012)), shadowFill);
    canvas.drawPath(
      core,
      Paint()
        ..color =
            (tier >= 3 ? const Color(0xFFFFF0B0) : const Color(0xFFFFD45A))
                .withValues(alpha: 0.97),
    );
    canvas.drawPath(core, outline);

    if (tier >= 2) {
      final sparkRadius = coreRadius * 0.34;
      canvas.drawCircle(
        glyphCenter,
        sparkRadius,
        Paint()
          ..color =
              (tier >= 3 ? const Color(0xFFFFFFFF) : const Color(0xFFFFF0B0))
                  .withValues(alpha: 0.82),
      );
    }

    if (tier >= 4) {
      canvas.drawCircle(
        glyphCenter.translate(0, -_tileSize * 0.006),
        coreRadius * 0.2,
        Paint()..color = const Color(0xFFFF8A3D).withValues(alpha: 0.95),
      );
    }
  }

  Path _levelDiamondPath(Offset center, double radius) {
    return Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.82, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.82, center.dy)
      ..close();
  }

  Path _levelWingPath(Offset center, double width, double height) {
    final halfWidth = width / 2;
    final halfHeight = height / 2;
    final bevel = height * 0.52;
    return Path()
      ..moveTo(center.dx - halfWidth, center.dy)
      ..lineTo(center.dx - halfWidth + bevel, center.dy - halfHeight)
      ..lineTo(center.dx + halfWidth - bevel, center.dy - halfHeight)
      ..lineTo(center.dx + halfWidth, center.dy)
      ..lineTo(center.dx + halfWidth - bevel, center.dy + halfHeight)
      ..lineTo(center.dx - halfWidth + bevel, center.dy + halfHeight)
      ..close();
  }

  Path _levelStarPath(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final pointRadius = i.isEven ? radius : radius * 0.48;
      final point = Offset(
        center.dx + math.cos(angle) * pointRadius,
        center.dy + math.sin(angle) * pointRadius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  int get _levelVisualTier {
    if (_level >= 10) {
      return 4;
    }
    if (_level >= 8) {
      return 3;
    }
    if (_level >= 5) {
      return 2;
    }
    return 1;
  }
}

enum TurretDamageKind { direct, splash, chain, burn }
