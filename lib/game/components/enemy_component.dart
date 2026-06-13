import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/save/game_save_data.dart';
import '../../domain/enemy/enemy_definition.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/map/grid_point.dart';
import '../rendering/enemy_shape_renderer.dart';
import '../rune_nexus_game.dart';
import 'damage_number_component.dart';

class EnemyComponent extends PositionComponent {
  EnemyComponent({
    required this.definition,
    required this.maxHp,
    this.maxShield = 0,
    this.maxArmor = 0,
    this.laneOffsetRatio = 0,
    this.visualPhase = 0,
    required this.path,
    required this.game,
  }) : hp = maxHp,
       shield = maxShield,
       armor = maxArmor,
       super(
         position: path.first.clone(),
         size: Vector2.all(_sizeForTileScale(game.boardDistanceScale)),
         anchor: Anchor.center,
       );

  final EnemyDefinition definition;
  final double maxHp;
  final double maxShield;
  final double maxArmor;
  final double laneOffsetRatio;
  final double visualPhase;
  final RuneNexusGame game;
  List<Vector2> path;
  double hp;
  double shield;
  bool shieldBroken = false;
  double armor;

  int _targetIndex = 1;
  double distanceTravelled = 0;
  final List<_BurnInstance> _burnInstances = [];
  double _burnNumberDamage = 0;
  double _burnNumberTimer = 0;
  double _poisonRemaining = 0;
  double _poisonDamagePerSecond = 0;
  double _poisonDamageMultiplier = 1;
  double _poisonNumberDamage = 0;
  double _poisonNumberTimer = 0;
  int _poisonStacks = 0;
  double _slowRemaining = 0;
  double _slowMultiplier = 1;
  double _physicalVulnerabilityRemaining = 0;
  double _physicalVulnerabilityBonus = 0;
  double _elementalVulnerabilityRemaining = 0;
  double _elementalVulnerabilityBonus = 0;
  double _riftMarkRemaining = 0;
  double _riftMarkDamageAmplification = 0;
  double _facingAngle = 0;
  double _hitFlashTimer = 0;
  Color _hitFlashColor = const Color(0xFFFFFFFF);
  double _statusEffectTime = 0;
  final Paint _slowRimPaint = Paint()
    ..color = const Color(0xCCBFEFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.7
    ..strokeCap = StrokeCap.round;
  final Paint _spritePaint = Paint()..filterQuality = FilterQuality.none;
  static const double _burnNumberInterval = 0.28;
  static const double _poisonNumberInterval = 0.5;
  static const double _designTileSize = 48;
  static const List<Offset> _burnBaseOffsets = [
    Offset(-0.31, -0.25),
    Offset(-0.11, -0.34),
    Offset(0.13, -0.31),
    Offset(0.32, -0.19),
  ];
  static const List<double> _burnPhaseOffsets = [0, 0.31, 0.62, 0.93];
  static const List<Offset> _slowShardOffsets = [
    Offset(0.34, 0),
    Offset(0, 0.34),
    Offset(-0.34, 0),
    Offset(0, -0.34),
  ];

  bool get isDead => hp <= 0;
  double get collisionRadius => size.x * 0.42;
  bool get isSlowed => _slowRemaining > 0;
  double get slowRemaining => _slowRemaining;
  double get slowMultiplier => _slowMultiplier;
  double get physicalResistanceReduction =>
      _physicalVulnerabilityRemaining > 0 ? _physicalVulnerabilityBonus : 0;
  double get elementalResistanceReduction =>
      _elementalVulnerabilityRemaining > 0 ? _elementalVulnerabilityBonus : 0;
  bool get hasRiftMark => _riftMarkRemaining > 0;
  double get riftMarkRemaining => _riftMarkRemaining;
  double get riftMarkDamageAmplification =>
      hasRiftMark ? _riftMarkDamageAmplification : 0;
  double get finalDamageMultiplier => 1 + riftMarkDamageAmplification;
  double get currentDurability => hp + shield + armor;
  Vector2 get visualPosition => position + _visualRenderOffset();
  double get totalBurnDamagePerSecond => _burnInstances.fold(
    0,
    (strongest, instance) => math.max(strongest, instance.damagePerSecond),
  );
  double get maxBurnRemaining => _burnInstances.fold(
    0,
    (maxRemaining, instance) => math.max(maxRemaining, instance.remaining),
  );

  SavedEnemy toSaveData() {
    final burnRemaining = maxBurnRemaining;
    final burnDamagePerSecond = totalBurnDamagePerSecond;
    return SavedEnemy(
      type: definition.type,
      maxHp: maxHp,
      hp: hp,
      shield: shield,
      shieldBroken: shieldBroken,
      armor: armor,
      distanceTravelled: distanceTravelled,
      burnRemaining: burnRemaining,
      burnDamagePerSecond: burnDamagePerSecond,
      burnDamageMultiplier: _burnInstances.isEmpty
          ? 1
          : _burnInstances
                .map((instance) => instance.damageMultiplier)
                .reduce(math.max),
      burnInstances: List.unmodifiable(
        _burnInstances.map((instance) => instance.toSaveData()),
      ),
      poisonRemaining: _poisonRemaining,
      poisonDamagePerSecond: _poisonDamagePerSecond,
      poisonDamageMultiplier: _poisonDamageMultiplier,
      poisonStacks: _poisonStacks,
      slowRemaining: _slowRemaining,
      slowMultiplier: _slowMultiplier,
      physicalVulnerabilityRemaining: _physicalVulnerabilityRemaining,
      physicalVulnerabilityBonus: _physicalVulnerabilityBonus,
      elementalVulnerabilityRemaining: _elementalVulnerabilityRemaining,
      elementalVulnerabilityBonus: _elementalVulnerabilityBonus,
      laneOffsetRatio: laneOffsetRatio,
      riftMarkRemaining: _riftMarkRemaining,
      riftMarkDamageAmplification: _riftMarkDamageAmplification,
    );
  }

  void restoreFromSaveData(SavedEnemy data) {
    hp = data.hp.clamp(0, maxHp).toDouble();
    shield = maxShield <= 0 ? 0 : data.shield.clamp(0, maxShield).toDouble();
    shieldBroken = maxShield > 0 && data.shieldBroken;
    armor = maxArmor <= 0 ? 0 : data.armor.clamp(0, maxArmor).toDouble();
    distanceTravelled = math.max(0, data.distanceTravelled);
    _burnInstances
      ..clear()
      ..addAll(
        data.burnInstances.map(
          (instance) => _BurnInstance.fromSaveData(instance),
        ),
      );
    _burnNumberDamage = 0;
    _burnNumberTimer = 0;
    _poisonRemaining = math.max(0, data.poisonRemaining);
    _poisonDamagePerSecond = math.max(0, data.poisonDamagePerSecond);
    _poisonDamageMultiplier = math.max(0, data.poisonDamageMultiplier);
    _poisonStacks = math.max(0, data.poisonStacks);
    _poisonNumberDamage = 0;
    _poisonNumberTimer = 0;
    _slowRemaining = math.max(0, data.slowRemaining);
    _slowMultiplier = data.slowMultiplier <= 0 ? 1 : data.slowMultiplier;
    _physicalVulnerabilityRemaining = math.max(
      0,
      data.physicalVulnerabilityRemaining,
    );
    _physicalVulnerabilityBonus = math.max(0, data.physicalVulnerabilityBonus);
    _elementalVulnerabilityRemaining = math.max(
      0,
      data.elementalVulnerabilityRemaining,
    );
    _elementalVulnerabilityBonus = math.max(
      0,
      data.elementalVulnerabilityBonus,
    );
    _riftMarkRemaining = math.max(0, data.riftMarkRemaining);
    _riftMarkDamageAmplification = math.max(
      0,
      data.riftMarkDamageAmplification,
    );
    _placeAtDistance(distanceTravelled);
  }

  void updateLayout({
    required double tileSize,
    required List<Vector2> newPath,
  }) {
    size = Vector2.all(tileSize * _sizeScaleByType);
    _slowRimPaint.strokeWidth = size.x * 0.077;
    updatePath(newPath);
  }

  void updatePath(List<Vector2> newPath) {
    if (newPath.length < 2) {
      return;
    }

    final progressRatio = _pathLength(path) == 0
        ? 0.0
        : (distanceTravelled / _pathLength(path)).clamp(0.0, 1.0).toDouble();
    path = newPath;
    distanceTravelled = _pathLength(path) * progressRatio;
    _placeAtDistance(distanceTravelled);
  }

  static double _sizeForTileScale(double boardDistanceScale) {
    return _designTileSize * 0.46 * boardDistanceScale;
  }

  double get _sizeScaleByType {
    return switch (definition.type) {
      EnemyType.fast => 0.48,
      EnemyType.normal => 0.55,
      EnemyType.armored => 0.58,
      EnemyType.shielded => 0.59,
      EnemyType.tank => 0.65,
      EnemyType.boss => 0.79,
    };
  }

  @override
  void update(double dt) {
    super.update(dt);
    _hitFlashTimer = math.max(0, _hitFlashTimer - dt);
    _statusEffectTime += dt;
    _updateShield(dt);
    _updateStatusEffects(dt);
    if (isDead) {
      return;
    }
    if (_targetIndex >= path.length) {
      return;
    }

    final target = path[_targetIndex];
    final direction = target - position;
    final distance = direction.length;
    if (distance > 0.001) {
      _facingAngle = math.atan2(direction.y, direction.x);
    }
    final speedMultiplier = _slowRemaining > 0 ? _slowMultiplier : 1;
    final step =
        definition.speed * game.boardDistanceScale * speedMultiplier * dt;

    if (distance <= step) {
      distanceTravelled += distance;
      position = target.clone();
      _targetIndex++;

      if (_targetIndex >= path.length) {
        game.enemyReachedCore(this);
      }
      return;
    }

    position += direction.normalized() * step;
    distanceTravelled += step;
  }

  double receiveDamage(
    double damage, {
    BurnTransferPayload? burnTransfer,
    bool ignoreArmorReduction = false,
  }) {
    if (damage <= 0 || isDead) {
      return 0;
    }
    final baseActualDamage = riftMarkDamageAmplification <= 0
        ? 0.0
        : _actualDamageFor(
            damage,
            multiplier: 1,
            ignoreArmorReduction: ignoreArmorReduction,
          );
    var remainingDamage = damage * finalDamageMultiplier;
    var actualDamage = 0.0;

    if (shield > 0) {
      final shieldDamage = math.min(shield, remainingDamage);
      shield = math.max(0, shield - shieldDamage);
      actualDamage += shieldDamage;
      remainingDamage -= shieldDamage;
      if (shield == 0) {
        shieldBroken = true;
      }
    }

    if (remainingDamage > 0 && armor > 0) {
      final armorDamage = ignoreArmorReduction
          ? remainingDamage
          : math.max(
              remainingDamage * definition.armorMinimumDamageRate,
              remainingDamage - armor * definition.armorReductionRate,
            );
      final actualArmorDamage = math.min(armor, armorDamage);
      armor = math.max(0, armor - actualArmorDamage);
      actualDamage += actualArmorDamage;
      remainingDamage = math.max(0, armorDamage - actualArmorDamage);
    }

    if (remainingDamage <= 0) {
      _recordRiftMarkBonusDamage(actualDamage, baseActualDamage);
      return actualDamage;
    }

    final previousHp = hp;
    hp = math.max(0, hp - remainingDamage);
    actualDamage += previousHp - hp;
    _recordRiftMarkBonusDamage(actualDamage, baseActualDamage);
    if (isDead) {
      game.enemyKilled(this, burnTransfer: burnTransfer);
    }
    return actualDamage;
  }

  double _actualDamageFor(
    double damage, {
    required double multiplier,
    required bool ignoreArmorReduction,
  }) {
    var remainingDamage = damage * multiplier;
    var actualDamage = 0.0;
    var simulatedShield = shield;
    var simulatedArmor = armor;
    var simulatedHp = hp;

    if (simulatedShield > 0) {
      final shieldDamage = math.min(simulatedShield, remainingDamage);
      simulatedShield = math.max(0, simulatedShield - shieldDamage);
      actualDamage += shieldDamage;
      remainingDamage -= shieldDamage;
    }

    if (remainingDamage > 0 && simulatedArmor > 0) {
      final armorDamage = ignoreArmorReduction
          ? remainingDamage
          : math.max(
              remainingDamage * definition.armorMinimumDamageRate,
              remainingDamage - simulatedArmor * definition.armorReductionRate,
            );
      final actualArmorDamage = math.min(simulatedArmor, armorDamage);
      simulatedArmor = math.max(0, simulatedArmor - actualArmorDamage);
      actualDamage += actualArmorDamage;
      remainingDamage = math.max(0, armorDamage - actualArmorDamage);
    }

    if (remainingDamage <= 0) {
      return actualDamage;
    }

    final previousHp = simulatedHp;
    simulatedHp = math.max(0, simulatedHp - remainingDamage);
    return actualDamage + previousHp - simulatedHp;
  }

  void _recordRiftMarkBonusDamage(
    double actualDamage,
    double baseActualDamage,
  ) {
    if (riftMarkDamageAmplification <= 0) {
      return;
    }
    final bonusDamage = actualDamage - baseActualDamage;
    if (bonusDamage <= 0) {
      return;
    }
    game.recordCoreCombatSkillBonusDamage(bonusDamage);
  }

  void showHitFlash(Color color) {
    _hitFlashColor = color;
    _hitFlashTimer = 0.08;
  }

  void applyPoison({
    required double damagePerSecond,
    required double duration,
    required int maxStacks,
    double damageMultiplier = 1,
  }) {
    _poisonDamagePerSecond = damagePerSecond;
    _poisonDamageMultiplier = damageMultiplier;
    _poisonStacks = math.min(maxStacks, _poisonStacks + 1);
    _poisonRemaining = duration;
  }

  void applyBurn({
    required double damagePerSecond,
    required double duration,
    double damageMultiplier = 1,
    GridPoint? sourceTurretPoint,
    bool ignoreArmorReduction = false,
  }) {
    if (damagePerSecond <= 0 || duration <= 0) {
      return;
    }
    final sourcePoint = sourceTurretPoint;
    if (sourcePoint != null) {
      for (final instance in _burnInstances) {
        if (instance.sourceTurretPoint == sourcePoint) {
          instance.damagePerSecond = math.max(
            instance.damagePerSecond,
            damagePerSecond,
          );
          instance.damageMultiplier = math.max(
            instance.damageMultiplier,
            damageMultiplier,
          );
          instance.ignoreArmorReduction =
              instance.ignoreArmorReduction || ignoreArmorReduction;
          instance.remaining = math.max(instance.remaining, duration);
          return;
        }
      }
    }
    _burnInstances.add(
      _BurnInstance(
        remaining: duration,
        damagePerSecond: damagePerSecond,
        damageMultiplier: damageMultiplier,
        sourceTurretPoint: sourceTurretPoint,
        ignoreArmorReduction: ignoreArmorReduction,
      ),
    );
  }

  bool hasBurnFromSource(GridPoint sourceTurretPoint) {
    return _burnInstances.any(
      (instance) =>
          instance.sourceTurretPoint == sourceTurretPoint &&
          instance.remaining > 0,
    );
  }

  double strongestBurnDamagePerSecondFromSource(GridPoint sourceTurretPoint) {
    return _burnInstances
        .where(
          (instance) =>
              instance.sourceTurretPoint == sourceTurretPoint &&
              instance.remaining > 0,
        )
        .fold(0.0, (strongest, instance) {
          return math.max(strongest, instance.damagePerSecond);
        });
  }

  BurnTransferPayload? burnTransferPayloadFromSource(
    GridPoint sourceTurretPoint,
  ) {
    _BurnInstance? strongestBurn;
    for (final instance in _burnInstances) {
      if (instance.sourceTurretPoint != sourceTurretPoint ||
          instance.remaining <= 0) {
        continue;
      }
      final isStronger =
          strongestBurn == null ||
          instance.damagePerSecond > strongestBurn.damagePerSecond;
      final isSameStrengthButLonger =
          strongestBurn != null &&
          instance.damagePerSecond == strongestBurn.damagePerSecond &&
          instance.remaining > strongestBurn.remaining;
      if (isStronger || isSameStrengthButLonger) {
        strongestBurn = instance;
      }
    }
    final burn = strongestBurn;
    if (burn == null) {
      return null;
    }
    return BurnTransferPayload(
      sourceTurretPoint: burn.sourceTurretPoint,
      remaining: burn.remaining,
      damagePerSecond: burn.damagePerSecond,
      damageMultiplier: burn.damageMultiplier,
      ignoreArmorReduction: burn.ignoreArmorReduction,
    );
  }

  void clearBurnSource(GridPoint sourceTurretPoint) {
    for (final instance in _burnInstances) {
      if (instance.sourceTurretPoint == sourceTurretPoint) {
        instance.sourceTurretPoint = null;
      }
    }
  }

  void applySlow({required double multiplier, required double duration}) {
    _slowMultiplier = math.min(_slowMultiplier, multiplier);
    _slowRemaining = math.max(_slowRemaining, duration);
  }

  void applyPhysicalVulnerability({
    required double bonus,
    required double duration,
  }) {
    if (bonus <= 0 || duration <= 0) {
      return;
    }
    _physicalVulnerabilityBonus = math.max(_physicalVulnerabilityBonus, bonus);
    _physicalVulnerabilityRemaining = math.max(
      _physicalVulnerabilityRemaining,
      duration,
    );
  }

  void applyElementalVulnerability({
    required double bonus,
    required double duration,
  }) {
    if (bonus <= 0 || duration <= 0) {
      return;
    }
    _elementalVulnerabilityBonus = math.max(
      _elementalVulnerabilityBonus,
      bonus,
    );
    _elementalVulnerabilityRemaining = math.max(
      _elementalVulnerabilityRemaining,
      duration,
    );
  }

  void applyRiftMark({
    required double damageAmplification,
    required double duration,
  }) {
    if (damageAmplification <= 0 || duration <= 0) {
      return;
    }
    _riftMarkDamageAmplification = math.max(
      _riftMarkDamageAmplification,
      damageAmplification,
    );
    _riftMarkRemaining = math.max(_riftMarkRemaining, duration);
  }

  void _updateStatusEffects(double dt) {
    if (_burnInstances.isNotEmpty) {
      _burnNumberTimer += dt;
      _BurnInstance? strongestBurn;
      var strongestBurnTickDuration = 0.0;
      for (var i = _burnInstances.length - 1; i >= 0; i--) {
        final instance = _burnInstances[i];
        final tickDuration = math.min(dt, instance.remaining);
        instance.remaining = math.max(0, instance.remaining - dt);
        if (tickDuration > 0 &&
            (strongestBurn == null ||
                instance.damagePerSecond > strongestBurn.damagePerSecond)) {
          strongestBurn = instance;
          strongestBurnTickDuration = tickDuration;
        }
      }
      final activeBurn = strongestBurn;
      if (activeBurn != null) {
        final damage = activeBurn.damagePerSecond * strongestBurnTickDuration;
        final actualDamage = receiveDamage(
          damage,
          burnTransfer: BurnTransferPayload(
            sourceTurretPoint: activeBurn.sourceTurretPoint,
            remaining: activeBurn.remaining,
            damagePerSecond: activeBurn.damagePerSecond,
            damageMultiplier: activeBurn.damageMultiplier,
            ignoreArmorReduction: activeBurn.ignoreArmorReduction,
          ),
          ignoreArmorReduction: activeBurn.ignoreArmorReduction,
        );
        _burnNumberDamage += actualDamage;
        game.recordTurretDamage(activeBurn.sourceTurretPoint, actualDamage);
      }
      _burnInstances.removeWhere((instance) => instance.remaining <= 0);
      if (!isDead &&
          (_burnNumberTimer >= _burnNumberInterval || _burnInstances.isEmpty) &&
          _burnNumberDamage > 0) {
        game.showDamageNumber(
          position: visualPosition,
          damage: _burnNumberDamage,
          color: const Color(0xFFFF8A2A),
          motion: DamageNumberMotion.fallArc,
          damageMultiplier: _maxBurnDamageMultiplier,
        );
        _burnNumberDamage = 0;
        _burnNumberTimer = 0;
      }
    }
    if (_poisonRemaining > 0) {
      _poisonRemaining = math.max(0, _poisonRemaining - dt);
      final damage = _poisonDamagePerSecond * _poisonStacks * dt;
      _poisonNumberTimer += dt;
      final actualDamage = receiveDamage(damage);
      _poisonNumberDamage += actualDamage;
      if (!isDead &&
          (_poisonNumberTimer >= _poisonNumberInterval ||
              _poisonRemaining == 0)) {
        game.showDamageNumber(
          position: visualPosition,
          damage: _poisonNumberDamage,
          color: const Color(0xFF9DFF4A),
          motion: DamageNumberMotion.fallArc,
          damageMultiplier: _poisonDamageMultiplier,
        );
        _poisonNumberDamage = 0;
        _poisonNumberTimer = 0;
      }
      if (_poisonRemaining == 0) {
        _poisonStacks = 0;
        _poisonDamagePerSecond = 0;
        _poisonNumberDamage = 0;
        _poisonNumberTimer = 0;
      }
    }
    if (_slowRemaining > 0) {
      _slowRemaining = math.max(0, _slowRemaining - dt);
      if (_slowRemaining == 0) {
        _slowMultiplier = 1;
      }
    }
    if (_physicalVulnerabilityRemaining > 0) {
      _physicalVulnerabilityRemaining = math.max(
        0,
        _physicalVulnerabilityRemaining - dt,
      );
      if (_physicalVulnerabilityRemaining == 0) {
        _physicalVulnerabilityBonus = 0;
      }
    }
    if (_elementalVulnerabilityRemaining > 0) {
      _elementalVulnerabilityRemaining = math.max(
        0,
        _elementalVulnerabilityRemaining - dt,
      );
      if (_elementalVulnerabilityRemaining == 0) {
        _elementalVulnerabilityBonus = 0;
      }
    }
    if (_riftMarkRemaining > 0) {
      _riftMarkRemaining = math.max(0, _riftMarkRemaining - dt);
      if (_riftMarkRemaining == 0) {
        _riftMarkDamageAmplification = 0;
      }
    }
  }

  void _updateShield(double dt) {
    if (isDead ||
        maxShield <= 0 ||
        shieldBroken ||
        shield >= maxShield ||
        definition.shieldRegenRate <= 0) {
      return;
    }
    shield = math.min(
      maxShield,
      shield + maxShield * definition.shieldRegenRate * dt,
    );
  }

  double get _maxBurnDamageMultiplier {
    if (_burnInstances.isEmpty) {
      return 1;
    }
    return _burnInstances
        .map((instance) => instance.damageMultiplier)
        .reduce(math.max);
  }

  @override
  void render(Canvas canvas) {
    final body = Paint()..color = definition.color;
    final outline = Paint()
      ..color = const Color(0xFF07111D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final visualOffset = _visualRenderOffset();
    canvas.save();
    canvas.translate(visualOffset.x, visualOffset.y);
    _drawMotionEffects(canvas);
    _drawBody(canvas, body, outline);
    _drawBodyOverlayEffects(canvas);
    _drawHitFlash(canvas);

    if (_burnInstances.isNotEmpty) {
      _drawBurnStatus(canvas);
    }
    if (_poisonRemaining > 0) {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x * 0.5,
        Paint()
          ..color = const Color(0x669DFF4A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (_slowRemaining > 0) {
      _drawSlowStatus(canvas);
    }
    if (_riftMarkRemaining > 0) {
      _drawRiftMarkStatus(canvas);
    }

    _drawDurabilityBars(canvas);
    canvas.restore();
  }

  void _drawDurabilityBars(Canvas canvas) {
    final barWidth = size.x - 2;
    const hpColor = Color(0xFFFF4E5D);
    const armorColor = Color(0xFFB7BDC8);
    const shieldColor = Color(0xFF62D9FF);
    const backgroundColor = Color(0xFF321118);
    const shieldBackgroundColor = Color(0xFF102B3A);

    if (maxShield > 0 && shield > 0) {
      final shieldRatio = (shield / maxShield).clamp(0.0, 1.0).toDouble();
      canvas.drawRect(
        Rect.fromLTWH(1, -9, barWidth, 3),
        Paint()..color = shieldBackgroundColor,
      );
      canvas.drawRect(
        Rect.fromLTWH(1, -9, barWidth * shieldRatio, 3),
        Paint()..color = shieldColor,
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(1, -5, barWidth, 3),
      Paint()..color = backgroundColor,
    );
    if (maxArmor > 0) {
      final totalDurability = math.max(1.0, maxHp + maxArmor);
      final hpWidth =
          barWidth * (hp / totalDurability).clamp(0.0, 1.0).toDouble();
      final armorWidth =
          barWidth * (armor / totalDurability).clamp(0.0, 1.0).toDouble();
      canvas.drawRect(
        Rect.fromLTWH(1, -5, hpWidth, 3),
        Paint()..color = hpColor,
      );
      if (armorWidth > 0) {
        canvas.drawRect(
          Rect.fromLTWH(1 + hpWidth, -5, armorWidth, 3),
          Paint()..color = armorColor,
        );
      }
      return;
    }

    final ratio = maxHp <= 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0).toDouble();
    canvas.drawRect(
      Rect.fromLTWH(1, -5, barWidth * ratio, 3),
      Paint()..color = hpColor,
    );
  }

  void _drawBody(Canvas canvas, Paint body, Paint outline) {
    drawEnemyShape(
      canvas,
      size: Size(size.x, size.y),
      type: definition.type,
      color: body.color,
      strokeWidth: outline.strokeWidth,
      facingAngle: _facingAngle,
    );
  }

  void _drawMotionEffects(Canvas canvas) {
    if (isDead) {
      return;
    }
    switch (definition.type) {
      case EnemyType.normal:
        _drawRearFlickerLight(
          canvas,
          glowColor: const Color(0xFFD7CFC0),
          coreColor: const Color(0xFFFFE6BD),
          speed: 29,
          widthScale: 0.92,
          alphaScale: 0.86,
        );
      case EnemyType.fast:
        _drawRearFlickerLight(
          canvas,
          glowColor: const Color(0xFF7CE8FF),
          coreColor: const Color(0xFFE8FBFF),
          speed: 34,
          widthScale: 1.08,
          alphaScale: 1,
        );
      case EnemyType.shielded:
        _drawRearFlickerLight(
          canvas,
          glowColor: const Color(0xFF7FDFFF),
          coreColor: const Color(0xFFEAFBFF),
          speed: 27,
          widthScale: 0.98,
          alphaScale: 0.82,
        );
      case EnemyType.armored:
      case EnemyType.tank:
        return;
      case EnemyType.boss:
        _drawBossCoreThrum(canvas);
        return;
    }
  }

  void _drawBodyOverlayEffects(Canvas canvas) {
    if (isDead || definition.type != EnemyType.boss) {
      return;
    }
    _drawBossCoreThrum(canvas, foreground: true);
  }

  void _drawRearFlickerLight(
    Canvas canvas, {
    required Color glowColor,
    required Color coreColor,
    required double speed,
    required double widthScale,
    required double alphaScale,
  }) {
    final loadFade = game.enemies.length >= 80 ? 0.5 : 1.0;
    final phase = _statusEffectTime * speed + visualPhase * math.pi * 2;
    final flicker =
        (0.62 + math.sin(phase) * 0.23 + math.sin(phase * 1.73 + 0.8) * 0.12)
            .clamp(0.22, 1.0)
            .toDouble();
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(_facingAngle);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-size.x * 0.63, 0),
        width: size.x * (0.44 + flicker * 0.13) * widthScale,
        height: size.y * 0.3,
      ),
      Paint()
        ..color = glowColor.withValues(
          alpha: 0.34 * flicker * alphaScale * loadFade,
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.x * 0.04),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-size.x * 0.47, 0),
        width: size.x * (0.24 + flicker * 0.05) * widthScale,
        height: size.y * 0.15,
      ),
      Paint()
        ..color = coreColor.withValues(
          alpha: 0.46 * flicker * alphaScale * loadFade,
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.x * 0.018),
    );
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-size.x * 0.26, side * size.y * 0.2),
          width: size.x * 0.105 * widthScale,
          height: size.y * 0.067,
        ),
        Paint()
          ..color = coreColor.withValues(
            alpha: 0.3 * flicker * alphaScale * loadFade,
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.x * 0.012),
      );
    }

    canvas.restore();
  }

  void _drawBossCoreThrum(Canvas canvas, {bool foreground = false}) {
    final loadFade = game.enemies.length >= 80 ? 0.82 : 1.0;
    final hpRatio = maxHp <= 0 ? 1.0 : (hp / maxHp).clamp(0.0, 1.0).toDouble();
    final stress = 1 - hpRatio;
    final phase =
        _statusEffectTime * (5.5 + stress * 1.8) + visualPhase * math.pi * 2;
    final pulseBase = (math.sin(phase) + 1) * 0.5;
    final pulse = math.pow(pulseBase, 1.85).toDouble();
    final shimmer = (math.sin(phase * 2.25 + 0.7) + 1) * 0.5;
    final thrum = (0.42 + pulse * 0.46 + shimmer * 0.12)
        .clamp(0.0, 1.0)
        .toDouble();
    final alphaBoost = 1 + stress * 0.32;

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(_facingAngle);

    if (foreground) {
      _drawBossCoreHighlights(
        canvas,
        pulse: pulse,
        thrum: thrum,
        alphaBoost: alphaBoost,
        loadFade: loadFade,
      );
      canvas.restore();
      return;
    }

    // 보스 동력 맥동
    canvas.drawCircle(
      Offset.zero,
      size.x * (0.56 + thrum * 0.045),
      Paint()
        ..color = const Color(
          0xFFFF5A66,
        ).withValues(alpha: 0.32 * thrum * alphaBoost * loadFade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.x * (0.055 + thrum * 0.022)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.x * 0.034),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-size.x * 0.58, 0),
        width: size.x * (0.58 + thrum * 0.14),
        height: size.y * (0.4 + thrum * 0.055),
      ),
      Paint()
        ..color = const Color(
          0xFFB6394B,
        ).withValues(alpha: 0.58 * thrum * alphaBoost * loadFade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.x * 0.07),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-size.x * 0.46, 0),
        width: size.x * (0.28 + thrum * 0.07),
        height: size.y * (0.18 + thrum * 0.032),
      ),
      Paint()
        ..color = const Color(
          0xFFFF8791,
        ).withValues(alpha: 0.72 * thrum * alphaBoost * loadFade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.x * 0.024),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-size.x * 0.38, 0),
        width: size.x * 0.11,
        height: size.y * 0.074,
      ),
      Paint()
        ..color = const Color(
          0xFFFFE1E5,
        ).withValues(alpha: 0.65 * pulse * alphaBoost * loadFade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.x * 0.01),
    );
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-size.x * 0.24, side * size.y * 0.25),
          width: size.x * (0.2 + thrum * 0.04),
          height: size.y * 0.088,
        ),
        Paint()
          ..color = const Color(
            0xFFFF8791,
          ).withValues(alpha: 0.56 * thrum * alphaBoost * loadFade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.x * 0.018),
      );
    }

    canvas.restore();
  }

  void _drawBossCoreHighlights(
    Canvas canvas, {
    required double pulse,
    required double thrum,
    required double alphaBoost,
    required double loadFade,
  }) {
    final ringAlpha = (0.46 * thrum * alphaBoost * loadFade)
        .clamp(0.0, 1.0)
        .toDouble();
    final coreAlpha = (0.95 * thrum * alphaBoost * loadFade)
        .clamp(0.0, 1.0)
        .toDouble();
    final ventAlpha = (0.82 * thrum * alphaBoost * loadFade)
        .clamp(0.0, 1.0)
        .toDouble();
    final hotCoreAlpha = (1.0 * pulse * alphaBoost * loadFade)
        .clamp(0.0, 1.0)
        .toDouble();
    final hotVentAlpha = (0.78 * pulse * alphaBoost * loadFade)
        .clamp(0.0, 1.0)
        .toDouble();
    canvas.drawCircle(
      Offset.zero,
      size.x * (0.28 + thrum * 0.025),
      Paint()
        ..color = const Color(0xFFFF5A66).withValues(alpha: ringAlpha)
        ..blendMode = BlendMode.plus
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.x * 0.04
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.x * 0.016),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-size.x * 0.12, 0),
        width: size.x * (0.38 + thrum * 0.08),
        height: size.y * (0.2 + thrum * 0.035),
      ),
      Paint()
        ..color = const Color(0xFFFF8791).withValues(alpha: coreAlpha)
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.x * 0.016),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-size.x * 0.12, 0),
        width: size.x * 0.17,
        height: size.y * 0.09,
      ),
      Paint()
        ..color = const Color(0xFFFFE1E5).withValues(alpha: hotCoreAlpha)
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.x * 0.006),
    );
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.x * 0.02, side * size.y * 0.22),
          width: size.x * (0.24 + thrum * 0.045),
          height: size.y * 0.105,
        ),
        Paint()
          ..color = const Color(0xFFFF8791).withValues(alpha: ventAlpha)
          ..blendMode = BlendMode.plus
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.x * 0.01),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.x * 0.02, side * size.y * 0.22),
          width: size.x * 0.082,
          height: size.y * 0.038,
        ),
        Paint()
          ..color = const Color(0xFFFFE1E5).withValues(alpha: hotVentAlpha)
          ..blendMode = BlendMode.plus,
      );
    }
  }

  void _drawHitFlash(Canvas canvas) {
    if (_hitFlashTimer <= 0) {
      return;
    }
    final progress = (_hitFlashTimer / 0.08).clamp(0.0, 1.0);
    final center = Offset(size.x / 2, size.y / 2);
    final radius = size.x * (0.44 + (1 - progress) * 0.12);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Color.lerp(
          _hitFlashColor,
          const Color(0xFFFFFFFF),
          0.55,
        )!.withValues(alpha: progress * 0.34),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _hitFlashColor.withValues(alpha: progress * 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
  }

  void _drawBurnStatus(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final emberCount = game.enemies.length >= 60 ? 2 : _burnBaseOffsets.length;
    for (var i = 0; i < emberCount; i++) {
      final phase = (_statusEffectTime * 3.4 + _burnPhaseOffsets[i]) % 1;
      final baseOffset = _burnBaseOffsets[i];
      final base = Offset(
        center.dx + baseOffset.dx * size.x,
        center.dy + baseOffset.dy * size.y,
      );
      final ember = base.translate(0, -phase * size.y * 0.34);
      final radius = size.x * (0.045 + (1 - phase) * 0.035);
      _drawStatusSprite(
        canvas,
        image: game.statusEffectSprites.burnGlow,
        center: ember,
        radius: radius * 2.2,
      );
      _drawStatusSprite(
        canvas,
        image: game.statusEffectSprites.burnEmber,
        center: ember,
        radius: radius,
      );
      if (i.isEven) {
        _drawStatusSprite(
          canvas,
          image: game.statusEffectSprites.burnSmoke,
          center: ember.translate(size.x * 0.04, -size.y * 0.1),
          radius: radius * 1.5,
          alpha: 0.22 * phase,
        );
      }
    }
  }

  void _drawSlowStatus(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final rimRect = Rect.fromCircle(center: center, radius: size.x * 0.48);
    final phase = _statusEffectTime * 0.9;
    final rimCount = game.enemies.length >= 60 ? 2 : 3;
    for (var i = 0; i < rimCount; i++) {
      canvas.drawArc(
        rimRect,
        phase + i * math.pi * 2 / 3,
        math.pi * 0.34,
        false,
        _slowRimPaint,
      );
    }

    final shardCount = game.enemies.length >= 60 ? 2 : _slowShardOffsets.length;
    for (var i = 0; i < shardCount; i++) {
      final shardOffset = _slowShardOffsets[i];
      final shardCenter = Offset(
        center.dx + shardOffset.dx * size.x,
        center.dy + shardOffset.dy * size.y,
      );
      final shardSize = size.x * 0.075;
      _drawStatusSprite(
        canvas,
        image: game.statusEffectSprites.slowShard,
        center: shardCenter,
        radius: shardSize / 0.34,
      );
    }
  }

  void _drawRiftMarkStatus(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final phase = (_statusEffectTime * 1.45) % 1;
    final baseRadius = size.x * (0.55 + phase * 0.08);
    final color = const Color(0xFFCFA7FF);
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.58 - phase * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.x * 0.055
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.x * 0.16;
    final rect = Rect.fromCircle(center: center, radius: baseRadius);
    canvas.drawCircle(center, baseRadius, glowPaint);
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        rect,
        phase * math.pi * 2 + i * math.pi / 2,
        math.pi * 0.26,
        false,
        ringPaint,
      );
    }
    canvas.drawLine(
      center.translate(-size.x * 0.16, -size.y * 0.16),
      center.translate(size.x * 0.16, size.y * 0.16),
      ringPaint,
    );
    canvas.drawLine(
      center.translate(size.x * 0.16, -size.y * 0.16),
      center.translate(-size.x * 0.16, size.y * 0.16),
      ringPaint,
    );
  }

  void _drawStatusSprite(
    Canvas canvas, {
    required Image image,
    required Offset center,
    required double radius,
    double alpha = 1,
  }) {
    _spritePaint.colorFilter = alpha >= 1
        ? null
        : ColorFilter.mode(
            const Color(0xFFFFFFFF).withValues(alpha: alpha),
            BlendMode.modulate,
          );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCircle(center: center, radius: radius),
      _spritePaint,
    );
  }

  void _placeAtDistance(double targetDistance) {
    var travelled = 0.0;
    for (var i = 1; i < path.length; i++) {
      final from = path[i - 1];
      final to = path[i];
      final segment = to - from;
      final segmentLength = segment.length;
      if (segmentLength == 0) {
        continue;
      }
      if (travelled + segmentLength >= targetDistance) {
        final ratio = ((targetDistance - travelled) / segmentLength)
            .clamp(0.0, 1.0)
            .toDouble();
        position = from + segment * ratio;
        _targetIndex = i;
        _facingAngle = math.atan2(segment.y, segment.x);
        return;
      }
      travelled += segmentLength;
    }

    position = path.last.clone();
    _targetIndex = path.length - 1;
  }

  Vector2 _visualRenderOffset() {
    return _visualLaneOffset() + Vector2(0, _visualBobOffset());
  }

  double _visualBobOffset() {
    final amplitude = _bobAmplitudeByType * game.boardDistanceScale;
    if (amplitude <= 0) {
      return 0;
    }
    final horizontalFacing = math.cos(_facingAngle).abs();
    return math.sin(
          _statusEffectTime * _bobSpeedByType + visualPhase * math.pi * 2,
        ) *
        amplitude *
        horizontalFacing;
  }

  Vector2 _visualLaneOffset() {
    if (laneOffsetRatio == 0 || path.length < 2) {
      return Vector2.zero();
    }
    final sampleDistance =
        _designTileSize * game.boardDistanceScale * _laneCornerSampleTiles;
    final before = _pointAtDistance(distanceTravelled - sampleDistance);
    final after = _pointAtDistance(distanceTravelled + sampleDistance);
    var tangent = after - before;
    if (tangent.length2 <= 0.001) {
      final target = _targetIndex < path.length
          ? path[_targetIndex]
          : path.last;
      tangent = target - position;
    }
    if (tangent.length2 <= 0.001) {
      return Vector2.zero();
    }
    final normal = Vector2(-tangent.y, tangent.x)..normalize();
    final distanceFromStart = distanceTravelled;
    final distanceFromEnd = _pathLength(path) - distanceTravelled;
    final endpointFadeDistance =
        _designTileSize * game.boardDistanceScale * _laneEndpointFadeTiles;
    final endpointFade = endpointFadeDistance <= 0
        ? 1.0
        : (math.min(distanceFromStart, distanceFromEnd) / endpointFadeDistance)
              .clamp(0.0, 1.0)
              .toDouble();
    return normal *
        laneOffsetRatio *
        _designTileSize *
        game.boardDistanceScale *
        endpointFade;
  }

  Vector2 _pointAtDistance(double targetDistance) {
    final clampedDistance = targetDistance
        .clamp(0.0, _pathLength(path))
        .toDouble();
    var travelled = 0.0;
    for (var i = 1; i < path.length; i++) {
      final from = path[i - 1];
      final to = path[i];
      final segment = to - from;
      final segmentLength = segment.length;
      if (segmentLength == 0) {
        continue;
      }
      if (travelled + segmentLength >= clampedDistance) {
        final ratio = ((clampedDistance - travelled) / segmentLength)
            .clamp(0.0, 1.0)
            .toDouble();
        return from + segment * ratio;
      }
      travelled += segmentLength;
    }
    return path.last.clone();
  }

  double _pathLength(List<Vector2> points) {
    var length = 0.0;
    for (var i = 1; i < points.length; i++) {
      length += points[i].distanceTo(points[i - 1]);
    }
    return length;
  }

  double get _bobAmplitudeByType {
    return switch (definition.type) {
      EnemyType.fast => 2.8,
      EnemyType.boss => 1.35,
      EnemyType.tank => 1.5,
      _ => 2.1,
    };
  }

  double get _bobSpeedByType {
    return switch (definition.type) {
      EnemyType.fast => 5.4,
      EnemyType.boss => 2.2,
      EnemyType.tank => 2.8,
      _ => 3.7,
    };
  }

  static const double _laneCornerSampleTiles = 0.4;
  static const double _laneEndpointFadeTiles = 0.55;
}

