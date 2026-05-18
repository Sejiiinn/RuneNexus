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
import '../domain/enemy/enemy_resistance_profile.dart';
import '../domain/enemy/enemy_type.dart';
import '../domain/gem/gem_equip_rules.dart';
import '../domain/gem/gem_type.dart';
import '../domain/map/grid_point.dart';
import '../domain/map/map_definition.dart';
import '../domain/map/tile_type.dart';
import '../domain/run_upgrade/run_upgrade_type.dart';
import '../domain/stage/stage_definition.dart';
import '../domain/turret/attack_tag.dart';
import '../domain/turret/damage_family.dart';
import '../domain/turret/turret_trait_type.dart';
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

const _debugPanelEnabled = bool.fromEnvironment(
  'RUNE_NEXUS_DEBUG_PANEL',
  defaultValue: false,
);

class RuneNexusGame extends FlameGame with TapCallbacks, ScaleDetector {
  static const double _chainDamageMultiplier = 0.5;
  static const double _burnDamagePerSecondScale = 0.5;
  static const double _burnDurationSeconds = 2;
  static const double _ignitionBurstDurationRate = 0.3;
  static const double _chainIgnitionDurationRate = 0.6;
  static const int gemShardRewardFallbackAmount = 10;
  static const int gemChoicePurchaseCost = 20;
  static const int primaryTraitCost = 12;
  static const int primaryTraitRequiredLevel = 3;
  static const int secondaryTraitCost = 24;
  static const int secondaryTraitRequiredLevel = 7;
  static const double burnDamagePerSecondScale = _burnDamagePerSecondScale;
  static const double burnDurationSeconds = _burnDurationSeconds;
  static const double _designTileSize = 48;
  static const double _chainJumpRange = 88;
  static const double _minBoardZoom = 1;
  static const double _maxBoardZoom = 2.1;
  static const double _baseBoardPanRatio = 0.2;
  static const int _spaceStarCount = 86;
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
      gemShards: 0,
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
      availableTurretTypes: const [
        TurretType.arrow,
        TurretType.cannon,
        TurretType.magic,
        TurretType.frost,
      ],
      selectedTurretType: TurretType.arrow,
      selectedRunPanelTab: RunPanelTab.turrets,
      previewText: firstWave.previewText,
      rewardOptions: const [],
      isPurchasedGemReward: false,
      gemInventory: const {},
      gemCollection: const {},
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
      selectedTurretLevelUpPreviewActive: false,
      selectedTurretNextLevel: 0,
      selectedTurretNextDamage: 0,
      selectedTurretNextRange: 0,
      selectedTurretNextAttackRate: 0,
      selectedTurretNextBurnDamagePerSecond: 0,
      selectedTurretNextBurnDuration: 0,
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
      selectedTurretSupportsTraits: false,
      selectedTurretPrimaryTraitChoices: const [],
      selectedTurretSecondaryTraitChoices: const [],
      selectedTurretPrimaryTrait: null,
      selectedTurretSecondaryTrait: null,
      selectedTurretCanChoosePrimaryTrait: false,
      selectedTurretCanChooseSecondaryTrait: false,
      selectedTurretPrimaryTraitCost: primaryTraitCost,
      selectedTurretSecondaryTraitCost: secondaryTraitCost,
      selectedTurretPrimaryTraitRequiredLevel: primaryTraitRequiredLevel,
      selectedTurretSecondaryTraitRequiredLevel: secondaryTraitRequiredLevel,
      topDamageTurretName: null,
      topDamageTurretDamageDealt: 0,
      nextWaveEnemyTypes: _enemyTypesFor(firstWave),
      nextWaveEnemyCounts: _enemyCountsFor(firstWave),
      nextWaveClearRewardGold: firstWave.clearRewardGold,
      nextWaveKillRewardGold: _killRewardGoldFor(firstWave),
      nextWaveClearRewardGemShards: _roundClearGemShardRewardFor(1),
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
      lastRunUnlockedSniperTurret: false,
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
      killGoldUpgradeLevel: 0,
      killGoldUpgradeCost: RunProgression.killGoldUpgradeBaseCost,
      canUpgradeKillGold: false,
      killGoldProgressionBonusRate: 0,
      emergencySaleUpgradeLevel: 0,
      emergencySaleUpgradeCost: RunProgression.emergencySaleUpgradeBaseCost,
      canUpgradeEmergencySale: false,
      turretRefundPercent: RunProgression.baseTurretRefundPercent,
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

  static int _killRewardGoldFor(WaveDefinition wave) {
    var total = 0;
    for (final group in wave.groups) {
      total += demoEnemies[group.enemyType]!.rewardGold * group.count;
    }
    return total;
  }

