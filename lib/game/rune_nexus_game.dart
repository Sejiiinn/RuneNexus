import 'dart:async';
import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart' as gestures;
import 'package:flutter/material.dart';

import '../data/definitions/demo_enemy_data.dart';
import '../data/definitions/demo_gem_data.dart';
import '../data/definitions/demo_run_upgrade_data.dart';
import '../data/definitions/demo_stage_data.dart';
import '../data/definitions/demo_turret_data.dart';
import '../data/save/game_save_data.dart';
import '../data/save/local_save_repository.dart';
import '../data/save/online_save_repository.dart';
import '../data/save/save_repository.dart';
import '../domain/combat/auto_start_mode.dart';
import '../domain/combat/game_phase.dart';
import '../domain/combat/run_panel_tab.dart';
import '../domain/enemy/enemy_scaling.dart';
import '../domain/enemy/enemy_type.dart';
import '../domain/gem/gem_equip_rules.dart';
import '../domain/gem/gem_type.dart';
import '../domain/map/grid_point.dart';
import '../domain/map/map_definition.dart';
import '../domain/map/tile_type.dart';
import '../domain/run_upgrade/run_upgrade_type.dart';
import '../domain/stage/stage_definition.dart';
import '../domain/turret/attack_tag.dart';
import '../domain/turret/turret_type.dart';
import '../domain/wave/wave_definition.dart';
import 'components/chain_projectile_component.dart';
import 'components/damage_number_component.dart';
import 'components/death_burst_effect_component.dart';
import 'components/enemy_component.dart';
import 'components/grid_component.dart';
import 'components/impact_effect_component.dart';
import 'components/projectile_component.dart';
import 'components/turret_component.dart';
import 'game_snapshot.dart';
import 'rendering/status_effect_sprite_cache.dart';
import 'rendering/turret_shape_renderer.dart';
import 'systems/gem_reward_generator.dart';
import 'systems/run_progression.dart';
import 'systems/save_scheduler.dart';
import 'systems/wave_spawner.dart';

class RuneNexusGame extends FlameGame with TapCallbacks, ScaleDetector {
  static const double _chainDamageMultiplier = 0.5;
  static const double _burnDamagePerSecondScale = 0.5;
  static const double _burnDurationSeconds = 2;
  static const double burnDamagePerSecondScale = _burnDamagePerSecondScale;
  static const double burnDurationSeconds = _burnDurationSeconds;
  static const double _designTileSize = 48;
  static const double _chainJumpRange = 88;
  static const double _minBoardZoom = 1;
  static const double _maxBoardZoom = 2.1;
  static const double _nexusHitAlertDuration = 0.65;
  static const double _portalAlertDuration = 0.55;
  static const double _postPortalAlertSpawnDelay = 0.15;
  static const double _combatStatsPublishInterval = 0.2;

  static List<StageDefinition> _buildInitialStages({
    StageDefinition? stage,
    List<StageDefinition>? stages,
    MapDefinition? map,
    List<WaveDefinition>? waves,
  }) {
    if (stages != null && stages.isNotEmpty) {
      return stages;
    }
    if (stage != null) {
      return [stage];
    }
    if (map != null || waves != null) {
      final customMap = map ?? demoMap;
      final customWaves = waves ?? demoWaves;
      return List<StageDefinition>.generate(
        RunProgression.maxStageCount,
        (index) => StageDefinition(
          id: index + 1,
          name: 'Stage ${index + 1}',
          map: customMap,
          waves: customWaves,
        ),
      );
    }
    return demoStages;
  }

  static StageDefinition _initialStage({
    StageDefinition? stage,
    required List<StageDefinition> stages,
    MapDefinition? map,
    List<WaveDefinition>? waves,
  }) {
    if (stage != null) {
      return stage;
    }
    if (map != null || waves != null) {
      return stages.first;
    }
    return stages.first;
  }

  static GameSnapshot _initialSnapshot(StageDefinition stage) {
    final firstWave = stage.waves.first;
    return GameSnapshot(
      gold: RunProgression.baseInitialGold,
      nexusHp: RunProgression.baseNexusHp,
      maxNexusHp: RunProgression.baseNexusHp,
      round: 1,
      maxRound: stage.waves.length,
      phase: GamePhase.preparation,
      restoredPhase: null,
      hasStageProgress: false,
      placedTurretCount: 0,
      currentStageNumber: stage.id,
      unlockedStageCount: 1,
      bestRoundsByStage: const {},
      clearedStageNumbers: const {},
      selectedTurretType: TurretType.arrow,
      selectedRunPanelTab: RunPanelTab.turrets,
      previewText: firstWave.previewText,
      rewardOptions: const [],
      gemInventory: const {},
      selectedBuildPoint: null,
      selectedBuildTurretType: null,
      selectedPortalPoint: null,
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
      selectedTurretRefundGold: 0,
      selectedTurretDamage: 0,
      selectedTurretRange: 0,
      selectedTurretAttackRate: 0,
      selectedTurretBurnDamagePerSecond: 0,
      selectedTurretBurnDuration: 0,
      selectedTurretDamageDealt: 0,
      selectedTurretDirectDamageDealt: 0,
      selectedTurretSplashDamageDealt: 0,
      selectedTurretChainDamageDealt: 0,
      selectedTurretBurnDamageDealt: 0,
      topDamageTurretName: null,
      topDamageTurretDamageDealt: 0,
      nextWaveEnemyTypes: _enemyTypesFor(firstWave),
      nextWaveEnemyCounts: _enemyCountsFor(firstWave),
      autoStartMode: AutoStartMode.pauseEachRound,
      speedMultiplier: 1,
      killGoldFractionWallet: 0,
      runUpgradeLevels: const {},
      towerDamageRunBonusRate: 0,
      killGoldRunBonusRate: 0,
      waveClearGoldRunBonus: 0,
      runes: 0,
      lastRunRuneReward: 0,
      projectedFailureRuneReward: 0,
      lastRunPreviousBestRound: 0,
      lastRunWasNewBestRound: false,
      lastRunUnlockedStageNumber: null,
      completedRounds: 0,
      startingGoldUpgradeLevel: 0,
      startingGoldUpgradeCost: RunProgression.startingGoldUpgradeBaseCost,
      canUpgradeStartingGold: false,
      nexusHpUpgradeLevel: 0,
      nexusHpUpgradeCost: RunProgression.nexusHpUpgradeBaseCost,
      canUpgradeNexusHp: false,
      supplyUpgradeLevel: 0,
      supplyUpgradeCost: RunProgression.supplyUpgradeBaseCost,
      canUpgradeSupply: false,
      waveClearGoldProgressionBonus: 0,
      fireTrainingUpgradeLevel: 0,
      fireTrainingUpgradeCost: RunProgression.fireTrainingUpgradeBaseCost,
      canUpgradeFireTraining: false,
      fireTrainingDamageBonusRate: 0,
    );
  }

