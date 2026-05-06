import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/save/game_save_data.dart';
import '../../domain/enemy/enemy_definition.dart';
import '../../domain/map/grid_point.dart';
import '../rendering/enemy_shape_renderer.dart';
import '../rune_nexus_game.dart';
import 'damage_number_component.dart';

class EnemyComponent extends PositionComponent {
  EnemyComponent({
    required this.definition,
    required this.maxHp,
    required this.path,
    required this.game,
  }) : hp = maxHp,
       super(
         position: path.first.clone(),
         size: Vector2.all(22),
         anchor: Anchor.center,
       );

  final EnemyDefinition definition;
  final double maxHp;
  final RuneNexusGame game;
  List<Vector2> path;
  double hp;

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
  double _facingAngle = 0;

  bool get isDead => hp <= 0;
  double get totalBurnDamagePerSecond => _burnInstances.fold(
    0,
    (total, instance) => total + instance.damagePerSecond,
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
    );
  }

  void restoreFromSaveData(SavedEnemy data) {
    hp = data.hp.clamp(0, maxHp).toDouble();
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
    _placeAtDistance(distanceTravelled);
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

  @override
  void update(double dt) {
    super.update(dt);
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

  double receiveDamage(double damage) {
    if (damage <= 0 || isDead) {
      return 0;
    }
    final previousHp = hp;
    hp = math.max(0, hp - damage);
    final actualDamage = previousHp - hp;
    if (isDead) {
      game.enemyKilled(this);
    }
    return actualDamage;
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
    _burnInstances.add(
      _BurnInstance(
        remaining: duration,
        damagePerSecond: damagePerSecond,
        damageMultiplier: damageMultiplier,
        sourceTurretPoint: sourceTurretPoint,
      ),
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

  void _updateStatusEffects(double dt) {
    if (_burnInstances.isNotEmpty) {
      _burnNumberTimer += dt;
      for (final instance in _burnInstances.toList()) {
        instance.remaining = math.max(0, instance.remaining - dt);
        final damage = instance.damagePerSecond * dt;
        final actualDamage = receiveDamage(damage);
        _burnNumberDamage += actualDamage;
        game.recordTurretDamage(instance.sourceTurretPoint, actualDamage);
        if (isDead) {
          break;
        }
      }
      _burnInstances.removeWhere((instance) => instance.remaining <= 0);
      if (!isDead &&
          (_burnNumberTimer >= 0.5 || _burnInstances.isEmpty) &&
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
      _poisonNumberDamage += damage;
      _poisonNumberTimer += dt;
      receiveDamage(damage);
      if (!isDead && (_poisonNumberTimer >= 0.75 || _poisonRemaining == 0)) {
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

    if (_burnInstances.isNotEmpty) {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x * 0.5,
        Paint()
          ..color = const Color(0x88FF8A2A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
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
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x * 0.58,
        Paint()
          ..color = const Color(0x669BE7FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    final ratio = hp / maxHp;
    canvas.drawRect(
      Rect.fromLTWH(1, -5, size.x - 2, 3),
      Paint()..color = const Color(0xFF321118),
    );
    canvas.drawRect(
      Rect.fromLTWH(1, -5, (size.x - 2) * ratio, 3),
      Paint()..color = const Color(0xFFFF4E5D),
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
  final double damagePerSecond;
  final double damageMultiplier;
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