class _BurnInstance {
  _BurnInstance({
    required this.remaining,
    required this.damagePerSecond,
    required this.damageMultiplier,
    required this.sourceTurretPoint,
    required this.ignoreArmorReduction,
  });

  double remaining;
  double damagePerSecond;
  double damageMultiplier;
  GridPoint? sourceTurretPoint;
  bool ignoreArmorReduction;

  SavedBurnInstance toSaveData() {
    return SavedBurnInstance(
      remaining: remaining,
      damagePerSecond: damagePerSecond,
      damageMultiplier: damageMultiplier,
      sourceX: sourceTurretPoint?.x,
      sourceY: sourceTurretPoint?.y,
      ignoreArmorReduction: ignoreArmorReduction,
    );
  }

  static _BurnInstance fromSaveData(SavedBurnInstance data) {
    return _BurnInstance(
      remaining: math.max(0, data.remaining),
      damagePerSecond: math.max(0, data.damagePerSecond),
      damageMultiplier: math.max(0, data.damageMultiplier),
      sourceTurretPoint: data.sourcePoint,
      ignoreArmorReduction: data.ignoreArmorReduction,
    );
  }
}

class BurnTransferPayload {
  const BurnTransferPayload({
    required this.sourceTurretPoint,
    required this.remaining,
    required this.damagePerSecond,
    required this.damageMultiplier,
    required this.ignoreArmorReduction,
  });

  final GridPoint? sourceTurretPoint;
  final double remaining;
  final double damagePerSecond;
  final double damageMultiplier;
  final bool ignoreArmorReduction;
}
