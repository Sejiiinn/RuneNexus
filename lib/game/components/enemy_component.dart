import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/save/game_save_data.dart';
import '../../domain/enemy/enemy_definition.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/map/grid_point.dart';
import '../rendering/enemy_renderer.dart';
import '../rune_nexus_game.dart';
import 'damage_number_component.dart';

class EnemyComponent extends PositionComponent {
  static const double _armorScratchDamageRate = 0.12;
  static const double _armorPressureScale = 3.0;

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
       super(
         position: path.first.clone(),
         size: Vector2.all(_sizeForTileScale(game.boardDistanceScale)),
         anchor: Anchor.center,
       ) {
    _rebuildPathGeometry();
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
  Color _hitFlashColor = const Color(0xFFFFFFFF);
  double _statusEffectTime = 0;
  final EnemyRenderer _renderer = EnemyRenderer();
  static const double _burnNumberInterval = 0.28;
  static const double _poisonNumberInterval = 0.5;
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
      applySlow(multiplier: instance.multiplier, duration: instance.remaining);
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
    _renderer.slowRimStrokeWidth = size.x * 0.077;
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
      final armorDamage = _armorDamageFor(
        remainingDamage,
        currentArmor: armor,
        ignoreArmorReduction: ignoreArmorReduction,
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
      final armorDamage = _armorDamageFor(
        remainingDamage,
        currentArmor: simulatedArmor,
        ignoreArmorReduction: ignoreArmorReduction,
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

  double _armorDamageFor(
    double incomingDamage, {
    required double currentArmor,
    required bool ignoreArmorReduction,
  }) {
    if (incomingDamage <= 0 || currentArmor <= 0) {
      return 0;
    }
    if (ignoreArmorReduction) {
      return incomingDamage;
    }

    final armorPressure = math.sqrt(maxArmor) * _armorPressureScale;
    final armorDamageRate =
        _armorScratchDamageRate +
        (1 - _armorScratchDamageRate) *
            incomingDamage /
            (incomingDamage + armorPressure);
    return incomingDamage * armorDamageRate;
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
    if (!multiplier.isFinite ||
        multiplier < 0 ||
        multiplier >= 1 ||
        !duration.isFinite ||
        duration <= 0) {
      return;
    }
    _slowDurations[multiplier] = math.max(
      _slowDurations[multiplier] ?? 0,
      duration,
    );
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
    if (_slowDurations.isNotEmpty) {
      _slowDurations.updateAll((_, remaining) => remaining - dt);
      _slowDurations.removeWhere((_, remaining) => remaining <= 0);
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

  EnemyRenderState get visualRenderState {
    final offset = _visualRenderOffset();
    return EnemyRenderState(
      size: Size(size.x, size.y),
      type: definition.type,
      color: definition.color,
      visualOffset: Offset(offset.x, offset.y),
      visualPhase: visualPhase,
      facingAngle: _facingAngle,
      effectTime: _statusEffectTime,
      hitFlashRemaining: _hitFlashTimer,
      hitFlashColor: _hitFlashColor,
      hp: hp,
      maxHp: maxHp,
      shield: shield,
      maxShield: maxShield,
      armor: armor,
      maxArmor: maxArmor,
      isDiamondCarrier: isDiamondCarrier,
      isBurning: _burnInstances.isNotEmpty,
      isPoisoned: _poisonRemaining > 0,
      isSlowed: isSlowed,
      hasRiftMark: hasRiftMark,
      enemyCount: game.enemies.length,
    );
  }

  void renderBattlefieldStatus(Canvas canvas) {
    _renderer.render(
      canvas,
      visualRenderState,
      statusEffectSprites: game.statusEffectSprites,
      diamondCurrencyImage: game.diamondCurrencyImage,
      showBody: false,
    );
  }

  @override
  void render(Canvas canvas) {
    _renderer.render(
      canvas,
      visualRenderState,
      statusEffectSprites: _burnInstances.isNotEmpty || isSlowed
          ? game.statusEffectSprites
          : null,
      diamondCurrencyImage: game.diamondCurrencyImage,
    );
  }

  void _placeAtDistance(double targetDistance) {
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
    final distanceFromEnd = _totalPathLength - distanceTravelled;
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
        .clamp(0.0, _totalPathLength)
        .toDouble();
    final segmentIndex = _segmentAtDistance(clampedDistance);
    if (segmentIndex == _pathSegmentEnds.length) {
      return path.last.clone();
    }
    return _pointOnSegment(segmentIndex, clampedDistance);
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

  double get _bobAmplitudeByType {
    return switch (definition.type) {
      EnemyType.fast => 2.8,
      EnemyType.boss => 1.35,
      EnemyType.shieldBoss => 1.25,
      EnemyType.forgeBoss => 1.1,
      EnemyType.tank => 1.5,
      _ => 2.1,
    };
  }

  double get _bobSpeedByType {
    return switch (definition.type) {
      EnemyType.fast => 5.4,
      EnemyType.boss => 2.2,
      EnemyType.shieldBoss => 2.0,
      EnemyType.forgeBoss => 1.8,
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
