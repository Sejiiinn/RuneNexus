import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/save/game_save_data.dart';
import '../../domain/gem/gem_type.dart';
import '../../domain/map/grid_point.dart';
import '../../domain/turret/attack_tag.dart';
import '../../domain/turret/damage_family.dart';
import '../../domain/turret/turret_definition.dart';
import '../../domain/turret/turret_type.dart';
import '../rendering/turret_shape_renderer.dart';
import '../rune_nexus_game.dart';
import 'enemy_component.dart';
import 'projectile_component.dart';

class TurretComponent extends PositionComponent {
  TurretComponent({
    required this.gridPoint,
    required this.definition,
    required this.game,
    required Vector2 center,
    required double tileSize,
  }) : _tileSize = tileSize,
       super(
         position: center,
         size: Vector2.all(tileSize * 0.72),
         anchor: Anchor.center,
       );

  final GridPoint gridPoint;
  final TurretDefinition definition;
  final RuneNexusGame game;
  final List<GemType> equippedGems = [];

  double _tileSize;
  double _cooldown = 0;
  double _aimAngle = -math.pi / 2;
  int _slotLimit = 1;
  int _level = 1;
  double _directDamageDealt = 0;
  double _splashDamageDealt = 0;
  double _chainDamageDealt = 0;
  double _burnDamageDealt = 0;

  static const double _damageGrowthPerLevel = 0.2;
  static const double _rangeGrowthPerLevel = 0.033;
  static const double _attackRateGrowthPerLevel = 0.05;

  int get level => _level;
  int get maxLevel => 10;
  double get cooldown => _cooldown;
  double get directDamageDealt => _directDamageDealt;
  double get splashDamageDealt => _splashDamageDealt;
  double get chainDamageDealt => _chainDamageDealt;
  double get burnDamageDealt => _burnDamageDealt;
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

    return levelDamage;
  }

  double get range {
    final levelMultiplier = 1 + (_level - 1) * _rangeGrowthPerLevel;
    return definition.range *
        levelMultiplier *
        (hasGem(GemType.range) ? 1.2 : 1) *
        game.boardDistanceScale;
  }

  double get attackRate {
    final levelMultiplier = math
        .pow(1 + _attackRateGrowthPerLevel, _level - 1)
        .toDouble();
    return definition.attackRate *
        levelMultiplier *
        (hasGem(GemType.attackSpeed) ? 1.4 : 1) *
        (definition.attackTags.contains(AttackTag.light) &&
                hasGem(GemType.lightWeapon)
            ? 1.2
            : 1);
  }

  double get projectileSpeed =>
      definition.projectileSpeed * game.boardDistanceScale;

  double get damageOverTimeDamageMultiplier =>
      definition.attackTags.contains(AttackTag.damageOverTime) &&
          hasGem(GemType.damageOverTime)
      ? 1.3
      : 1;

  double get damageOverTimeDurationMultiplier =>
      definition.attackTags.contains(AttackTag.damageOverTime) &&
          hasGem(GemType.damageOverTime)
      ? 1.3
      : 1;

  double get splashSecondaryDamageMultiplier {
    if (hasGem(GemType.explosion)) {
      return definition.splashRadius > 0 ? 0.75 : 0.35;
    }
    return definition.splashRadius > 0 ? 0.75 : 1;
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
          heavyMultiplier *
          game.boardDistanceScale;
    }
    return (hasGem(GemType.explosion) ? 34 : 0) *
        heavyMultiplier *
        game.boardDistanceScale;
  }

  bool hasGem(GemType type) => equippedGems.contains(type);

  SavedTurret toSaveData() {
    return SavedTurret(
      x: gridPoint.x,
      y: gridPoint.y,
      type: definition.type,
      level: _level,
      slotLimit: _slotLimit,
      cooldown: _cooldown,
      equippedGems: List.unmodifiable(equippedGems),
      damageDealt: damageDealt,
      directDamageDealt: _directDamageDealt,
      splashDamageDealt: _splashDamageDealt,
      chainDamageDealt: _chainDamageDealt,
      burnDamageDealt: _burnDamageDealt,
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
    if (damageDealt == 0 && data.damageDealt > 0) {
      _directDamageDealt = math.max(0, data.damageDealt);
    }
    equippedGems
      ..clear()
      ..addAll(data.equippedGems.take(_slotLimit));
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

  void updateLayout({required Vector2 center, required double tileSize}) {
    position = center;
    _tileSize = tileSize;
    size = Vector2.all(tileSize * 0.72);
  }

  GemType? equipGem(GemType type, int slotIndex) {
    if (slotIndex < 0 || slotIndex >= slotLimit) {
      return null;
    }

    if (slotIndex == equippedGems.length) {
      equippedGems.add(type);
      return null;
    }
    if (slotIndex > equippedGems.length) {
      return null;
    }

    final previous = equippedGems[slotIndex];
    equippedGems[slotIndex] = type;
    return previous;
  }

  GemType? removeGemAt(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= equippedGems.length) {
      return null;
    }
    return equippedGems.removeAt(slotIndex);
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
    _cooldown = math.max(0, _cooldown - dt);
    if (_cooldown > 0 || !game.isWaveRunning) {
      return;
    }

    final target = _findTarget();
    if (target == null) {
      return;
    }

    _cooldown = 1 / attackRate;
    _aimAngle = math.atan2(
      target.position.y - position.y,
      target.position.x - position.x,
    );
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
    final candidates = game.enemies.where((enemy) {
      return enemy.isMounted &&
          !enemy.isDead &&
          enemy.position.distanceTo(position) <= range;
    }).toList();

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort(
      (a, b) => b.distanceTravelled.compareTo(a.distanceTravelled),
    );
    return candidates.first;
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

    drawTurretShape(
      canvas,
      size: Size(size.x, size.y),
      type: definition.type,
      color: definition.color,
      aimAngle: _aimAngle,
    );

    if (_level > 1) {
      final markerCount = _level - 1;
      final markerSize = _tileSize * 0.045;
      final markerGap = _tileSize * 0.035;
      final markerWidth = markerSize * 2;
      final totalWidth =
          markerCount * markerWidth + (markerCount - 1) * markerGap;
      final startX = center.dx - totalWidth / 2 + markerSize;
      final markerY = center.dy + _tileSize * 0.32;
      final markerFill = Paint()..color = const Color(0xFFFFD45A);
      final markerOutline = Paint()
        ..color = const Color(0xFF050A12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      for (var i = 0; i < markerCount; i++) {
        final x = startX + i * (markerWidth + markerGap);
        final marker = Path()
          ..moveTo(x, markerY - markerSize)
          ..lineTo(x + markerSize, markerY)
          ..lineTo(x, markerY + markerSize)
          ..lineTo(x - markerSize, markerY)
          ..close();
        canvas.drawPath(marker, markerFill);
        canvas.drawPath(marker, markerOutline);
      }
    }

    for (var i = 0; i < equippedGems.length; i++) {
      final offsetX = size.x * 0.78 - i * _tileSize * 0.14;
      canvas.drawCircle(
        Offset(offsetX, size.y * 0.22),
        _tileSize * 0.08,
        Paint()..color = game.colorForGem(equippedGems[i]),
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
}

enum TurretDamageKind { direct, splash, chain, burn }
