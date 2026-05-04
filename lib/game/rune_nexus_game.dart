import 'dart:async';
import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart' as gestures;
import 'package:flutter/material.dart';

import '../data/definitions/demo_enemy_data.dart';
import '../data/definitions/demo_gem_data.dart';
import '../data/definitions/demo_stage_data.dart';
import '../data/definitions/demo_turret_data.dart';
import '../data/save/game_save_data.dart';
import '../data/save/local_save_repository.dart';
import '../data/save/online_save_repository.dart';
import '../data/save/save_repository.dart';
import '../domain/combat/game_phase.dart';
import '../domain/enemy/enemy_scaling.dart';
import '../domain/enemy/enemy_type.dart';
import '../domain/gem/gem_equip_rules.dart';
import '../domain/gem/gem_type.dart';
import '../domain/map/grid_point.dart';
import '../domain/map/map_definition.dart';
import '../domain/turret/attack_tag.dart';
import '../domain/turret/turret_type.dart';
import '../domain/wave/wave_definition.dart';
import 'components/chain_projectile_component.dart';
import 'components/damage_number_component.dart';
import 'components/enemy_component.dart';
import 'components/grid_component.dart';
import 'components/impact_effect_component.dart';
import 'components/projectile_component.dart';
import 'components/turret_component.dart';
import 'game_snapshot.dart';
import 'systems/gem_reward_generator.dart';
import 'systems/run_progression.dart';
import 'systems/save_scheduler.dart';
import 'systems/wave_spawner.dart';

class RuneNexusGame extends FlameGame with TapCallbacks, ScaleDetector {
  static const double _chainDamageMultiplier = 0.5;
  static const double _minBoardZoom = 1;
  static const double _maxBoardZoom = 2.1;

  RuneNexusGame({
    MapDefinition map = demoMap,
    List<WaveDefinition>? waves,
    SaveRepository? saveRepository,
    OnlineSaveRepository? onlineSaveRepository,
  }) : _map = map,
       _waves = waves ?? demoWaves,
       _saveRepository = saveRepository ?? createDefaultSaveRepository(),
       _onlineSaveRepository =
           onlineSaveRepository ?? const NoopOnlineSaveRepository(),
       snapshotNotifier = ValueNotifier(
         GameSnapshot(
           gold: RunProgression.baseInitialGold,
           nexusHp: RunProgression.baseNexusHp,
           maxNexusHp: RunProgression.baseNexusHp,
           round: 1,
           maxRound: (waves ?? demoWaves).length,
           phase: GamePhase.preparation,
           restoredPhase: null,
           selectedTurretType: TurretType.arrow,
           previewText: (waves ?? demoWaves).first.previewText,
           rewardOptions: const [],
           gemInventory: const {},
           selectedBuildPoint: null,
           selectedBuildTurretType: null,
           selectedTurretPoint: null,
           selectedTurretName: null,
           selectedTurretGems: const [],
           selectedTurretGemSlotIndex: null,
           selectedTurretSlotLimit: 0,
           selectedTurretHasLinkUpgrade: false,
           selectedTurretCanUpgradeLink: false,
           selectedTurretLinkUpgradeCost: 0,
           selectedTurretNextSlotLimit: 0,
           selectedTurretLinkUpgradeRequiredLevel: 0,
           selectedTurretLevel: 0,
           selectedTurretMaxLevel: 0,
           selectedTurretCanLevelUp: false,
           selectedTurretLevelUpCost: 0,
           selectedTurretDamage: 0,
           selectedTurretRange: 0,
           selectedTurretAttackRate: 0,
           nextWaveEnemyTypes: const [],
           speedMultiplier: 1,
           runes: 0,
           lastRunRuneReward: 0,
           completedRounds: 0,
           startingGoldUpgradeLevel: 0,
           startingGoldUpgradeCost: RunProgression.startingGoldUpgradeBaseCost,
           canUpgradeStartingGold: false,
           nexusHpUpgradeLevel: 0,
           nexusHpUpgradeCost: RunProgression.nexusHpUpgradeBaseCost,
           canUpgradeNexusHp: false,
         ),
       );

  final MapDefinition _map;
  final List<WaveDefinition> _waves;
  final SaveRepository _saveRepository;
  final OnlineSaveRepository _onlineSaveRepository;
  final ValueNotifier<GameSnapshot> snapshotNotifier;

  final List<EnemyComponent> enemies = [];
  final Map<GridPoint, TurretComponent> _turrets = {};
  final Map<GemType, int> _gemInventory = {};
  final List<GemType> _rewardOptions = [];
  final WaveSpawner _waveSpawner = WaveSpawner();
  final GemRewardGenerator _gemRewardGenerator = GemRewardGenerator();
  final RunProgression _progression = RunProgression();
  late final SaveScheduler _saveScheduler = SaveScheduler(
    saveNow: _writeLocalSave,
  );