  static List<EnemyType> _enemyTypesFor(WaveDefinition wave) {
    final types = <EnemyType>[];
    for (final group in wave.groups) {
      if (!types.contains(group.enemyType)) {
        types.add(group.enemyType);
      }
    }
    return List.unmodifiable(types);
  }

  static Map<EnemyType, int> _enemyCountsFor(WaveDefinition wave) {
    final counts = <EnemyType, int>{};
    for (final group in wave.groups) {
      counts[group.enemyType] = (counts[group.enemyType] ?? 0) + group.count;
    }
    return Map.unmodifiable(counts);
  }

  RuneNexusGame({
    StageDefinition? stage,
    List<StageDefinition>? stages,
    MapDefinition? map,
    List<WaveDefinition>? waves,
    SaveRepository? saveRepository,
    OnlineSaveRepository? onlineSaveRepository,
  }) : _saveRepository = saveRepository ?? createDefaultSaveRepository(),
       _onlineSaveRepository =
           onlineSaveRepository ?? const NoopOnlineSaveRepository() {
    _stages = List.unmodifiable(
      _buildInitialStages(stage: stage, stages: stages, map: map, waves: waves),
    );
    _activeStage = _initialStage(
      stage: stage,
      stages: _stages,
      map: map,
      waves: waves,
    );
    _currentStageNumber = _activeStage.id;
    snapshotNotifier = ValueNotifier(_initialSnapshot(_activeStage));
  }

  late final List<StageDefinition> _stages;
  late StageDefinition _activeStage;
  final SaveRepository _saveRepository;
  final OnlineSaveRepository _onlineSaveRepository;
  late final ValueNotifier<GameSnapshot> snapshotNotifier;
  final ValueNotifier<bool> readyNotifier = ValueNotifier(false);
  final ValueNotifier<Object?> loadErrorNotifier = ValueNotifier(null);

  MapDefinition get _map => _activeStage.map;
  List<WaveDefinition> get _waves => _activeStage.waves;

  final List<EnemyComponent> enemies = [];
  final Map<GridPoint, TurretComponent> _turrets = {};
  final Map<GemType, int> _gemInventory = {};
  final Map<RunUpgradeType, int> _runUpgradeLevels = {};
  final List<GemType> _rewardOptions = [];
  final WaveSpawner _waveSpawner = WaveSpawner();
  final GemRewardGenerator _gemRewardGenerator = GemRewardGenerator();
  final RunProgression _progression = RunProgression();
  late final SaveScheduler _saveScheduler = SaveScheduler(
    saveNow: _writeLocalSave,
  );

  late GridComponent _gridComponent;
  late final StatusEffectSpriteCache statusEffectSprites;
  bool _statusEffectSpritesReady = false;
  bool _gridComponentReady = false;
  late Vector2 _origin;
  late double _tileSize;
  late List<Vector2> _worldPath;
  bool _boardConfigured = false;

  int _gold = RunProgression.baseInitialGold;
  int _nexusHp = RunProgression.baseNexusHp;
  late int _currentStageNumber;
  int _completedRounds = 0;
  int _lastRunPreviousBestRound = 0;
  bool _lastRunWasNewBestRound = false;
  int? _lastRunUnlockedStageNumber;
  int _roundIndex = 0;
  GamePhase _phase = GamePhase.preparation;
  GamePhase? _restoredPhase;
  TurretType _selectedTurretType = TurretType.arrow;
  RunPanelTab _selectedRunPanelTab = RunPanelTab.turrets;
  TurretType? _selectedBuildTurretType;
  GridPoint? _selectedBuildPoint;
  GridPoint? _selectedPortalPoint;
  GridPoint? _selectedTurretPoint;
  int? _selectedTurretGemSlotIndex;
  AutoStartMode _autoStartMode = AutoStartMode.pauseEachRound;
  double _speedMultiplier = 1;
  double _killGoldFractionWallet = 0;
  double _boardZoom = _minBoardZoom;
  Vector2 _boardOffset = Vector2.zero();
  double _scaleStartZoom = _minBoardZoom;
  double _trackpadStartZoom = _minBoardZoom;
  int? _dragPointer;
  Vector2? _lastDragPosition;
  double _dragDistance = 0;
  bool _suppressNextTap = false;
  double _nexusHitAlertTimer = 0;
  double _portalAlertTimer = 0;
  bool _savedDataLoaded = false;
  bool _menuSaveDataLoaded = false;
  int _savedTurretCountForMenu = 0;
  GameSaveData? _pendingFullSaveData;
  double _combatStatsPublishTimer = 0;
  bool _combatStatsPublishPending = false;

  bool get isWaveRunning => _phase == GamePhase.wave;
  double get boardDistanceScale =>
      _boardConfigured ? _tileSize / _designTileSize : 1;
  bool isTurretSelected(GridPoint point) => _selectedTurretPoint == point;

  int get _initialGold => _progression.initialGold;
  int get _maxNexusHp => _progression.maxNexusHp;
  bool get _canEditBoard =>
      _phase == GamePhase.preparation || _phase == GamePhase.wave;
  double get towerDamageRunMultiplier =>
      1 + _towerDamageRunBonusRate + _progression.fireTrainingDamageBonusRate;

