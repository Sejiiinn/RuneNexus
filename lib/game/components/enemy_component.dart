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
  double _magicalVulnerabilityRemaining = 0;
  double _magicalVulnerabilityBonus = 0;
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
  double get magicalResistanceReduction =>
      _magicalVulnerabilityRemaining > 0 ? _magicalVulnerabilityBonus : 0;
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
      magicalVulnerabilityRemaining: _magicalVulnerabilityRemaining,
      magicalVulnerabilityBonus: _magicalVulnerabilityBonus,
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
    _magicalVulnerabilityRemaining = math.max(
      0,
      data.magicalVulnerabilityRemaining,
    );
    _magicalVulnerabilityBonus = math.max(0, data.magicalVulnerabilityBonus);
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

  double receiveDamage(double damage, {BurnTransferPayload? burnTransfer}) {
    if (damage <= 0 || isDead) {
      return 0;
    }
    var remainingDamage = damage;
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
      final armorReduction = armor * definition.armorReductionRate;
      final minimumArmorDamage =
          remainingDamage * definition.armorMinimumDamageRate;
      final armorDamage = math.max(
        minimumArmorDamage,
        remainingDamage - armorReduction,
      );
      final actualArmorDamage = math.min(armor, armorDamage);
      armor = math.max(0, armor - actualArmorDamage);
      actualDamage += actualArmorDamage;
      remainingDamage = math.max(0, armorDamage - actualArmorDamage);
    }

    if (remainingDamage <= 0) {
      return actualDamage;
    }

    final previousHp = hp;
    hp = math.max(0, hp - remainingDamage);
    actualDamage += previousHp - hp;
    if (isDead) {
      game.enemyKilled(this, burnTransfer: burnTransfer);
    }
    return actualDamage;
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

  void applyMagicalVulnerability({
    required double bonus,
    required double duration,
  }) {
    if (bonus <= 0 || duration <= 0) {
      return;
    }
    _magicalVulnerabilityBonus = math.max(_magicalVulnerabilityBonus, bonus);
    _magicalVulnerabilityRemaining = math.max(
      _magicalVulnerabilityRemaining,
      duration,
    );
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
          ),
        );
        _burnNumberDamage += actualDamage;
        game.recordTurretDamage(activeBurn.sourceTurretPoint, actualDamage);
      }
      _burnInstances.removeWhere((instance) => instance.remaining <= 0);
      if (!isDead &&
          (_burnNumberTimer >= _burnNumberInterval || _burnInstances.isEmpty) &&
          _burnNumberDamage > 0) {
        game.showDamageNumber(
          position: position.clone(),
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
          position: position.clone(),
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
    if (_magicalVulnerabilityRemaining > 0) {
      _magicalVulnerabilityRemaining = math.max(
        0,
        _magicalVulnerabilityRemaining - dt,
      );
      if (_magicalVulnerabilityRemaining == 0) {
        _magicalVulnerabilityBonus = 0;
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

    _drawBody(canvas, body, outline);
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

    _drawDurabilityBars(canvas);
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

  double _pathLength(List<Vector2> points) {
    var length = 0.0;
    for (var i = 1; i < points.length; i++) {
      length += points[i].distanceTo(points[i - 1]);
    }
    return length;
  }
}

class _BurnInstance {
  _BurnInstance({
    required this.remaining,
    required this.damagePerSecond,
    required this.damageMultiplier,
    required this.sourceTurretPoint,
  });

  double remaining;
  double damagePerSecond;
  double damageMultiplier;
  GridPoint? sourceTurretPoint;

  SavedBurnInstance toSaveData() {
    return SavedBurnInstance(
      remaining: remaining,
      damagePerSecond: damagePerSecond,
      damageMultiplier: damageMultiplier,
      sourceX: sourceTurretPoint?.x,
      sourceY: sourceTurretPoint?.y,
    );
  }

  static _BurnInstance fromSaveData(SavedBurnInstance data) {
    return _BurnInstance(
      remaining: math.max(0, data.remaining),
      damagePerSecond: math.max(0, data.damagePerSecond),
      damageMultiplier: math.max(0, data.damageMultiplier),
      sourceTurretPoint: data.sourcePoint,
    );
  }
}

class BurnTransferPayload {
  const BurnTransferPayload({
    required this.sourceTurretPoint,
    required this.remaining,
    required this.damagePerSecond,
    required this.damageMultiplier,
  });

  final GridPoint? sourceTurretPoint;
  final double remaining;
  final double damagePerSecond;
  final double damageMultiplier;
}