  late GridComponent _gridComponent;
  late Vector2 _origin;
  late double _tileSize;
  late List<Vector2> _worldPath;

  int _gold = RunProgression.baseInitialGold;
  int _nexusHp = RunProgression.baseNexusHp;
  int _completedRounds = 0;
  int _roundIndex = 0;
  GamePhase _phase = GamePhase.preparation;
  GamePhase? _restoredPhase;
  TurretType _selectedTurretType = TurretType.arrow;
  TurretType? _selectedBuildTurretType;
  GridPoint? _selectedBuildPoint;
  GridPoint? _selectedTurretPoint;
  int? _selectedTurretGemSlotIndex;
  double _speedMultiplier = 1;
  double _boardZoom = _minBoardZoom;
  Vector2 _boardOffset = Vector2.zero();
  double _scaleStartZoom = _minBoardZoom;
  double _trackpadStartZoom = _minBoardZoom;
  int? _dragPointer;
  Vector2? _lastDragPosition;
  double _dragDistance = 0;
  bool _suppressNextTap = false;

  bool get isWaveRunning => _phase == GamePhase.wave;
  int get _initialGold => _progression.initialGold;
  int get _maxNexusHp => _progression.maxNexusHp;
  bool get _canEditBoard =>
      _phase == GamePhase.preparation || _phase == GamePhase.wave;

