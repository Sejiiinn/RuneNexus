import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../../data/save/game_save_data.dart';
import '../../domain/enemy/enemy_definition.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/map/grid_point.dart';
import '../rune_nexus_game.dart';

/// Saved/UI mirror of a Godot-owned enemy. No combat clock or rendering.
class EnemyComponent {
  EnemyComponent({
    required this.definition,
    required this.maxHp,
    this.maxShield = 0,
    this.maxArmor = 0,
    this.laneOffsetRatio = 0,
    this.visualPhase = 0,
    int diamondReward = 0,
    required List<Vector2> path,
    required this.game,
  }) : _path = path,
       diamondReward = definition.type.isBoss
           ? 0
           : diamondReward.clamp(0, 3).toInt(),
       hp = maxHp,
       shield = maxShield,
       armor = maxArmor,
       position = path.isEmpty ? Vector2.zero() : path.first.clone(),
       size = Vector2.all(_sizeForTileScale(game.boardDistanceScale)) {
    _rebuildPathGeometry();
  }

  Vector2 position;
  Vector2 size;
  bool _attached = false;
  bool _removed = false;
  void Function()? _onRemove;

  /// Registration only: the coordinator owns the collection, Godot owns time.
  bool get isMounted => _attached;
  bool get isRemoving => _removed;
  void attach({void Function()? onRemove}) {
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

  final EnemyDefinition definition;
  final double maxHp;
  final double maxShield;
  final double maxArmor;
  final double laneOffsetRatio;
  final double visualPhase;
  final int diamondReward;
  final RuneNexusGame game;
  List<Vector2> _path;
  List<Vector2> get path => _path;
  // 좌표를 제자리 수정한 경우 updatePath를 통한 경로 캐시 갱신
  set path(List<Vector2> value) {
    _path = value;
    _rebuildPathGeometry();
  }

  final List<int> _pathSegmentEnds = [];
  final List<double> _pathSegmentLengths = [];
  final List<double> _pathCumulativeLengths = [];
  double _totalPathLength = 0;
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
  // 같은 강도만 재갱신, 서로 다른 강도는 독립 만료
  final Map<double, double> _slowDurations = {};
  double get _slowMultiplier => _slowDurations.keys.fold(1.0, math.min);
  double get _slowRemaining => _slowDurations[_slowMultiplier] ?? 0;
  double _physicalVulnerabilityRemaining = 0;
  double _physicalVulnerabilityBonus = 0;
  double _elementalVulnerabilityRemaining = 0;
  double _elementalVulnerabilityBonus = 0;
  double _riftMarkRemaining = 0;
  double _riftMarkDamageAmplification = 0;
  double _facingAngle = 0;
  double _hitFlashTimer = 0;
  double _statusEffectTime = 0;
  static const double _designTileSize = 48;

  bool get isDead => hp <= 0;
  bool get isDiamondCarrier => diamondReward > 0;
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
  double get maxDurability => maxHp + maxShield + maxArmor;
  double get currentDurability => hp + shield + armor;
  final Vector2 _visualOffset = Vector2.zero();
  Vector2 get visualPosition => position + _visualOffset;
  double get facingAngle => _facingAngle;
  bool get isBurning => _burnInstances.isNotEmpty;
  bool get isPoisoned => _poisonRemaining > 0;
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
      slowInstances: List.unmodifiable(
        _slowDurations.entries.map(
          (entry) =>
              SavedSlowInstance(multiplier: entry.key, remaining: entry.value),
        ),
      ),
      physicalVulnerabilityRemaining: _physicalVulnerabilityRemaining,
      physicalVulnerabilityBonus: _physicalVulnerabilityBonus,
      elementalVulnerabilityRemaining: _elementalVulnerabilityRemaining,
      elementalVulnerabilityBonus: _elementalVulnerabilityBonus,
      laneOffsetRatio: laneOffsetRatio,
      diamondReward: diamondReward,
      riftMarkRemaining: _riftMarkRemaining,
      riftMarkDamageAmplification: _riftMarkDamageAmplification,
    );
  }

  Map<String, Object?> nativeCombatState(int id) => {
    ...toSaveData().toJson(),
    'id': id,
    'x': position.x,
    'y': position.y,
    'position': {'x': position.x, 'y': position.y},
    'presentationScale': size.x / (48 * game.boardDistanceScale),
    'presentationSize': [size.x, size.y],
    'visualOffset': [
      visualPosition.x - position.x,
      visualPosition.y - position.y,
    ],
    'path': [
      for (final point in path) {'x': point.x, 'y': point.y},
    ],
    'speed': definition.speed,
    'boardDistanceScale': game.boardDistanceScale,
    'maxShield': maxShield,
    'maxArmor': maxArmor,
    'shieldRegenRate': definition.shieldRegenRate,
    'targetIndex': _targetIndex,
    'facingAngle': _facingAngle,
    'collisionRadius': collisionRadius,
    'targetingRadius': math.min(size.x, size.y) / 2,
    'visualPhase': visualPhase,
    'burnNumberDamage': _burnNumberDamage,
    'burnNumberTimer': _burnNumberTimer,
    'poisonNumberDamage': _poisonNumberDamage,
    'poisonNumberTimer': _poisonNumberTimer,
    'hitFlashTimer': _hitFlashTimer,
    'statusEffectTime': _statusEffectTime,
    'familyResistances': {
      for (final entry
          in definition.resistanceProfile.familyResistances.entries)
        entry.key.name: entry.value,
    },
    'tagResistances': {
      for (final entry in definition.resistanceProfile.tagResistances.entries)
        entry.key.name: entry.value,
    },
  };

  void applyNativeCombatState(Map<String, dynamic> state) {
    final saved = SavedEnemy.fromJson(state);
    if (saved == null) throw StateError('Invalid native enemy snapshot');
    restoreFromSaveData(saved);
    if (state['x'] is num && state['y'] is num) {
      position.setValues(
        (state['x'] as num).toDouble(),
        (state['y'] as num).toDouble(),
      );
    }
    _targetIndex = (state['targetIndex'] as num?)?.toInt() ?? _targetIndex;
    _facingAngle = (state['facingAngle'] as num?)?.toDouble() ?? _facingAngle;
    _burnNumberDamage = (state['burnNumberDamage'] as num?)?.toDouble() ?? 0;
    _burnNumberTimer = (state['burnNumberTimer'] as num?)?.toDouble() ?? 0;
    _poisonNumberDamage =
        (state['poisonNumberDamage'] as num?)?.toDouble() ?? 0;
    _poisonNumberTimer = (state['poisonNumberTimer'] as num?)?.toDouble() ?? 0;
    _hitFlashTimer = (state['hitFlashTimer'] as num?)?.toDouble() ?? 0;
    _statusEffectTime = (state['statusEffectTime'] as num?)?.toDouble() ?? 0;
    final offset = state['visualOffset'];
    if (offset is List && offset.length >= 2) {
      _visualOffset.setValues(
        (offset[0] as num).toDouble(),
        (offset[1] as num).toDouble(),
      );
    }
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
    _slowDurations.clear();
    for (final instance in data.slowInstances) {
      final multiplier = instance.multiplier;
      final remaining = instance.remaining;
      if (multiplier.isFinite &&
          multiplier >= 0 &&
          multiplier < 1 &&
          remaining.isFinite &&
          remaining > 0) {
        _slowDurations[multiplier] = math.max(
          _slowDurations[multiplier] ?? 0,
          remaining,
        );
      }
    }
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
    updatePath(newPath);
  }

  void updatePath(List<Vector2> newPath) {
    if (newPath.length < 2) {
      return;
    }

    final progressRatio = _totalPathLength == 0
        ? 0.0
        : (distanceTravelled / _totalPathLength).clamp(0.0, 1.0).toDouble();
    path = newPath;
    _rebuildPathGeometry();
    distanceTravelled = _totalPathLength * progressRatio;
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
      EnemyType.shieldBoss => 0.81,
      EnemyType.forgeBoss => 0.83,
    };
  }

  // Layout/save reconstruction only. Movement is simulated exclusively in Godot.
  void _placeAtDistance(double targetDistance) {
    if (path.isEmpty) {
      position.setZero();
      _targetIndex = 0;
      return;
    }
    final segmentIndex = _segmentAtDistance(targetDistance);
    if (segmentIndex < _pathSegmentEnds.length) {
      final endIndex = _pathSegmentEnds[segmentIndex];
      position = _pointOnSegment(segmentIndex, targetDistance);
      _targetIndex = endIndex;
      final segment = path[endIndex] - path[endIndex - 1];
      _facingAngle = math.atan2(segment.y, segment.x);
      return;
    }

    position = path.last.clone();
    _targetIndex = path.length - 1;
  }

  void _rebuildPathGeometry() {
    _pathSegmentEnds.clear();
    _pathSegmentLengths.clear();
    _pathCumulativeLengths.clear();
    _totalPathLength = 0;
    for (var i = 1; i < path.length; i++) {
      final length = path[i].distanceTo(path[i - 1]);
      // 중복 좌표 제외: 경계에서는 앞쪽의 유효 구간 선택
      if (length == 0) {
        continue;
      }
      _totalPathLength += length;
      _pathSegmentEnds.add(i);
      _pathSegmentLengths.add(length);
      _pathCumulativeLengths.add(_totalPathLength);
    }
  }

  int _segmentAtDistance(double distance) {
    var low = 0;
    var high = _pathCumulativeLengths.length;
    // 누적 거리가 목표 이상인 첫 구간의 이분 탐색
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_pathCumulativeLengths[middle] < distance) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  Vector2 _pointOnSegment(int segmentIndex, double distance) {
    final endIndex = _pathSegmentEnds[segmentIndex];
    final startDistance = segmentIndex == 0
        ? 0.0
        : _pathCumulativeLengths[segmentIndex - 1];
    final ratio =
        ((distance - startDistance) / _pathSegmentLengths[segmentIndex])
            .clamp(0.0, 1.0)
            .toDouble();
    final from = path[endIndex - 1];
    return from + (path[endIndex] - from) * ratio;
  }
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
