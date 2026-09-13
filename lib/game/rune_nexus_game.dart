import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/components.dart' show Component, PositionComponent;
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' as gestures;
import 'package:flutter/material.dart';

import '../data/definitions/game_core_passive_tree_data.dart';
import '../data/definitions/game_enemy_data.dart';
import '../data/definitions/game_gem_data.dart';
import '../data/definitions/game_run_upgrade_data.dart';
import '../data/definitions/game_stage_data.dart';
import '../data/definitions/game_turret_data.dart';
import '../data/save/game_save_data.dart';
import '../data/save/local_save_coordinator.dart';
import '../data/save/local_save_repository.dart';
import '../data/save/online_save_repository.dart';
import '../data/save/online_save_coordinator.dart'
    show createOnlineSaveIdempotencyKey;
import '../data/save/save_repository.dart';
import '../domain/combat/attack_rules.dart';
import '../domain/combat/auto_start_mode.dart';
import '../domain/combat/game_phase.dart';
import '../domain/combat/run_panel_tab.dart';
import '../domain/core/core_ability.dart';
import '../domain/core/core_passive_tree.dart';
import '../domain/daily_quest/daily_quest_type.dart';
import '../domain/economy/weekly_reward_claim.dart';
import '../domain/economy/authoritative_economy_commands.dart';
import '../domain/economy/economy_snapshot.dart';
import '../domain/enemy/diamond_carrier_rules.dart';
import '../domain/enemy/enemy_definition.dart';
import '../domain/enemy/enemy_scaling.dart';
import '../domain/enemy/enemy_type.dart';
import '../domain/gem/gem_type.dart';
import '../domain/gem/gem_reward_target_status.dart';
import '../domain/map/grid_point.dart';
import '../domain/map/map_definition.dart';
import '../domain/map/tile_type.dart';
import '../domain/research/research_type.dart';
import '../domain/run_upgrade/run_upgrade_type.dart';
import '../domain/stage/stage_definition.dart';
import '../domain/turret/attack_tag.dart';
import '../domain/turret/damage_family.dart';
import '../domain/turret/turret_target_priority.dart';
import '../domain/turret/turret_trait_type.dart';
import '../domain/turret/turret_type.dart';
import '../domain/turret_module/turret_module_type.dart';
import '../domain/wave/wave_definition.dart';
import 'components/damage_number_component.dart';
import 'components/death_burst_effect_component.dart';
import 'components/diamond_reward_effect_component.dart';
import 'components/enemy_component.dart';
import 'components/gem_equip_effect_component.dart';
import 'components/grid_component.dart';
import 'components/impact_effect_component.dart';
import 'components/lightning_chain_beam_component.dart';
import 'components/lightning_charge_component.dart';
import 'components/nexus_core_beam_component.dart';
import 'components/projectile_component.dart';
import 'components/rift_mark_pulse_component.dart';
import 'components/sequential_lightning_chain_component.dart';
import 'components/turret_component.dart';
import 'game_snapshot.dart';
import 'rendering/core_skill_cooldown_renderer.dart';
import 'rendering/diamond_currency_renderer.dart';
import 'rendering/game_board_selection_renderer.dart';
import 'rendering/game_scene_effect_renderer.dart';
import 'rendering/gem_reward_target_renderer.dart';
import 'rendering/status_effect_sprite_cache.dart';
import 'rendering/stage1_3d/battlefield_frame.dart';
import 'rendering/stage1_3d/battlefield_effects.dart';
import 'rendering/stage1_3d/battlefield_effect_queue.dart';
import 'rendering/stage1_3d/battlefield_labels.dart';
import 'rendering/stage1_3d/battlefield_selection.dart';
import 'rendering/stage1_3d/battlefield_projection.dart';
import 'systems/board_camera.dart';
import 'systems/board_gesture_controller.dart';
import 'systems/combat_resolver.dart';
import 'systems/combat_execution_controller.dart';
import 'systems/core_combat_skill_controller.dart';
import 'systems/game_save_adapter.dart';
import 'systems/gem_reward_controller.dart';
import 'systems/gem_reward_selection_controller.dart';
import 'systems/run_progression.dart';
import 'systems/save_scheduler.dart';
import 'systems/turret_action_controller.dart';
import 'systems/wave_spawner.dart';

part 'game_restore_controller.dart';
part 'game_snapshot_builder.dart';
part 'game_battlefield_presentation.dart';
part 'game_battlefield_effects.dart';
part 'game_battlefield_labels.dart';
part 'game_battlefield_selection.dart';

const _debugPanelEnabled = bool.fromEnvironment(
  'RUNE_NEXUS_DEBUG_PANEL',
  defaultValue: false,
);