  double get _towerDamageRunBonusRate =>
      _runUpgradeLevel(RunUpgradeType.towerDamage) *
      demoRunUpgrades[RunUpgradeType.towerDamage]!.effectPerLevel;
  double get _killGoldRunBonusRate =>
      _runUpgradeLevel(RunUpgradeType.killGold) *
      demoRunUpgrades[RunUpgradeType.killGold]!.effectPerLevel;
  int get _waveClearGoldRunBonus =>
      (_runUpgradeLevel(RunUpgradeType.waveGold) *
              demoRunUpgrades[RunUpgradeType.waveGold]!.effectPerLevel)
          .round();

  int _runUpgradeLevel(RunUpgradeType type) {
    final definition = demoRunUpgrades[type];
    final level = _runUpgradeLevels[type] ?? 0;
    return definition == null ? 0 : level.clamp(0, definition.maxLevel).toInt();
  }

  @override
  Color backgroundColor() => const Color(0xFF07111D);

  @override
  Future<void> onLoad() async {
    try {
      await super.onLoad();
      _prepareStatusEffectSprites();
      _configureBoard();
      _gridComponent = GridComponent(
        map: _map,
        origin: _origin,
        tileSize: _tileSize,
      );
      _gridComponentReady = true;
      add(_gridComponent);
      try {
        await _restoreSavedDataIfNeeded();
      } on Object {
        // 저장 복원 실패 폴백
      }
      _syncBoardComponents();
      _publish();
      readyNotifier.value = true;
    } on Object catch (error) {
      loadErrorNotifier.value = error;
      rethrow;
    }
  }