  @override
  Color backgroundColor() => const Color(0xFF07111D);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _configureBoard();
    _gridComponent = GridComponent(
      map: _map,
      origin: _origin,
      tileSize: _tileSize,
    );
    add(_gridComponent);
    final savedData = await _saveRepository.load();
    if (savedData != null) {
      _restoreFromSaveData(savedData);
    }
    _publish();
  }

  @override
  void onRemove() {
    _saveScheduler.dispose();
    super.onRemove();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _configureBoard();
      _syncBoardComponents();
    }
  }

  @override
  void update(double dt) {
    if (_phase == GamePhase.restored) {
      super.update(0);
      return;
    }
    super.update(dt * _speedMultiplier);
    if (_phase != GamePhase.wave) {
      return;
    }

    _updateWaveSpawns(dt * _speedMultiplier);
    _checkWaveClear();
    _requestLocalSave();
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    if (info.pointerCount < 2) {
      return;
    }
    _scaleStartZoom = _boardZoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    if (info.pointerCount < 2) {
      return;
    }
    final scale = (info.scale.global.x + info.scale.global.y) / 2;
    _boardZoom = (_scaleStartZoom * scale).clamp(_minBoardZoom, _maxBoardZoom);
    _boardOffset = _clampBoardOffset(_boardOffset + info.delta.global);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_suppressNextTap) {
      _suppressNextTap = false;
      return;
    }
    if (_phase == GamePhase.restored) {
      return;
    }

    final point = _gridPointAt(_unzoomPosition(event.localPosition));
    if (point == null) {
      return;
    }
    if (_turrets.containsKey(point)) {
      final turret = _turrets[point]!;
      _selectedBuildPoint = null;
      _selectedBuildTurretType = null;
      _selectedTurretType = turret.definition.type;
      _selectedTurretPoint = point;
      _selectedTurretGemSlotIndex = null;
      _publish();
      return;
    }
    if (_canEditBoard && _map.canBuildAt(point)) {
      _selectedBuildPoint = point;
      _selectedBuildTurretType = null;
      _selectedTurretPoint = null;
      _selectedTurretGemSlotIndex = null;
      _publish();
      return;
    }

    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;
    _publish();
  }

  void previewOrBuildSelectedTile(TurretType type) {
    _selectedTurretType = type;
    final point = _selectedBuildPoint;
    if (point == null) {
      _publish();
      return;
    }

    if (_selectedBuildTurretType != type) {
      _selectedBuildTurretType = type;
      _publish();
      return;
    }
    tryBuildTurret(point);
  }

  void confirmBuildSelectedTile() {
    final type = _selectedBuildTurretType;
    final point = _selectedBuildPoint;
    if (type == null || point == null) {
      return;
    }

    _selectedTurretType = type;
    tryBuildTurret(point);
  }

  void selectTurretType(TurretType type) {
    _selectedTurretType = type;
    _publish();
  }

  void setSpeedMultiplier(double value) {
    _speedMultiplier = value;
    _publish();
  }

  void startNextWave() {
    if (_phase != GamePhase.preparation || _roundIndex >= _waves.length) {
      return;
    }

    _phase = GamePhase.wave;
    _selectedTurretPoint = null;
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedTurretGemSlotIndex = null;
    _waveSpawner.start(_waves[_roundIndex]);
    _publish();
    _requestLocalSave(immediate: true);
  }

  void restartDemo() {
    _clearActiveCombat();

    for (final turret in _turrets.values.toList()) {
      turret.removeFromParent();
    }
    _turrets.clear();
    _gemInventory.clear();
    _rewardOptions.clear();

    _gold = _initialGold;
    _nexusHp = _maxNexusHp;
    _roundIndex = 0;
    _completedRounds = 0;
    _progression.resetLastRunReward();
    _phase = GamePhase.preparation;
    _selectedTurretType = TurretType.arrow;
    _selectedBuildTurretType = null;
    _selectedBuildPoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;
    _restoredPhase = null;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void continueRestoredRun() {
    if (_phase != GamePhase.restored) {
      return;
    }

    _phase = _restoredPhase ?? GamePhase.preparation;
    _restoredPhase = null;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void discardRestoredRun() {
    if (_phase != GamePhase.restored) {
      return;
    }

    _restoredPhase = null;
    restartDemo();
  }

  void upgradeStartingGoldProgression() {
    if (!_progression.upgradeStartingGold()) {
      return;
    }

    if (_phase == GamePhase.preparation && _turrets.isEmpty) {
      _gold += 10;
    }
    _publish();
    _requestLocalSave(immediate: true);
  }

  void upgradeNexusHpProgression() {
    if (!_progression.upgradeNexusHp()) {
      return;
    }

    if (_phase == GamePhase.preparation || _phase == GamePhase.success) {
      _nexusHp++;
    }
    _publish();
    _requestLocalSave(immediate: true);
  }

  void debugSetRound(int round) {
    final clampedRound = round.clamp(1, _waves.length).toInt();
    _clearActiveCombat();
    _roundIndex = clampedRound - 1;
    _phase = GamePhase.preparation;
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void debugAddGold(int amount) {
    if (amount <= 0) {
      return;
    }

    _gold += amount;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void tryBuildTurret(GridPoint point) {
    if (!_canEditBoard) {
      return;
    }
    if (!_map.canBuildAt(point) || _turrets.containsKey(point)) {
      return;
    }

    final definition = demoTurrets[_selectedTurretType]!;
    if (_gold < definition.cost) {
      return;
    }

    _gold -= definition.cost;
    final turret = TurretComponent(
      gridPoint: point,
      definition: definition,
      game: this,
      center: _centerOf(point),
      tileSize: _tileSize,
    );
    _turrets[point] = turret;
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedTurretPoint = point;
    _selectedTurretGemSlotIndex = null;
    add(turret);
    _publish();
    _requestLocalSave(immediate: true);
  }

  void selectRewardGem(GemType type) {
    if (_phase != GamePhase.reward || !_rewardOptions.contains(type)) {
      return;
    }

    grantGem(type);
    _rewardOptions.clear();
    _phase = GamePhase.preparation;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void grantGem(GemType type) {
    _gemInventory[type] = (_gemInventory[type] ?? 0) + 1;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void selectSelectedTurretGemSlot(int slotIndex) {
    final point = _selectedTurretPoint;
    if (point == null) {
      return;
    }
    final turret = _turrets[point];
    if (turret == null || slotIndex < 0 || slotIndex >= turret.slotLimit) {
      return;
    }

    _selectedTurretGemSlotIndex = slotIndex;
    _publish();
  }

  void equipSelectedTurret(GemType type) {
    if (_phase != GamePhase.preparation || (_gemInventory[type] ?? 0) <= 0) {
      return;
    }

    final point = _selectedTurretPoint;
    if (point == null) {
      return;
    }
    final turret = _turrets[point];
    if (turret == null) {
      return;
    }
    if (turret.equippedGems.contains(type)) {
      return;
    }
    if (!canEquipGemOnTurret(type, turret.definition)) {
      return;
    }

    final selectedSlotIndex = _selectedTurretGemSlotIndex;
    final slotIndex = selectedSlotIndex == null
        ? _defaultGemSlotIndex(turret)
        : selectedSlotIndex.clamp(0, turret.slotLimit - 1).toInt();
    final returnedGem = turret.equipGem(type, slotIndex);
    _gemInventory[type] = (_gemInventory[type] ?? 0) - 1;
    if ((_gemInventory[type] ?? 0) <= 0) {
      _gemInventory.remove(type);
    }
    if (returnedGem != null) {
      _gemInventory[returnedGem] = (_gemInventory[returnedGem] ?? 0) + 1;
    }
    _selectedTurretGemSlotIndex = slotIndex;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void removeSelectedTurretGemSlot() {
    if (_phase != GamePhase.preparation) {
      return;
    }

    final point = _selectedTurretPoint;
    if (point == null) {
      return;
    }
    final turret = _turrets[point];
    if (turret == null) {
      return;
    }

    final slotIndex = _selectedTurretGemSlotIndex;
    if (slotIndex == null) {
      return;
    }

    final removedGem = turret.removeGemAt(slotIndex);
    if (removedGem == null) {
      return;
    }

    _gemInventory[removedGem] = (_gemInventory[removedGem] ?? 0) + 1;
    _selectedTurretGemSlotIndex = slotIndex
        .clamp(0, math.max(0, turret.slotLimit - 1))
        .toInt();
    _publish();
    _requestLocalSave(immediate: true);
  }

  void levelUpSelectedTurret() {
    if (!_canEditBoard) {
      return;
    }

    final point = _selectedTurretPoint;
    if (point == null) {
      return;
    }
    final turret = _turrets[point];
    if (turret == null || !turret.canLevelUp) {
      return;
    }
    if (_gold < turret.levelUpCost) {
      return;
    }

    _gold -= turret.levelUpCost;
    turret.upgradeLevel();
    _publish();
    _requestLocalSave(immediate: true);
  }

  void upgradeSelectedTurretLink() {
    if (_phase != GamePhase.preparation) {
      return;
    }

    final point = _selectedTurretPoint;
    if (point == null) {
      return;
    }
    final turret = _turrets[point];
    if (turret == null || !turret.canUpgradeLink) {
      return;
    }
    if (_gold < turret.linkUpgradeCost) {
      return;
    }

    _gold -= turret.linkUpgradeCost;
    turret.upgradeLink();
    _selectedTurretGemSlotIndex = null;
    _publish();
    _requestLocalSave(immediate: true);
  }

  int _defaultGemSlotIndex(TurretComponent turret) {
    if (turret.equippedGems.length < turret.slotLimit) {
      return turret.equippedGems.length;
    }
    return 0;
  }

  Color colorForGem(GemType type) => demoGems[type]!.color;

  void showDamageNumber({
    required Vector2 position,
    required double damage,
    required Color color,
    DamageNumberMotion motion = DamageNumberMotion.rise,
    double damageMultiplier = 1,
  }) {
    add(
      DamageNumberComponent(
        text: damage.round().toString(),
        color: color,
        position: position,
        motion: motion,
        feedback: _damageFeedbackFor(damageMultiplier),
      ),
    );
  }

  DamageNumberFeedback _damageFeedbackFor(double multiplier) {
    if (multiplier >= 1.05) {
      return DamageNumberFeedback.weak;
    }
    if (multiplier <= 0.95) {
      return DamageNumberFeedback.resisted;
    }
    return DamageNumberFeedback.neutral;
  }

  void handleTrackpadZoomStart(gestures.PointerPanZoomStartEvent event) {
    _trackpadStartZoom = _boardZoom;
  }

  void handleTrackpadZoomUpdate(gestures.PointerPanZoomUpdateEvent event) {
    _boardZoom = (_trackpadStartZoom * event.scale).clamp(
      _minBoardZoom,
      _maxBoardZoom,
    );
    final panDelta = Vector2(event.panDelta.dx, event.panDelta.dy);
    if (panDelta.length2 > 0) {
      _moveBoardBy(panDelta);
    } else {
      _boardOffset = _clampBoardOffset(_boardOffset);
    }
  }

  void handleBoardPointerDown(gestures.PointerDownEvent event) {
    if (_boardZoom <= _minBoardZoom) {
      return;
    }

    _dragPointer = event.pointer;
    _lastDragPosition = Vector2(event.localPosition.dx, event.localPosition.dy);
    _dragDistance = 0;
  }

  void handleBoardPointerMove(gestures.PointerMoveEvent event) {
    if (_dragPointer != event.pointer || _boardZoom <= _minBoardZoom) {
      return;
    }

    final lastPosition = _lastDragPosition;
    if (lastPosition == null) {
      return;
    }

    final position = Vector2(event.localPosition.dx, event.localPosition.dy);
    final delta = position - lastPosition;
    _lastDragPosition = position;
    _dragDistance += delta.length;

    if (_dragDistance < 4) {
      return;
    }
    if (_dragDistance >= 8) {
      _suppressNextTap = true;
    }
    _moveBoardBy(delta);
  }

  void handleBoardPointerUp(gestures.PointerUpEvent event) {
    if (_dragPointer == event.pointer) {
      _dragPointer = null;
      _lastDragPosition = null;
      _dragDistance = 0;
    }
  }

  void handleBoardPointerCancel(gestures.PointerCancelEvent event) {
    if (_dragPointer == event.pointer) {
      _dragPointer = null;
      _lastDragPosition = null;
      _dragDistance = 0;
    }
  }

  void _moveBoardBy(Vector2 delta) {
    if (_boardZoom <= _minBoardZoom) {
      _boardOffset = Vector2.zero();
      return;
    }
    _boardOffset = _clampBoardOffset(_boardOffset + delta);
  }

  void resolveProjectileHit({
    required TurretComponent owner,
    required EnemyComponent target,
    required Vector2 hitPosition,
  }) {
    final impacted = <EnemyComponent>{};
    if (owner.splashRadius > 0) {
      for (final enemy in enemies.toList()) {
        if (enemy.isMounted &&
            !enemy.isDead &&
            enemy.position.distanceTo(hitPosition) <= owner.splashRadius) {
          impacted.add(enemy);
        }
      }
    } else if (target.isMounted && !target.isDead) {
      impacted.add(target);
    }
    _showImpact(owner: owner, position: hitPosition);

    for (final enemy in impacted.toList()) {
      final baseDamage = identical(enemy, target)
          ? owner.damage
          : owner.damage * owner.splashSecondaryDamageMultiplier;
      final multiplier = _damageMultiplier(owner, enemy);
      final damage = baseDamage * multiplier;
      _applyGemStatuses(owner, enemy);
      showDamageNumber(
        position: enemy.position.clone(),
        damage: damage,
        color: owner.definition.color,
        damageMultiplier: multiplier,
      );
      enemy.receiveDamage(damage);
    }

    if (owner.hasGem(GemType.chain)) {
      _spawnChainProjectiles(owner: owner, source: target, excluded: impacted);
    }
  }

  void resolveChainHit({
    required TurretComponent owner,
    required EnemyComponent target,
    required double damage,
  }) {
    final multiplier = _damageMultiplier(owner, target);
    final adjustedDamage = damage * multiplier;
    final statusScale = owner.damage <= 0 ? 0.0 : damage / owner.damage;
    _applyGemStatuses(owner, target, damageScale: statusScale);
    showDamageNumber(
      position: target.position.clone(),
      damage: adjustedDamage,
      color: chainColorFor(owner),
      damageMultiplier: multiplier,
    );
    target.receiveDamage(adjustedDamage);
  }

  Color chainColorFor(TurretComponent owner) {
    return Color.lerp(owner.definition.color, const Color(0xFF02070D), 0.38)!;
  }

  void _showImpact({
    required TurretComponent owner,
    required Vector2 position,
  }) {
    final style = switch (owner.definition.type) {
      TurretType.arrow => ImpactEffectStyle.spark,
      TurretType.cannon => ImpactEffectStyle.blast,
      TurretType.magic => ImpactEffectStyle.flame,
    };
    final radius = owner.splashRadius > 0
        ? owner.splashRadius.clamp(18, 48).toDouble()
        : switch (owner.definition.type) {
            TurretType.arrow => 11.0,
            TurretType.cannon => 22.0,
            TurretType.magic => 16.0,
          };
    add(
      ImpactEffectComponent(
        position: position,
        color: owner.definition.color,
        style: style,
        radius: radius,
      ),
    );
  }

  void _spawnChainProjectiles({
    required TurretComponent owner,
    required EnemyComponent source,
    required Set<EnemyComponent> excluded,
  }) {
    final candidates =
        enemies.where((enemy) {
          return enemy.isMounted &&
              !enemy.isDead &&
              !excluded.contains(enemy) &&
              enemy.position.distanceTo(source.position) <= 88;
        }).toList()..sort(
          (a, b) => a.position
              .distanceTo(source.position)
              .compareTo(b.position.distanceTo(source.position)),
        );

    for (final enemy in candidates.take(2)) {
      add(
        ChainProjectileComponent(
          origin: source.position.clone(),
          target: enemy,
          owner: owner,
          damage: owner.damage * _chainDamageMultiplier,
          game: this,
        ),
      );
    }
  }

  void enemyKilled(EnemyComponent enemy) {
    if (!enemy.isMounted) {
      return;
    }
    _gold += enemy.definition.rewardGold;
    enemies.remove(enemy);
    enemy.removeFromParent();
    _publish();
  }

  void enemyReachedCore(EnemyComponent enemy) {
    if (!enemy.isMounted) {
      return;
    }
    _nexusHp = math.max(0, _nexusHp - enemy.definition.coreDamage);
    enemies.remove(enemy);
    enemy.removeFromParent();

    if (_nexusHp <= 0) {
      _waveSpawner.clear();
      for (final activeEnemy in enemies.toList()) {
        activeEnemy.removeFromParent();
      }
      enemies.clear();
      _finishRun(GamePhase.failure);
      unawaited(_saveRoundCheckpoint());
    }
    _publish();
  }

  void _configureBoard() {
    const topReservedHeight = 88.0;
    const bottomReservedHeight = 305.0;
    final availableHeight = math.max(
      160.0,
      size.y - topReservedHeight - bottomReservedHeight,
    );
    final availableWidth = math.max(1.0, size.x);
    _tileSize = math.max(
      12.0,
      math.min(availableWidth / _map.columns, availableHeight / _map.rows),
    );
    final width = _tileSize * _map.columns;
    final height = _tileSize * _map.rows;
    _origin = Vector2(
      (size.x - width) / 2,
      topReservedHeight + (availableHeight - height) / 2,
    );
    if (_boardZoom <= _minBoardZoom) {
      _boardOffset = Vector2.zero();
    } else {
      _boardOffset = _clampBoardOffset(_boardOffset);
    }
    _worldPath = _map.path.map(_centerOf).toList();
  }

  void _syncBoardComponents() {
    _gridComponent.updateLayout(origin: _origin, tileSize: _tileSize);
    for (final entry in _turrets.entries) {
      entry.value.updateLayout(
        center: _centerOf(entry.key),
        tileSize: _tileSize,
      );
    }
    for (final enemy in enemies) {
      enemy.updatePath(_worldPath);
    }
  }

  void _clearActiveCombat() {
    for (final enemy in enemies.toList()) {
      enemy.removeFromParent();
    }
    enemies.clear();
    _waveSpawner.clear();
    _rewardOptions.clear();

    for (final component
        in children.whereType<ProjectileComponent>().toList()) {
      component.removeFromParent();
    }
    for (final component
        in children.whereType<ChainProjectileComponent>().toList()) {
      component.removeFromParent();
    }
    for (final component
        in children.whereType<ImpactEffectComponent>().toList()) {
      component.removeFromParent();
    }
    for (final component
        in children.whereType<DamageNumberComponent>().toList()) {
      component.removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    _applyBoardZoom(canvas);
    super.render(canvas);
    final point = _selectedBuildPoint;
    if (point == null) {
      canvas.restore();
      return;
    }

    final rect = Rect.fromLTWH(
      _origin.x + point.x * _tileSize + 2,
      _origin.y + point.y * _tileSize + 2,
      _tileSize - 4,
      _tileSize - 4,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0x668EE6FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.restore();
  }

  void _applyBoardZoom(Canvas canvas) {
    if (_boardZoom == _minBoardZoom) {
      return;
    }

    final center = _boardCenter();
    canvas
      ..translate(_boardOffset.x, _boardOffset.y)
      ..translate(center.x, center.y)
      ..scale(_boardZoom)
      ..translate(-center.x, -center.y);
  }

  Vector2 _unzoomPosition(Vector2 position) {
    if (_boardZoom == _minBoardZoom) {
      return position;
    }

    final center = _boardCenter();
    return center + (position - _boardOffset - center) / _boardZoom;
  }

  Vector2 _clampBoardOffset(Vector2 offset) {
    if (_boardZoom <= _minBoardZoom) {
      return Vector2.zero();
    }

    final maxX = _tileSize * _map.columns * (_boardZoom - 1) / 2;
    final maxY = _tileSize * _map.rows * (_boardZoom - 1) / 2;
    return Vector2(
      offset.x.clamp(-maxX, maxX).toDouble(),
      offset.y.clamp(-maxY, maxY).toDouble(),
    );
  }

  Vector2 _boardCenter() {
    return Vector2(
      _origin.x + _tileSize * _map.columns / 2,
      _origin.y + _tileSize * _map.rows / 2,
    );
  }

  GridPoint? _gridPointAt(Vector2 position) {
    final x = ((position.x - _origin.x) / _tileSize).floor();
    final y = ((position.y - _origin.y) / _tileSize).floor();
    final point = GridPoint(x, y);
    return _map.contains(point) ? point : null;
  }

  Vector2 _centerOf(GridPoint point) {
    return Vector2(
      _origin.x + point.x * _tileSize + _tileSize / 2,
      _origin.y + point.y * _tileSize + _tileSize / 2,
    );
  }

  void _updateWaveSpawns(double dt) {
    for (final enemyType in _waveSpawner.update(dt)) {
      _spawnEnemy(enemyType);
    }
  }

  void _spawnEnemy(EnemyType type) {
    final definition = demoEnemies[type]!;
    final enemy = EnemyComponent(
      definition: definition,
      maxHp: scaledEnemyMaxHp(definition, _waves[_roundIndex].round),
      path: _worldPath,
      game: this,
    );
    enemies.add(enemy);
    add(enemy);
  }

  void _checkWaveClear() {
    if (!_waveSpawner.isEmpty ||
        enemies.isNotEmpty ||
        _phase != GamePhase.wave) {
      return;
    }

    final completedRound = _roundIndex + 1;
    _gold += _waves[_roundIndex].clearRewardGold;
    _roundIndex++;
    _completedRounds = completedRound;
    if (_roundIndex >= _waves.length) {
      _rewardOptions.clear();
      _finishRun(GamePhase.success);
      unawaited(_saveRoundCheckpoint());
    } else if (_gemRewardGenerator.shouldOfferReward(completedRound)) {
      _phase = GamePhase.reward;
      _rewardOptions
        ..clear()
        ..addAll(_gemRewardGenerator.generateOptions());
      unawaited(_saveRoundCheckpoint());
    } else {
      _phase = GamePhase.preparation;
      _rewardOptions.clear();
      unawaited(_saveRoundCheckpoint());
    }
    _publish();
  }

  void _finishRun(GamePhase resultPhase) {
    if (_phase == GamePhase.success || _phase == GamePhase.failure) {
      return;
    }

    final success = resultPhase == GamePhase.success;
    _completedRounds = success ? _waves.length : _roundIndex;
    _progression.finishRun(completedRounds: _completedRounds, success: success);
    _phase = resultPhase;
  }

  void _requestLocalSave({bool immediate = false}) {
    _saveScheduler.requestSave(immediate: immediate);
  }

  Future<void> saveNow() async {
    await _saveScheduler.flush();
  }

  Future<void> _saveRoundCheckpoint() async {
    final data = _buildSaveData();
    await _writeLocalSaveData(data);
    try {
      await _onlineSaveRepository.saveRoundCheckpoint(data);
    } on Object {
      // 온라인 저장은 아직 선택 기능이므로 게임 진행을 막지 않는다.
    }
  }

  Future<void> _writeLocalSave() {
    return _writeLocalSaveData(_buildSaveData());
  }

  Future<void> _writeLocalSaveData(GameSaveData data) async {
    try {
      await _saveRepository.save(data);
    } on Object {
      // 로컬 저장 실패는 다음 저장 기회에 재시도한다.
    }
  }

  GameSaveData _buildSaveData() {
    final savedPhase = _phase == GamePhase.restored
        ? _restoredPhase ?? GamePhase.preparation
        : _phase;
    return GameSaveData(
      version: GameSaveData.currentVersion,
      savedAtMillis: DateTime.now().millisecondsSinceEpoch,
      gold: _gold,
      nexusHp: _nexusHp,
      roundIndex: _roundIndex,
      completedRounds: _completedRounds,
      phase: savedPhase,
      progression: _progression.toSaveData(),
      gemInventory: Map.unmodifiable(_gemInventory),
      rewardOptions: List.unmodifiable(_rewardOptions),
      turrets: [for (final turret in _turrets.values) turret.toSaveData()],
      enemies: [
        for (final enemy in enemies)
          if (!enemy.isDead) enemy.toSaveData(),
      ],
      spawnQueue: _waveSpawner.toSaveData(),
    );
  }

  void _restoreFromSaveData(GameSaveData data) {
    _progression.restoreFromSaveData(data.progression);
    _clearActiveCombat();
    for (final turret in _turrets.values.toList()) {
      turret.removeFromParent();
    }
    _turrets.clear();
    _gemInventory
      ..clear()
      ..addEntries(data.gemInventory.entries.where((entry) => entry.value > 0));
    _rewardOptions
      ..clear()
      ..addAll(data.rewardOptions);

    if (!data.hasActiveRun) {
      _gold = _initialGold;
      _nexusHp = _maxNexusHp;
      _roundIndex = 0;
      _completedRounds = 0;
      _phase = GamePhase.preparation;
      _restoredPhase = null;
      return;
    }

    _gold = math.max(0, data.gold);
    _nexusHp = data.nexusHp.clamp(0, _maxNexusHp).toInt();
    _roundIndex = data.roundIndex.clamp(0, _waves.length - 1).toInt();
    _completedRounds = data.completedRounds.clamp(0, _waves.length).toInt();
    _selectedTurretType = TurretType.arrow;
    _selectedBuildTurretType = null;
    _selectedBuildPoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;

    for (final savedTurret in data.turrets) {
      final definition = demoTurrets[savedTurret.type];
      if (definition == null || !_map.contains(savedTurret.point)) {
        continue;
      }
      final turret = TurretComponent(
        gridPoint: savedTurret.point,
        definition: definition,
        game: this,
        center: _centerOf(savedTurret.point),
        tileSize: _tileSize,
      )..restoreFromSaveData(savedTurret);
      _turrets[savedTurret.point] = turret;
      add(turret);
    }

    for (final savedEnemy in data.enemies) {
      final definition = demoEnemies[savedEnemy.type];
      if (definition == null || savedEnemy.hp <= 0) {
        continue;
      }
      final enemy = EnemyComponent(
        definition: definition,
        maxHp: savedEnemy.maxHp > 0
            ? savedEnemy.maxHp
            : scaledEnemyMaxHp(definition, _waves[_roundIndex].round),
        path: _worldPath,
        game: this,
      )..restoreFromSaveData(savedEnemy);
      enemies.add(enemy);
      add(enemy);
    }
    _waveSpawner.restoreFromSaveData(data.spawnQueue);

    final restoredPhase = data.phase == GamePhase.restored
        ? GamePhase.preparation
        : data.phase;
    if (restoredPhase != GamePhase.wave) {
      _phase = restoredPhase;
      _restoredPhase = null;
      return;
    }

    _phase = GamePhase.restored;
    _restoredPhase = restoredPhase;
  }

  void _applyGemStatuses(
    TurretComponent owner,
    EnemyComponent enemy, {
    double damageScale = 1,
  }) {
    if (owner.definition.attackTags.contains(AttackTag.damageOverTime)) {
      final burnMultiplier = _damageMultiplier(owner, enemy);
      enemy.applyBurn(
        damagePerSecond:
            owner.damage *
            0.35 *
            damageScale *
            burnMultiplier *
            owner.damageOverTimeDamageMultiplier,
        duration: 2 * owner.damageOverTimeDurationMultiplier,
        damageMultiplier: burnMultiplier,
      );
    }
  }

  double _damageMultiplier(
    TurretComponent owner,
    EnemyComponent enemy, {
    Set<AttackTag> extraTags = const {},
  }) {
    return enemy.definition.resistanceProfile.multiplierFor(
      family: owner.definition.damageFamily,
      tags: {...owner.definition.attackTags, ...extraTags},
    );
  }

  void _publish() {
    final nextWave = _roundIndex < _waves.length
        ? _waves[_roundIndex]
        : _waves.last;
    final selectedTurret = _selectedTurretPoint == null
        ? null
        : _turrets[_selectedTurretPoint];
    final nextWaveEnemyTypes = <EnemyType>[];
    for (final group in nextWave.groups) {
      if (!nextWaveEnemyTypes.contains(group.enemyType)) {
        nextWaveEnemyTypes.add(group.enemyType);
      }
    }
    snapshotNotifier.value = GameSnapshot(
      gold: _gold,
      nexusHp: _nexusHp,
      maxNexusHp: _maxNexusHp,
      round: math.min(_roundIndex + 1, _waves.length),
      maxRound: _waves.length,
      phase: _phase,
      restoredPhase: _phase == GamePhase.restored ? _restoredPhase : null,
      selectedTurretType: _selectedTurretType,
      previewText: nextWave.previewText,
      rewardOptions: List.unmodifiable(_rewardOptions),
      gemInventory: Map.unmodifiable(_gemInventory),
      selectedBuildPoint: _selectedBuildPoint,
      selectedBuildTurretType: _selectedBuildTurretType,
      selectedTurretPoint: _selectedTurretPoint,
      selectedTurretName: selectedTurret?.definition.name,
      selectedTurretGems: List.unmodifiable(
        selectedTurret?.equippedGems ?? const [],
      ),
      selectedTurretGemSlotIndex:
          selectedTurret == null || _selectedTurretGemSlotIndex == null
          ? null
          : _selectedTurretGemSlotIndex!
                .clamp(0, selectedTurret.slotLimit - 1)
                .toInt(),
      selectedTurretSlotLimit: selectedTurret?.slotLimit ?? 0,
      selectedTurretHasLinkUpgrade: selectedTurret?.hasNextLinkUpgrade ?? false,
      selectedTurretCanUpgradeLink: selectedTurret?.canUpgradeLink ?? false,
      selectedTurretLinkUpgradeCost: selectedTurret?.linkUpgradeCost ?? 0,
      selectedTurretNextSlotLimit: selectedTurret?.nextSlotLimit ?? 0,
      selectedTurretLinkUpgradeRequiredLevel:
          selectedTurret?.linkUpgradeRequiredLevel ?? 0,
      selectedTurretLevel: selectedTurret?.level ?? 0,
      selectedTurretMaxLevel: selectedTurret?.maxLevel ?? 0,
      selectedTurretCanLevelUp: selectedTurret?.canLevelUp ?? false,
      selectedTurretLevelUpCost: selectedTurret?.levelUpCost ?? 0,
      selectedTurretDamage: selectedTurret?.damage ?? 0,
      selectedTurretRange: selectedTurret?.range ?? 0,
      selectedTurretAttackRate: selectedTurret?.attackRate ?? 0,
      nextWaveEnemyTypes: List.unmodifiable(nextWaveEnemyTypes),
      speedMultiplier: _speedMultiplier,
      runes: _progression.runes,
      lastRunRuneReward: _progression.lastRunRuneReward,
      completedRounds: _completedRounds,
      startingGoldUpgradeLevel: _progression.startingGoldUpgradeLevel,
      startingGoldUpgradeCost: _progression.startingGoldUpgradeCost,
      canUpgradeStartingGold: _progression.canUpgradeStartingGold,
      nexusHpUpgradeLevel: _progression.nexusHpUpgradeLevel,
      nexusHpUpgradeCost: _progression.nexusHpUpgradeCost,
      canUpgradeNexusHp: _progression.canUpgradeNexusHp,
    );
  }
}