  static int _roundClearGemShardRewardFor(int completedRound) {
    if (completedRound <= 0) {
      return 0;
    }
    if (completedRound <= 20) {
      return 1;
    }
    if (completedRound <= 40) {
      return 2;
    }
    return 3;
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
  final Set<EnemyComponent> _debugEnemies = {};
  final Map<GemType, int> _gemInventory = {};
  final Map<RunUpgradeType, int> _runUpgradeLevels = {};
  final List<GemType> _rewardOptions = [];
  final DamageNumberImageCache _damageNumberImages = DamageNumberImageCache();
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
  int _gemShards = 0;
  int _nexusHp = RunProgression.baseNexusHp;
  late int _currentStageNumber;
  int _completedRounds = 0;
  int _lastRunPreviousBestRound = 0;
  bool _lastRunWasNewBestRound = false;
  int? _lastRunUnlockedStageNumber;
  bool _lastRunUnlockedSniperTurret = false;
  int _roundIndex = 0;
  GamePhase _phase = GamePhase.preparation;
  bool _debugCombatActive = false;
  GamePhase? _restoredPhase;
  bool _isPurchasedGemReward = false;
  TurretType _selectedTurretType = TurretType.arrow;
  RunPanelTab _selectedRunPanelTab = RunPanelTab.turrets;
  TurretType? _selectedBuildTurretType;
  GridPoint? _selectedBuildPoint;
  GridPoint? _selectedPortalPoint;
  GridPoint? _selectedTurretPoint;
  GridPoint? _levelUpPreviewPoint;
  int? _selectedTurretGemSlotIndex;
  AutoStartMode _autoStartMode = AutoStartMode.pauseEachRound;
  double _speedMultiplier = 1;
  double _killGoldFractionWallet = 0;
  double _boardZoom = _minBoardZoom;
  Vector2 _boardOffset = Vector2.zero();
  double _scaleStartZoom = _minBoardZoom;
  Vector2 _scaleStartOffset = Vector2.zero();
  Vector2 _scaleStartFocal = Vector2.zero();
  double _trackpadStartZoom = _minBoardZoom;
  Vector2 _trackpadStartOffset = Vector2.zero();
  Vector2 _trackpadStartFocal = Vector2.zero();
  final Set<int> _boardPointers = {};
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
  bool _appResourcesDisposed = false;
  double _spaceTime = 0;

  bool get isWaveRunning => _phase == GamePhase.wave || _debugCombatActive;
  double get boardDistanceScale =>
      _boardConfigured ? _tileSize / _designTileSize : 1;
  bool isTurretSelected(GridPoint point) => _selectedTurretPoint == point;
  double? levelUpPreviewRangeFor(GridPoint point) {
    if (_levelUpPreviewPoint != point || _selectedTurretPoint != point) {
      return null;
    }
    final turret = _turrets[point];
    if (turret == null || !turret.canLevelUp || _gold < turret.levelUpCost) {
      return null;
    }
    return turret.rangeAtLevel(turret.level + 1);
  }

  int get _initialGold => _progression.initialGold;
  int get _maxNexusHp => _progression.maxNexusHp;
  int get turretRefundPercent => _progression.isStageCleared(2)
      ? _progression.turretRefundPercent
      : RunProgression.baseTurretRefundPercent;
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
  double get _killGoldProgressionBonusRate =>
      _progression.isStageCleared(2) ? _progression.killGoldBonusRate : 0;
  double get _killGoldTotalBonusRate =>
      _killGoldRunBonusRate + _killGoldProgressionBonusRate;
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

  void disposeAppResources() {
    if (_appResourcesDisposed) {
      return;
    }
    _appResourcesDisposed = true;
    if (_statusEffectSpritesReady) {
      statusEffectSprites.dispose();
      _statusEffectSpritesReady = false;
    }
    _damageNumberImages.dispose();
    _saveScheduler.dispose();
    readyNotifier.dispose();
    loadErrorNotifier.dispose();
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
    _spaceTime = (_spaceTime + dt) % 1200;
    _updateVisualAlerts(dt);
    if (_phase == GamePhase.restored) {
      super.update(0);
      return;
    }
    final scaledDt = dt * _speedMultiplier;
    super.update(scaledDt);
    _updateCombatStatsPublish(dt);
    if (_phase != GamePhase.wave) {
      if (!_debugCombatActive) {
        _maybeAutoStartNextWave();
      }
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
    _scaleStartOffset = _boardOffset.clone();
    _scaleStartFocal = info.eventPosition.widget.clone();
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    if (info.pointerCount < 2) {
      return;
    }
    final scale = (info.scale.global.x + info.scale.global.y) / 2;
    _zoomBoardAround(
      zoom: (_scaleStartZoom * scale).clamp(_minBoardZoom, _maxBoardZoom),
      focal: _scaleStartFocal,
      startZoom: _scaleStartZoom,
      startOffset: _scaleStartOffset,
      startFocal: _scaleStartFocal,
    );
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
      _clearBoardSelection(closePanel: true);
      _publish();
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

    _clearBoardSelection(closePanel: true);
    _publish();
  }

  void _clearBoardSelection({required bool closePanel}) {
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedPortalPoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;
    if (closePanel) {
      _selectedRunPanelTab = RunPanelTab.closed;
    }
  }

  void previewOrBuildSelectedTile(TurretType type) {
    if (!_isTurretUnlocked(type)) {
      return;
    }
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
    if (!_isTurretUnlocked(type)) {
      return;
    }

    _selectedTurretType = type;
    tryBuildTurret(point);
  }

  void selectTurretType(TurretType type) {
    if (!_isTurretUnlocked(type)) {
      return;
    }
    _selectedTurretType = type;
    _selectedRunPanelTab = RunPanelTab.turrets;
    _publish();
  }

  void selectRunPanelTab(RunPanelTab tab) {
    if (_selectedRunPanelTab == tab) {
      _selectedRunPanelTab = RunPanelTab.closed;
      _publish();
      return;
    }
    _selectedRunPanelTab = tab;
    _publish();
  }

  void purchaseGemChoice() {
    if (_phase != GamePhase.preparation || _gemShards < gemChoicePurchaseCost) {
      return;
    }

    _gemShards -= gemChoicePurchaseCost;
    _isPurchasedGemReward = true;
    _rewardOptions
      ..clear()
      ..addAll(
        _gemRewardGenerator.generateOptions(
          availableGems: _availableGemTypes(),
        ),
      );
    _phase = GamePhase.reward;
    _publish();
    _requestLocalSave(immediate: true);
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
    _gemShards = 0;
    _runUpgradeLevels.clear();
    _rewardOptions.clear();
    _isPurchasedGemReward = false;
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
    _lastRunUnlockedSniperTurret = false;
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

  void suspendCurrentRunForMenu() {
    if (_phase != GamePhase.wave) {
      return;
    }
    _phase = GamePhase.restored;
    _restoredPhase = GamePhase.wave;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void continueRestoredRun() {
    if (_phase != GamePhase.restored) {
      return;
    }

    _phase = _restoredPhase ?? GamePhase.preparation;
    _restoredPhase = null;
    resumeEngine();
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

  void upgradeKillGoldProgression() {
    if (!_progression.isStageCleared(2)) {
      return;
    }
    if (!_progression.upgradeKillGold()) {
      return;
    }

    _publish();
    _requestLocalSave(immediate: true);
  }

  void upgradeEmergencySaleProgression() {
    if (!_progression.isStageCleared(2)) {
      return;
    }
    if (!_progression.upgradeEmergencySale()) {
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

  void debugAddGemShards(int amount) {
    if (!_debugPanelEnabled) {
      return;
    }
    if (amount <= 0) {
      return;
    }

    _gemShards += amount;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void debugSpawnEnemy(EnemyType type) {
    if (!_debugPanelEnabled) {
      return;
    }
    if (_phase != GamePhase.preparation && _phase != GamePhase.wave) {
      return;
    }
    if (!demoEnemies.containsKey(type) || _worldPath.length < 2) {
      return;
    }

    _debugCombatActive = true;
    _spawnEnemy(type, debugSpawn: true);
    _triggerPortalAlert();
    _publish();
  }

  void debugOpenGemReward() {
    if (!_debugPanelEnabled) {
      return;
    }

    _clearActiveCombat();
    _phase = GamePhase.reward;
    _isPurchasedGemReward = false;
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedPortalPoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;
    _completedRounds = math.max(_completedRounds, _roundIndex + 1);
    _seedDebugGemInventory();
    _rewardOptions
      ..clear()
      ..addAll(
        _gemRewardGenerator.generateOptions(
          availableGems: _availableGemTypes(),
        ),
      );
    _publish();
  }

  void debugPreparePrimaryTrait() {
    if (!_debugPanelEnabled) {
      return;
    }

    final turret = _debugEnsureTraitTurret(
      targetLevel: primaryTraitRequiredLevel,
    );
    if (turret == null) {
      return;
    }
    _gemShards = math.max(_gemShards, primaryTraitCost);
    _publish();
    _requestLocalSave(immediate: true);
  }

  void debugPrepareSecondaryTrait() {
    if (!_debugPanelEnabled) {
      return;
    }

    final turret = _debugEnsureTraitTurret(
      targetLevel: secondaryTraitRequiredLevel,
    );
    if (turret == null) {
      return;
    }
    turret.choosePrimaryTrait(TurretTraitType.lightweightBarrel);
    _gemShards = math.max(_gemShards, secondaryTraitCost);
    _publish();
    _requestLocalSave(immediate: true);
  }

  void debugPrepareBossWave() {
    if (!_debugPanelEnabled) {
      return;
    }

    final bossRoundIndex = _waves.indexWhere(
      (wave) => wave.groups.any((group) => group.enemyType == EnemyType.boss),
    );
    if (bossRoundIndex < 0) {
      return;
    }

    _clearActiveCombat();
    _roundIndex = bossRoundIndex;
    _phase = GamePhase.preparation;
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedPortalPoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void tryBuildTurret(GridPoint point) {
    if (!_canEditBoard) {
      return;
    }
    if (!_isTurretUnlocked(_selectedTurretType)) {
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

    _gemInventory[type] = (_gemInventory[type] ?? 0) + 1;
    _rewardOptions.clear();
    _isPurchasedGemReward = false;
    _phase = GamePhase.preparation;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void selectRewardGemShards() {
    if (_phase != GamePhase.reward || _isPurchasedGemReward) {
      return;
    }

    _gemShards += gemShardRewardFallbackAmount;
    _rewardOptions.clear();
    _isPurchasedGemReward = false;
    _phase = GamePhase.preparation;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void grantGem(GemType type) {
    _gemInventory[type] = (_gemInventory[type] ?? 0) + 1;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void _seedDebugGemInventory() {
    const seeds = {
      GemType.attackSpeed: 1,
      GemType.range: 2,
      GemType.physicalDamage: 1,
      GemType.lightWeapon: 1,
    };

    for (final entry in seeds.entries) {
      _gemInventory[entry.key] = math.max(
        _gemInventory[entry.key] ?? 0,
        entry.value,
      );
    }
  }

  TurretComponent? _debugEnsureTraitTurret({required int targetLevel}) {
    _clearActiveCombat();
    _phase = GamePhase.preparation;
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedPortalPoint = null;
    _selectedTurretGemSlotIndex = null;
    _selectedRunPanelTab = RunPanelTab.gems;

    MapEntry<GridPoint, TurretComponent>? entry;
    for (final candidate in _turrets.entries) {
      if (candidate.value.supportsTraits) {
        entry = candidate;
        break;
      }
    }
    if (entry == null) {
      final point = _firstEmptyBuildPoint();
      if (point == null || !_boardConfigured) {
        return null;
      }
      final turret = TurretComponent(
        gridPoint: point,
        definition: demoTurrets[TurretType.arrow]!,
        game: this,
        center: _centerOf(point),
        tileSize: _tileSize,
      );
      _turrets[point] = turret;
      add(turret);
      entry = MapEntry(point, turret);
    }

    final turret = entry.value;
    while (turret.level < targetLevel && turret.upgradeLevel()) {}
    _selectedTurretType = TurretType.arrow;
    _selectedTurretPoint = entry.key;
    _gold = math.max(_gold, 500);
    return turret;
  }

  GridPoint? _firstEmptyBuildPoint() {
    for (var y = 0; y < _map.rows; y++) {
      for (var x = 0; x < _map.columns; x++) {
        final point = GridPoint(x, y);
        if (_map.canBuildAt(point) && !_turrets.containsKey(point)) {
          return point;
        }
      }
    }
    return null;
  }

  void selectSelectedTurretGemSlot(int slotIndex) {
    final point = _selectedTurretPoint;
    if (point == null) {
      return;
    }
    final turret = _turrets[point];
    if (turret == null || !turret.canEquipGemAt(slotIndex)) {
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
    if (!turret.canEquipGemAt(slotIndex)) {
      return;
    }
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
    if (_levelUpPreviewPoint == point &&
        (!turret.canLevelUp || _gold < turret.levelUpCost)) {
      _levelUpPreviewPoint = null;
    }
    _publish();
    _requestLocalSave(immediate: true);
  }

  void previewOrLevelUpSelectedTurret() {
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

    if (_levelUpPreviewPoint == point) {
      levelUpSelectedTurret();
      return;
    }

    _levelUpPreviewPoint = point;
    _publish();
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
    _selectedTurretGemSlotIndex = _defaultGemSlotIndex(turret);
    _publish();
    _requestLocalSave(immediate: true);
  }

  void chooseSelectedTurretPrimaryTrait(TurretTraitType trait) {
    if (!_canEditBoard || _gemShards < primaryTraitCost) {
      return;
    }

    final point = _selectedTurretPoint;
    if (point == null) {
      return;
    }
    final turret = _turrets[point];
    if (turret == null || !turret.canChoosePrimaryTrait) {
      return;
    }

    if (!turret.choosePrimaryTrait(trait)) {
      return;
    }
    _gemShards -= primaryTraitCost;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void chooseSelectedTurretSecondaryTrait(TurretTraitType trait) {
    if (!_canEditBoard || _gemShards < secondaryTraitCost) {
      return;
    }

    final point = _selectedTurretPoint;
    if (point == null) {
      return;
    }
    final turret = _turrets[point];
    if (turret == null || !turret.canChooseSecondaryTrait) {
      return;
    }

    if (!turret.chooseSecondaryTrait(trait)) {
      return;
    }
    _gemShards -= secondaryTraitCost;
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
    final slots = turret.equippedGemSlots;
    for (var index = 0; index < turret.slotLimit; index++) {
      if (index >= slots.length || slots[index] == null) {
        return index;
      }
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
    final text = damage.round().toString();
    final feedback = _damageFeedbackFor(damageMultiplier);
    final size = Vector2(78, 28);
    add(
      DamageNumberComponent(
        position: position,
        textImage: _damageNumberImages.imageFor(
          text: text,
          color: color,
          feedback: feedback,
          size: size,
        ),
        motion: motion,
        feedback: feedback,
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
    _trackpadStartOffset = _boardOffset.clone();
    _trackpadStartFocal = Vector2(
      event.localPosition.dx,
      event.localPosition.dy,
    );
  }

  void handleTrackpadZoomUpdate(gestures.PointerPanZoomUpdateEvent event) {
    _zoomBoardAround(
      zoom: (_trackpadStartZoom * event.scale).clamp(
        _minBoardZoom,
        _maxBoardZoom,
      ),
      focal: _trackpadStartFocal,
      startZoom: _trackpadStartZoom,
      startOffset: _trackpadStartOffset,
      startFocal: _trackpadStartFocal,
    );
  }

  void handleBoardPointerDown(gestures.PointerDownEvent event) {
    _boardPointers.add(event.pointer);
    if (_boardPointers.length != 1) {
      _dragPointer = null;
      _lastDragPosition = null;
      _dragDistance = 0;
      return;
    }

    _dragPointer = event.pointer;
    _lastDragPosition = Vector2(event.localPosition.dx, event.localPosition.dy);
    _dragDistance = 0;
  }

  void handleBoardPointerMove(gestures.PointerMoveEvent event) {
    if (_boardPointers.length != 1 || _dragPointer != event.pointer) {
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
    _boardPointers.remove(event.pointer);
    if (_dragPointer == event.pointer) {
      _dragPointer = null;
      _lastDragPosition = null;
      _dragDistance = 0;
    }
  }

  void handleBoardPointerCancel(gestures.PointerCancelEvent event) {
    _boardPointers.remove(event.pointer);
    if (_dragPointer == event.pointer) {
      _dragPointer = null;
      _lastDragPosition = null;
      _dragDistance = 0;
    }
  }

  void _moveBoardBy(Vector2 delta) {
    _boardOffset = _clampBoardOffset(_boardOffset + delta);
  }

  void resolveProjectileHit({
    required TurretComponent owner,
    required EnemyComponent target,
    required Vector2 hitPosition,
  }) {
    final criticalMultiplier = owner.rollCriticalHit()
        ? owner.criticalDamageMultiplier
        : 1.0;
    final impacted = <EnemyComponent>{};
    if (owner.splashRadius > 0) {
      final splashRadiusSquared = owner.splashRadius * owner.splashRadius;
      for (final enemy in enemies.toList()) {
        final dx = enemy.position.x - hitPosition.x;
        final dy = enemy.position.y - hitPosition.y;
        if ((enemy.isMounted || enemies.contains(enemy)) &&
            !enemy.isDead &&
            dx * dx + dy * dy <= splashRadiusSquared) {
          impacted.add(enemy);
        }
      }
    } else if ((target.isMounted || enemies.contains(target)) &&
        !target.isDead) {
      impacted.add(target);
    }
    _showImpact(owner: owner, position: hitPosition);

    for (final enemy in impacted.toList()) {
      final ignitionBurstDamage = identical(enemy, target)
          ? _ignitionBurstDamage(owner, enemy)
          : 0.0;
      final traitMultiplier = identical(enemy, target)
          ? owner.registerDirectHitTraits(enemy)
          : 1.0;
      final baseDamage = identical(enemy, target)
          ? owner.damage * criticalMultiplier
          : owner.damage * owner.splashSecondaryDamageMultiplier;
      final multiplier = _damageMultiplier(owner, enemy);
      final damage = baseDamage * traitMultiplier * multiplier;
      _applyAttackStatuses(owner, enemy);
      enemy.showHitFlash(owner.definition.color);
      final actualDamage = enemy.receiveDamage(
        damage,
        burnTransfer: _burnTransferForHit(owner, enemy),
      );
      showDamageNumber(
        position: enemy.position.clone(),
        damage: actualDamage,
        color: owner.definition.color,
        damageMultiplier:
            multiplier * (identical(enemy, target) ? criticalMultiplier : 1),
      );
      _recordTurretDamage(
        owner,
        actualDamage,
        identical(enemy, target)
            ? TurretDamageKind.direct
            : TurretDamageKind.splash,
      );
      if (ignitionBurstDamage > 0 && !enemy.isDead) {
        enemy.showHitFlash(owner.definition.color);
        final actualBurstDamage = enemy.receiveDamage(
          ignitionBurstDamage,
          burnTransfer: _burnTransferForHit(owner, enemy),
        );
        showDamageNumber(
          position: enemy.position.clone(),
          damage: actualBurstDamage,
          color: owner.definition.color,
        );
        _recordTurretDamage(owner, actualBurstDamage, TurretDamageKind.direct);
      }
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
    target.showHitFlash(chainColorFor(owner));
    final actualDamage = target.receiveDamage(
      adjustedDamage,
      burnTransfer: _burnTransferForHit(owner, target),
    );
    showDamageNumber(
      position: target.position.clone(),
      damage: actualDamage,
      color: chainColorFor(owner),
      damageMultiplier: multiplier,
    );
    _recordTurretDamage(owner, actualDamage, TurretDamageKind.chain);
  }

  void resolveInstantHit({
    required TurretComponent owner,
    required EnemyComponent target,
    double criticalMultiplier = 1,
  }) {
    if ((!target.isMounted && !enemies.contains(target)) ||
        target.isDead ||
        !owner.isEnemyBodyInRange(target)) {
      return;
    }

    final impacted = <EnemyComponent>{target};
    if (owner.splashRadius > 0) {
      final splashRadiusSquared = owner.splashRadius * owner.splashRadius;
      for (final enemy in enemies.toList()) {
        final dx = enemy.position.x - target.position.x;
        final dy = enemy.position.y - target.position.y;
        if ((enemy.isMounted || enemies.contains(enemy)) &&
            !enemy.isDead &&
            dx * dx + dy * dy <= splashRadiusSquared) {
          impacted.add(enemy);
        }
      }
    }
    _showImpact(owner: owner, position: target.position.clone());

    for (final enemy in impacted.toList()) {
      final isPrimaryTarget = identical(enemy, target);
      final traitMultiplier = isPrimaryTarget
          ? owner.registerDirectHitTraits(enemy)
          : 1.0;
      final baseDamage = isPrimaryTarget
          ? owner.damage * criticalMultiplier
          : owner.damage * owner.splashSecondaryDamageMultiplier;
      final multiplier = _damageMultiplier(owner, enemy);
      final damage = baseDamage * traitMultiplier * multiplier;
      _applyAttackStatuses(owner, enemy);
      enemy.showHitFlash(owner.definition.color);
      final actualDamage = enemy.receiveDamage(
        damage,
        burnTransfer: _burnTransferForHit(owner, enemy),
      );
      showDamageNumber(
        position: enemy.position.clone(),
        damage: actualDamage,
        color: owner.definition.color,
        damageMultiplier:
            multiplier * (isPrimaryTarget ? criticalMultiplier : 1),
      );
      _recordTurretDamage(
        owner,
        actualDamage,
        isPrimaryTarget ? TurretDamageKind.direct : TurretDamageKind.splash,
      );
    }

    if (owner.hasGem(GemType.chain)) {
      _spawnChainProjectiles(owner: owner, source: target, excluded: impacted);
    }
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
      enemy.showHitFlash(owner.definition.color);
      final actualDamage = enemy.receiveDamage(
        damage,
        burnTransfer: _burnTransferForHit(owner, enemy),
      );
      showDamageNumber(
        position: enemy.position.clone(),
        damage: actualDamage,
        color: owner.definition.color,
        damageMultiplier: multiplier,
      );
      _recordTurretDamage(owner, actualDamage, TurretDamageKind.splash);
    }
  }

  void recordTurretDamage(GridPoint? sourceTurretPoint, double damage) {
    if (sourceTurretPoint == null || damage <= 0) {
      return;
    }
    final turret = _turretForPoint(sourceTurretPoint);
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
            TurretType.sniper => ImpactEffectStyle.spark,
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
                TurretType.sniper => 13.0,
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

  void enemyKilled(EnemyComponent enemy, {BurnTransferPayload? burnTransfer}) {
    if (!enemy.isMounted && !enemies.contains(enemy)) {
      return;
    }
    if (burnTransfer != null) {
      _spreadChainIgnition(source: enemy, burnTransfer: burnTransfer);
    }
    final isDebugEnemy = _debugEnemies.remove(enemy);
    for (final turret in _turrets.values) {
      turret.handleEnemyKilled(enemy);
    }
    if (!isDebugEnemy) {
      final baseReward = enemy.definition.rewardGold;
      final bonusReward = baseReward * _killGoldTotalBonusRate;
      final wholeBonus = bonusReward.floor();
      _killGoldFractionWallet += bonusReward - wholeBonus;
      final walletGold = _killGoldFractionWallet.floor();
      if (walletGold > 0) {
        _killGoldFractionWallet -= walletGold;
      }
      _gold += baseReward + wholeBonus + walletGold;
    }
    enemies.remove(enemy);
    _finishDebugCombatIfIdle();
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
    final isDebugEnemy = _debugEnemies.remove(enemy);
    if (!isDebugEnemy) {
      _nexusHp = math.max(0, _nexusHp - enemy.definition.coreDamage);
    }
    enemies.remove(enemy);
    _finishDebugCombatIfIdle();
    enemy.removeFromParent();

    if (!isDebugEnemy && _nexusHp <= 0) {
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

  void _finishDebugCombatIfIdle() {
    if (_debugCombatActive && _debugEnemies.isEmpty) {
      _debugCombatActive = false;
    }
  }

  void _configureBoard() {
    const topReservedHeight = 76.0;
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
      enemy.updateLayout(tileSize: _tileSize, newPath: _worldPath);
    }
  }

  void _clearActiveCombat() {
    for (final enemy in enemies.toList()) {
      enemy.removeFromParent();
    }
    enemies.clear();
    _debugEnemies.clear();
    _debugCombatActive = false;
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
    _drawSpaceBackground(canvas);
    canvas.save();
    _applyBoardZoom(canvas);
    super.render(canvas);
    _drawBuildSelection(canvas);
    canvas.restore();
    _drawNexusScreenAlert(canvas);
  }

  void _drawSpaceBackground(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0) {
      return;
    }

    final bounds = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF040913), Color(0xFF07111D), Color(0xFF02060C)],
        ).createShader(bounds),
    );

    final hazeCenter = Offset(size.x * 0.52, size.y * 0.18);
    canvas.drawCircle(
      hazeCenter,
      math.max(size.x, size.y) * 0.44,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFF1A4B66).withValues(alpha: 0.16),
                const Color(0xFF1A4B66).withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: hazeCenter,
                radius: math.max(size.x, size.y) * 0.44,
              ),
            ),
    );

    for (var i = 0; i < _spaceStarCount; i++) {
      final x = _starUnit(i, 1) * size.x;
      final y = _starUnit(i, 2) * size.y;
      final speed = 0.75 + _starUnit(i, 3) * 1.8;
      final phase = _starUnit(i, 4) * math.pi * 2;
      final pulse = (math.sin(_spaceTime * speed + phase) + 1) / 2;
      final baseAlpha = 0.16 + _starUnit(i, 5) * 0.24;
      final alpha = baseAlpha + pulse * (0.18 + _starUnit(i, 6) * 0.24);
      final radius = 0.55 + _starUnit(i, 7) * 1.05;
      final color = Color.lerp(
        const Color(0xFFC7F2FF),
        const Color(0xFFFFFFFF),
        _starUnit(i, 8),
      )!.withValues(alpha: alpha.clamp(0.0, 0.82));

      if (radius > 1.25 && pulse > 0.62) {
        canvas.drawCircle(
          Offset(x, y),
          radius * (2.2 + pulse),
          Paint()..color = color.withValues(alpha: alpha * 0.16),
        );
      }
      canvas.drawCircle(Offset(x, y), radius, Paint()..color = color);
    }
  }

  double _starUnit(int index, int salt) {
    final value = math.sin(index * 12.9898 + salt * 78.233) * 43758.5453;
    return value - value.floorToDouble();
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
    if (_boardZoom == _minBoardZoom && _boardOffset.length2 == 0) {
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
    if (_boardZoom == _minBoardZoom && _boardOffset.length2 == 0) {
      return position;
    }

    final center = _boardCenter();
    return center + (position - _boardOffset - center) / _boardZoom;
  }

  Vector2 _clampBoardOffset(Vector2 offset) {
    final limit = _boardPanLimit();
    return Vector2(
      offset.x.clamp(-limit.x, limit.x).toDouble(),
      offset.y.clamp(-limit.y, limit.y).toDouble(),
    );
  }

  Vector2 _boardPanLimit() {
    final boardWidth = _tileSize * _map.columns;
    final boardHeight = _tileSize * _map.rows;
    final zoomOverflow = math.max(0, _boardZoom - _minBoardZoom);
    final zoomPanX = boardWidth * zoomOverflow / 2;
    final zoomPanY = boardHeight * zoomOverflow / 2;
    final basePanX = math.max(_tileSize * 0.8, boardWidth * _baseBoardPanRatio);
    final basePanY = math.max(
      _tileSize * 1.8,
      boardHeight * _baseBoardPanRatio,
    );
    return Vector2(zoomPanX + basePanX, zoomPanY + basePanY);
  }

  @visibleForTesting
  Vector2 debugBoardPanLimit() => _boardPanLimit();

  void _zoomBoardAround({
    required double zoom,
    required Vector2 focal,
    required double startZoom,
    required Vector2 startOffset,
    required Vector2 startFocal,
  }) {
    final center = _boardCenter();
    final anchoredWorld =
        center + (startFocal - startOffset - center) / startZoom;
    _boardZoom = zoom;
    _boardOffset = _clampBoardOffset(
      focal - center - (anchoredWorld - center) * _boardZoom,
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

  void _spawnEnemy(EnemyType type, {bool debugSpawn = false}) {
    final definition = demoEnemies[type]!;
    final enemy = EnemyComponent(
      definition: definition,
      maxHp: scaledEnemyMaxHp(
        definition,
        _waves[_roundIndex].round,
        stageNumber: _currentStageNumber,
      ),
      maxShield: scaledEnemyMaxShield(
        definition,
        _waves[_roundIndex].round,
        stageNumber: _currentStageNumber,
      ),
      maxArmor: scaledEnemyMaxArmor(
        definition,
        _waves[_roundIndex].round,
        stageNumber: _currentStageNumber,
      ),
      path: _worldPath,
      game: this,
    );
    enemy.updateLayout(tileSize: _tileSize, newPath: _worldPath);
    enemies.add(enemy);
    if (debugSpawn) {
      _debugEnemies.add(enemy);
    }
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
    _gemShards += _roundClearGemShardRewardFor(completedRound);
    _roundIndex++;
    _completedRounds = completedRound;
    if (_roundIndex >= _waves.length) {
      _rewardOptions.clear();
      _finishRun(GamePhase.success);
      unawaited(_saveRoundCheckpoint());
    } else if (_gemRewardGenerator.shouldOfferReward(completedRound)) {
      _phase = GamePhase.reward;
      _isPurchasedGemReward = false;
      _rewardOptions
        ..clear()
        ..addAll(
          _gemRewardGenerator.generateOptions(
            availableGems: _availableGemTypes(),
          ),
        );
      unawaited(_saveRoundCheckpoint());
    } else {
      _phase = GamePhase.preparation;
      _rewardOptions.clear();
      _isPurchasedGemReward = false;
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
    final stageOneWasCleared = _progression.isStageCleared(1);
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
    _lastRunUnlockedSniperTurret =
        success && !stageOneWasCleared && _progression.isStageCleared(1);
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

  bool _isTurretUnlocked(TurretType type) {
    return _availableTurretTypes().contains(type);
  }

  List<TurretType> _availableTurretTypes() {
    final types = <TurretType>[
      TurretType.arrow,
      TurretType.cannon,
      TurretType.magic,
      TurretType.frost,
    ];
    if (_progression.isStageCleared(1)) {
      types.add(TurretType.sniper);
    }
    return types;
  }

  List<GemType> _availableGemTypes() {
    return GemType.values
        .where(
          (type) => type != GemType.aimSpeed || _progression.isStageCleared(1),
        )
        .toList();
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
      gemShards: _gemShards,
      nexusHp: _nexusHp,
      stageNumber: _currentStageNumber,
      mapSignature: pendingSave?.hasActiveRun == true
          ? pendingSave?.mapSignature
          : _mapSignature(_map),
      roundIndex: _roundIndex,
      completedRounds: _completedRounds,
      phase: savedPhase,
      autoStartMode: _autoStartMode,
      progression: _progression.toSaveData(),
      runUpgradeLevels: Map.unmodifiable(_runUpgradeLevels),
      killGoldFractionWallet: _killGoldFractionWallet,
      gemInventory: Map.unmodifiable(_gemInventory),
      rewardOptions: List.unmodifiable(_rewardOptions),
      isPurchasedGemReward: _isPurchasedGemReward,
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
    _gemShards = math.max(0, data.gemShards);
    _isPurchasedGemReward = data.isPurchasedGemReward;
    _savedTurretCountForMenu = data.turrets.length;

    if (!data.hasActiveRun) {
      _savedTurretCountForMenu = 0;
      _selectStage(_clampedStageNumber(data.stageNumber));
      _gold = _initialGold;
      _gemShards = 0;
      _nexusHp = _maxNexusHp;
      _roundIndex = 0;
      _completedRounds = 0;
      _runUpgradeLevels.clear();
      _killGoldFractionWallet = 0;
      _lastRunPreviousBestRound = 0;
      _lastRunWasNewBestRound = false;
      _lastRunUnlockedStageNumber = null;
      _lastRunUnlockedSniperTurret = false;
      _selectedTurretType = TurretType.arrow;
      _selectedRunPanelTab = RunPanelTab.turrets;
      _selectedBuildTurretType = null;
      _selectedBuildPoint = null;
      _selectedPortalPoint = null;
      _selectedTurretPoint = null;
      _selectedTurretGemSlotIndex = null;
      _phase = GamePhase.preparation;
      _restoredPhase = null;
      _isPurchasedGemReward = false;
      return;
    }
    _gold = math.max(0, data.gold);
    _gemShards = math.max(0, data.gemShards);
    _selectStage(_clampedStageNumber(data.stageNumber));
    _nexusHp = data.nexusHp.clamp(0, _maxNexusHp).toInt();
    _roundIndex = data.roundIndex.clamp(0, _waves.length - 1).toInt();
    _completedRounds = data.completedRounds.clamp(0, _waves.length).toInt();
    _lastRunPreviousBestRound = 0;
    _lastRunWasNewBestRound = false;
    _lastRunUnlockedStageNumber = null;
    _lastRunUnlockedSniperTurret = false;
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
    _isPurchasedGemReward = false;
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
    _gemShards = math.max(0, data.gemShards);
    _isPurchasedGemReward = data.isPurchasedGemReward;

    if (!data.hasActiveRun) {
      _selectStage(_clampedStageNumber(data.stageNumber));
      _gold = _initialGold;
      _gemShards = 0;
      _nexusHp = _maxNexusHp;
      _roundIndex = 0;
      _completedRounds = 0;
      _runUpgradeLevels.clear();
      _killGoldFractionWallet = 0;
      _lastRunPreviousBestRound = 0;
      _lastRunWasNewBestRound = false;
      _lastRunUnlockedStageNumber = null;
      _lastRunUnlockedSniperTurret = false;
      _phase = GamePhase.preparation;
      _restoredPhase = null;
      _isPurchasedGemReward = false;
      return;
    }

    _restoreRunUpgradeState(data);
    _gold = math.max(0, data.gold);
    _gemShards = math.max(0, data.gemShards);
    _selectStage(_clampedStageNumber(data.stageNumber));
    _nexusHp = data.nexusHp.clamp(0, _maxNexusHp).toInt();
    _roundIndex = data.roundIndex.clamp(0, _waves.length - 1).toInt();
    _completedRounds = data.completedRounds.clamp(0, _waves.length).toInt();
    _lastRunPreviousBestRound = 0;
    _lastRunWasNewBestRound = false;
    _lastRunUnlockedStageNumber = null;
    _lastRunUnlockedSniperTurret = false;
    _selectedTurretType = TurretType.arrow;
    _selectedRunPanelTab = RunPanelTab.turrets;
    _selectedBuildTurretType = null;
    _selectedBuildPoint = null;
    _selectedPortalPoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;

    if (_hasSavedRunMapMismatch(data)) {
      _refundSavedTurretsForMapChange(data.turrets);
      _phase = GamePhase.preparation;
      _restoredPhase = null;
      _rewardOptions.clear();
      _isPurchasedGemReward = false;
      _selectedBuildTurretType = null;
      _selectedBuildPoint = null;
      _selectedPortalPoint = null;
      _selectedTurretPoint = null;
      _selectedTurretGemSlotIndex = null;
      _requestLocalSave(immediate: true);
      return;
    }

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
        maxShield: scaledEnemyMaxShield(
          definition,
          _waves[_roundIndex].round,
          stageNumber: _currentStageNumber,
        ),
        maxArmor: scaledEnemyMaxArmor(
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
    _isPurchasedGemReward = false;
  }

  bool _hasSavedRunMapMismatch(GameSaveData data) {
    if (data.mapSignature != _mapSignature(_map)) {
      return true;
    }
    for (final savedTurret in data.turrets) {
      if (!_map.canBuildAt(savedTurret.point)) {
        return true;
      }
    }
    return false;
  }

  void _refundSavedTurretsForMapChange(List<SavedTurret> savedTurrets) {
    for (final savedTurret in savedTurrets) {
      final definition = demoTurrets[savedTurret.type];
      if (definition != null) {
        _gold += _savedTurretInvestedGold(savedTurret, definition.cost);
      }
      for (final gem in savedTurret.equippedGems) {
        _gemInventory[gem] = (_gemInventory[gem] ?? 0) + 1;
      }
      if (savedTurret.primaryTrait != null) {
        _gemShards += primaryTraitCost;
      }
      if (savedTurret.secondaryTrait != null) {
        _gemShards += secondaryTraitCost;
      }
    }
    _waveSpawner.clear();
  }

  String _mapSignature(MapDefinition map) {
    final buffer = StringBuffer('${map.columns}x${map.rows}|');
    for (final row in map.tiles) {
      for (final tile in row) {
        buffer.write('${tile.name},');
      }
      buffer.write('/');
    }
    buffer.write('|');
    for (final point in map.path) {
      buffer.write('${point.x},${point.y};');
    }
    return buffer.toString();
  }

  int _savedTurretInvestedGold(SavedTurret savedTurret, int baseCost) {
    var total = baseCost;
    final level = savedTurret.level.clamp(1, 10).toInt();
    for (var currentLevel = 1; currentLevel < level; currentLevel++) {
      total += _turretLevelUpCostAt(baseCost, currentLevel);
    }
    final slotLimit = savedTurret.slotLimit.clamp(1, 3).toInt();
    if (slotLimit >= 2) {
      total += _turretLinkUpgradeCostForSlot(baseCost, 2);
    }
    if (slotLimit >= 3) {
      total += _turretLinkUpgradeCostForSlot(baseCost, 3);
    }
    return total;
  }

  int _turretLevelUpCostAt(int baseCost, int level) {
    return (baseCost * (70 + (level - 1) * 45) + 50) ~/ 100;
  }

  int _turretLinkUpgradeCostForSlot(int baseCost, int slotLimit) {
    final costPercent = slotLimit == 2 ? 150 : 300;
    return (baseCost * costPercent + 50) ~/ 100;
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
    if (owner.slowDuration > 0 && owner.slowMultiplier < 1) {
      enemy.applySlow(
        multiplier: owner.slowMultiplier,
        duration: owner.slowDuration,
      );
      if (owner.appliesFrostCrack) {
        enemy.applyMagicalVulnerability(
          bonus: 0.15,
          duration: owner.slowDuration,
        );
      }
    }
  }

  bool _isActiveTurret(TurretComponent turret) {
    return _turrets[turret.gridPoint] == turret;
  }

  TurretComponent? _turretForPoint(GridPoint point) {
    final activeTurret = _turrets[point];
    if (activeTurret != null) {
      return activeTurret;
    }
    for (final child in children.whereType<TurretComponent>()) {
      if (child.gridPoint == point) {
        return child;
      }
    }
    return null;
  }

  double _ignitionBurstDamage(TurretComponent owner, EnemyComponent enemy) {
    if (!owner.appliesIgnitionBurst ||
        !owner.definition.attackTags.contains(AttackTag.damageOverTime) ||
        !_isActiveTurret(owner) ||
        !enemy.hasBurnFromSource(owner.gridPoint)) {
      return 0;
    }
    final burnDamagePerSecond = enemy.strongestBurnDamagePerSecondFromSource(
      owner.gridPoint,
    );
    final burnDuration =
        _burnDurationSeconds * owner.damageOverTimeDurationMultiplier;
    return burnDamagePerSecond * burnDuration * _ignitionBurstDurationRate;
  }

  BurnTransferPayload? _burnTransferForHit(
    TurretComponent owner,
    EnemyComponent enemy,
  ) {
    if (!owner.spreadsChainIgnition ||
        !owner.definition.attackTags.contains(AttackTag.damageOverTime) ||
        !_isActiveTurret(owner)) {
      return null;
    }
    return enemy.burnTransferPayloadFromSource(owner.gridPoint);
  }

  void _spreadChainIgnition({
    required EnemyComponent source,
    required BurnTransferPayload burnTransfer,
  }) {
    final sourcePoint = burnTransfer.sourceTurretPoint;
    if (sourcePoint == null ||
        burnTransfer.remaining <= 0 ||
        burnTransfer.damagePerSecond <= 0) {
      return;
    }
    final turret = _turretForPoint(sourcePoint);
    if (turret == null ||
        !turret.spreadsChainIgnition ||
        !_isActiveTurret(turret)) {
      return;
    }
    final transferDuration =
        burnTransfer.remaining * _chainIgnitionDurationRate;
    if (transferDuration <= 0) {
      return;
    }
    final target = _chainIgnitionTarget(source);
    if (target == null) {
      return;
    }
    target.applyBurn(
      damagePerSecond: burnTransfer.damagePerSecond,
      duration: transferDuration,
      damageMultiplier: burnTransfer.damageMultiplier,
      sourceTurretPoint: sourcePoint,
    );
    target.showHitFlash(turret.definition.color);
  }

  EnemyComponent? _chainIgnitionTarget(EnemyComponent source) {
    final jumpRange = _chainJumpRange * boardDistanceScale;
    final jumpRangeSquared = jumpRange * jumpRange;
    EnemyComponent? target;
    var targetDistanceTravelled = -double.infinity;
    var targetDistanceSquared = double.infinity;
    for (final enemy in enemies) {
      if (identical(enemy, source) ||
          (!enemy.isMounted && !enemies.contains(enemy)) ||
          enemy.isDead) {
        continue;
      }
      final dx = enemy.position.x - source.position.x;
      final dy = enemy.position.y - source.position.y;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared > jumpRangeSquared) {
        continue;
      }
      final isFurtherAhead = enemy.distanceTravelled > targetDistanceTravelled;
      final isTieButCloser =
          enemy.distanceTravelled == targetDistanceTravelled &&
          distanceSquared < targetDistanceSquared;
      if (isFurtherAhead || isTieButCloser) {
        target = enemy;
        targetDistanceTravelled = enemy.distanceTravelled;
        targetDistanceSquared = distanceSquared;
      }
    }
    return target;
  }

  double _damageMultiplier(
    TurretComponent owner,
    EnemyComponent enemy, {
    Set<AttackTag> extraTags = const {},
  }) {
    final resistance = enemy.definition.resistanceProfile;
    final tags = {...owner.definition.attackTags, ...extraTags};
    var familyResistance = resistance.familyResistance(
      owner.definition.damageFamily,
    );
    if (owner.definition.damageFamily == DamageFamily.physical) {
      familyResistance -=
          enemy.physicalResistanceReduction + owner.physicalResistanceReduction;
    }
    if (owner.definition.damageFamily == DamageFamily.magical) {
      familyResistance -= enemy.magicalResistanceReduction;
    }

    var multiplier = EnemyResistanceProfile.multiplierForResistance(
      familyResistance,
    );
    for (final tag in tags) {
      multiplier *= EnemyResistanceProfile.multiplierForResistance(
        resistance.tagResistance(tag),
      );
    }
    return multiplier;
  }

  double _turretBurnDamagePerSecondAtLevel(TurretComponent turret, int level) {
    if (!turret.definition.attackTags.contains(AttackTag.damageOverTime)) {
      return 0;
    }
    return turret.damageAtLevel(level) *
        _burnDamagePerSecondScale *
        turret.damageOverTimeDamageMultiplier;
  }

  double _turretBurnDuration(TurretComponent turret) {
    if (!turret.definition.attackTags.contains(AttackTag.damageOverTime)) {
      return 0;
    }
    return _burnDurationSeconds * turret.damageOverTimeDurationMultiplier;
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
    final levelUpPreviewActive =
        _levelUpPreviewPoint != null &&
        _levelUpPreviewPoint == _selectedTurretPoint &&
        selectedTurret != null &&
        selectedTurret.canLevelUp &&
        _gold >= selectedTurret.levelUpCost;
    if (!levelUpPreviewActive) {
      _levelUpPreviewPoint = null;
    }
    final selectedTurretNextLevel = levelUpPreviewActive
        ? selectedTurret.level + 1
        : 0;
    final selectedTurretBurnDamagePerSecond = selectedTurret == null
        ? 0.0
        : _turretBurnDamagePerSecondAtLevel(
            selectedTurret,
            selectedTurret.level,
          );
    final selectedTurretBurnDuration = selectedTurret == null
        ? 0.0
        : _turretBurnDuration(selectedTurret);
    final selectedTurretNextBurnDamagePerSecond = levelUpPreviewActive
        ? _turretBurnDamagePerSecondAtLevel(
            selectedTurret,
            selectedTurretNextLevel,
          )
        : 0.0;
    final selectedTurretNextBurnDuration = levelUpPreviewActive
        ? _turretBurnDuration(selectedTurret)
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
    final gemCollection = _gemCollectionTotals();
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
        _savedTurretCountForMenu > 0 ||
        _gemShards > 0 ||
        _gemInventory.isNotEmpty ||
        _rewardOptions.isNotEmpty ||
        _gold != _initialGold ||
        _nexusHp != _maxNexusHp;
    final placedTurretCount = _turrets.isNotEmpty
        ? _turrets.length
        : _savedTurretCountForMenu;
    snapshotNotifier.value = GameSnapshot(
      gold: _gold,
      gemShards: _gemShards,
      nexusHp: _nexusHp,
      maxNexusHp: _maxNexusHp,
      round: math.min(_roundIndex + 1, _waves.length),
      maxRound: _waves.length,
      phase: _phase,
      restoredPhase: _phase == GamePhase.restored ? _restoredPhase : null,
      hasStageProgress: hasStageProgress,
      placedTurretCount: placedTurretCount,
      currentStageNumber: _currentStageNumber,
      unlockedStageCount: _progression.unlockedStageCount,
      bestRoundsByStage: Map.unmodifiable(_progression.bestRoundsByStage),
      clearedStageNumbers: Set.unmodifiable(_progression.clearedStageNumbers),
      availableTurretTypes: List.unmodifiable(_availableTurretTypes()),
      selectedTurretType: _selectedTurretType,
      selectedRunPanelTab: _selectedRunPanelTab,
      previewText: nextWave.previewText,
      rewardOptions: List.unmodifiable(_rewardOptions),
      isPurchasedGemReward: _isPurchasedGemReward,
      gemInventory: Map.unmodifiable(_gemInventory),
      gemCollection: Map.unmodifiable(gemCollection),
      selectedBuildPoint: _selectedBuildPoint,
      selectedBuildTurretType: _selectedBuildTurretType,
      selectedPortalPoint: _selectedPortalPoint,
      selectedTurretPoint: _selectedTurretPoint,
      selectedTurretName: selectedTurret?.definition.name,
      selectedTurretGems: List.unmodifiable(
        selectedTurret?.equippedGemSlots ?? const [],
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
      selectedTurretLevelUpPreviewActive: levelUpPreviewActive,
      selectedTurretNextLevel: selectedTurretNextLevel,
      selectedTurretNextDamage: levelUpPreviewActive
          ? selectedTurret.damageAtLevel(selectedTurretNextLevel)
          : 0,
      selectedTurretNextRange: levelUpPreviewActive
          ? selectedTurret.rangeAtLevel(selectedTurretNextLevel)
          : 0,
      selectedTurretNextAttackRate: levelUpPreviewActive
          ? selectedTurret.attackRateAtLevel(selectedTurretNextLevel)
          : 0,
      selectedTurretNextBurnDamagePerSecond:
          selectedTurretNextBurnDamagePerSecond,
      selectedTurretNextBurnDuration: selectedTurretNextBurnDuration,
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
      selectedTurretSupportsTraits: selectedTurret?.supportsTraits ?? false,
      selectedTurretPrimaryTraitChoices: List.unmodifiable(
        selectedTurret?.primaryTraitChoices ?? const [],
      ),
      selectedTurretSecondaryTraitChoices: List.unmodifiable(
        selectedTurret?.secondaryTraitChoices ?? const [],
      ),
      selectedTurretPrimaryTrait: selectedTurret?.primaryTrait,
      selectedTurretSecondaryTrait: selectedTurret?.secondaryTrait,
      selectedTurretCanChoosePrimaryTrait:
          selectedTurret?.canChoosePrimaryTrait ?? false,
      selectedTurretCanChooseSecondaryTrait:
          selectedTurret?.canChooseSecondaryTrait ?? false,
      selectedTurretPrimaryTraitCost: primaryTraitCost,
      selectedTurretSecondaryTraitCost: secondaryTraitCost,
      selectedTurretPrimaryTraitRequiredLevel: primaryTraitRequiredLevel,
      selectedTurretSecondaryTraitRequiredLevel: secondaryTraitRequiredLevel,
      topDamageTurretName:
          topDamageTurret == null || topDamageTurret.damageDealt <= 0
          ? null
          : topDamageTurret.definition.name,
      topDamageTurretDamageDealt: topDamageTurret?.damageDealt ?? 0,
      nextWaveEnemyTypes: List.unmodifiable(nextWaveEnemyTypes),
      nextWaveEnemyCounts: Map.unmodifiable(nextWaveEnemyCounts),
      nextWaveClearRewardGold: nextWave.clearRewardGold,
      nextWaveKillRewardGold: _killRewardGoldFor(nextWave),
      nextWaveClearRewardGemShards: _roundClearGemShardRewardFor(
        math.min(_roundIndex + 1, _waves.length),
      ),
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
          ? _progression.runeRewardFor(
              _roundIndex,
              success: false,
              stageNumber: _currentStageNumber,
            )
          : 0,
      lastRunPreviousBestRound: _lastRunPreviousBestRound,
      lastRunWasNewBestRound: _lastRunWasNewBestRound,
      lastRunUnlockedStageNumber: _lastRunUnlockedStageNumber,
      lastRunUnlockedSniperTurret: _lastRunUnlockedSniperTurret,
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
      killGoldUpgradeLevel: _progression.killGoldUpgradeLevel,
      killGoldUpgradeCost: _progression.killGoldUpgradeCost,
      canUpgradeKillGold:
          _progression.isStageCleared(2) && _progression.canUpgradeKillGold,
      killGoldProgressionBonusRate: _killGoldProgressionBonusRate,
      emergencySaleUpgradeLevel: _progression.emergencySaleUpgradeLevel,
      emergencySaleUpgradeCost: _progression.emergencySaleUpgradeCost,
      canUpgradeEmergencySale:
          _progression.isStageCleared(2) &&
          _progression.canUpgradeEmergencySale,
      turretRefundPercent: turretRefundPercent,
    );
  }

  Map<GemType, int> _gemCollectionTotals() {
    final totals = <GemType, int>{..._gemInventory};
    for (final turret in _turrets.values) {
      for (final gem in turret.equippedGems) {
        totals[gem] = (totals[gem] ?? 0) + 1;
      }
    }
    return totals;
  }
}