  Future<void> prepareForAppStart() async {
    try {
      _prepareStatusEffectSprites();
      await prepareSavedStateForMenu().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {},
      );
      readyNotifier.value = true;
    } on Object catch (error) {
      loadErrorNotifier.value = error;
      rethrow;
    }
  }

  Future<void> prepareSavedStateForMenu() async {
    if (isLoaded || _savedDataLoaded || _menuSaveDataLoaded) {
      return;
    }
    _menuSaveDataLoaded = true;
    final savedData = await _saveRepository.load();
    _pendingFullSaveData = savedData;
    if (savedData != null) {
      _restoreMenuStateFromSaveData(savedData);
    }
    _publish();
  }

  void _prepareStatusEffectSprites() {
    if (_statusEffectSpritesReady) {
      return;
    }
    statusEffectSprites = StatusEffectSpriteCache.create();
    _statusEffectSpritesReady = true;
  }

  @override
  void onRemove() {
    if (_statusEffectSpritesReady) {
      statusEffectSprites.dispose();
    }
    _saveScheduler.dispose();
    readyNotifier.dispose();
    loadErrorNotifier.dispose();
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
    _updateVisualAlerts(dt);
    if (_phase == GamePhase.restored) {
      super.update(0);
      return;
    }
    final scaledDt = dt * _speedMultiplier;
    super.update(scaledDt);
    _updateCombatStatsPublish(dt);
    if (_phase != GamePhase.wave) {
      _maybeAutoStartNextWave();
      return;
    }

    _updateWaveSpawns(scaledDt);
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
      _selectedPortalPoint = null;
      _selectedTurretType = turret.definition.type;
      _selectedRunPanelTab = RunPanelTab.turrets;
      _selectedTurretPoint = point;
      _selectedTurretGemSlotIndex = null;
      _publish();
      return;
    }
    if (_map.tileAt(point) == TileType.spawn) {
      _selectedBuildPoint = null;
      _selectedBuildTurretType = null;
      _selectedPortalPoint = point;
      _selectedTurretPoint = null;
      _selectedTurretGemSlotIndex = null;
      _selectedRunPanelTab = RunPanelTab.turrets;
      _publish();
      return;
    }
    if (_canEditBoard && _map.canBuildAt(point)) {
      _selectedBuildPoint = point;
      _selectedPortalPoint = null;
      _selectedRunPanelTab = RunPanelTab.turrets;
      _selectedTurretPoint = null;
      _selectedTurretGemSlotIndex = null;
      _publish();
      return;
    }

    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedPortalPoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;
    _publish();
  }

  void previewOrBuildSelectedTile(TurretType type) {
    _selectedTurretType = type;
    _selectedRunPanelTab = RunPanelTab.turrets;
    _selectedBuildTurretType = type;
    _selectedPortalPoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;
    final point = _selectedBuildPoint;
    if (point == null) {
      _publish();
      return;
    }

    _publish();
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
    _selectedRunPanelTab = RunPanelTab.turrets;
    _publish();
  }

  void selectRunPanelTab(RunPanelTab tab) {
    if (_selectedRunPanelTab == tab) {
      return;
    }
    _selectedRunPanelTab = tab;
    _publish();
  }

  void buyRunUpgrade(RunUpgradeType type) {
    if (!_canEditBoard) {
      return;
    }
    final definition = demoRunUpgrades[type];
    if (definition == null) {
      return;
    }
    final currentLevel = _runUpgradeLevel(type);
    if (currentLevel >= definition.maxLevel) {
      return;
    }
    final cost = definition.costForLevel(currentLevel);
    if (_gold < cost) {
      return;
    }

    _gold -= cost;
    _runUpgradeLevels[type] = currentLevel + 1;
    _selectedRunPanelTab = RunPanelTab.upgrades;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void setSpeedMultiplier(double value) {
    _speedMultiplier = value;
    _publish();
  }

  void setAutoStartMode(AutoStartMode mode) {
    if (_autoStartMode == mode) {
      return;
    }
    _autoStartMode = mode;
    _publish();
    _requestLocalSave(immediate: true);
    _maybeAutoStartNextWave();
  }

  void startNextWave() {
    if (_phase != GamePhase.preparation || _roundIndex >= _waves.length) {
      return;
    }

    _phase = GamePhase.wave;
    _selectedTurretPoint = null;
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedPortalPoint = null;
    _selectedTurretGemSlotIndex = null;
    _triggerPortalAlert();
    final initialSpawnDelay = _boardConfigured
        ? (_portalAlertDuration + _postPortalAlertSpawnDelay) * _speedMultiplier
        : 0.0;
    _waveSpawner.start(_waves[_roundIndex], initialDelay: initialSpawnDelay);
    _publish();
    _requestLocalSave(immediate: true);
  }

  void startStage(int stageNumber) {
    restartDemo(stageNumber: stageNumber);
  }

  void restartDemo({int? stageNumber}) {
    final targetStageNumber = stageNumber == null
        ? null
        : _clampedStageNumber(stageNumber);
    _clearActiveCombat();

    for (final turret in _turrets.values.toList()) {
      turret.removeFromParent();
    }
    _turrets.clear();
    if (targetStageNumber != null) {
      _selectStage(targetStageNumber);
    }
    _gemInventory.clear();
    _runUpgradeLevels.clear();
    _rewardOptions.clear();
    _killGoldFractionWallet = 0;
    _pendingFullSaveData = null;
    _savedTurretCountForMenu = 0;
    _menuSaveDataLoaded = true;

    _gold = _initialGold;
    _nexusHp = _maxNexusHp;
    _roundIndex = 0;
    _completedRounds = 0;
    _lastRunPreviousBestRound = 0;
    _lastRunWasNewBestRound = false;
    _lastRunUnlockedStageNumber = null;
    _progression.resetLastRunReward();
    _phase = GamePhase.preparation;
    _selectedTurretType = TurretType.arrow;
    _selectedRunPanelTab = RunPanelTab.turrets;
    _selectedBuildTurretType = null;
    _selectedBuildPoint = null;
    _selectedPortalPoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;
    _restoredPhase = null;
    _publish();
    _requestLocalSave(immediate: true);
  }

  Future<void> settleCurrentRunAsFailure() async {
    if (_phase == GamePhase.success || _phase == GamePhase.failure) {
      return;
    }
    _finishRun(GamePhase.failure);
    _publish();
    await _saveRoundCheckpoint();
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

  Future<void> discardRestoredRun() async {
    if (_phase != GamePhase.restored) {
      return;
    }

    await settleCurrentRunAsFailure();
    restartDemo();
  }

  void upgradeStartingGoldProgression() {
    if (!_progression.upgradeStartingGold()) {
      return;
    }

    if (_phase == GamePhase.preparation && _turrets.isEmpty) {
      _gold += RunProgression.startingGoldPerUpgradeLevel;
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

  void upgradeSupplyProgression() {
    if (!_progression.upgradeSupply()) {
      return;
    }

    _publish();
    _requestLocalSave(immediate: true);
  }

  void upgradeFireTrainingProgression() {
    if (!_progression.upgradeFireTraining()) {
      return;
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
    _selectedPortalPoint = null;
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
    _selectedPortalPoint = null;
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

  void refundSelectedTurret() {
    if (!_canEditBoard) {
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

    _gold += turret.refundGold;
    for (final gem in turret.equippedGems) {
      _gemInventory[gem] = (_gemInventory[gem] ?? 0) + 1;
    }
    for (final enemy in enemies) {
      enemy.clearBurnSource(point);
    }
    _turrets.remove(point);
    turret.removeFromParent();
    _selectedTurretPoint = null;
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
      final splashRadiusSquared = owner.splashRadius * owner.splashRadius;
      for (final enemy in enemies.toList()) {
        final dx = enemy.position.x - hitPosition.x;
        final dy = enemy.position.y - hitPosition.y;
        if (enemy.isMounted &&
            !enemy.isDead &&
            dx * dx + dy * dy <= splashRadiusSquared) {
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
      _applyAttackStatuses(owner, enemy);
      showDamageNumber(
        position: enemy.position.clone(),
        damage: damage,
        color: owner.definition.color,
        damageMultiplier: multiplier,
      );
      enemy.showHitFlash(owner.definition.color);
      final actualDamage = enemy.receiveDamage(damage);
      _recordTurretDamage(
        owner,
        actualDamage,
        identical(enemy, target)
            ? TurretDamageKind.direct
            : TurretDamageKind.splash,
      );
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
    _applyAttackStatuses(owner, target, damageScale: statusScale);
    showDamageNumber(
      position: target.position.clone(),
      damage: adjustedDamage,
      color: chainColorFor(owner),
      damageMultiplier: multiplier,
    );
    target.showHitFlash(chainColorFor(owner));
    final actualDamage = target.receiveDamage(adjustedDamage);
    _recordTurretDamage(owner, actualDamage, TurretDamageKind.chain);
  }

  void resolveCenteredAreaAttack({
    required TurretComponent owner,
    required Iterable<EnemyComponent> targets,
  }) {
    final impacted = targets
        .where((enemy) => !enemy.isDead && owner.isEnemyBodyInRange(enemy))
        .toList();
    if (impacted.isEmpty) {
      return;
    }

    add(
      ImpactEffectComponent(
        position: owner.position.clone(),
        color: owner.definition.color,
        style: ImpactEffectStyle.frost,
        radius: owner.range,
      ),
    );

    for (final enemy in impacted) {
      final multiplier = _damageMultiplier(owner, enemy);
      final damage = owner.damage * multiplier;
      _applyAttackStatuses(owner, enemy);
      showDamageNumber(
        position: enemy.position.clone(),
        damage: damage,
        color: owner.definition.color,
        damageMultiplier: multiplier,
      );
      enemy.showHitFlash(owner.definition.color);
      final actualDamage = enemy.receiveDamage(damage);
      _recordTurretDamage(owner, actualDamage, TurretDamageKind.splash);
    }
  }

  void recordTurretDamage(GridPoint? sourceTurretPoint, double damage) {
    if (sourceTurretPoint == null || damage <= 0) {
      return;
    }
    TurretComponent? turret = _turrets[sourceTurretPoint];
    if (turret == null) {
      for (final child in children.whereType<TurretComponent>()) {
        if (child.gridPoint == sourceTurretPoint) {
          turret = child;
          break;
        }
      }
    }
    if (turret == null) {
      return;
    }
    _recordTurretDamage(turret, damage, TurretDamageKind.burn);
  }

  void _recordTurretDamage(
    TurretComponent turret,
    double damage,
    TurretDamageKind kind,
  ) {
    if (damage <= 0 || !_isActiveTurret(turret)) {
      return;
    }
    turret.recordDamageDealt(damage, kind);
    _requestCombatStatsPublish();
  }

  void _requestCombatStatsPublish() {
    if (_phase != GamePhase.wave) {
      _publish();
      return;
    }
    _combatStatsPublishPending = true;
  }

  void _updateCombatStatsPublish(double dt) {
    if (!_combatStatsPublishPending) {
      return;
    }
    if (_phase != GamePhase.wave) {
      _publish();
      return;
    }
    _combatStatsPublishTimer += dt;
    if (_combatStatsPublishTimer >= _combatStatsPublishInterval) {
      _publish();
    }
  }

  Color chainColorFor(TurretComponent owner) {
    return Color.lerp(owner.definition.color, const Color(0xFF02070D), 0.38)!;
  }

  void _showImpact({
    required TurretComponent owner,
    required Vector2 position,
  }) {
    final splashRadius = owner.splashRadius;
    final style = splashRadius > 0
        ? ImpactEffectStyle.blast
        : switch (owner.definition.type) {
            TurretType.arrow => ImpactEffectStyle.spark,
            TurretType.cannon => ImpactEffectStyle.blast,
            TurretType.magic => ImpactEffectStyle.flame,
            TurretType.frost => ImpactEffectStyle.frost,
          };
    final radius = splashRadius > 0
        ? splashRadius
              .clamp(18 * boardDistanceScale, double.infinity)
              .toDouble()
        : switch (owner.definition.type) {
                TurretType.arrow => 11.0,
                TurretType.cannon => 22.0,
                TurretType.magic => 16.0,
                TurretType.frost => 18.0,
              } *
              boardDistanceScale;
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
    final jumpRange = _chainJumpRange * boardDistanceScale;
    final jumpRangeSquared = jumpRange * jumpRange;
    EnemyComponent? firstTarget;
    EnemyComponent? secondTarget;
    var firstDistanceSquared = double.infinity;
    var secondDistanceSquared = double.infinity;

    for (final enemy in enemies) {
      if (!enemy.isMounted || enemy.isDead || excluded.contains(enemy)) {
        continue;
      }
      final dx = enemy.position.x - source.position.x;
      final dy = enemy.position.y - source.position.y;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared > jumpRangeSquared) {
        continue;
      }
      if (distanceSquared < firstDistanceSquared) {
        secondDistanceSquared = firstDistanceSquared;
        secondTarget = firstTarget;
        firstDistanceSquared = distanceSquared;
        firstTarget = enemy;
      } else if (distanceSquared < secondDistanceSquared) {
        secondDistanceSquared = distanceSquared;
        secondTarget = enemy;
      }
    }

    for (final enemy in [firstTarget, secondTarget].nonNulls) {
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
    if (!enemy.isMounted && !enemies.contains(enemy)) {
      return;
    }
    final baseReward = enemy.definition.rewardGold;
    final bonusReward = baseReward * _killGoldRunBonusRate;
    final wholeBonus = bonusReward.floor();
    _killGoldFractionWallet += bonusReward - wholeBonus;
    final walletGold = _killGoldFractionWallet.floor();
    if (walletGold > 0) {
      _killGoldFractionWallet -= walletGold;
    }
    _gold += baseReward + wholeBonus + walletGold;
    enemies.remove(enemy);
    add(
      DeathBurstEffectComponent(
        position: enemy.position.clone(),
        color: enemy.definition.color,
        type: enemy.definition.type,
        radius: enemy.size.x,
      ),
    );
    enemy.removeFromParent();
    _publish();
  }

  void enemyReachedCore(EnemyComponent enemy) {
    if (!enemy.isMounted) {
      return;
    }
    _triggerNexusHitAlert();
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
    _boardConfigured = true;
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
    _nexusHitAlertTimer = 0;
    _portalAlertTimer = 0;
    _syncVisualAlerts();

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
    _drawBuildSelection(canvas);
    canvas.restore();
    _drawNexusScreenAlert(canvas);
  }

  void _drawBuildSelection(Canvas canvas) {
    final point = _selectedBuildPoint;
    final portalPoint = _selectedPortalPoint;
    if (portalPoint != null) {
      final rect = Rect.fromLTWH(
        _origin.x + portalPoint.x * _tileSize + 2,
        _origin.y + portalPoint.y * _tileSize + 2,
        _tileSize - 4,
        _tileSize - 4,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xCCB16DFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    if (point == null) {
      return;
    }

    final center = _centerOf(point);
    final selectedType = _selectedBuildTurretType;
    if (selectedType != null) {
      _drawBuildGhost(canvas, center, selectedType);
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
  }

  void _drawBuildGhost(Canvas canvas, Vector2 center, TurretType type) {
    final definition = demoTurrets[type]!;
    final ghostCenter = Offset(center.x, center.y);
    final rangeFill = Paint()
      ..color = definition.color.withValues(alpha: 0.09)
      ..style = PaintingStyle.fill;
    final rangeStroke = Paint()
      ..color = definition.color.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final range = definition.range * boardDistanceScale;
    canvas.drawCircle(ghostCenter, range, rangeFill);
    canvas.drawCircle(ghostCenter, range, rangeStroke);

    final ghostSize = _tileSize * 0.72;
    final ghostBounds = Rect.fromCenter(
      center: ghostCenter,
      width: ghostSize,
      height: ghostSize,
    );
    canvas.saveLayer(
      ghostBounds.inflate(_tileSize * 0.16),
      Paint()..color = const Color(0xAAFFFFFF),
    );
    canvas.translate(ghostBounds.left, ghostBounds.top);
    drawTurretShape(
      canvas,
      size: Size(ghostSize, ghostSize),
      type: type,
      color: definition.color,
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
      maxHp: scaledEnemyMaxHp(
        definition,
        _waves[_roundIndex].round,
        stageNumber: _currentStageNumber,
      ),
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
    _gold +=
        _waves[_roundIndex].clearRewardGold +
        _progression.waveClearGoldBonus +
        _waveClearGoldRunBonus;
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

  void _maybeAutoStartNextWave() {
    if (_phase != GamePhase.preparation || _roundIndex >= _waves.length) {
      return;
    }
    if (_autoStartMode == AutoStartMode.pauseEachRound) {
      return;
    }
    final nextWaveHasBoss = _waves[_roundIndex].groups.any(
      (group) => group.enemyType == EnemyType.boss,
    );
    if (_autoStartMode == AutoStartMode.skipBossRounds && nextWaveHasBoss) {
      return;
    }
    startNextWave();
  }

  void _updateVisualAlerts(double dt) {
    _nexusHitAlertTimer = math.max(0, _nexusHitAlertTimer - dt);
    _portalAlertTimer = math.max(0, _portalAlertTimer - dt);
    _syncVisualAlerts();
  }

  void _triggerNexusHitAlert() {
    _nexusHitAlertTimer = _nexusHitAlertDuration;
    _syncVisualAlerts();
  }

  void _triggerPortalAlert() {
    _portalAlertTimer = _portalAlertDuration;
    _syncVisualAlerts();
  }

  void _syncVisualAlerts() {
    if (!_gridComponentReady) {
      return;
    }
    _gridComponent.nexusHitAlert =
        (_nexusHitAlertTimer / _nexusHitAlertDuration).clamp(0.0, 1.0);
    _gridComponent.portalAlert = (_portalAlertTimer / _portalAlertDuration)
        .clamp(0.0, 1.0);
  }

  void _drawNexusScreenAlert(Canvas canvas) {
    final alert = (_nexusHitAlertTimer / _nexusHitAlertDuration).clamp(
      0.0,
      1.0,
    );
    if (alert <= 0) {
      return;
    }
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final fadeWidth = (math.min(size.x, size.y) * 0.12)
        .clamp(26.0, 54.0)
        .toDouble();
    final edgeColor = const Color(0xFFFF3D3D).withValues(alpha: 0.22 * alert);
    const transparent = Color(0x00FF3D3D);

    void drawEdge(Rect edgeRect, Alignment begin, Alignment end) {
      canvas.drawRect(
        edgeRect,
        Paint()
          ..shader = LinearGradient(
            begin: begin,
            end: end,
            colors: [edgeColor, transparent],
            stops: const [0.0, 1.0],
          ).createShader(edgeRect),
      );
    }

    drawEdge(
      Rect.fromLTWH(0, 0, size.x, fadeWidth),
      Alignment.topCenter,
      Alignment.bottomCenter,
    );
    drawEdge(
      Rect.fromLTWH(0, size.y - fadeWidth, size.x, fadeWidth),
      Alignment.bottomCenter,
      Alignment.topCenter,
    );
    drawEdge(
      Rect.fromLTWH(0, 0, fadeWidth, size.y),
      Alignment.centerLeft,
      Alignment.centerRight,
    );
    drawEdge(
      Rect.fromLTWH(size.x - fadeWidth, 0, fadeWidth, size.y),
      Alignment.centerRight,
      Alignment.centerLeft,
    );
  }

  void _finishRun(GamePhase resultPhase) {
    if (_phase == GamePhase.success || _phase == GamePhase.failure) {
      return;
    }

    final success = resultPhase == GamePhase.success;
    _completedRounds = success ? _waves.length : _roundIndex;
    final previousBestRound = _progression.bestRoundForStage(
      _currentStageNumber,
    );
    final previousUnlockedStageCount = _progression.unlockedStageCount;
    _progression.finishRun(
      completedRounds: _completedRounds,
      success: success,
      stageNumber: _currentStageNumber,
    );
    _lastRunPreviousBestRound = previousBestRound;
    _lastRunWasNewBestRound = _completedRounds > previousBestRound;
    _lastRunUnlockedStageNumber =
        _progression.unlockedStageCount > previousUnlockedStageCount
        ? _progression.unlockedStageCount
        : null;
    _phase = resultPhase;
  }

  int _clampedStageNumber(int stageNumber) {
    final maxConfiguredStage = _stages.fold<int>(
      1,
      (maxId, stage) => math.max(maxId, stage.id),
    );
    final maxSelectableStage = math.min(
      _progression.unlockedStageCount,
      maxConfiguredStage,
    );
    return stageNumber.clamp(1, maxSelectableStage).toInt();
  }

  StageDefinition _stageForNumber(int stageNumber) {
    for (final stage in _stages) {
      if (stage.id == stageNumber) {
        return stage;
      }
    }
    return _stages.first;
  }

  void _selectStage(int stageNumber) {
    final nextStage = _stageForNumber(stageNumber);
    if (_activeStage.id == nextStage.id) {
      _currentStageNumber = nextStage.id;
      return;
    }
    _activeStage = nextStage;
    _currentStageNumber = nextStage.id;
    if (isLoaded) {
      _rebuildGridComponent();
    }
  }

  void _rebuildGridComponent() {
    _configureBoard();
    _gridComponentReady = false;
    _gridComponent.removeFromParent();
    _gridComponent = GridComponent(
      map: _map,
      origin: _origin,
      tileSize: _tileSize,
    );
    _gridComponentReady = true;
    add(_gridComponent);
    _syncVisualAlerts();
    _syncBoardComponents();
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

  Future<void> _restoreSavedDataIfNeeded() async {
    if (_savedDataLoaded) {
      return;
    }
    _savedDataLoaded = true;
    final savedData = _pendingFullSaveData ?? await _saveRepository.load();
    _pendingFullSaveData = null;
    _savedTurretCountForMenu = 0;
    if (savedData != null) {
      _restoreFromSaveData(savedData);
    }
  }

  GameSaveData _buildSaveData() {
    final savedPhase = _phase == GamePhase.restored
        ? _restoredPhase ?? GamePhase.preparation
        : _phase;
    final pendingSave = !_savedDataLoaded ? _pendingFullSaveData : null;
    return GameSaveData(
      version: GameSaveData.currentVersion,
      savedAtMillis: DateTime.now().millisecondsSinceEpoch,
      gold: _gold,
      nexusHp: _nexusHp,
      stageNumber: _currentStageNumber,
      roundIndex: _roundIndex,
      completedRounds: _completedRounds,
      phase: savedPhase,
      autoStartMode: _autoStartMode,
      progression: _progression.toSaveData(),
      runUpgradeLevels: Map.unmodifiable(_runUpgradeLevels),
      killGoldFractionWallet: _killGoldFractionWallet,
      gemInventory: Map.unmodifiable(_gemInventory),
      rewardOptions: List.unmodifiable(_rewardOptions),
      turrets:
          pendingSave?.turrets ??
          [for (final turret in _turrets.values) turret.toSaveData()],
      enemies:
          pendingSave?.enemies ??
          [
            for (final enemy in enemies)
              if (!enemy.isDead) enemy.toSaveData(),
          ],
      spawnQueue: pendingSave?.spawnQueue ?? _waveSpawner.toSaveData(),
    );
  }

  void _restoreMenuStateFromSaveData(GameSaveData data) {
    _autoStartMode = data.autoStartMode;
    _progression.restoreFromSaveData(data.progression);
    _restoreRunUpgradeState(data);
    _gemInventory
      ..clear()
      ..addEntries(data.gemInventory.entries.where((entry) => entry.value > 0));
    _rewardOptions
      ..clear()
      ..addAll(data.rewardOptions);
    _savedTurretCountForMenu = data.turrets.length;

    if (!data.hasActiveRun) {
      _savedTurretCountForMenu = 0;
      _selectStage(_clampedStageNumber(data.stageNumber));
      _gold = _initialGold;
      _nexusHp = _maxNexusHp;
      _roundIndex = 0;
      _completedRounds = 0;
      _runUpgradeLevels.clear();
      _killGoldFractionWallet = 0;
      _lastRunPreviousBestRound = 0;
      _lastRunWasNewBestRound = false;
      _lastRunUnlockedStageNumber = null;
      _selectedTurretType = TurretType.arrow;
      _selectedRunPanelTab = RunPanelTab.turrets;
      _selectedBuildTurretType = null;
      _selectedBuildPoint = null;
      _selectedPortalPoint = null;
      _selectedTurretPoint = null;
      _selectedTurretGemSlotIndex = null;
      _phase = GamePhase.preparation;
      _restoredPhase = null;
      return;
    }
    _gold = math.max(0, data.gold);
    _selectStage(_clampedStageNumber(data.stageNumber));
    _nexusHp = data.nexusHp.clamp(0, _maxNexusHp).toInt();
    _roundIndex = data.roundIndex.clamp(0, _waves.length - 1).toInt();
    _completedRounds = data.completedRounds.clamp(0, _waves.length).toInt();
    _lastRunPreviousBestRound = 0;
    _lastRunWasNewBestRound = false;
    _lastRunUnlockedStageNumber = null;
    _selectedTurretType = TurretType.arrow;
    _selectedRunPanelTab = RunPanelTab.turrets;
    _selectedBuildTurretType = null;
    _selectedBuildPoint = null;
    _selectedPortalPoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;

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

  void _restoreFromSaveData(GameSaveData data) {
    _autoStartMode = data.autoStartMode;
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
      _selectStage(_clampedStageNumber(data.stageNumber));
      _gold = _initialGold;
      _nexusHp = _maxNexusHp;
      _roundIndex = 0;
      _completedRounds = 0;
      _runUpgradeLevels.clear();
      _killGoldFractionWallet = 0;
      _lastRunPreviousBestRound = 0;
      _lastRunWasNewBestRound = false;
      _lastRunUnlockedStageNumber = null;
      _phase = GamePhase.preparation;
      _restoredPhase = null;
      return;
    }

    _restoreRunUpgradeState(data);
    _gold = math.max(0, data.gold);
    _selectStage(_clampedStageNumber(data.stageNumber));
    _nexusHp = data.nexusHp.clamp(0, _maxNexusHp).toInt();
    _roundIndex = data.roundIndex.clamp(0, _waves.length - 1).toInt();
    _completedRounds = data.completedRounds.clamp(0, _waves.length).toInt();
    _lastRunPreviousBestRound = 0;
    _lastRunWasNewBestRound = false;
    _lastRunUnlockedStageNumber = null;
    _selectedTurretType = TurretType.arrow;
    _selectedRunPanelTab = RunPanelTab.turrets;
    _selectedBuildTurretType = null;
    _selectedBuildPoint = null;
    _selectedPortalPoint = null;
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
            : scaledEnemyMaxHp(
                definition,
                _waves[_roundIndex].round,
                stageNumber: _currentStageNumber,
              ),
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

  void _restoreRunUpgradeState(GameSaveData data) {
    _runUpgradeLevels
      ..clear()
      ..addEntries(
        data.runUpgradeLevels.entries
            .where((entry) {
              final definition = demoRunUpgrades[entry.key];
              return definition != null && entry.value > 0;
            })
            .map((entry) {
              final maxLevel = demoRunUpgrades[entry.key]!.maxLevel;
              return MapEntry(
                entry.key,
                entry.value.clamp(0, maxLevel).toInt(),
              );
            }),
      );
    _killGoldFractionWallet = data.killGoldFractionWallet
        .clamp(0.0, 0.999999)
        .toDouble();
  }

  void _applyAttackStatuses(
    TurretComponent owner,
    EnemyComponent enemy, {
    double damageScale = 1,
  }) {
    if (owner.definition.attackTags.contains(AttackTag.damageOverTime)) {
      final burnMultiplier = _damageMultiplier(owner, enemy);
      enemy.applyBurn(
        damagePerSecond:
            owner.damage *
            _burnDamagePerSecondScale *
            damageScale *
            burnMultiplier *
            owner.damageOverTimeDamageMultiplier,
        duration: _burnDurationSeconds * owner.damageOverTimeDurationMultiplier,
        damageMultiplier: burnMultiplier,
        sourceTurretPoint: _isActiveTurret(owner) ? owner.gridPoint : null,
      );
    }
    if (owner.definition.slowDuration > 0 &&
        owner.definition.slowMultiplier < 1) {
      enemy.applySlow(
        multiplier: owner.definition.slowMultiplier,
        duration: owner.definition.slowDuration,
      );
    }
  }

  bool _isActiveTurret(TurretComponent turret) {
    return _turrets[turret.gridPoint] == turret;
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
    _combatStatsPublishPending = false;
    _combatStatsPublishTimer = 0;
    final nextWave = _roundIndex < _waves.length
        ? _waves[_roundIndex]
        : _waves.last;
    final selectedTurret = _selectedTurretPoint == null
        ? null
        : _turrets[_selectedTurretPoint];
    final selectedTurretBurnDamagePerSecond =
        selectedTurret != null &&
            selectedTurret.definition.attackTags.contains(
              AttackTag.damageOverTime,
            )
        ? selectedTurret.damage *
              _burnDamagePerSecondScale *
              selectedTurret.damageOverTimeDamageMultiplier
        : 0.0;
    final selectedTurretBurnDuration = selectedTurretBurnDamagePerSecond > 0
        ? _burnDurationSeconds *
              selectedTurret!.damageOverTimeDurationMultiplier
        : 0.0;
    final topDamageTurret = _turrets.values.fold<TurretComponent?>(null, (
      current,
      turret,
    ) {
      if (current == null || turret.damageDealt > current.damageDealt) {
        return turret;
      }
      return current;
    });
    final nextWaveEnemyTypes = _enemyTypesFor(nextWave);
    final nextWaveEnemyCounts = _enemyCountsFor(nextWave);
    final hasStageProgress =
        _phase == GamePhase.wave ||
        _phase == GamePhase.reward ||
        _phase == GamePhase.restored ||
        _roundIndex > 0 ||
        _completedRounds > 0 ||
        _turrets.isNotEmpty ||
        enemies.isNotEmpty ||
        !_waveSpawner.isEmpty ||
        _runUpgradeLevels.isNotEmpty ||
        _killGoldFractionWallet > 0 ||
        _gemInventory.isNotEmpty ||
        _rewardOptions.isNotEmpty ||
        _gold != _initialGold ||
        _nexusHp != _maxNexusHp;
    snapshotNotifier.value = GameSnapshot(
      gold: _gold,
      nexusHp: _nexusHp,
      maxNexusHp: _maxNexusHp,
      round: math.min(_roundIndex + 1, _waves.length),
      maxRound: _waves.length,
      phase: _phase,
      restoredPhase: _phase == GamePhase.restored ? _restoredPhase : null,
      hasStageProgress: hasStageProgress,
      placedTurretCount: _turrets.length,
      currentStageNumber: _currentStageNumber,
      unlockedStageCount: _progression.unlockedStageCount,
      bestRoundsByStage: Map.unmodifiable(_progression.bestRoundsByStage),
      clearedStageNumbers: Set.unmodifiable(_progression.clearedStageNumbers),
      selectedTurretType: _selectedTurretType,
      selectedRunPanelTab: _selectedRunPanelTab,
      previewText: nextWave.previewText,
      rewardOptions: List.unmodifiable(_rewardOptions),
      gemInventory: Map.unmodifiable(_gemInventory),
      selectedBuildPoint: _selectedBuildPoint,
      selectedBuildTurretType: _selectedBuildTurretType,
      selectedPortalPoint: _selectedPortalPoint,
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
      selectedTurretRefundGold: selectedTurret?.refundGold ?? 0,
      selectedTurretDamage: selectedTurret?.damage ?? 0,
      selectedTurretRange: selectedTurret?.range ?? 0,
      selectedTurretAttackRate: selectedTurret?.attackRate ?? 0,
      selectedTurretBurnDamagePerSecond: selectedTurretBurnDamagePerSecond,
      selectedTurretBurnDuration: selectedTurretBurnDuration,
      selectedTurretDamageDealt: selectedTurret?.damageDealt ?? 0,
      selectedTurretDirectDamageDealt: selectedTurret?.directDamageDealt ?? 0,
      selectedTurretSplashDamageDealt: selectedTurret?.splashDamageDealt ?? 0,
      selectedTurretChainDamageDealt: selectedTurret?.chainDamageDealt ?? 0,
      selectedTurretBurnDamageDealt: selectedTurret?.burnDamageDealt ?? 0,
      topDamageTurretName:
          topDamageTurret == null || topDamageTurret.damageDealt <= 0
          ? null
          : topDamageTurret.definition.name,
      topDamageTurretDamageDealt: topDamageTurret?.damageDealt ?? 0,
      nextWaveEnemyTypes: List.unmodifiable(nextWaveEnemyTypes),
      nextWaveEnemyCounts: Map.unmodifiable(nextWaveEnemyCounts),
      autoStartMode: _autoStartMode,
      speedMultiplier: _speedMultiplier,
      killGoldFractionWallet: _killGoldFractionWallet,
      runUpgradeLevels: Map.unmodifiable(_runUpgradeLevels),
      towerDamageRunBonusRate: _towerDamageRunBonusRate,
      killGoldRunBonusRate: _killGoldRunBonusRate,
      waveClearGoldRunBonus: _waveClearGoldRunBonus,
      runes: _progression.runes,
      lastRunRuneReward: _progression.lastRunRuneReward,
      projectedFailureRuneReward: hasStageProgress
          ? _progression.runeRewardFor(_roundIndex, success: false)
          : 0,
      lastRunPreviousBestRound: _lastRunPreviousBestRound,
      lastRunWasNewBestRound: _lastRunWasNewBestRound,
      lastRunUnlockedStageNumber: _lastRunUnlockedStageNumber,
      completedRounds: _completedRounds,
      startingGoldUpgradeLevel: _progression.startingGoldUpgradeLevel,
      startingGoldUpgradeCost: _progression.startingGoldUpgradeCost,
      canUpgradeStartingGold: _progression.canUpgradeStartingGold,
      nexusHpUpgradeLevel: _progression.nexusHpUpgradeLevel,
      nexusHpUpgradeCost: _progression.nexusHpUpgradeCost,
      canUpgradeNexusHp: _progression.canUpgradeNexusHp,
      supplyUpgradeLevel: _progression.supplyUpgradeLevel,
      supplyUpgradeCost: _progression.supplyUpgradeCost,
      canUpgradeSupply: _progression.canUpgradeSupply,
      waveClearGoldProgressionBonus: _progression.waveClearGoldBonus,
      fireTrainingUpgradeLevel: _progression.fireTrainingUpgradeLevel,
      fireTrainingUpgradeCost: _progression.fireTrainingUpgradeCost,
      canUpgradeFireTraining: _progression.canUpgradeFireTraining,
      fireTrainingDamageBonusRate: _progression.fireTrainingDamageBonusRate,
    );
  }
}