class RuneNexusGame extends FlameGame with TapCallbacks, ScaleDetector {
  static const double _burnDamagePerSecondScale = 0.5;
  static const double _burnDurationSeconds = 2;
  static const int gemShardRewardFallbackAmount = 10;
  static const int gemChoicePurchaseCost = 20;
  static const int primaryTraitCost = 12;
  static const int primaryTraitRequiredLevel = 3;
  static const int secondaryTraitCost = 24;
  static const int secondaryTraitRequiredLevel = 7;
  static const int economyUpgradeUnlockStage = 1;
  static const int advancedEconomyUpgradeUnlockStage = 9;
  static const int sniperUnlockStage = 3;
  static const int aimSpeedGemUnlockStage = 3;
  static const int armorPiercingGemUnlockStage = 10;
  static const double burnDamagePerSecondScale = _burnDamagePerSecondScale;
  static const double burnDurationSeconds = _burnDurationSeconds;
  static const double _designTileSize = 48;
  static const double _chainJumpRange = 110;
  static const double _lightningChainJumpRange = 115;
  static const double _nexusHitAlertDuration = 0.65;
  static const double _coreDestructionCameraDuration = 1.15;
  static const double _coreDestructionTotalDuration = 3.2;
  static const double _coreDestructionSlowMotionScale = 0.25;
  static const double _coreDestructionTargetZoom = 1.75;
  static const double _coreDestructionFocusYRatio = 0.56;
  static const double _portalAlertDuration = 0.55;
  static const double _postPortalAlertSpawnDelay = 0.15;
  static const double _combatStatsPublishInterval = 0.2;
  static const double _timeBasedProgressRefreshInterval = 1;
  static const double _nexusCoreBeamInterval = 5;
  static const double _nexusCoreBeamDuration = 1;
  static const double _nexusCoreBeamTickInterval = 0.1;
  static const double _nexusCoreBeamDpsRate = 0.08;
  static const double _nexusCoreBeamMinNormalHpRate = 0.10;
  static const double _nexusCoreBeamEnemyHpCapRate = 0.35;
  static const double _nexusCoreBeamBossHpCapRate = 0.025;
  static const Color _nexusCoreBeamColor = Color(0xFF8EE6FF);
  static const double _riftMarkInterval = 10;
  static const double _riftMarkDuration = 5;
  static const int _riftMarkTargetCount = 4;
  static const double _riftMarkDamageAmplification = 0.25;
  static const double _riftMarkBossDamageAmplification = 0.125;
  static const Color _riftMarkColor = Color(0xFFCFA7FF);

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
      final customMap = map ?? gameMap;
      final customWaves = waves ?? gameWaves;
      return List<StageDefinition>.generate(
        RunProgression.maxStageCount,
        (index) => StageDefinition(
          id: index + 1,
          name: 'Stage ${index + 1}',
          map: customMap,
          waves: customWaves,
          firstClearCorePointReward: 0,
        ),
      );
    }
    return gameStages;
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
      nexusHp: RunProgression.baseNexusHp.toDouble(),
      maxNexusHp: RunProgression.baseNexusHp.toDouble(),
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
      selectedCorePoint: null,
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
      selectedTurretCriticalChance: 0,
      selectedTurretCriticalDamageMultiplier: 1.5,
      selectedTurretBurnDamagePerSecond: 0,
      selectedTurretBurnDuration: 0,
      selectedTurretSlowMultiplier: 1,
      selectedTurretSlowDuration: 0,
      selectedTurretNextSlowMultiplier: 1,
      selectedTurretNextSlowDuration: 0,
      selectedTurretDamageDealt: 0,
      selectedTurretDirectDamageDealt: 0,
      selectedTurretSplashDamageDealt: 0,
      selectedTurretChainDamageDealt: 0,
      selectedTurretBurnDamageDealt: 0,
      canSetTurretTargetPriority: false,
      selectedTurretTargetPriority: TurretTargetPriority.first,
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
      totalTurretDps: 0,
      nexusCoreBeamIntervalSeconds: _nexusCoreBeamInterval,
      nexusCoreBeamCooldownSeconds: _nexusCoreBeamInterval,
      nexusCoreBeamAvailable: true,
      nexusCoreBeamActive: false,
      nexusCoreBeamDamage: 0,
      coreCombatSkillDirectDamageDealt: 0,
      coreCombatSkillBonusDamageDealt: 0,
      coreCombatSkillActivationCount: 0,
      coreCombatSkill: CoreCombatSkill.guardianBeam,
      totalCorePoints: 0,
      spentCorePoints: 0,
      availableCorePoints: 0,
      lastRunCorePointReward: 0,
      lastRunTurretModuleTicketReward: 0,
      corePassiveNodeRanks: const {},
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
      diamonds: 0,
      turretModuleTickets: 0,
      ownedTurretModules: const [],
      dailyQuestDayKey: RunProgression.uninitializedDailyQuestDayKey,
      dailyQuestProgress: const {},
      claimedDailyQuestRewards: const {},
      completedDailyQuestCount: 0,
      dailyAttendanceRewardClaimed: false,
      dailyQuestAllCompleteClaimed: false,
      dailyQuestClockRollbackDetected: false,
      weeklyQuestWeekKey: RunProgression.uninitializedWeeklyQuestWeekKey,
      weeklyQuestProgress: const {},
      claimedWeeklyQuestRewards: const {},
      completedWeeklyQuestCount: 0,
      weeklyQuestAllCompleteClaimed: false,
      weeklyAttendanceDays: 0,
      weeklyAttendanceRewardClaimed: false,
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
      physicalDamageTrainingUpgradeLevel: 0,
      physicalDamageTrainingUpgradeCost:
          RunProgression.familyDamageTrainingUpgradeBaseCost,
      canUpgradePhysicalDamageTraining: false,
      physicalDamageTrainingBonusRate: 0,
      elementalDamageTrainingUpgradeLevel: 0,
      elementalDamageTrainingUpgradeCost:
          RunProgression.familyDamageTrainingUpgradeBaseCost,
      canUpgradeElementalDamageTraining: false,
      elementalDamageTrainingBonusRate: 0,
      criticalChanceUpgradeLevel: 0,
      criticalChanceUpgradeCost: RunProgression.criticalChanceUpgradeBaseCost,
      canUpgradeCriticalChance: false,
      criticalChanceProgressionBonusRate: 0,
      criticalDamageUpgradeLevel: 0,
      criticalDamageUpgradeCost: RunProgression.criticalDamageUpgradeBaseCost,
      canUpgradeCriticalDamage: false,
      criticalDamageProgressionBonusRate: 0,
      killGoldUpgradeLevel: 0,
      killGoldUpgradeCost: RunProgression.killGoldUpgradeBaseCost,
      canUpgradeKillGold: false,
      killGoldProgressionBonusRate: 0,
      emergencySaleUpgradeLevel: 0,
      emergencySaleUpgradeCost: RunProgression.emergencySaleUpgradeBaseCost,
      canUpgradeEmergencySale: false,
      turretRefundPercent: RunProgression.baseTurretRefundPercent,
      researchSlotCount: RunProgression.researchSlotCount,
      researchLevels: const {},
      researchElapsedMillis: const {},
      activeResearches: const [],
      startingGemShards: 0,
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
      total += gameEnemies[group.enemyType]!.rewardGold * group.count;
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
    this.transparentBackground = false,
    StageDefinition? stage,
    List<StageDefinition>? stages,
    MapDefinition? map,
    List<WaveDefinition>? waves,
    SaveRepository? saveRepository,
    OnlineSaveRepository? onlineSaveRepository,
    @visibleForTesting double Function()? diamondCarrierRollForTesting,
    @visibleForTesting bool enableDebugEnemySpawnForTesting = false,
    @visibleForTesting String Function()? economyRunIdFactory,
  }) : _saveRepository = saveRepository is LocalSaveCoordinator
           ? saveRepository
           : LocalSaveCoordinator(
               saveRepository ?? createDefaultSaveRepository(),
             ),
       _onlineSaveRepository =
           onlineSaveRepository ?? const NoopOnlineSaveRepository(),
       _diamondCarrierRoll =
           diamondCarrierRollForTesting ?? math.Random().nextDouble,
       _enableDebugEnemySpawnForTesting = enableDebugEnemySpawnForTesting {
    _economyRunIdFactory =
        economyRunIdFactory ?? createOnlineSaveIdempotencyKey;
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
  final double Function() _diamondCarrierRoll;
  final bool _enableDebugEnemySpawnForTesting;
  late final String Function() _economyRunIdFactory;
  AuthoritativeEconomyCommands? _authoritativeEconomyCommands;
  late final ValueNotifier<GameSnapshot> snapshotNotifier;
  final bool transparentBackground;
  BattlefieldProjection? battlefieldProjection;

  /// 실제 Godot 적용 확인을 받은 표시 묶음만 Flame 그리기를 생략한다.
  Set<String> nativeBattlefieldGroups = const {};
  int nativeBattlefieldSceneEpoch = 0;
  bool nativeBattlefieldTurretLevels = false;
  final _battlefieldEffectClock = Stopwatch()..start();
  final _battlefieldEffectQueue = BattlefieldEffectQueue();
  final Map<int, Set<int>> _battlefieldEffectSubmissions = {};
  Set<int> _nativeAppliedEffectIds = const {};
  int _nativeEffectAppliedSequence = -1;
  final _battlefieldIds = Expando<int>('battlefield visual id');
  int _nextBattlefieldId = 0;
  final List<BattlefieldProjectile> _finishedProjectiles = [];
  static const _projectileVisualDuration = 0.14;
  static const _projectileVisualCapacity = 192;

  BattlefieldFrame? get battlefieldFrame => _buildBattlefieldFrame();

  void retainProjectileVisual(
    ProjectileComponent projectile, {
    Vector2? hitTarget,
  }) {
    final type = projectile.owner.definition.type;
    if (battlefieldProjection == null ||
        _activeStage.id != 1 ||
        (type != TurretType.arrow && type != TurretType.cannon)) {
      return;
    }
    Offset grid(Offset position) =>
        (position - Offset(_origin.x, _origin.y)) / _tileSize;
    if (_finishedProjectiles.length >= _projectileVisualCapacity) {
      _finishedProjectiles.removeAt(0);
    }
    // 즉시 제거된 탄환도 다음 렌더 프레임에서 확인할 수 있는 표시 전용 사본.
    _finishedProjectiles.add(
      BattlefieldProjectile(
        id: _battlefieldIds[projectile] ??= _nextBattlefieldId++,
        type: type,
        position: grid(Offset(projectile.position.x, projectile.position.y)),
        direction: projectile.visualDirection,
        origin: grid(projectile.visualOrigin),
        ownerId: _battlefieldIds[projectile.owner] ??= _nextBattlefieldId++,
        shotSequence: projectile.visualShotSequence,
        isChain: projectile.isChain,
        finishedAt: _spaceTime,
        hitTarget: hitTarget == null
            ? null
            : grid(Offset(hitTarget.x, hitTarget.y)),
      ),
    );
  }

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
  final CombatResolver _combatResolver = const CombatResolver(
    chainJumpRange: _chainJumpRange,
    burnDamagePerSecondScale: _burnDamagePerSecondScale,
    burnDurationSeconds: _burnDurationSeconds,
  );
  late final CombatExecutionController _combatExecution =
      CombatExecutionController(
        resolver: _combatResolver,
        enemies: enemies,
        isActiveTurret: _isActiveTurret,
        turretForPoint: _turretForPoint,
        recordTurretDamage: _recordTurretDamage,
        showDamageNumber: showDamageNumber,
        showImpact: _showImpact,
        addEffect: add,
        burnDurationSeconds: _burnDurationSeconds,
      );
  final WaveSpawner _waveSpawner = WaveSpawner();
  final math.Random _enemyLaneRandom = math.Random();
  final math.Random _impactEffectRandom = math.Random();
  final GemRewardController _gemRewards = GemRewardController();
  final GameSaveAdapter _saveAdapter = const GameSaveAdapter();
  late final GameRestoreController _restoreController = GameRestoreController(
    this,
  );
  final TurretActionController _turretActions = const TurretActionController();
  late final GemRewardSelectionController _rewardSelection =
      GemRewardSelectionController(
        rewards: _gemRewards,
        turretActions: _turretActions,
      );
  final RunProgression _progression = RunProgression();
  final CoreCombatSkillController _coreCombatSkillController =
      CoreCombatSkillController(
        guardianBeamInterval: _nexusCoreBeamInterval,
        guardianBeamDuration: _nexusCoreBeamDuration,
        guardianBeamTickInterval: _nexusCoreBeamTickInterval,
        riftMarkInterval: _riftMarkInterval,
        attackSyncDuration: corePassiveAttackSyncDurationSeconds,
      );
  late final SaveScheduler _saveScheduler = SaveScheduler(
    saveNow: _writeLocalSave,
  );

  late GridComponent _gridComponent;
  late final StatusEffectSpriteCache statusEffectSprites;
  ui.Image? _cannonBlastSpriteSheet;
  ui.Image? diamondCurrencyImage;
  bool _statusEffectSpritesReady = false;
  bool _gridComponentReady = false;
  late Vector2 _origin;
  late double _tileSize;
  late List<Vector2> _worldPath;
  bool _boardConfigured = false;

  int _gold = RunProgression.baseInitialGold;
  int _gemShards = 0;
  double _nexusHp = RunProgression.baseNexusHp.toDouble();
  late int _currentStageNumber;
  int _completedRounds = 0;
  int _lastRunPreviousBestRound = 0;
  bool _lastRunWasNewBestRound = false;
  int? _lastRunUnlockedStageNumber;
  bool _lastRunUnlockedSniperTurret = false;
  int _roundIndex = 0;
  GamePhase _phase = GamePhase.preparation;
  bool _debugCombatActive = false;
  bool _debugInstantResearchCompletion = false;
  GamePhase? _restoredPhase;
  GamePhase? _rewardReturnPhase;
  bool _isPurchasedGemReward = false;
  Rect? _gemRewardBoardViewport;
  TurretType _selectedTurretType = TurretType.arrow;
  RunPanelTab _selectedRunPanelTab = RunPanelTab.turrets;
  TurretType? _selectedBuildTurretType;
  GridPoint? _selectedBuildPoint;
  GridPoint? _selectedPortalPoint;
  GridPoint? _selectedCorePoint;
  GridPoint? _selectedTurretPoint;
  GridPoint? _levelUpPreviewPoint;
  int? _selectedTurretGemSlotIndex;
  AutoStartMode _autoStartMode = AutoStartMode.pauseEachRound;
  double _speedMultiplier = 1;
  double _killGoldFractionWallet = 0;
  final BoardCamera _boardCamera = BoardCamera();
  final BoardGestureController _boardGestures = BoardGestureController();
  double _nexusHitAlertTimer = 0;
  double _coreDestructionElapsed = 0;
  double _coreDestructionStartZoom = BoardCamera.minZoom;
  Vector2 _coreDestructionStartOffset = Vector2.zero();
  Vector2 _coreDestructionTargetOffset = Vector2.zero();
  double _portalAlertTimer = 0;
  bool _savedDataLoaded = false;
  bool _menuSaveDataLoaded = false;
  int _savedTurretCountForMenu = 0;
  GameSaveData? _pendingFullSaveData;
  double _combatStatsPublishTimer = 0;
  bool _combatStatsPublishPending = false;
  double _timeBasedProgressRefreshTimer = 0;
  bool _appResourcesDisposed = false;
  double _spaceTime = 0;
  double _roundNexusHpLost = 0;
  bool _emergencyChargeUsedThisRound = false;
  bool _finalDefenseUsedThisRound = false;
  int _distinctPlacedTurretTypeCount = 0;
  int _distinctEquippedGemTypeCount = 0;
  int _damageNumberSpawnIndex = 0;
  String? _economyRunId;
  int _pendingEconomyDiamonds = 0;

  bool get isWaveRunning => _phase == GamePhase.wave || _debugCombatActive;
  bool get isGemRewardTargeting =>
      _phase == GamePhase.reward && _rewardSelection.pendingGem != null;
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
  double get _maxNexusHp =>
      _progression.maxNexusHp.toDouble() *
      corePassiveNexusMaxHpMultiplier(_progression.corePassiveNodeRanks);
  int get turretRefundPercent =>
      _progression.isStageCleared(economyUpgradeUnlockStage)
      ? _progression.turretRefundPercent
      : RunProgression.baseTurretRefundPercent;
  int get maxTurretLinkSlotLimit => _progression.maxTurretLinkSlots;
  double get firstLinkUpgradeDiscountRate =>
      _progression.firstLinkUpgradeDiscountRate;
  int get primaryTraitGemShardCost => _traitGemShardCost(primaryTraitCost);
  int get secondaryTraitGemShardCost => _traitGemShardCost(secondaryTraitCost);
  double get passiveTurretLevelUpCostMultiplier =>
      corePassiveTurretLevelUpCostMultiplier(
        _progression.corePassiveNodeRanks,
        distinctTurretTypeCount: _distinctPlacedTurretTypeCount,
      );
  double get permanentTurretLevelUpCostMultiplier =>
      _progression.permanentTurretLevelUpCostMultiplier;
  double get passiveTurretLinkCostMultiplier =>
      corePassiveTurretLinkCostMultiplier(
        _progression.corePassiveNodeRanks,
        distinctTurretTypeCount: _distinctPlacedTurretTypeCount,
      );
  double get permanentTurretLinkCostMultiplier =>
      _progression.permanentLinkCostMultiplier;
  double get passiveNumericGemEffectMultiplier =>
      corePassiveNumericGemEffectMultiplier(
        _progression.corePassiveNodeRanks,
        distinctEquippedGemTypeCount: _distinctEquippedGemTypeCount,
      );
  bool get _canEditBoard =>
      _phase == GamePhase.preparation || _phase == GamePhase.wave;
  double towerDamageMultiplierFor(DamageFamily family) {
    final familyBonus = switch (family) {
      DamageFamily.physical => _progression.physicalDamageTrainingBonusRate,
      DamageFamily.elemental => _progression.elementalDamageTrainingBonusRate,
    };
    return 1 +
        _towerDamageRunBonusRate +
        _progression.fireTrainingDamageBonusRate +
        familyBonus;
  }

  double get criticalChanceProgressionBonusRate =>
      _progression.isStageCleared(4) ? _progression.criticalChanceBonusRate : 0;
  double get criticalDamageProgressionBonusRate =>
      _progression.isStageCleared(4) ? _progression.criticalDamageBonusRate : 0;
  double get chainJumpRange => _chainJumpRange * boardDistanceScale;
  double get lightningChainJumpRange =>
      _lightningChainJumpRange * boardDistanceScale;

  double get _towerDamageRunBonusRate =>
      _runUpgradeLevel(RunUpgradeType.towerDamage) *
      gameRunUpgrades[RunUpgradeType.towerDamage]!.effectPerLevel;
  double get _killGoldRunBonusRate =>
      _runUpgradeLevel(RunUpgradeType.killGold) *
      gameRunUpgrades[RunUpgradeType.killGold]!.effectPerLevel;
  double get _killGoldProgressionBonusRate =>
      _progression.isStageCleared(economyUpgradeUnlockStage)
      ? _progression.killGoldBonusRate
      : 0;
  double get _killGoldTotalBonusRate =>
      _killGoldRunBonusRate + _killGoldProgressionBonusRate;
  double get _bossKillGoldResearchBonusRate => _progression.bossBountyBonusRate;
  int get _bossKillGemShardResearchBonus => _progression.bossKillGemShardBonus;
  double get _coreCombatSkillCooldownRecoveryMultiplier =>
      1.0 + corePassiveCooldownRecoveryRate(_progression.corePassiveNodeRanks);
  double get _coreCombatSkillCooldownInterval =>
      _coreCombatSkillController.cooldownInterval(
        cooldownRecoveryMultiplier: _coreCombatSkillCooldownRecoveryMultiplier,
      );

  int get _waveClearGoldRunBonus => gameRunUpgrades[RunUpgradeType.waveGold]!
      .effectForLevel(
        _runUpgradeLevel(RunUpgradeType.waveGold),
        maxLevel: runUpgradeMaxLevelFor(RunUpgradeType.waveGold),
      )
      .round();
  double get _totalTurretDps => _turrets.values.fold<double>(0, (
    total,
    turret,
  ) {
    final directDps = turret.attackRate <= 0
        ? 0.0
        : turret.damage *
              turret.attackRate *
              (turret.definition.firesProjectile ? turret.projectileCount : 1);
    final burnDps = _turretBurnDamagePerSecondAtLevel(turret, turret.level);
    return total + directDps + burnDps;
  });
  double get nexusCoreBeamIntervalSeconds => _coreCombatSkillCooldownInterval;
  double get nexusCoreBeamCooldownSeconds =>
      _coreCombatSkillController.cooldownSeconds(
        cooldownRecoveryMultiplier: _coreCombatSkillCooldownRecoveryMultiplier,
      );
  bool get nexusCoreBeamAvailable => _coreCombatSkillController.isAvailable;
  bool get nexusCoreBeamActive =>
      _coreCombatSkillController.isGuardianBeamActive;
  double get nexusCoreBeamDamage =>
      _coreCombatSkillController.guardianBeamDamage(
        baseDamage: _nexusCoreBeamTotalDamage,
        powerMultiplierForActivation:
            _coreCombatSkillPowerMultiplierForActivation,
      );
  double get corePassiveTurretDamageMultiplier =>
      _coreCombatSkillController.isAttackSyncActive
      ? 1.0 +
            corePassiveTurretDamageAmplification(
              _progression.corePassiveNodeRanks,
            )
      : 1.0;
  double get corePassiveTurretAttackRateMultiplier =>
      _coreCombatSkillController.isAttackSyncActive
      ? 1.0 +
            corePassiveTurretAttackRateAmplification(
              _progression.corePassiveNodeRanks,
            )
      : 1.0;
  double get coreCombatSkillDirectDamageDealt =>
      _coreCombatSkillController.directDamageDealt;
  double get coreCombatSkillBonusDamageDealt =>
      _coreCombatSkillController.bonusDamageDealt;
  int get coreCombatSkillActivationCount =>
      _coreCombatSkillController.activationCount;
  CoreCombatSkill? get coreCombatSkill => _progression.coreCombatSkill;
  int get totalCorePoints => _progression.totalCorePoints;
  int get spentCorePoints => _progression.spentCorePoints;
  int get availableCorePoints => _progression.availableCorePoints;
  int get lastRunCorePointReward => _progression.lastRunCorePointReward;
  int get lastRunTurretModuleTicketReward =>
      _progression.lastRunTurretModuleTicketReward;
  Map<CorePassiveNodeId, int> get corePassiveNodeRanks =>
      Map.unmodifiable(_progression.corePassiveNodeRanks);
  int turretBuildCost(TurretType type) {
    final baseCost = gameTurrets[type]?.cost;
    if (baseCost == null) {
      return 0;
    }
    return _turretBuildCostFor(type, baseCost);
  }

  TurretModuleEffect turretModuleEffectFor(TurretType type) {
    return _progression.turretModuleEffectFor(type);
  }

  void attachAuthoritativeEconomyCommands(
    AuthoritativeEconomyCommands commands,
  ) {
    _authoritativeEconomyCommands = commands;
    _economyRunId ??= _economyRunIdFactory();
  }

  void detachAuthoritativeEconomyCommands() {
    _authoritativeEconomyCommands = null;
  }

  Future<void> applyAuthoritativeEconomy(EconomySnapshot snapshot) async {
    _progression.applyAuthoritativeEconomy(snapshot);
    _publish();
    _requestLocalSave(immediate: true);
    await saveNow();
  }

  Future<bool> applyEconomyProgressionEffect(
    EconomyProgressionEffect effect,
  ) async {
    if (effect.effectType != 'complete_research') {
      return false;
    }
    final typeName = effect.payload['researchType'];
    final targetLevel = effect.payload['targetLevel'];
    ResearchType? researchType;
    for (final candidate in ResearchType.values) {
      if (candidate.name == typeName) {
        researchType = candidate;
        break;
      }
    }
    if (researchType == null || targetLevel is! int || targetLevel <= 0) {
      return false;
    }
    _progression.applyResearchCompletionEffect(researchType, targetLevel);
    _publish();
    _requestLocalSave(immediate: true);
    await saveNow();
    return true;
  }

  Future<List<TurretModuleInventoryItem>> drawTurretModules(
    int count, {
    TurretType? turretType,
    bool buyMissingTicketsWithDiamonds = false,
  }) {
    final commands = _authoritativeEconomyCommands;
    if (commands != null) {
      final selectedTurretType = turretType;
      if (selectedTurretType == null ||
          !_availableTurretTypes().contains(selectedTurretType)) {
        return Future.value(const []);
      }
      return commands.drawTurretModules(
        count,
        turretType: selectedTurretType,
        buyMissingTicketsWithDiamonds: buyMissingTicketsWithDiamonds,
      );
    }
    final availableTurretTypes = _availableTurretTypes();
    if (turretType != null && !availableTurretTypes.contains(turretType)) {
      return Future.value(const []);
    }
    final results = _progression.drawTurretModules(
      count: count,
      availableTurretTypes: turretType == null
          ? availableTurretTypes
          : [turretType],
      buyMissingTicketsWithDiamonds: buyMissingTicketsWithDiamonds,
    );
    if (results.isEmpty) {
      return Future.value(const []);
    }
    _publish();
    _requestLocalSave(immediate: true);
    return Future.value(results);
  }

  bool equipTurretModule(String id) {
    if (!_progression.equipTurretModule(id)) {
      return false;
    }
    _publish();
    _requestLocalSave(immediate: true);
    return true;
  }

  bool unequipTurretModule(String id) {
    if (!_progression.unequipTurretModule(id)) {
      return false;
    }
    _publish();
    _requestLocalSave(immediate: true);
    return true;
  }

  Future<bool> disassembleTurretModule(String id) async {
    final commands = _authoritativeEconomyCommands;
    if (commands != null) {
      return commands.disassembleTurretModules([id]);
    }
    if (!_progression.disassembleTurretModule(id)) {
      return false;
    }
    _publish();
    _requestLocalSave(immediate: true);
    return true;
  }

  Future<int> disassembleTurretModules(Iterable<String> ids) async {
    final commands = _authoritativeEconomyCommands;
    if (commands != null) {
      final uniqueIDs = ids.toSet();
      return await commands.disassembleTurretModules(uniqueIDs)
          ? uniqueIDs.length
          : 0;
    }
    final disassembledCount = _progression.disassembleTurretModules(ids);
    if (disassembledCount == 0) {
      return 0;
    }
    _publish();
    _requestLocalSave(immediate: true);
    return disassembledCount;
  }

  int runUpgradeMaxLevelFor(RunUpgradeType type) {
    final definition = gameRunUpgrades[type];
    if (definition == null) {
      return 0;
    }
    return definition.maxLevel + _progression.runUpgradeMaxLevelBonusFor(type);
  }

  int runUpgradeCostFor(RunUpgradeType type, int currentLevel) {
    final definition = gameRunUpgrades[type];
    if (definition == null) {
      return 0;
    }
    final baseCost = definition.costForLevel(
      currentLevel,
      maxLevel: runUpgradeMaxLevelFor(type),
    );
    if (baseCost <= 0) {
      return 0;
    }
    return math.max(
      1,
      (baseCost * _progression.runUpgradeCostMultiplier).round(),
    );
  }

  int _runUpgradeLevel(RunUpgradeType type) {
    final definition = gameRunUpgrades[type];
    final level = _runUpgradeLevels[type] ?? 0;
    return definition == null
        ? 0
        : level.clamp(0, runUpgradeMaxLevelFor(type)).toInt();
  }

  @override
  Color backgroundColor() =>
      transparentBackground || battlefieldProjection != null
      ? const Color(0x00000000)
      : const Color(0xFF07111D);

  @override
  FutureOr<void> add(Component component) {
    final result = super.add(component);
    _trackBattlefieldEffect(component);
    return result;
  }

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
      if (!kDebugMode || BindingBase.debugBindingType() != null) {
        // Flutter 바인딩이 없는 순수 로직 테스트에서는 에셋 디코딩 생략.
        diamondCurrencyImage = await images.load(diamondCurrencyImageFile);
        _startCannonBlastSpriteSheetLoad();
      }
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

  void _startCannonBlastSpriteSheetLoad() {
    if (_cannonBlastSpriteSheet != null) {
      return;
    }
    unawaited(
      images
          .load('cannon_blast_core_sheet.png')
          .then<void>(
            (image) => _cannonBlastSpriteSheet = image,
            onError: (Object error, StackTrace stackTrace) {
              loadErrorNotifier.value = error;
              FlutterError.reportError(
                FlutterErrorDetails(
                  exception: error,
                  stack: stackTrace,
                  library: 'RuneNexusGame',
                  context: ErrorDescription('대포 폭발 스프라이트 로드 중'),
                ),
              );
            },
          ),
    );
  }

  Future<void> prepareSavedStateForMenu() async {
    if (isLoaded || _savedDataLoaded || _menuSaveDataLoaded) {
      return;
    }
    _menuSaveDataLoaded = true;
    final savedData = await _saveRepository.load();
    _pendingFullSaveData = savedData;
    if (savedData != null) {
      _restoreController.restoreMenuStateFromSaveData(savedData);
    }
    _updateResearchProgress();
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
    _progression.recordPlayTime(dt);
    _updateTimeBasedProgress(dt);
    _spaceTime = (_spaceTime + dt) % 1200;
    // 표시 시계의 1200초 순환을 고려하며 전투 배속을 적용하지 않음.
    _finishedProjectiles.removeWhere(
      (projectile) =>
          (_spaceTime - projectile.finishedAt! + 1200) % 1200 >=
          _projectileVisualDuration,
    );
    _updateVisualAlerts(dt);
    if (_phase == GamePhase.coreDestruction) {
      super.update(dt * _coreDestructionSlowMotionScale);
      _updateCoreDestructionSequence(dt);
      return;
    }
    if (_phase == GamePhase.restored || _phase == GamePhase.reward) {
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
    _updateCoreCombatSkill(scaledDt);
    _checkWaveClear();
    _requestLocalSave();
  }

  bool refreshResearchProgress() {
    _timeBasedProgressRefreshTimer = 0;
    return _updateResearchProgress();
  }

  void _updateTimeBasedProgress(double dt) {
    _timeBasedProgressRefreshTimer += dt;
    if (_timeBasedProgressRefreshTimer < _timeBasedProgressRefreshInterval) {
      return;
    }

    // 벽시계 기반 진행도 저빈도 갱신.
    _timeBasedProgressRefreshTimer = 0;
    _updateResearchProgress();
  }

  bool _updateResearchProgress() {
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final previousDailyQuestSeenMillis = _progression.lastDailyQuestSeenMillis;
    final dailyChanged = _progression.refreshDailyQuests(nowMillis: nowMillis);
    final dailyQuestSeenChanged =
        previousDailyQuestSeenMillis != _progression.lastDailyQuestSeenMillis;
    final completed = _progression.completeFinishedResearches(
      nowMillis: nowMillis,
    );
    if (!dailyChanged && !completed) {
      if (dailyQuestSeenChanged) {
        _requestLocalSave();
      }
      return false;
    }
    _publish();
    _requestLocalSave(immediate: true);
    return true;
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    if (_phase == GamePhase.coreDestruction ||
        _phase == GamePhase.reward ||
        info.pointerCount < 2) {
      _boardCamera.endGesture();
      return;
    }
    _boardCamera.beginGesture(info.eventPosition.widget);
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    if (_phase == GamePhase.coreDestruction ||
        _phase == GamePhase.reward ||
        info.pointerCount < 2) {
      _boardCamera.endGesture();
      return;
    }
    // 축별 배율 평균의 회전 오차를 피하는 두 손가락 사이 거리 배율.
    _boardCamera.updateGesture(
      scale: info.raw.scale,
      focal: info.eventPosition.widget,
    );
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    _boardCamera.endGesture();
  }

  @override
  void onTapDown(TapDownEvent event) {
    // 보상 포탑 선택은 드래그와 구분할 수 있도록 탭 완료 시 처리.
    if (_phase == GamePhase.reward) {
      return;
    }
    if (_boardGestures.suppressNextTap) {
      _boardGestures.suppressNextTap = false;
      return;
    }
    if (_phase == GamePhase.restored || _phase == GamePhase.coreDestruction) {
      return;
    }

    final point = _gridPointAt(
      _battlefieldWorldFromScreen(event.localPosition),
    );
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
      _selectedCorePoint = null;
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
      _selectedCorePoint = null;
      _selectedTurretPoint = null;
      _selectedTurretGemSlotIndex = null;
      _selectedRunPanelTab = RunPanelTab.turrets;
      _publish();
      return;
    }
    if (_map.tileAt(point) == TileType.core) {
      _selectedBuildPoint = null;
      _selectedBuildTurretType = null;
      _selectedPortalPoint = null;
      _selectedCorePoint = point;
      _selectedTurretPoint = null;
      _selectedTurretGemSlotIndex = null;
      _selectedRunPanelTab = RunPanelTab.turrets;
      _publish();
      return;
    }
    if (_canEditBoard && _map.canBuildAt(point)) {
      _selectedBuildPoint = point;
      _selectedPortalPoint = null;
      _selectedCorePoint = null;
      _selectedRunPanelTab = RunPanelTab.turrets;
      _selectedTurretPoint = null;
      _selectedTurretGemSlotIndex = null;
      _publish();
      return;
    }

    _clearBoardSelection(closePanel: true);
    _publish();
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (_phase != GamePhase.reward || _boardGestures.suppressNextTap) {
      return;
    }
    final point = _gridPointAt(
      _battlefieldWorldFromScreen(event.localPosition),
    );
    if (point != null &&
        _rewardSelection.replacementPoint == null &&
        (_gemRewardBoardViewport?.contains(
              Offset(event.localPosition.x, event.localPosition.y),
            ) ??
            true)) {
      selectRewardGemTarget(point);
    }
  }

  void _clearBoardSelection({required bool closePanel}) {
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedPortalPoint = null;
    _selectedCorePoint = null;
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
    final shouldBuildSelectedTile =
        _selectedBuildPoint != null && _selectedBuildTurretType == type;
    _selectedTurretType = type;
    _selectedRunPanelTab = RunPanelTab.turrets;
    _selectedBuildTurretType = type;
    _selectedPortalPoint = null;
    _selectedCorePoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;
    if (shouldBuildSelectedTile) {
      confirmBuildSelectedTile();
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
    if (_phase == GamePhase.coreDestruction) {
      return;
    }
    if (!_isTurretUnlocked(type)) {
      return;
    }
    _selectedTurretType = type;
    _selectedRunPanelTab = RunPanelTab.turrets;
    _publish();
  }

  void selectRunPanelTab(RunPanelTab tab) {
    if (_phase == GamePhase.coreDestruction) {
      return;
    }
    if (_selectedRunPanelTab == tab) {
      _selectedRunPanelTab = RunPanelTab.closed;
      _publish();
      return;
    }
    _selectedRunPanelTab = tab;
    _publish();
  }

  bool purchaseGemChoice() {
    final returnPhase = _phase == GamePhase.wave ? GamePhase.wave : null;
    final purchase = _gemRewards.purchaseGemChoice(
      phase: _phase,
      gemShards: _gemShards,
      purchaseCost: gemChoicePurchaseCost,
      availableGems: _availableGemTypes(),
    );
    if (purchase == null) {
      return false;
    }

    _gemShards = purchase.gemShards;
    _isPurchasedGemReward = true;
    _rewardReturnPhase = returnPhase;
    _rewardOptions
      ..clear()
      ..addAll(purchase.rewardOptions);
    _phase = GamePhase.reward;
    _clearBoardSelection(closePanel: true);
    _publish();
    _requestLocalSave(immediate: true);
    return true;
  }

  void buyRunUpgrade(RunUpgradeType type) {
    if (!_canEditBoard) {
      return;
    }
    final definition = gameRunUpgrades[type];
    if (definition == null) {
      return;
    }
    final currentLevel = _runUpgradeLevel(type);
    if (currentLevel >= runUpgradeMaxLevelFor(type)) {
      return;
    }
    final cost = runUpgradeCostFor(type, currentLevel);
    if (_gold < cost) {
      return;
    }

    _gold -= cost;
    _runUpgradeLevels[type] = currentLevel + 1;
    _progression.recordDailyQuestProgress(
      DailyQuestType.buyRunUpgrades,
      nowMillis: DateTime.now().millisecondsSinceEpoch,
    );
    _selectedRunPanelTab = RunPanelTab.upgrades;
    _publish();
    _requestLocalSave(immediate: true);
  }

  Future<bool> claimDailyQuestReward(DailyQuestType type) async {
    final commands = _authoritativeEconomyCommands;
    if (commands != null) {
      return commands.claimDailyQuestReward(type);
    }
    final claimed = _progression.claimDailyQuestReward(
      type,
      nowMillis: DateTime.now().millisecondsSinceEpoch,
    );
    if (!claimed) {
      return false;
    }
    _publish();
    _requestLocalSave(immediate: true);
    return true;
  }

  Future<bool> claimDailyQuestAllCompleteReward() async {
    final commands = _authoritativeEconomyCommands;
    if (commands != null) {
      return commands.claimDailyQuestAllCompleteReward();
    }
    final claimed = _progression.claimDailyQuestAllCompleteReward(
      nowMillis: DateTime.now().millisecondsSinceEpoch,
    );
    if (!claimed) {
      return false;
    }
    _publish();
    _requestLocalSave(immediate: true);
    return true;
  }

  Future<bool> claimDailyAttendanceReward() async {
    final commands = _authoritativeEconomyCommands;
    if (commands != null) {
      return commands.claimDailyAttendanceReward();
    }
    final claimed = _progression.claimDailyAttendanceReward(
      nowMillis: DateTime.now().millisecondsSinceEpoch,
    );
    if (!claimed) {
      return false;
    }
    _publish();
    _requestLocalSave(immediate: true);
    return true;
  }

  Future<bool> applyAuthoritativeDailyRewardReceipt({
    required String rewardType,
    DailyQuestType? questType,
    required int dayKey,
  }) async {
    final applied = switch (rewardType) {
      'quest' when questType != null =>
        _progression.applyDailyQuestRewardReceipt(questType, dayKey: dayKey),
      'all_complete' => _progression.applyDailyQuestAllCompleteRewardReceipt(
        dayKey: dayKey,
      ),
      'attendance' => _progression.applyDailyAttendanceRewardReceipt(
        dayKey: dayKey,
      ),
      _ => false,
    };
    if (!applied) {
      return false;
    }
    _publish();
    _requestLocalSave(immediate: true);
    await saveNow();
    return true;
  }

  bool applyWeeklyRewardReceipt(WeeklyRewardReceipt receipt) {
    final claimed = switch (receipt.target.kind) {
      WeeklyRewardKind.quest => _progression.applyWeeklyQuestRewardReceipt(
        receipt.target.questType!,
        weekKey: receipt.weekKey,
        rewardDiamonds: receipt.diamonds,
        grantEconomyRewardsLocally: _authoritativeEconomyCommands == null,
      ),
      WeeklyRewardKind.allComplete =>
        _progression.applyWeeklyQuestAllCompleteRewardReceipt(
          weekKey: receipt.weekKey,
          rewardDiamonds: receipt.diamonds,
          rewardModuleTickets: receipt.moduleTickets,
          grantEconomyRewardsLocally: _authoritativeEconomyCommands == null,
        ),
      WeeklyRewardKind.attendance =>
        _progression.applyWeeklyAttendanceRewardReceipt(
          weekKey: receipt.weekKey,
          rewardDiamonds: receipt.diamonds,
          grantEconomyRewardsLocally: _authoritativeEconomyCommands == null,
        ),
    };
    if (!claimed) {
      return false;
    }
    _publish();
    _requestLocalSave(immediate: true);
    return true;
  }

  void setSpeedMultiplier(double value) {
    if (_phase == GamePhase.coreDestruction) {
      return;
    }
    _speedMultiplier = value;
    _publish();
  }

  void setAutoStartMode(AutoStartMode mode) {
    if (_phase == GamePhase.coreDestruction) {
      return;
    }
    if (_autoStartMode == mode) {
      return;
    }
    _autoStartMode = mode;
    _publish();
    _requestLocalSave(immediate: true);
    _maybeAutoStartNextWave();
  }

  bool equipCoreCombatSkill(CoreCombatSkill skill) {
    if (!_progression.equipCoreCombatSkill(skill)) {
      return false;
    }
    _publish();
    _requestLocalSave(immediate: true);
    return true;
  }

  bool unequipCoreCombatSkill() {
    if (!_progression.unequipCoreCombatSkill()) {
      return false;
    }
    _publish();
    _requestLocalSave(immediate: true);
    return true;
  }

  bool setCorePassiveNodeRank(CorePassiveNodeId id, int rank) {
    if (!_progression.setCorePassiveNodeRank(id, rank)) {
      return false;
    }
    _nexusHp = math.min(_nexusHp, _maxNexusHp);
    _publish();
    _requestLocalSave(immediate: true);
    return true;
  }

  bool setCorePassiveNodeRanks(Map<CorePassiveNodeId, int> ranks) {
    if (!_progression.setCorePassiveNodeRanks(ranks)) {
      return false;
    }
    _nexusHp = math.min(_nexusHp, _maxNexusHp);
    _publish();
    _requestLocalSave(immediate: true);
    return true;
  }

  bool resetCorePassiveTree() {
    if (!_progression.resetCorePassiveTree()) {
      return false;
    }
    _nexusHp = math.min(_nexusHp, _maxNexusHp);
    _publish();
    _requestLocalSave(immediate: true);
    return true;
  }

  void startNextWave() {
    if (_phase != GamePhase.preparation || _roundIndex >= _waves.length) {
      return;
    }

    _resetRoundDefenseState();
    _phase = GamePhase.wave;
    _selectedPortalPoint = null;
    _selectedCorePoint = null;
    if (_selectedTurretPoint == null ||
        !_turrets.containsKey(_selectedTurretPoint)) {
      _selectedTurretPoint = null;
      _selectedTurretGemSlotIndex = null;
    }
    _resetNexusCoreBeamCycle();
    _triggerPortalAlert();
    final initialSpawnDelay = _boardConfigured
        ? (_portalAlertDuration + _postPortalAlertSpawnDelay) * _speedMultiplier
        : 0.0;
    _waveSpawner.start(_waves[_roundIndex], initialDelay: initialSpawnDelay);
    _publish();
    _requestLocalSave(immediate: true);
  }

  void startStage(int stageNumber) {
    restartRun(stageNumber: stageNumber);
  }

  void restartRun({int? stageNumber}) {
    final targetStageNumber = stageNumber == null
        ? null
        : _clampedStageNumber(stageNumber);
    _clearActiveCombat();
    _resetCoreDestructionSequence(resetCamera: true);

    for (final turret in _turrets.values.toList()) {
      turret.removeFromParent();
    }
    _turrets.clear();
    _refreshEfficiencyPassiveBoardState();
    if (targetStageNumber != null) {
      _selectStage(targetStageNumber);
    }
    _gemInventory.clear();
    _gemShards = _progression.startingGemShards;
    _runUpgradeLevels.clear();
    _rewardOptions.clear();
    _isPurchasedGemReward = false;
    _rewardReturnPhase = null;
    _killGoldFractionWallet = 0;
    _economyRunId = _economyRunIdFactory();
    _pendingEconomyDiamonds = 0;
    _pendingFullSaveData = null;
    _savedTurretCountForMenu = 0;
    _menuSaveDataLoaded = true;

    _gold = _initialGold;
    _nexusHp = _maxNexusHp;
    _resetRoundDefenseState();
    _roundIndex = 0;
    _completedRounds = 0;
    _lastRunPreviousBestRound = 0;
    _lastRunWasNewBestRound = false;
    _lastRunUnlockedStageNumber = null;
    _lastRunUnlockedSniperTurret = false;
    _progression.resetLastRunReward();
    _captureRunCoreLoadoutFromProgression();
    _phase = GamePhase.preparation;
    _selectedTurretType = TurretType.arrow;
    _selectedRunPanelTab = RunPanelTab.turrets;
    _selectedBuildTurretType = null;
    _selectedBuildPoint = null;
    _selectedPortalPoint = null;
    _selectedCorePoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;
    _restoredPhase = null;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void startResearch(ResearchType type) {
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final started = _progression.startResearch(type, nowMillis: nowMillis);
    if (!started) {
      return;
    }
    if (_debugInstantResearchCompletion) {
      _completeActiveResearchesForDebug(nowMillis);
    }
    _publish();
    _requestLocalSave(immediate: true);
  }

  void cancelResearch(ResearchType type) {
    final canceled = _progression.cancelResearch(
      type,
      nowMillis: DateTime.now().millisecondsSinceEpoch,
    );
    if (!canceled) {
      return;
    }
    _publish();
    _requestLocalSave(immediate: true);
  }

  Future<void> completeResearchWithDiamonds(ResearchType type) async {
    final commands = _authoritativeEconomyCommands;
    if (commands != null) {
      await commands.completeResearchWithDiamonds(type);
      return;
    }
    final completed = _progression.completeResearchWithDiamonds(
      type,
      nowMillis: DateTime.now().millisecondsSinceEpoch,
    );
    if (!completed) {
      return;
    }
    _publish();
    _requestLocalSave(immediate: true);
  }

  Future<bool> unlockResearchSlotTwo() async {
    final commands = _authoritativeEconomyCommands;
    if (commands != null) {
      return commands.unlockResearchSlotTwo();
    }
    if (!_progression.unlockResearchSlotTwo()) {
      return false;
    }
    _publish();
    _requestLocalSave(immediate: true);
    return true;
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
    restartRun();
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
    final previousMaxNexusHp = _maxNexusHp;
    if (!_progression.upgradeNexusHp()) {
      return;
    }

    if (_phase == GamePhase.preparation || _phase == GamePhase.success) {
      _nexusHp = math.min(
        _maxNexusHp,
        _nexusHp + (_maxNexusHp - previousMaxNexusHp),
      );
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

  void upgradePhysicalDamageTrainingProgression() {
    if (!_progression.isStageCleared(7)) {
      return;
    }
    if (!_progression.upgradePhysicalDamageTraining()) {
      return;
    }

    _publish();
    _requestLocalSave(immediate: true);
  }

  void upgradeElementalDamageTrainingProgression() {
    if (!_progression.isStageCleared(7)) {
      return;
    }
    if (!_progression.upgradeElementalDamageTraining()) {
      return;
    }

    _publish();
    _requestLocalSave(immediate: true);
  }

  void upgradeCriticalChanceProgression() {
    if (!_progression.isStageCleared(4)) {
      return;
    }
    if (!_progression.upgradeCriticalChance()) {
      return;
    }

    _publish();
    _requestLocalSave(immediate: true);
  }

  void upgradeCriticalDamageProgression() {
    if (!_progression.isStageCleared(4)) {
      return;
    }
    if (!_progression.upgradeCriticalDamage()) {
      return;
    }

    _publish();
    _requestLocalSave(immediate: true);
  }

  void upgradeKillGoldProgression() {
    if (!_progression.isStageCleared(economyUpgradeUnlockStage)) {
      return;
    }
    if (!_progression.upgradeKillGold()) {
      return;
    }

    _publish();
    _requestLocalSave(immediate: true);
  }

  void upgradeEmergencySaleProgression() {
    if (!_progression.isStageCleared(economyUpgradeUnlockStage)) {
      return;
    }
    if (!_progression.upgradeEmergencySale()) {
      return;
    }

    _publish();
    _requestLocalSave(immediate: true);
  }

  void upgradeLinkCostOptimizationProgression() {
    if (!_progression.isStageCleared(advancedEconomyUpgradeUnlockStage)) {
      return;
    }
    if (!_progression.upgradeLinkCostOptimization()) {
      return;
    }

    _publish();
    _requestLocalSave(immediate: true);
  }

  void upgradeTurretLevelUpOptimizationProgression() {
    if (!_progression.isStageCleared(advancedEconomyUpgradeUnlockStage)) {
      return;
    }
    if (!_progression.upgradeTurretLevelUpOptimization()) {
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
    _rewardReturnPhase = null;
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedPortalPoint = null;
    _selectedCorePoint = null;
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

  void debugAddRunes(int amount) {
    if (amount <= 0) {
      return;
    }

    _progression.runes += amount;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void debugSetRunes(int amount) {
    _progression.runes = math.max(0, amount);
    _publish();
    _requestLocalSave(immediate: true);
  }

  void debugAddDiamonds(int amount) {
    if (amount <= 0 || _authoritativeEconomyCommands != null) {
      return;
    }
    _progression.addFreeDiamonds(amount);
    _publish();
    _requestLocalSave(immediate: true);
  }

  void debugSetClearedStageCount(int count) {
    final clearedCount = count.clamp(0, RunProgression.maxStageCount).toInt();
    _progression.clearedStageNumbers
      ..clear()
      ..addAll(List<int>.generate(clearedCount, (index) => index + 1));
    _progression.unlockedStageCount = math.min(
      RunProgression.maxStageCount,
      clearedCount + 1,
    );
    for (var stage = 1; stage <= RunProgression.maxStageCount; stage++) {
      if (stage <= clearedCount) {
        _progression.bestRoundsByStage[stage] = _stageForNumber(
          stage,
        ).waves.length;
      } else {
        _progression.bestRoundsByStage.remove(stage);
      }
    }
    _publish();
    _requestLocalSave(immediate: true);
  }

  void debugResetResearchProgress() {
    _progression.researchLevels.clear();
    _progression.researchElapsedMillis.clear();
    _progression.activeResearches.clear();
    _publish();
    _requestLocalSave(immediate: true);
  }

  void debugResetUpgradeProgress() {
    _progression.startingGoldUpgradeLevel = 0;
    _progression.nexusHpUpgradeLevel = 0;
    _progression.supplyUpgradeLevel = 0;
    _progression.fireTrainingUpgradeLevel = 0;
    _progression.physicalDamageTrainingUpgradeLevel = 0;
    _progression.elementalDamageTrainingUpgradeLevel = 0;
    _progression.criticalChanceUpgradeLevel = 0;
    _progression.criticalDamageUpgradeLevel = 0;
    _progression.killGoldUpgradeLevel = 0;
    _progression.emergencySaleUpgradeLevel = 0;
    _progression.linkCostOptimizationUpgradeLevel = 0;
    _progression.turretLevelUpOptimizationUpgradeLevel = 0;
    _publish();
    _requestLocalSave(immediate: true);
  }

  bool get debugInstantResearchCompletion => _debugInstantResearchCompletion;

  void debugSetInstantResearchCompletion(bool enabled) {
    if (_debugInstantResearchCompletion == enabled) {
      return;
    }
    _debugInstantResearchCompletion = enabled;
    if (enabled) {
      _completeActiveResearchesForDebug(DateTime.now().millisecondsSinceEpoch);
    }
    _publish();
    _requestLocalSave(immediate: true);
  }

  void _completeActiveResearchesForDebug(int nowMillis) {
    if (_progression.activeResearches.isEmpty) {
      return;
    }
    final completionMillis = _progression.activeResearches.fold<int>(
      nowMillis,
      (latest, research) =>
          math.max(latest, research.startedAtMillis + research.durationMillis),
    );
    _progression.completeFinishedResearches(nowMillis: completionMillis);
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
    if (!_debugPanelEnabled && !_enableDebugEnemySpawnForTesting) {
      return;
    }
    if (_phase != GamePhase.preparation && _phase != GamePhase.wave) {
      return;
    }
    if (!gameEnemies.containsKey(type) || _worldPath.length < 2) {
      return;
    }

    _debugCombatActive = true;
    _spawnEnemy(type, debugSpawn: true);
    _triggerPortalAlert();
    _publish();
  }

  void debugSpawnDiamondCarrier() {
    if (!_debugPanelEnabled && !_enableDebugEnemySpawnForTesting) {
      return;
    }
    if (_phase != GamePhase.preparation && _phase != GamePhase.wave) {
      return;
    }
    if (_worldPath.length < 2) {
      return;
    }

    _debugCombatActive = true;
    _spawnEnemy(EnemyType.normal, debugSpawn: true, forceDiamondCarrier: true);
    _triggerPortalAlert();
    _publish();
  }

  void debugShowTurretLevels() {
    if (!_debugPanelEnabled || !_boardConfigured) {
      return;
    }

    _clearActiveCombat();
    for (final turret in _turrets.values) {
      turret.removeFromParent();
    }
    _turrets.clear();

    _phase = GamePhase.preparation;
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedPortalPoint = null;
    _selectedCorePoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;
    _selectedRunPanelTab = RunPanelTab.closed;

    final buildPoints = <GridPoint>[
      for (var y = 0; y < _map.rows; y++)
        for (var x = 0; x < _map.columns; x++)
          if (_map.canBuildAt(GridPoint(x, y))) GridPoint(x, y),
    ];
    final count = math.min(10, buildPoints.length);
    for (var index = 0; index < count; index++) {
      final point = buildPoints[index];
      final type = TurretType.values[index % TurretType.values.length];
      final turret = TurretComponent(
        gridPoint: point,
        definition: gameTurrets[type]!,
        game: this,
        center: _centerOf(point),
        tileSize: _tileSize,
      );
      while (turret.level < index + 1 && turret.upgradeLevel()) {}
      _turrets[point] = turret;
      add(turret);
    }
    _refreshEfficiencyPassiveBoardState();
    _publish();
  }

  void debugShowCannonBarrage() {
    if (!_debugPanelEnabled || !_boardConfigured || _worldPath.length < 3) {
      return;
    }
    _clearActiveCombat();
    for (final turret in _turrets.values) {
      turret.removeFromParent();
    }
    _turrets.clear();
    _phase = GamePhase.preparation;
    _clearBoardSelection(closePanel: true);

    final middle = _worldPath.length ~/ 2;
    final target = _worldPath[middle];
    final buildPoints =
        <GridPoint>[
          for (var y = 0; y < _map.rows; y++)
            for (var x = 0; x < _map.columns; x++)
              if (_map.canBuildAt(GridPoint(x, y))) GridPoint(x, y),
        ]..sort(
          (a, b) => _centerOf(
            a,
          ).distanceTo(target).compareTo(_centerOf(b).distanceTo(target)),
        );
    for (final point in buildPoints.take(6)) {
      final turret = TurretComponent(
        gridPoint: point,
        definition: gameTurrets[TurretType.cannon]!,
        game: this,
        center: _centerOf(point),
        tileSize: _tileSize,
      );
      _turrets[point] = turret;
      add(turret);
    }

    final base = gameEnemies[EnemyType.tank]!;
    final targetDefinition = EnemyDefinition(
      type: base.type,
      name: base.name,
      maxHp: 1000000000,
      speed: 0,
      rewardGold: 0,
      coreDamage: 0,
      color: base.color,
      resistanceProfile: base.resistanceProfile,
    );
    for (var index = middle - 1; index <= middle + 1; index++) {
      final enemy = EnemyComponent(
        definition: targetDefinition,
        maxHp: targetDefinition.maxHp,
        path: _worldPath,
        game: this,
      );
      // 전체 경로 진행도 유지: 화면 크기가 바뀌어도 표적 위치 보존.
      for (var step = 1; step <= index; step++) {
        enemy.distanceTravelled += _worldPath[step].distanceTo(
          _worldPath[step - 1],
        );
      }
      enemy.updateLayout(tileSize: _tileSize, newPath: _worldPath);
      enemies.add(enemy);
      _debugEnemies.add(enemy);
      add(enemy);
    }
    _debugCombatActive = true;
    _refreshEfficiencyPassiveBoardState();
    _publish();
  }

  void debugOpenGemReward() {
    if (!_debugPanelEnabled) {
      return;
    }

    _clearActiveCombat();
    _phase = GamePhase.reward;
    _isPurchasedGemReward = false;
    _rewardReturnPhase = null;
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedPortalPoint = null;
    _selectedCorePoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;
    final reward = _gemRewards.openDebugReward(
      completedRounds: _completedRounds,
      roundIndex: _roundIndex,
      availableGems: _availableGemTypes(),
    );
    _completedRounds = reward.completedRounds;
    _rewardOptions
      ..clear()
      ..addAll(reward.rewardOptions);
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
    _gemShards = math.max(_gemShards, primaryTraitGemShardCost);
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
    _gemShards = math.max(_gemShards, secondaryTraitGemShardCost);
    _publish();
    _requestLocalSave(immediate: true);
  }

  void debugPrepareBossWave() {
    if (!_debugPanelEnabled) {
      return;
    }

    final bossRoundIndex = _waves.indexWhere(
      (wave) => wave.groups.any((group) => group.enemyType.isBoss),
    );
    if (bossRoundIndex < 0) {
      return;
    }

    _clearActiveCombat();
    _roundIndex = bossRoundIndex;
    _phase = GamePhase.preparation;
    _rewardReturnPhase = null;
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedPortalPoint = null;
    _selectedCorePoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;
    _publish();
    _requestLocalSave(immediate: true);
  }

  void debugForceVictory() {
    _clearActiveCombat();
    _rewardReturnPhase = null;
    _rewardOptions.clear();
    _isPurchasedGemReward = false;
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedPortalPoint = null;
    _selectedCorePoint = null;
    _selectedTurretPoint = null;
    _selectedTurretGemSlotIndex = null;
    _finishRun(GamePhase.success);
    _publish();
    _requestLocalSave(immediate: true);
  }

  void debugForceDefeat() {
    if (_phase == GamePhase.success ||
        _phase == GamePhase.failure ||
        _phase == GamePhase.coreDestruction) {
      return;
    }

    _clearActiveCombat();
    _rewardReturnPhase = null;
    _rewardOptions.clear();
    _isPurchasedGemReward = false;
    _nexusHp = 0.0;
    _triggerNexusHitAlert();
    _startCoreDestructionSequence();
    _publish();
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

    final definition = gameTurrets[_selectedTurretType]!;
    final buildCost = _turretBuildCostFor(definition.type, definition.cost);
    if (_gold < buildCost) {
      return;
    }

    _gold -= buildCost;
    final turret = TurretComponent(
      gridPoint: point,
      definition: definition,
      game: this,
      center: _centerOf(point),
      tileSize: _tileSize,
      investedGold: buildCost,
    );
    _turrets[point] = turret;
    _refreshEfficiencyPassiveBoardState();
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedPortalPoint = null;
    _selectedCorePoint = null;
    _selectedTurretPoint = point;
    _selectedTurretGemSlotIndex = null;
    add(turret);
    _publish();
    _requestLocalSave(immediate: true);
  }

  int _turretBuildCostFor(TurretType type, int baseCost) {
    final discountRate = turretModuleEffectFor(type).buildCostDiscountRate;
    final moduleDiscountedCost = math.max(
      1,
      (baseCost * (1 - discountRate.clamp(0.0, 0.8))).round(),
    );
    final minimumCost = math.max(1, (baseCost * 0.8).round());
    final moduleAdjustedCost = math.max(minimumCost, moduleDiscountedCost);
    final passiveMultiplier = corePassiveTurretBuildCostMultiplier(
      _progression.corePassiveNodeRanks,
      distinctTurretTypeCount: _distinctPlacedTurretTypeCount,
    );
    return math.max(1, (moduleAdjustedCost * passiveMultiplier).round());
  }

  int _traitGemShardCost(int baseCost) {
    final multiplier = corePassiveTraitShardCostMultiplier(
      _progression.corePassiveNodeRanks,
    );
    return math.max(1, (baseCost * multiplier).round());
  }

  bool previewRewardGem(GemType type) {
    if (!_rewardSelection.preview(
      phase: _phase,
      rewardOptions: _rewardOptions,
      type: type,
    )) {
      return false;
    }
    _clearBoardSelection(closePanel: true);
    _levelUpPreviewPoint = null;
    _boardGestures.suppressNextTap = false;
    _publish();
    return true;
  }

  void clearRewardGemPreview() {
    if (_phase != GamePhase.reward) {
      return;
    }
    _rewardSelection.clear();
    _gemRewardBoardViewport = null;
    _clearBoardSelection(closePanel: true);
    _publish();
  }

  GemRewardTargetStatus gemRewardTargetStatus(GridPoint point) {
    return _rewardSelection.targetStatus(
      phase: _phase,
      turret: _turrets[point],
    );
  }

  bool selectRewardGemTarget(GridPoint point) {
    final status = _rewardSelection.selectTarget(
      phase: _phase,
      turret: _turrets[point],
    );
    if (status == GemRewardTargetStatus.unavailable) {
      return false;
    }
    final turret = _turrets[point]!;
    if (status == GemRewardTargetStatus.available) {
      return _confirmRewardGem(
        _rewardSelection.pendingGem!,
        turret: turret,
        slotIndex: turret.equippedGemSlots.indexOf(null),
      );
    }
    _selectedTurretPoint = point;
    _selectedTurretType = turret.definition.type;
    _selectedTurretGemSlotIndex = null;
    _publish();
    return true;
  }

  void cancelRewardGemReplacement() {
    if (!_rewardSelection.cancelReplacement(phase: _phase)) {
      return;
    }
    _clearBoardSelection(closePanel: true);
    _publish();
  }

  bool replaceRewardGem(int slotIndex) {
    final point = _rewardSelection.replacementPoint;
    final type = _rewardSelection.pendingGem;
    final turret = point == null ? null : _turrets[point];
    if (type == null ||
        turret == null ||
        !turret.canEquipGemAt(slotIndex) ||
        gemRewardTargetStatus(point!) == GemRewardTargetStatus.unavailable) {
      return false;
    }
    return _confirmRewardGem(type, turret: turret, slotIndex: slotIndex);
  }

  bool storeRewardGem() {
    final type = _rewardSelection.pendingGem;
    return type != null && _confirmRewardGem(type);
  }

  // 기존 호출은 보관 확정 의미 유지. 후보 선택은 previewRewardGem 사용.
  void selectRewardGem(GemType type) => _confirmRewardGem(type);

  bool _confirmRewardGem(
    GemType type, {
    TurretComponent? turret,
    int? slotIndex,
  }) {
    final selected = _rewardSelection.confirm(
      phase: _phase,
      rewardOptions: _rewardOptions,
      gemInventory: _gemInventory,
      turrets: _turrets,
      type: type,
      turret: turret,
      slotIndex: slotIndex,
    );
    if (!selected) {
      return false;
    }
    if (turret != null) {
      _refreshEfficiencyPassiveBoardState();
      _spawnGemEquipEffect(turret, type);
    }
    _finishGemReward();
    return true;
  }

  void selectRewardGemShards() {
    final gemShards = _gemRewards.selectRewardGemShards(
      phase: _phase,
      isPurchasedGemReward: _isPurchasedGemReward,
      gemShards: _gemShards,
      shardRewardAmount: gemShardRewardFallbackAmount,
      rewardOptions: _rewardOptions,
    );
    if (gemShards == null) {
      return;
    }

    _gemShards = gemShards;
    _finishGemReward();
  }

  void _finishGemReward() {
    final nextPhase = _rewardReturnPhase ?? GamePhase.preparation;
    _isPurchasedGemReward = false;
    _rewardReturnPhase = null;
    _rewardSelection.clear();
    _gemRewardBoardViewport = null;
    _clearBoardSelection(closePanel: true);
    _phase = nextPhase;
    // 보상은 update(0)으로 멈추므로 사용자의 엔진 일시정지 상태를 변경하지 않음.
    _publish();
    _requestLocalSave(immediate: true);
  }

  void grantGem(GemType type) {
    _gemRewards.grantGem(gemInventory: _gemInventory, type: type);
    _publish();
    _requestLocalSave(immediate: true);
  }

  TurretComponent? _debugEnsureTraitTurret({required int targetLevel}) {
    _clearActiveCombat();
    _phase = GamePhase.preparation;
    _selectedBuildPoint = null;
    _selectedBuildTurretType = null;
    _selectedPortalPoint = null;
    _selectedCorePoint = null;
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
        definition: gameTurrets[TurretType.arrow]!,
        game: this,
        center: _centerOf(point),
        tileSize: _tileSize,
      );
      _turrets[point] = turret;
      _refreshEfficiencyPassiveBoardState();
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
    _applyTurretAction(
      _turretActions.selectGemSlot(
        selectedPoint: _selectedTurretPoint,
        turrets: _turrets,
        slotIndex: slotIndex,
        gold: _gold,
        gemShards: _gemShards,
        levelUpPreviewPoint: _levelUpPreviewPoint,
      ),
    );
  }

  void equipSelectedTurret(GemType type) {
    final result = _turretActions.equipGem(
      phase: _phase,
      selectedPoint: _selectedTurretPoint,
      selectedSlotIndex: _selectedTurretGemSlotIndex,
      turrets: _turrets,
      gemInventory: _gemInventory,
      type: type,
      gold: _gold,
      gemShards: _gemShards,
      levelUpPreviewPoint: _levelUpPreviewPoint,
    );
    _applyTurretAction(result);

    final selectedPoint = result?.selectedTurretPoint;
    final turret = selectedPoint == null ? null : _turrets[selectedPoint];
    if (turret != null) {
      _spawnGemEquipEffect(turret, type);
    }
  }

  void removeSelectedTurretGemSlot() {
    _applyTurretAction(
      _turretActions.removeGem(
        phase: _phase,
        selectedPoint: _selectedTurretPoint,
        selectedSlotIndex: _selectedTurretGemSlotIndex,
        turrets: _turrets,
        gemInventory: _gemInventory,
        gold: _gold,
        gemShards: _gemShards,
        levelUpPreviewPoint: _levelUpPreviewPoint,
      ),
    );
  }

  void levelUpSelectedTurret() {
    _applyTurretAction(
      _turretActions.levelUp(
        canEditBoard: _canEditBoard,
        selectedPoint: _selectedTurretPoint,
        turrets: _turrets,
        gold: _gold,
        gemShards: _gemShards,
        selectedGemSlotIndex: _selectedTurretGemSlotIndex,
        levelUpPreviewPoint: _levelUpPreviewPoint,
      ),
    );
  }

  void previewOrLevelUpSelectedTurret() {
    _applyTurretAction(
      _turretActions.previewOrLevelUp(
        canEditBoard: _canEditBoard,
        selectedPoint: _selectedTurretPoint,
        turrets: _turrets,
        gold: _gold,
        gemShards: _gemShards,
        selectedGemSlotIndex: _selectedTurretGemSlotIndex,
        levelUpPreviewPoint: _levelUpPreviewPoint,
      ),
    );
  }

  void upgradeSelectedTurretLink() {
    _applyTurretAction(
      _turretActions.upgradeLink(
        phase: _phase,
        selectedPoint: _selectedTurretPoint,
        turrets: _turrets,
        gold: _gold,
        gemShards: _gemShards,
        levelUpPreviewPoint: _levelUpPreviewPoint,
      ),
    );
  }

  void setSelectedTurretTargetPriority(TurretTargetPriority priority) {
    if (!_progression.canSetTurretTargetPriority) {
      return;
    }
    final selectedPoint = _selectedTurretPoint;
    if (selectedPoint == null) {
      return;
    }
    final turret = _turrets[selectedPoint];
    if (turret == null || turret.targetPriority == priority) {
      return;
    }

    turret.setTargetPriority(priority);
    _publish();
    _requestLocalSave(immediate: true);
  }

  void chooseSelectedTurretPrimaryTrait(TurretTraitType trait) {
    _applyTurretAction(
      _turretActions.choosePrimaryTrait(
        canEditBoard: _canEditBoard,
        selectedPoint: _selectedTurretPoint,
        turrets: _turrets,
        gold: _gold,
        gemShards: _gemShards,
        selectedGemSlotIndex: _selectedTurretGemSlotIndex,
        levelUpPreviewPoint: _levelUpPreviewPoint,
        primaryTraitCost: primaryTraitGemShardCost,
        trait: trait,
      ),
    );
  }

  void chooseSelectedTurretSecondaryTrait(TurretTraitType trait) {
    _applyTurretAction(
      _turretActions.chooseSecondaryTrait(
        canEditBoard: _canEditBoard,
        selectedPoint: _selectedTurretPoint,
        turrets: _turrets,
        gold: _gold,
        gemShards: _gemShards,
        selectedGemSlotIndex: _selectedTurretGemSlotIndex,
        levelUpPreviewPoint: _levelUpPreviewPoint,
        secondaryTraitCost: secondaryTraitGemShardCost,
        trait: trait,
      ),
    );
  }

  void refundSelectedTurret() {
    _applyTurretAction(
      _turretActions.refund(
        canEditBoard: _canEditBoard,
        selectedPoint: _selectedTurretPoint,
        turrets: _turrets,
        enemies: enemies,
        gemInventory: _gemInventory,
        gold: _gold,
        gemShards: _gemShards,
        levelUpPreviewPoint: _levelUpPreviewPoint,
      ),
    );
  }

  void _applyTurretAction(TurretActionResult? result) {
    if (result == null) {
      return;
    }
    _refreshEfficiencyPassiveBoardState();
    _gold = result.gold;
    _gemShards = result.gemShards;
    _selectedTurretPoint = result.selectedTurretPoint;
    _selectedTurretGemSlotIndex = result.selectedGemSlotIndex;
    _levelUpPreviewPoint = result.levelUpPreviewPoint;
    _publish();
    if (result.saveImmediately) {
      _requestLocalSave(immediate: true);
    }
  }

  void _refreshEfficiencyPassiveBoardState() {
    _distinctPlacedTurretTypeCount = _turrets.values
        .map((turret) => turret.definition.type)
        .toSet()
        .length;
    _distinctEquippedGemTypeCount = _turrets.values
        .expand((turret) => turret.equippedGems)
        .toSet()
        .length;
  }

  Color colorForGem(GemType type) => gameGems[type]!.color;

  void _spawnGemEquipEffect(TurretComponent turret, GemType type) {
    add(
      GemEquipEffectComponent(
        position: turret.position.clone(),
        gemColor: colorForGem(type),
        visualScale: boardDistanceScale,
      ),
    );
  }

  void showDamageNumber({
    required Vector2 position,
    required double damage,
    required Color color,
    DamageNumberMotion motion = DamageNumberMotion.rise,
    double damageMultiplier = 1,
    Vector2? sourcePosition,
  }) {
    final text = damage.round().toString();
    final feedback = _damageFeedbackFor(damageMultiplier);
    add(
      DamageNumberComponent.cached(
        position: _damageNumberStartPosition(
          position: position,
          sourcePosition: sourcePosition,
          motion: motion,
        ),
        imageCache: _damageNumberImages,
        text: text,
        color: color,
        motion: motion,
        feedback: feedback,
      ),
    );
  }

  Vector2 _damageNumberStartPosition({
    required Vector2 position,
    required Vector2? sourcePosition,
    required DamageNumberMotion motion,
  }) {
    final start = position.clone();
    final scale = boardDistanceScale;
    if (sourcePosition != null) {
      final dx = sourcePosition.x - position.x;
      final dy = sourcePosition.y - position.y;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared > 0.001) {
        final distance = math.sqrt(distanceSquared);
        start.x += dx / distance * 14 * scale;
        start.y += dy / distance * 6 * scale - 10 * scale;
      } else {
        start.y -= 10 * scale;
      }
    }

    final scatterIndex = _damageNumberSpawnIndex++ % 7;
    final scatterAngle = -math.pi * 0.82 + scatterIndex * math.pi * 0.27;
    final scatterRadius =
        (motion == DamageNumberMotion.fallArc ? 5 : 8) * scale;
    start.x += math.cos(scatterAngle) * scatterRadius;
    start.y += math.sin(scatterAngle) * scatterRadius;
    return start;
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
    if (_phase == GamePhase.coreDestruction || _phase == GamePhase.reward) {
      return;
    }
    _boardCamera.beginGesture(
      Vector2(event.localPosition.dx, event.localPosition.dy),
    );
  }

  void handleTrackpadZoomUpdate(gestures.PointerPanZoomUpdateEvent event) {
    if (_phase == GamePhase.coreDestruction || _phase == GamePhase.reward) {
      return;
    }
    final focal = event.localPosition + event.localPan;
    _boardCamera.updateGesture(
      scale: event.scale,
      focal: Vector2(focal.dx, focal.dy),
    );
  }

  void handleBoardPointerDown(gestures.PointerDownEvent event) {
    if (_phase == GamePhase.coreDestruction ||
        (_phase == GamePhase.reward &&
            (!isGemRewardTargeting ||
                _rewardSelection.replacementPoint != null))) {
      return;
    }
    _boardGestures.pointerDown(
      event.pointer,
      Vector2(event.localPosition.dx, event.localPosition.dy),
    );
  }

  void handleBoardPointerMove(gestures.PointerMoveEvent event) {
    if (_phase == GamePhase.coreDestruction ||
        (_phase == GamePhase.reward &&
            (!isGemRewardTargeting ||
                _rewardSelection.replacementPoint != null))) {
      return;
    }
    final delta = _boardGestures.pointerMove(
      event.pointer,
      Vector2(event.localPosition.dx, event.localPosition.dy),
    );
    if (delta == null) {
      return;
    }
    _boardCamera.moveBy(
      delta,
      interactionViewport: isGemRewardTargeting
          ? _gemRewardBoardViewport
          : null,
    );
    if (isGemRewardTargeting && isAttached) {
      // 엔진 일시정지 중에도 직접 이동한 전장 표시 갱신.
      renderBox.markNeedsPaint();
    }
  }

  void handleBoardPointerUp(gestures.PointerUpEvent event) {
    _boardGestures.pointerEnd(
      event.pointer,
      clearTapSuppression: isGemRewardTargeting,
    );
  }

  void handleBoardPointerCancel(gestures.PointerCancelEvent event) {
    _boardGestures.pointerEnd(
      event.pointer,
      clearTapSuppression: isGemRewardTargeting,
    );
  }

  void resolveProjectileHit({
    required TurretComponent owner,
    TurretAttackSnapshot? attack,
    required EnemyComponent target,
    required Vector2 hitPosition,
    int? remainingChainCount,
    Set<EnemyComponent>? directHitEnemies,
    bool isChain = false,
  }) {
    final profile =
        attack ??
        owner.createAttackSnapshot(
          criticalMultiplier: owner.rollCriticalHit()
              ? owner.criticalDamageMultiplier
              : 1.0,
        );
    final visited = {...?directHitEnemies, target};
    _combatExecution.resolveAttackImpact(
      owner: owner,
      attack: profile,
      target: target,
      hitPosition: hitPosition,
      damageScale: isChain ? AttackRules.chainDamageMultiplier : 1,
      areaScale: isChain ? AttackRules.chainAreaMultiplier : 1,
      directKind: isChain ? TurretDamageKind.chain : TurretDamageKind.direct,
    );

    final remaining = remainingChainCount ?? profile.chainCount;
    if (remaining > 0 &&
        profile.definition.projectileSpeed > 0 &&
        !profile.definition.instantHit &&
        !profile.definition.centeredAreaAttack) {
      _spawnNextChainProjectile(
        owner: owner,
        attack: profile,
        origin: hitPosition,
        directHitEnemies: visited,
        remainingChainCount: remaining,
      );
    }
  }

  void resolveInstantHit({
    required TurretComponent owner,
    required EnemyComponent target,
    TurretAttackSnapshot? attack,
    double criticalMultiplier = 1,
  }) {
    _combatExecution.resolveInstantHit(
      owner: owner,
      target: target,
      attack: attack,
      criticalMultiplier: criticalMultiplier,
    );
  }

  void resolveLightningChainAttack({
    required TurretComponent owner,
    required EnemyComponent target,
    TurretAttackSnapshot? attack,
  }) {
    final profile = attack ?? owner.createAttackSnapshot();
    if ((!target.isMounted && !enemies.contains(target)) ||
        target.isDead ||
        !_combatExecution.isEnemyBodyInAttackRange(owner, profile, target)) {
      return;
    }
    add(
      LightningChainBeamComponent(
        sourcePosition: owner.lightningChargePosition,
        target: target,
        color: owner.definition.color,
        visualScale: boardDistanceScale,
      ),
    );
    _combatExecution.resolveAttackImpact(
      owner: owner,
      attack: profile,
      target: target,
      hitPosition: target.position.clone(),
    );
    if (profile.lightningChainMaxJumps <= 0) {
      owner.recordLightningChainCompletion(
        usedJumps: 0,
        maxJumps: profile.lightningChainMaxJumps,
      );
      return;
    }
    add(
      SequentialLightningChainComponent(
        owner: owner,
        attack: profile,
        source: target,
        excluded: {target},
        game: this,
        maxJumps: profile.lightningChainMaxJumps,
      ),
    );
  }

  EnemyComponent? nextLightningChainTarget({
    required Vector2 sourcePosition,
    required Set<EnemyComponent> excluded,
    required TurretAttackSnapshot attack,
  }) {
    return _combatExecution.nextLightningChainTarget(
      sourcePosition: sourcePosition,
      excluded: excluded,
      attack: attack,
    );
  }

  void resolveLightningChainJump({
    required TurretComponent owner,
    required TurretAttackSnapshot attack,
    required Vector2 sourcePosition,
    required EnemyComponent target,
  }) {
    _combatExecution.resolveLightningChainJump(
      owner: owner,
      attack: attack,
      sourcePosition: sourcePosition,
      target: target,
      boardDistanceScale: boardDistanceScale,
    );
  }

  void resolveCenteredAreaAttack({
    required TurretComponent owner,
    TurretAttackSnapshot? attack,
    required Iterable<EnemyComponent> targets,
  }) {
    _combatExecution.resolveCenteredAreaAttack(
      owner: owner,
      attack: attack,
      targets: targets,
    );
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
    if (owner.definition.type == TurretType.lightning) {
      return owner.definition.color;
    }
    return Color.lerp(owner.definition.color, const Color(0xFF02070D), 0.38)!;
  }

  void _showImpact({
    required TurretComponent owner,
    required TurretAttackSnapshot attack,
    required Vector2 position,
    double areaScale = 1,
  }) {
    final splashRadius = attack.splashRadius * areaScale;
    final style = splashRadius > 0
        ? owner.definition.type == TurretType.sniper
              ? ImpactEffectStyle.sniperBlast
              : owner.definition.type == TurretType.lightning
              ? ImpactEffectStyle.lightningBlast
              : ImpactEffectStyle.blast
        : switch (owner.definition.type) {
            TurretType.arrow => ImpactEffectStyle.spark,
            TurretType.cannon => ImpactEffectStyle.blast,
            TurretType.magic => ImpactEffectStyle.flame,
            TurretType.frost => ImpactEffectStyle.frost,
            TurretType.sniper => ImpactEffectStyle.spark,
            TurretType.lightning => ImpactEffectStyle.lightning,
          };
    final radius = splashRadius > 0
        ? splashRadius
        : switch (owner.definition.type) {
                TurretType.arrow => 11.0,
                TurretType.cannon => 22.0,
                TurretType.magic => 16.0,
                TurretType.frost => 18.0,
                TurretType.sniper => 13.0,
                TurretType.lightning => 15.0,
              } *
              boardDistanceScale;
    add(
      ImpactEffectComponent(
        position: position,
        color: owner.definition.color,
        style: style,
        radius: radius,
        cannonBlastSpriteSheet:
            style == ImpactEffectStyle.blast && battlefieldProjection == null
            ? _cannonBlastSpriteSheet
            : null,
        blastDuration: battlefieldProjection == null
            ? 0.42
            : BattlefieldImpact.duration,
        // Dart Web의 32비트 shift 오버플로 방지
        randomSeed: _impactEffectRandom.nextInt(0x7FFFFFFF),
      ),
    );
  }

  void _spawnNextChainProjectile({
    required TurretComponent owner,
    required TurretAttackSnapshot attack,
    required Vector2 origin,
    required Set<EnemyComponent> directHitEnemies,
    required int remainingChainCount,
  }) {
    final target = _combatResolver.nextChainProjectileTarget(
      enemies: enemies,
      sourcePosition: origin,
      excluded: directHitEnemies,
      boardDistanceScale: boardDistanceScale,
    );
    if (target == null) return;
    add(
      ProjectileComponent(
        origin: origin.clone(),
        targetPosition: target.position.clone(),
        owner: owner,
        attack: attack,
        game: this,
        isChain: true,
        remainingChainCount: remainingChainCount - 1,
        directHitEnemies: directHitEnemies,
        maxDistance: chainJumpRange,
      ),
    );
  }

  void enemyKilled(EnemyComponent enemy, {BurnTransferPayload? burnTransfer}) {
    if (!enemy.isMounted && !enemies.contains(enemy)) {
      return;
    }
    if (burnTransfer != null) {
      _combatExecution.spreadChainIgnition(
        source: enemy,
        burnTransfer: burnTransfer,
        boardDistanceScale: boardDistanceScale,
      );
    }
    final isDebugEnemy = _debugEnemies.remove(enemy);
    final diamondReward = enemy.diamondReward;
    for (final turret in _turrets.values) {
      turret.handleEnemyKilled(enemy);
    }
    if (!isDebugEnemy) {
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      _progression.recordDailyQuestProgress(
        DailyQuestType.killEnemies,
        nowMillis: nowMillis,
      );
      if (enemy.definition.type.isBoss) {
        _progression.recordDailyQuestProgress(
          DailyQuestType.killBosses,
          nowMillis: nowMillis,
        );
      }
      final baseReward = enemy.definition.rewardGold;
      final bossBonusRate = enemy.definition.type.isBoss
          ? _bossKillGoldResearchBonusRate
          : 0.0;
      final bonusReward =
          baseReward * (_killGoldTotalBonusRate + bossBonusRate);
      final wholeBonus = bonusReward.floor();
      _killGoldFractionWallet += bonusReward - wholeBonus;
      final walletGold = _killGoldFractionWallet.floor();
      if (walletGold > 0) {
        _killGoldFractionWallet -= walletGold;
      }
      _gold += baseReward + wholeBonus + walletGold;
      if (enemy.definition.type.isBoss && _bossKillGemShardResearchBonus > 0) {
        _gemShards += _bossKillGemShardResearchBonus;
      }
    }
    if (diamondReward > 0) {
      if (_authoritativeEconomyCommands == null) {
        _progression.addFreeDiamonds(diamondReward);
      } else {
        _economyRunId ??= _economyRunIdFactory();
        _pendingEconomyDiamonds += diamondReward;
      }
      add(
        DiamondRewardEffectComponent(
          diamondImage: diamondCurrencyImage,
          position: enemy.visualPosition.clone(),
          reward: diamondReward,
          visualScale: boardDistanceScale,
        ),
      );
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
    if (diamondReward > 0) {
      _requestLocalSave(immediate: true);
    }
  }

  void enemyReachedCore(EnemyComponent enemy) {
    if (_phase == GamePhase.coreDestruction ||
        _phase == GamePhase.success ||
        _phase == GamePhase.failure) {
      return;
    }
    if (!enemy.isMounted && !enemies.contains(enemy)) {
      return;
    }
    _triggerNexusHitAlert();
    final isDebugEnemy = _debugEnemies.remove(enemy);
    if (!isDebugEnemy) {
      final finalDefenseActive =
          corePassiveHasFinalDefense(_progression.corePassiveNodeRanks) &&
          !enemy.definition.type.isBoss &&
          !_finalDefenseUsedThisRound;
      if (finalDefenseActive) {
        _finalDefenseUsedThisRound = true;
      } else {
        // 체력·보호막·방어구를 합친 총 내구도 손실률.
        final lostDurabilityRatio = enemy.maxDurability <= 0
            ? 0.0
            : (1.0 - enemy.currentDurability / enemy.maxDurability)
                  .clamp(0.0, 1.0)
                  .toDouble();
        final nexusDamage =
            enemy.definition.coreDamage.toDouble() *
            corePassiveNexusDamageMultiplier(
              _progression.corePassiveNodeRanks,
              lostDurabilityRatio: lostDurabilityRatio,
            );
        final previousNexusHp = _nexusHp;
        _nexusHp = math.max(0.0, _nexusHp - nexusDamage);
        final actualNexusHpLost = previousNexusHp - _nexusHp;
        if (actualNexusHpLost > 0) {
          _roundNexusHpLost += actualNexusHpLost;
          _showNexusHealthChange(-actualNexusHpLost);
          _applyEmergencyCharge();
        }
      }
    }
    enemies.remove(enemy);
    _finishDebugCombatIfIdle();
    enemy.removeFromParent();

    if (!isDebugEnemy && _nexusHp <= 0) {
      _startCoreDestructionSequence();
    }
    _publish();
  }

  void _startCoreDestructionSequence() {
    if (_phase == GamePhase.coreDestruction ||
        _phase == GamePhase.success ||
        _phase == GamePhase.failure) {
      return;
    }
    _waveSpawner.clear();
    _debugEnemies.clear();
    _debugCombatActive = false;
    _clearBoardSelection(closePanel: true);
    _settleRunResult(GamePhase.failure);
    _queueAuthoritativeRunSettlement(GamePhase.failure);
    _phase = GamePhase.coreDestruction;
    _coreDestructionElapsed = 0;
    _coreDestructionStartZoom = _boardCamera.zoom;
    _coreDestructionStartOffset = _boardCamera.offset;
    final targetZoom = math.min(
      _coreDestructionTargetZoom,
      BoardCamera.maxZoom,
    );
    final boardCenter = _boardCamera.center;
    final coreCenter = _nexusCorePosition();
    final focus = Vector2(size.x * 0.5, size.y * _coreDestructionFocusYRatio);
    _coreDestructionTargetOffset = _boardCamera.clampOffset(
      focus - boardCenter - (coreCenter - boardCenter) * targetZoom,
      targetZoom,
    );
    if (_gridComponentReady) {
      _gridComponent.nexusDestructionProgress = 0;
    }
    _requestLocalSave(immediate: true);
  }

  void _updateCoreDestructionSequence(double dt) {
    _coreDestructionElapsed = math.min(
      _coreDestructionTotalDuration,
      _coreDestructionElapsed + dt,
    );
    final targetZoom = math.min(
      _coreDestructionTargetZoom,
      BoardCamera.maxZoom,
    );
    final cameraProgress =
        (_coreDestructionElapsed / _coreDestructionCameraDuration).clamp(
          0.0,
          1.0,
        );
    final easedCamera = _easeOutCubic(cameraProgress);
    _boardCamera.setView(
      zoom: _lerpDouble(_coreDestructionStartZoom, targetZoom, easedCamera),
      offset: _lerpVector(
        _coreDestructionStartOffset,
        _coreDestructionTargetOffset,
        easedCamera,
      ),
    );
    if (_gridComponentReady) {
      _gridComponent.nexusDestructionProgress =
          (_coreDestructionElapsed / _coreDestructionTotalDuration).clamp(
            0.0,
            1.0,
          );
    }
    if (_coreDestructionElapsed >= _coreDestructionTotalDuration) {
      _completeCoreDestructionSequence();
    }
  }

  void _completeCoreDestructionSequence() {
    if (_phase != GamePhase.coreDestruction) {
      return;
    }
    if (_gridComponentReady) {
      _gridComponent.nexusDestructionProgress = 1;
    }
    _clearActiveCombat();
    if (_gridComponentReady) {
      _gridComponent.nexusDestructionProgress = 1;
    }
    _phase = GamePhase.failure;
    _publish();
    unawaited(_saveRoundCheckpoint());
  }

  void _finishDebugCombatIfIdle() {
    if (_debugCombatActive && _debugEnemies.isEmpty) {
      _debugCombatActive = false;
    }
  }

  void _configureBoard() {
    const topReservedHeight = 76.0;
    const bottomReservedHeight = 305.0;
    final activeBounds = _activeTileBounds();
    final activeColumns = math.max(1.0, activeBounds.width);
    final activeRows = math.max(1.0, activeBounds.height);
    final horizontalReservedWidth = (size.x * 0.12).clamp(36.0, 56.0);
    final availableHeight = math.max(
      160.0,
      size.y - topReservedHeight - bottomReservedHeight,
    );
    final verticalReservedHeight = (availableHeight * 0.1).clamp(18.0, 36.0);
    final availableWidth = math.max(1.0, size.x - horizontalReservedWidth);
    final boardAvailableHeight = math.max(
      1.0,
      availableHeight - verticalReservedHeight,
    );
    _tileSize = math.max(
      12.0,
      math.min(
        availableWidth / activeColumns,
        boardAvailableHeight / activeRows,
      ),
    );
    _boardConfigured = true;
    final activeWidth = _tileSize * activeColumns;
    final activeHeight = _tileSize * activeRows;
    final activeOriginX =
        horizontalReservedWidth / 2 + (availableWidth - activeWidth) / 2;
    final activeOriginY =
        topReservedHeight +
        verticalReservedHeight / 2 +
        (boardAvailableHeight - activeHeight) / 2;
    _origin = Vector2(
      activeOriginX - activeBounds.left * _tileSize,
      activeOriginY - activeBounds.top * _tileSize,
    );
    _boardCamera.configure(
      center: Vector2(
        _origin.x + _tileSize * (activeBounds.left + activeBounds.width / 2),
        _origin.y + _tileSize * (activeBounds.top + activeBounds.height / 2),
      ),
      boardSize: Vector2(
        _tileSize * activeBounds.width,
        _tileSize * activeBounds.height,
      ),
      tileSize: _tileSize,
      interactionViewport: isGemRewardTargeting
          ? _gemRewardBoardViewport
          : null,
    );
    _worldPath = _map.path.map(_centerOf).toList();
  }

  Rect _activeTileBounds() {
    var minX = _map.columns;
    var minY = _map.rows;
    var maxX = -1;
    var maxY = -1;
    for (var y = 0; y < _map.rows; y++) {
      for (var x = 0; x < _map.columns; x++) {
        if (_map.tileAt(GridPoint(x, y)) == TileType.blocked) {
          continue;
        }
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
      }
    }
    if (maxX < minX || maxY < minY) {
      return Rect.fromLTWH(0, 0, _map.columns.toDouble(), _map.rows.toDouble());
    }
    return Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    );
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
    _finishedProjectiles.clear();
    _rewardSelection.clear();
    _gemRewardBoardViewport = null;
    for (final enemy in enemies.toList()) {
      enemy.removeFromParent();
    }
    enemies.clear();
    _debugEnemies.clear();
    _debugCombatActive = false;
    _waveSpawner.clear();
    _resetRoundDefenseState();
    _rewardOptions.clear();
    _nexusHitAlertTimer = 0;
    _portalAlertTimer = 0;
    if (_gridComponentReady) {
      _gridComponent.nexusDestructionProgress = 0;
    }
    _syncVisualAlerts();

    for (final component
        in children.whereType<ProjectileComponent>().toList()) {
      component.removeFromParent();
    }
    for (final component
        in children.whereType<SequentialLightningChainComponent>().toList()) {
      component.removeFromParent();
    }
    for (final component
        in children.whereType<LightningChargeComponent>().toList()) {
      component.removeFromParent();
    }
    for (final component
        in children.whereType<LightningChainBeamComponent>().toList()) {
      component.removeFromParent();
    }
    for (final component
        in children.whereType<NexusCoreBeamComponent>().toList()) {
      component.removeFromParent();
    }
    for (final component
        in children.whereType<ImpactEffectComponent>().toList()) {
      component.removeFromParent();
    }
    for (final component
        in children.whereType<GemEquipEffectComponent>().toList()) {
      component.removeFromParent();
    }
    for (final component
        in children.whereType<DamageNumberComponent>().toList()) {
      component.removeFromParent();
    }
    _resetNexusCoreBeamCycle();
  }

  void _resetCoreDestructionSequence({required bool resetCamera}) {
    _coreDestructionElapsed = 0;
    _coreDestructionStartZoom = BoardCamera.minZoom;
    _coreDestructionStartOffset = Vector2.zero();
    _coreDestructionTargetOffset = Vector2.zero();
    if (resetCamera) {
      _boardCamera.reset();
    }
    if (_gridComponentReady) {
      _gridComponent.nexusDestructionProgress = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    final sceneSize = Size(size.x, size.y);
    if (battlefieldProjection == null) {
      drawGameSpaceBackground(
        canvas,
        size: sceneSize,
        animationTime: _spaceTime,
      );
    }
    canvas.save();
    if (_phase == GamePhase.coreDestruction &&
        !_usesNativeBattlefieldGroup('effects')) {
      final progress = (_coreDestructionElapsed / _coreDestructionTotalDuration)
          .clamp(0.0, 1.0);
      final shake =
          math.sin(_coreDestructionElapsed * 78) *
          (1 - progress) *
          3.4 *
          boardDistanceScale;
      canvas.translate(shake, -shake * 0.45);
    }
    _applyBattlefieldTransform(canvas);
    if (battlefieldProjection == null) {
      super.render(canvas);
    } else {
      for (final child in children) {
        if (isNativeBattlefieldEffect(child)) continue;
        if (child is TurretComponent &&
            _usesNativeBattlefieldGroup('selection')) {
          continue;
        }
        if (child is GridComponent ||
            child is EnemyComponent ||
            child is ProjectileComponent ||
            child is DamageNumberComponent ||
            child is DiamondRewardEffectComponent) {
          continue;
        }
        if (child is ImpactEffectComponent &&
            child.style == ImpactEffectStyle.blast) {
          // 새 Blender 착탄은 3D 전장에만 표시하여 이전 폭발과 중복 방지.
          continue;
        } else {
          child.renderTree(canvas);
        }
      }
    }
    _drawNexusCoreCooldownBar(canvas);
    if (!_usesNativeBattlefieldGroup('selection')) {
      final selectedBuildType = _selectedBuildTurretType;
      drawGameBoardSelection(
        canvas,
        origin: Offset(_origin.x, _origin.y),
        tileSize: _tileSize,
        boardDistanceScale: boardDistanceScale,
        buildPoint: _selectedBuildPoint,
        portalPoint: _selectedPortalPoint,
        corePoint: _selectedCorePoint,
        showBuildGhost: battlefieldProjection == null,
        buildTurret: selectedBuildType == null
            ? null
            : gameTurrets[selectedBuildType]!,
      );
    }
    canvas.restore();
    if (battlefieldProjection != null) _renderBattlefieldLabels(canvas);
    final hitAlert = (_nexusHitAlertTimer / _nexusHitAlertDuration).clamp(
      0.0,
      1.0,
    );
    final destructionAlert = _phase == GamePhase.coreDestruction
        ? (0.36 +
              0.56 *
                  (_coreDestructionElapsed / _coreDestructionTotalDuration)
                      .clamp(0.0, 1.0))
        : 0.0;
    drawNexusScreenAlert(
      canvas,
      size: sceneSize,
      alert: math.max(hitAlert, destructionAlert),
    );
    if (isGemRewardTargeting && !_usesNativeBattlefieldGroup('selection')) {
      canvas.drawRect(
        Offset.zero & sceneSize,
        Paint()..color = const Color(0xAD02070D),
      );
      canvas.save();
      final viewport = _gemRewardBoardViewport;
      if (viewport != null) {
        canvas.clipRect(viewport);
      }
      _applyBattlefieldTransform(canvas);
      for (final entry in _turrets.entries) {
        final status = gemRewardTargetStatus(entry.key);
        if (status == GemRewardTargetStatus.unavailable ||
            (_rewardSelection.replacementPoint != null &&
                _rewardSelection.replacementPoint != entry.key)) {
          continue;
        }
        // 어둡게 처리한 전장 위에 대상 포탑 본체를 다시 그려 형태 보존.
        entry.value.renderTree(canvas);
        drawGemRewardTargetHighlight(
          canvas,
          tileRect: Rect.fromLTWH(
            _origin.x + entry.key.x * _tileSize,
            _origin.y + entry.key.y * _tileSize,
            _tileSize,
            _tileSize,
          ),
          requiresReplacement: status == GemRewardTargetStatus.replacement,
          animationTime: _spaceTime,
          visualScale: boardDistanceScale,
        );
      }
      canvas.restore();
    }
  }

  void _drawNexusCoreCooldownBar(Canvas canvas) {
    if (_usesNativeBattlefieldGroup('labels') ||
        _phase != GamePhase.wave ||
        _worldPath.isEmpty ||
        !nexusCoreBeamAvailable) {
      return;
    }

    final center = _nexusCorePosition();
    final progress = _coreCombatSkillController.cooldownProgress(
      cooldownRecoveryMultiplier: _coreCombatSkillCooldownRecoveryMultiplier,
    );
    final accent =
        _coreCombatSkillController.runSkill == CoreCombatSkill.riftMark
        ? _riftMarkColor
        : _nexusCoreBeamColor;
    drawCoreSkillCooldownBar(
      canvas,
      center: Offset(center.x, center.y),
      tileSize: _tileSize,
      progress: progress,
      accent: accent,
      active: nexusCoreBeamActive,
    );
  }

  void setGemRewardBoardViewport(Rect viewport) {
    if (!isGemRewardTargeting || !viewport.isFinite || viewport.isEmpty) {
      return;
    }
    final clipped = viewport.intersect(Rect.fromLTWH(0, 0, size.x, size.y));
    if (clipped.isEmpty || clipped == _gemRewardBoardViewport) {
      return;
    }
    _gemRewardBoardViewport = clipped;
    _publish();
  }

  Offset? get gemRewardReplacementAnchor {
    final point = _rewardSelection.replacementPoint;
    final viewport = _gemRewardBoardViewport;
    if (!isGemRewardTargeting ||
        !_boardConfigured ||
        point == null ||
        viewport == null) {
      return null;
    }
    final world = _centerOf(point);
    // 보상 선택 중에도 기존 전장 시점으로 화면 좌표 변환.
    final projected = battlefieldProjection?.gridToScreen(
      Offset(point.x + 0.5, point.y + 0.5),
    );
    final screen = projected == null
        ? _boardCamera.worldToScreen(world)
        : Vector2(projected.dx, projected.dy);
    return Offset(
      (screen.x - viewport.left) / viewport.width,
      (screen.y - viewport.top) / viewport.height,
    );
  }

  @visibleForTesting
  Vector2 debugBoardPanLimit() =>
      _boardCamera.panLimitForZoom(_boardCamera.zoom);

  @visibleForTesting
  double debugBoardZoom() => _boardCamera.zoom;

  @visibleForTesting
  Vector2 debugBoardOffset() => _boardCamera.offset;

  @visibleForTesting
  Vector2 debugBoardOrigin() => _origin.clone();

  @visibleForTesting
  Vector2 debugBoardSize() =>
      Vector2(_tileSize * _map.columns, _tileSize * _map.rows);

  @visibleForTesting
  Vector2 debugActiveBoardOrigin() {
    final activeBounds = _activeTileBounds();
    return Vector2(
      _origin.x + activeBounds.left * _tileSize,
      _origin.y + activeBounds.top * _tileSize,
    );
  }

  @visibleForTesting
  Vector2 debugActiveBoardSize() {
    final activeBounds = _activeTileBounds();
    return Vector2(
      _tileSize * activeBounds.width,
      _tileSize * activeBounds.height,
    );
  }

  double _lerpDouble(double start, double end, double t) =>
      start + (end - start) * t;

  Vector2 _lerpVector(Vector2 start, Vector2 end, double t) {
    return Vector2(
      _lerpDouble(start.x, end.x, t),
      _lerpDouble(start.y, end.y, t),
    );
  }

  double _easeOutCubic(double t) {
    final inverse = 1 - t;
    return 1 - inverse * inverse * inverse;
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
      _spawnEnemy(enemyType, canBecomeDiamondCarrier: true);
    }
  }

  void _spawnEnemy(
    EnemyType type, {
    bool debugSpawn = false,
    bool canBecomeDiamondCarrier = false,
    bool forceDiamondCarrier = false,
  }) {
    final definition = gameEnemies[type]!;
    // 웨이브 직접 생성만 확률 판정, 디버그·향후 소환은 기본 제외.
    final diamondReward = definition.type.isBoss
        ? 0
        : forceDiamondCarrier
        ? DiamondCarrierRules.rewardForCarrierRoll(_diamondCarrierRoll())
        : canBecomeDiamondCarrier
        ? DiamondCarrierRules.rewardForSpawn(
            type: type,
            isDirectWaveSpawn: true,
            roll: _diamondCarrierRoll(),
          )
        : 0;
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
      laneOffsetRatio: _enemyLaneOffsetRatioFor(type),
      visualPhase: _enemyVisualPhase(),
      diamondReward: diamondReward,
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

  double _enemyLaneOffsetRatioFor(EnemyType type) {
    final amplitude = switch (type) {
      EnemyType.fast => 0.18,
      EnemyType.boss => 0.055,
      EnemyType.shieldBoss => 0.055,
      EnemyType.forgeBoss => 0.045,
      EnemyType.tank => 0.12,
      _ => 0.14,
    };
    return (_enemyLaneRandom.nextDouble() * 2 - 1) * amplitude;
  }

  double _enemyVisualPhase() => _enemyLaneRandom.nextDouble();

  void _captureRunCoreLoadoutFromProgression() {
    _coreCombatSkillController.captureRunSkill(
      _progression.coreCombatSkill,
      cooldownRecoveryMultiplier: _coreCombatSkillCooldownRecoveryMultiplier,
    );
  }

  void _restoreRunCoreLoadoutFromSave(SavedRunState data) {
    _coreCombatSkillController.restoreRunSkill(
      data.runCoreCombatSkill,
      data.runCoreCombatSkillStats,
      cooldownRecoveryMultiplier: _coreCombatSkillCooldownRecoveryMultiplier,
    );
  }

  SavedCoreCombatSkillStats _coreCombatSkillStatsToSaveData() =>
      _coreCombatSkillController.statsToSaveData();

  void recordCoreCombatSkillBonusDamage(double damage) {
    if (!_coreCombatSkillController.recordBonusDamage(damage)) {
      return;
    }
    _requestCombatStatsPublish();
  }

  void _resetNexusCoreBeamCycle() => _coreCombatSkillController.resetCycle(
    cooldownRecoveryMultiplier: _coreCombatSkillCooldownRecoveryMultiplier,
  );

  void _updateCoreCombatSkill(double dt) {
    final shouldPublish = _coreCombatSkillController.update(
      dt,
      cooldownRecoveryMultiplier: _coreCombatSkillCooldownRecoveryMultiplier,
      hasGuardianBeamTarget: () => _nexusCoreBeamTarget() != null,
      guardianBeamBaseDamage: _nexusCoreBeamTotalDamage,
      powerMultiplierForActivation:
          _coreCombatSkillPowerMultiplierForActivation,
      applyGuardianBeamTick: _applyNexusCoreBeamTick,
      hasRiftMarkCandidate: enemies.isNotEmpty,
      applyRiftMark: _applyRiftMark,
    );
    if (shouldPublish) {
      _requestCombatStatsPublish();
    }
  }

  bool _applyRiftMark() {
    final targets = _riftMarkTargets();
    if (targets.isEmpty) {
      return false;
    }
    final powerMultiplier = _coreCombatSkillController.activate(
      powerMultiplierForActivation:
          _coreCombatSkillPowerMultiplierForActivation,
    );
    add(
      RiftMarkPulseComponent(
        source: _nexusCorePosition(),
        targets: targets,
        color: _riftMarkColor,
        game: this,
      ),
    );
    for (final target in targets) {
      final amplification = target.definition.type.isBoss
          ? _riftMarkBossDamageAmplification
          : _riftMarkDamageAmplification;
      target.applyRiftMark(
        damageAmplification: amplification * powerMultiplier,
        duration: _riftMarkDuration,
      );
      target.showHitFlash(_riftMarkColor);
    }
    return true;
  }

  List<EnemyComponent> _riftMarkTargets() {
    final candidates = enemies.where((enemy) => !enemy.isDead).toList();
    candidates.sort((a, b) {
      final durabilityCompare = b.currentDurability.compareTo(
        a.currentDurability,
      );
      if (durabilityCompare != 0) {
        return durabilityCompare;
      }
      return b.distanceTravelled.compareTo(a.distanceTravelled);
    });
    return candidates.take(_riftMarkTargetCount).toList();
  }

  void _applyNexusCoreBeamTick(double tickDamage) {
    final target = _nexusCoreBeamTarget();
    if (target == null) {
      return;
    }
    final capRate = target.definition.type.isBoss
        ? _nexusCoreBeamBossHpCapRate
        : _nexusCoreBeamEnemyHpCapRate;
    final tickCap =
        target.maxHp *
        capRate *
        (_nexusCoreBeamTickInterval / _nexusCoreBeamDuration);
    final damage = math.min(tickDamage, tickCap);
    if (damage <= 0) {
      return;
    }

    target.showHitFlash(_nexusCoreBeamColor);
    final actualDamage = target.receiveDamage(damage);
    if (actualDamage <= 0) {
      return;
    }
    _coreCombatSkillController.recordDirectDamage(actualDamage);
    add(
      NexusCoreBeamComponent(
        start: _nexusCorePosition(),
        target: target,
        color: _nexusCoreBeamColor,
        game: this,
      ),
    );
    showDamageNumber(
      position: target.position.clone(),
      damage: actualDamage,
      color: _nexusCoreBeamColor,
      sourcePosition: _nexusCorePosition(),
    );
    _requestCombatStatsPublish();
  }

  EnemyComponent? _nexusCoreBeamTarget() {
    EnemyComponent? selected;
    var selectedProgress = double.negativeInfinity;
    for (final enemy in enemies) {
      if (enemy.isDead) {
        continue;
      }
      if (enemy.distanceTravelled > selectedProgress) {
        selected = enemy;
        selectedProgress = enemy.distanceTravelled;
      }
    }
    return selected;
  }

  Vector2 _nexusCorePosition() {
    if (_worldPath.isEmpty) {
      return _boardCamera.center;
    }
    return _worldPath.last.clone();
  }

  double _nexusCoreBeamTotalDamage() {
    final round = _roundIndex < _waves.length
        ? _waves[_roundIndex].round
        : _waves.last.round;
    final minimumDamage =
        scaledEnemyMaxHp(
          gameEnemies[EnemyType.normal]!,
          round,
          stageNumber: _currentStageNumber,
        ) *
        _nexusCoreBeamMinNormalHpRate;
    return math.max(
      minimumDamage,
      _totalTurretDps * _nexusCoreBeamInterval * _nexusCoreBeamDpsRate,
    );
  }

  double _coreCombatSkillPowerMultiplierForActivation(int activationNumber) {
    return corePassiveCoreSkillPowerMultiplier(
      _progression.corePassiveNodeRanks,
      activationNumber: activationNumber,
    );
  }

  void _applyEmergencyCharge() {
    if (_emergencyChargeUsedThisRound) {
      return;
    }
    final recoveryRate = corePassiveEmergencyChargeRecoveryRate(
      _progression.corePassiveNodeRanks,
    );
    if (!_coreCombatSkillController.applyEmergencyCharge(
      recoveryRate: recoveryRate,
      cooldownRecoveryMultiplier: _coreCombatSkillCooldownRecoveryMultiplier,
    )) {
      return;
    }
    _emergencyChargeUsedThisRound = true;
    _requestCombatStatsPublish();
  }

  void _restoreNexusAtRoundEnd() {
    if (_nexusHp <= 0 || _nexusHp >= _maxNexusHp) {
      _resetRoundDefenseState();
      return;
    }
    final nodeRanks = _progression.corePassiveNodeRanks;
    // 최대 체력 비례 수복과 해당 라운드 실제 손실 복원 합산.
    final recovery =
        _maxNexusHp * corePassiveRoundRecoveryRate(nodeRanks) +
        _roundNexusHpLost * corePassiveDamageRestorationRate(nodeRanks);
    if (recovery > 0) {
      final previousNexusHp = _nexusHp;
      _nexusHp = math.min(_maxNexusHp, _nexusHp + recovery);
      final actualRecovery = _nexusHp - previousNexusHp;
      if (actualRecovery > 0) {
        _showNexusHealthChange(actualRecovery);
      }
    }
    _resetRoundDefenseState();
  }

  void _resetRoundDefenseState() {
    _roundNexusHpLost = 0;
    _emergencyChargeUsedThisRound = false;
    _finalDefenseUsedThisRound = false;
  }

  void _showNexusHealthChange(double healthChange) {
    if (healthChange == 0) {
      return;
    }
    final text =
        '${healthChange > 0 ? '+' : '-'}${healthChange.abs().toStringAsFixed(1)}';
    add(
      DamageNumberComponent.cached(
        position: _damageNumberStartPosition(
          position: _nexusCorePosition(),
          sourcePosition: null,
          motion: DamageNumberMotion.rise,
        ),
        imageCache: _damageNumberImages,
        text: text,
        color: healthChange > 0
            ? const Color(0xFF72E0A2)
            : const Color(0xFFFF7043),
      ),
    );
  }

  void _checkWaveClear() {
    if (!_waveSpawner.isEmpty ||
        enemies.isNotEmpty ||
        _phase != GamePhase.wave) {
      return;
    }

    final completedRound = _roundIndex + 1;
    _restoreNexusAtRoundEnd();
    final clearGoldBeforePassive =
        _waves[_roundIndex].clearRewardGold +
        _progression.waveClearGoldBonus +
        _waveClearGoldRunBonus;
    _gold +=
        (clearGoldBeforePassive *
                corePassiveRoundClearGoldMultiplier(
                  _progression.corePassiveNodeRanks,
                ))
            .round();
    _gemShards += _roundClearGemShardRewardFor(completedRound);
    _roundIndex++;
    _completedRounds = completedRound;
    _progression.recordDailyQuestProgress(
      DailyQuestType.clearWaves,
      nowMillis: DateTime.now().millisecondsSinceEpoch,
    );
    final gemRoundReward = _gemRewards.completeRound(
      completedRound: completedRound,
      availableGems: _availableGemTypes(),
    );
    if (_roundIndex >= _waves.length) {
      _rewardOptions.clear();
      _rewardReturnPhase = null;
      _finishRun(GamePhase.success);
      unawaited(_saveRoundCheckpoint());
    } else if (gemRoundReward != null) {
      _phase = GamePhase.reward;
      _isPurchasedGemReward = false;
      _rewardReturnPhase = null;
      _rewardOptions
        ..clear()
        ..addAll(gemRoundReward.rewardOptions);
      unawaited(_saveRoundCheckpoint());
    } else {
      _phase = GamePhase.preparation;
      _rewardOptions.clear();
      _isPurchasedGemReward = false;
      _rewardReturnPhase = null;
      unawaited(_saveRoundCheckpoint());
    }
    _resetNexusCoreBeamCycle();
    _publish();
  }

  void _maybeAutoStartNextWave() {
    if (_phase != GamePhase.preparation || _roundIndex >= _waves.length) {
      return;
    }
    if (_roundIndex == 0) {
      return;
    }
    if (_autoStartMode == AutoStartMode.pauseEachRound) {
      return;
    }
    final nextWaveHasBoss = _waves[_roundIndex].groups.any(
      (group) => group.enemyType.isBoss,
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

  void _finishRun(GamePhase resultPhase) {
    if (_phase == GamePhase.success ||
        _phase == GamePhase.failure ||
        _phase == GamePhase.coreDestruction) {
      return;
    }

    _settleRunResult(resultPhase);
    _phase = resultPhase;
    _queueAuthoritativeRunSettlement(resultPhase);
  }

  void _queueAuthoritativeRunSettlement(GamePhase resultPhase) {
    final commands = _authoritativeEconomyCommands;
    final runId = _economyRunId;
    if (commands == null || runId == null) {
      return;
    }
    unawaited(
      commands.queueRunSettlement(
        runId: runId,
        stageNumber: _currentStageNumber,
        completedRounds: _completedRounds,
        success: resultPhase == GamePhase.success,
        pendingDiamonds: _pendingEconomyDiamonds,
        firstClearModuleTickets: _progression.lastRunTurretModuleTicketReward,
      ),
    );
  }

  void _settleRunResult(GamePhase resultPhase) {
    final success = resultPhase == GamePhase.success;
    _completedRounds = success ? _waves.length : _roundIndex;
    final previousBestRound = _progression.bestRoundForStage(
      _currentStageNumber,
    );
    final previousUnlockedStageCount = _progression.unlockedStageCount;
    final sniperWasUnlocked = _progression.isStageCleared(sniperUnlockStage);
    _progression.finishRun(
      completedRounds: _completedRounds,
      success: success,
      stageNumber: _currentStageNumber,
      firstClearCorePointReward: _activeStage.firstClearCorePointReward,
      firstClearTurretModuleTicketReward:
          _activeStage.firstClearTurretModuleTicketReward,
      grantEconomyRewardsLocally: _authoritativeEconomyCommands == null,
    );
    _lastRunPreviousBestRound = previousBestRound;
    _lastRunWasNewBestRound = _completedRounds > previousBestRound;
    _lastRunUnlockedStageNumber =
        _progression.unlockedStageCount > previousUnlockedStageCount
        ? _progression.unlockedStageCount
        : null;
    _lastRunUnlockedSniperTurret =
        success &&
        !sniperWasUnlocked &&
        _progression.isStageCleared(sniperUnlockStage);
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
    if (_progression.isStageCleared(sniperUnlockStage)) {
      types.add(TurretType.sniper);
    }
    if (_progression.isStageCleared(6)) {
      types.add(TurretType.lightning);
    }
    return types;
  }

  List<GemType> _availableGemTypes() {
    return GemType.values.where((type) {
      if (type == GemType.aimSpeed) {
        return _progression.isStageCleared(aimSpeedGemUnlockStage);
      }
      if (type == GemType.armorPiercing) {
        return _progression.isStageCleared(armorPiercingGemUnlockStage);
      }
      return true;
    }).toList();
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
    if (immediate && !_savedDataLoaded) {
      _pendingFullSaveData = _buildSaveData();
    }
    _saveScheduler.requestSave(immediate: immediate);
  }

  Future<void> saveNow() async {
    await _saveScheduler.flush();
  }

  Future<bool> saveAccountCheckpoint() => _writeAccountCheckpoint();

  Future<void> quiesceLocalSavesForRemoteRebase() {
    return _saveScheduler.quiesce();
  }

  void resumeLocalSavesAfterRemoteRebaseFailure() {
    _saveScheduler.resume();
  }

  Future<void> _saveRoundCheckpoint() async {
    await _writeAccountCheckpoint();
  }

  Future<bool> _writeAccountCheckpoint() async {
    final data = _buildSaveData();
    if (!await _writeLocalSaveData(data)) {
      return false;
    }
    try {
      await _onlineSaveRepository.saveRoundCheckpoint(data);
      return true;
    } on Object {
      // 온라인 전송 실패는 영속 Outbox가 복구하므로 로컬 플레이를 막지 않는다.
      return false;
    }
  }

  Future<void> _writeLocalSave() async {
    final data = _buildSaveData();
    if (!_savedDataLoaded) {
      _pendingFullSaveData = data;
    }
    await _writeLocalSaveData(data);
  }

  Future<bool> _writeLocalSaveData(GameSaveData data) async {
    try {
      await _saveRepository.save(data);
      return true;
    } on Object {
      // 로컬 저장 실패는 다음 저장 기회에 재시도한다.
      return false;
    }
  }

  Future<void> _restoreSavedDataIfNeeded() async {
    if (_savedDataLoaded) {
      return;
    }
    final pendingRewardOptions = List<GemType>.of(_rewardOptions);
    final pendingRewardPhase = _phase;
    final pendingRewardGemShards = _gemShards;
    final pendingRewardIsPurchase = _isPurchasedGemReward;
    final pendingRewardReturnPhase = _rewardReturnPhase;
    _savedDataLoaded = true;
    final savedData = _pendingFullSaveData ?? await _saveRepository.load();
    _pendingFullSaveData = null;
    _savedTurretCountForMenu = 0;
    if (savedData != null) {
      _restoreController.restoreFromSaveData(savedData);
    }
    if (pendingRewardPhase == GamePhase.reward &&
        pendingRewardOptions.isNotEmpty) {
      _phase = GamePhase.reward;
      _restoredPhase = null;
      _gemShards = pendingRewardGemShards;
      _isPurchasedGemReward = pendingRewardIsPurchase;
      _rewardReturnPhase = pendingRewardIsPurchase
          ? pendingRewardReturnPhase
          : null;
      _rewardOptions
        ..clear()
        ..addAll(pendingRewardOptions);
      _requestLocalSave(immediate: true);
    }
    _updateResearchProgress();
  }

  GameSaveData _buildSaveData() {
    return _saveAdapter.buildSaveData(
      GameSaveBuildState(
        savedAtMillis: DateTime.now().millisecondsSinceEpoch,
        selectedStageNumber: _currentStageNumber,
        autoStartMode: _autoStartMode,
        progression: _progression,
        run: GameRunSaveBuildState(
          gold: _gold,
          gemShards: _gemShards,
          nexusHp: _nexusHp,
          map: _map,
          roundIndex: _roundIndex,
          completedRounds: _completedRounds,
          phase: _phase,
          restoredPhase: _restoredPhase,
          runCoreCombatSkill: _coreCombatSkillController.runSkill,
          runCoreCombatSkillStats: _coreCombatSkillStatsToSaveData(),
          roundNexusHpLost: _roundNexusHpLost,
          emergencyChargeUsedThisRound: _emergencyChargeUsedThisRound,
          finalDefenseUsedThisRound: _finalDefenseUsedThisRound,
          runUpgradeLevels: _runUpgradeLevels,
          killGoldFractionWallet: _killGoldFractionWallet,
          gemInventory: _gemInventory,
          rewardOptions: _rewardOptions,
          isPurchasedGemReward: _isPurchasedGemReward,
          economyRunId: _economyRunId,
          pendingEconomyDiamonds: _pendingEconomyDiamonds,
          rewardReturnPhase: _rewardReturnPhase,
          turrets: [for (final turret in _turrets.values) turret.toSaveData()],
          enemies: [
            for (final enemy in enemies)
              if (!enemy.isDead) enemy.toSaveData(),
          ],
          spawnQueue: _waveSpawner.toSaveData(),
        ),
        savedDataLoaded: _savedDataLoaded,
        pendingFullSaveData: _pendingFullSaveData,
      ),
    );
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

  void _sanitizeLevelUpPreview() {
    final previewPoint = _levelUpPreviewPoint;
    if (previewPoint == null) {
      return;
    }
    final selectedPoint = _selectedTurretPoint;
    final selectedTurret = selectedPoint == null
        ? null
        : _turrets[selectedPoint];
    if (previewPoint != selectedPoint ||
        selectedTurret == null ||
        !selectedTurret.canLevelUp ||
        _gold < selectedTurret.levelUpCost) {
      _levelUpPreviewPoint = null;
    }
  }

  void _publish() {
    if (_phase != GamePhase.reward ||
        !_rewardOptions.contains(_rewardSelection.pendingGem)) {
      _rewardSelection.clear();
      _gemRewardBoardViewport = null;
    }
    _combatStatsPublishPending = false;
    _combatStatsPublishTimer = 0;
    _sanitizeLevelUpPreview();
    snapshotNotifier.value = GameSnapshotBuilder(this).build();
    if (isAttached) {
      // 사용자 일시정지 중에도 후보·대상 변경을 즉시 반영.
      renderBox.markNeedsPaint();
    }
  }
}
