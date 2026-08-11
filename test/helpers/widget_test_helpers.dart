import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/app/rune_nexus_app.dart';
import 'package:rune_nexus/data/definitions/game_core_passive_tree_data.dart';
import 'package:rune_nexus/data/definitions/game_turret_module_data.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/combat/auto_start_mode.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
import 'package:rune_nexus/domain/combat/run_panel_tab.dart';
import 'package:rune_nexus/domain/core/core_ability.dart';
import 'package:rune_nexus/domain/core/core_passive_tree.dart';
import 'package:rune_nexus/domain/gem/gem_type.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/research/research_progress.dart';
import 'package:rune_nexus/domain/research/research_type.dart';
import 'package:rune_nexus/domain/turret/turret_target_priority.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/turret_module/turret_module_type.dart';
import 'package:rune_nexus/game/game_snapshot.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';
import 'package:rune_nexus/l10n/rune_nexus_localizations.dart';
import 'package:rune_nexus/ui/menu/main_menu_screen.dart';

export 'package:flutter/foundation.dart';
export 'package:flutter/gestures.dart';
export 'package:flutter/material.dart';
export 'package:flutter_localizations/flutter_localizations.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:rune_nexus/app/rune_nexus_app.dart';
export 'package:rune_nexus/data/definitions/game_core_passive_tree_data.dart';
export 'package:rune_nexus/data/definitions/game_stage_maps.dart';
export 'package:rune_nexus/data/definitions/game_turret_module_data.dart';
export 'package:rune_nexus/data/save/game_save_data.dart';
export 'package:rune_nexus/data/save/save_repository.dart';
export 'package:rune_nexus/domain/combat/auto_start_mode.dart';
export 'package:rune_nexus/domain/combat/game_phase.dart';
export 'package:rune_nexus/domain/combat/run_panel_tab.dart';
export 'package:rune_nexus/domain/core/core_ability.dart';
export 'package:rune_nexus/domain/core/core_passive_tree.dart';
export 'package:rune_nexus/domain/gem/gem_type.dart';
export 'package:rune_nexus/domain/map/grid_point.dart';
export 'package:rune_nexus/domain/research/research_progress.dart';
export 'package:rune_nexus/domain/research/research_type.dart';
export 'package:rune_nexus/domain/turret/turret_target_priority.dart';
export 'package:rune_nexus/domain/turret/turret_trait_type.dart';
export 'package:rune_nexus/domain/turret/turret_type.dart';
export 'package:rune_nexus/domain/turret_module/turret_module_type.dart';
export 'package:rune_nexus/game/game_snapshot.dart';
export 'package:rune_nexus/game/rune_nexus_game.dart';
export 'package:rune_nexus/game/systems/game_save_adapter.dart';
export 'package:rune_nexus/game/systems/run_progression.dart';
export 'package:rune_nexus/l10n/rune_nexus_localizations.dart';
export 'package:rune_nexus/ui/game/core_ability_icon.dart';
export 'package:rune_nexus/ui/game/game_button.dart';
export 'package:rune_nexus/ui/game/game_icons.dart';
export 'package:rune_nexus/ui/game/research_icon.dart';
export 'package:rune_nexus/ui/game/upgrade_icon.dart';
export 'package:rune_nexus/ui/hud/core_info_panel.dart';
export 'package:rune_nexus/ui/hud/game_hud.dart';
export 'package:rune_nexus/ui/hud/reward_overlay.dart';
export 'package:rune_nexus/ui/menu/main_menu_screen.dart';
export 'package:rune_nexus/ui/menu/map_editor_panel.dart';
export 'package:rune_nexus/ui/menu/result_overlay.dart';

Widget coreTreeTestApp(
  RuneNexusGame game,
  ValueListenable<GameSnapshot> snapshots,
) {
  return MaterialApp(
    locale: const Locale('ko'),
    localizationsDelegates: const [
      RuneNexusLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: RuneNexusLocalizations.supportedLocales,
    home: MainMenuScreen(
      game: game,
      snapshot: snapshots.value,
      snapshotListenable: snapshots,
      selectedTab: MainMenuTab.core,
      onSelectTab: (_) {},
      onStartStage: (_) {},
    ),
  );
}

Future<void> pumpLoadedApp(WidgetTester tester) async {
  await tester.pumpWidget(
    RuneNexusApp(game: RuneNexusGame(saveRepository: MemorySaveRepository())),
  );
  await pumpUntilLoadedApp(tester);
}

Future<void> pumpUntilLoadedApp(
  WidgetTester tester, {
  int maxFrameCount = 100,
}) async {
  for (var i = 0; i < maxFrameCount; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    if (find.byType(MainMenuScreen).evaluate().isNotEmpty) {
      return;
    }
  }
  fail('앱 초기 로딩이 완료되지 않았습니다.');
}

Offset tabLeadingEdge(WidgetTester tester, String key) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  return Offset(rect.left + 8, rect.center.dy);
}

Finder stageChipText(String text) {
  return find.descendant(
    of: find.byType(ChoiceChip),
    matching: find.text(text),
  );
}

Future<void> tapStageCard(WidgetTester tester, String stageName) async {
  final stageNumber = RegExp(r'\d+').firstMatch(stageName)?.group(0);
  expect(stageNumber, isNotNull);
  final row = find.byKey(ValueKey('stage-selection-row-$stageNumber'));
  if (row.evaluate().isNotEmpty) {
    await tester.tap(row);
  } else {
    await tester.tap(find.text(stageName).first);
  }
  await tester.pump();
}

Future<void> pumpGameFrames(WidgetTester tester, {int frameCount = 3}) async {
  for (var i = 0; i < frameCount; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxFrameCount = 60,
}) async {
  for (var i = 0; i < maxFrameCount; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('앱 초기 로딩이 완료되지 않았습니다.');
}

GameSnapshot resultSnapshot({
  required GamePhase phase,
  required int currentStageNumber,
  int unlockedStageCount = 1,
  bool hasStageProgress = false,
  int completedRounds = 0,
  int runes = 0,
  int diamonds = 0,
  int lastRunRuneReward = 0,
  int lastRunPreviousBestRound = 0,
  bool lastRunWasNewBestRound = false,
  int? lastRunUnlockedStageNumber,
  bool lastRunUnlockedSniperTurret = false,
  Map<int, int> bestRoundsByStage = const {},
  Set<int> clearedStageNumbers = const {},
  int killGoldUpgradeLevel = 0,
  double killGoldProgressionBonusRate = 0,
  int criticalChanceUpgradeLevel = 0,
  int criticalChanceUpgradeCost = 70,
  bool canUpgradeCriticalChance = false,
  double criticalChanceProgressionBonusRate = 0,
  int criticalDamageUpgradeLevel = 0,
  int criticalDamageUpgradeCost = 60,
  bool canUpgradeCriticalDamage = false,
  double criticalDamageProgressionBonusRate = 0,
  int nexusHpUpgradeLevel = 0,
  int fireTrainingUpgradeLevel = 0,
  double fireTrainingDamageBonusRate = 0,
  int physicalDamageTrainingUpgradeLevel = 0,
  double physicalDamageTrainingBonusRate = 0,
  int elementalDamageTrainingUpgradeLevel = 0,
  double elementalDamageTrainingBonusRate = 0,
  int emergencySaleUpgradeLevel = 0,
  int emergencySaleUpgradeCost = 80,
  bool canUpgradeEmergencySale = false,
  int turretRefundPercent = 75,
  int linkCostOptimizationUpgradeLevel = 0,
  int linkCostOptimizationUpgradeCost = 70,
  bool canUpgradeLinkCostOptimization = false,
  int turretLevelUpOptimizationUpgradeLevel = 0,
  int turretLevelUpOptimizationUpgradeCost = 70,
  bool canUpgradeTurretLevelUpOptimization = false,
  List<ResearchProgress> activeResearches = const [],
  Map<ResearchType, int> researchLevels = const {},
  bool researchSlotTwoUnlocked = false,
  CoreCombatSkill? coreCombatSkill = CoreCombatSkill.guardianBeam,
  int totalCorePoints = 0,
  int spentCorePoints = 0,
  int availableCorePoints = 0,
  int lastRunCorePointReward = 0,
  int lastRunTurretModuleTicketReward = 0,
  Map<CorePassiveNodeId, int> corePassiveNodeRanks = const {},
  GridPoint? selectedCorePoint,
  double nexusCoreBeamDamage = 0,
  double coreCombatSkillDirectDamageDealt = 0,
  double coreCombatSkillBonusDamageDealt = 0,
  int coreCombatSkillActivationCount = 0,
  int turretModuleTickets = 0,
  int turretModuleDrawCount = 0,
  List<TurretModuleInventoryItem> ownedTurretModules = const [],
  int gemShards = 0,
  List<GemType> rewardOptions = const [],
  Map<GemType, int> gemCollection = const {},
}) {
  return GameSnapshot(
    gold: 0,
    gemShards: gemShards,
    nexusHp: 0,
    maxNexusHp: 20,
    round: completedRounds,
    maxRound: 40,
    phase: phase,
    restoredPhase: null,
    hasStageProgress: hasStageProgress,
    placedTurretCount: 0,
    currentStageNumber: currentStageNumber,
    unlockedStageCount: unlockedStageCount,
    bestRoundsByStage: bestRoundsByStage,
    clearedStageNumbers: clearedStageNumbers,
    availableTurretTypes: [
      TurretType.arrow,
      TurretType.cannon,
      TurretType.magic,
      TurretType.frost,
      if (clearedStageNumbers.contains(3)) TurretType.sniper,
      if (clearedStageNumbers.contains(6)) TurretType.lightning,
    ],
    selectedTurretType: TurretType.arrow,
    selectedRunPanelTab: RunPanelTab.turrets,
    previewText: '',
    rewardOptions: rewardOptions,
    isPurchasedGemReward: false,
    gemInventory: const {},
    gemCollection: gemCollection,
    selectedBuildPoint: null,
    selectedBuildTurretType: null,
    selectedPortalPoint: null,
    selectedCorePoint: selectedCorePoint,
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
    selectedTurretPrimaryTraitCost: 12,
    selectedTurretSecondaryTraitCost: 24,
    selectedTurretPrimaryTraitRequiredLevel: 3,
    selectedTurretSecondaryTraitRequiredLevel: 7,
    topDamageTurretName: null,
    topDamageTurretDamageDealt: 0,
    totalTurretDps: 0,
    nexusCoreBeamIntervalSeconds: 5,
    nexusCoreBeamCooldownSeconds: 5,
    nexusCoreBeamAvailable: true,
    nexusCoreBeamActive: false,
    nexusCoreBeamDamage: nexusCoreBeamDamage,
    coreCombatSkillDirectDamageDealt: coreCombatSkillDirectDamageDealt,
    coreCombatSkillBonusDamageDealt: coreCombatSkillBonusDamageDealt,
    coreCombatSkillActivationCount: coreCombatSkillActivationCount,
    coreCombatSkill: coreCombatSkill,
    totalCorePoints: totalCorePoints,
    spentCorePoints: spentCorePoints,
    availableCorePoints: availableCorePoints == 0 && totalCorePoints > 0
        ? totalCorePoints - spentCorePoints
        : availableCorePoints,
    lastRunCorePointReward: lastRunCorePointReward,
    lastRunTurretModuleTicketReward: lastRunTurretModuleTicketReward,
    corePassiveNodeRanks: corePassiveNodeRanks,
    nextWaveEnemyTypes: const [],
    nextWaveEnemyCounts: const {},
    nextWaveClearRewardGold: 0,
    nextWaveKillRewardGold: 0,
    nextWaveClearRewardGemShards: 0,
    autoStartMode: AutoStartMode.pauseEachRound,
    speedMultiplier: 1,
    killGoldFractionWallet: 0,
    runUpgradeLevels: const {},
    towerDamageRunBonusRate: 0,
    killGoldRunBonusRate: 0,
    waveClearGoldRunBonus: 0,
    runes: runes,
    diamonds: diamonds,
    turretModuleTickets: turretModuleTickets,
    turretModuleDrawCount: turretModuleDrawCount,
    ownedTurretModules: ownedTurretModules,
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
    lastRunRuneReward: lastRunRuneReward,
    projectedFailureRuneReward: completedRounds * 2,
    lastRunPreviousBestRound: lastRunPreviousBestRound,
    lastRunWasNewBestRound: lastRunWasNewBestRound,
    lastRunUnlockedStageNumber: lastRunUnlockedStageNumber,
    lastRunUnlockedSniperTurret: lastRunUnlockedSniperTurret,
    completedRounds: completedRounds,
    startingGoldUpgradeLevel: 0,
    startingGoldUpgradeCost: 4,
    canUpgradeStartingGold: false,
    nexusHpUpgradeLevel: nexusHpUpgradeLevel,
    nexusHpUpgradeCost: 14,
    canUpgradeNexusHp: false,
    supplyUpgradeLevel: 0,
    supplyUpgradeCost: 7,
    canUpgradeSupply: false,
    waveClearGoldProgressionBonus: 0,
    fireTrainingUpgradeLevel: fireTrainingUpgradeLevel,
    fireTrainingUpgradeCost: 7,
    canUpgradeFireTraining: false,
    fireTrainingDamageBonusRate: fireTrainingDamageBonusRate,
    physicalDamageTrainingUpgradeLevel: physicalDamageTrainingUpgradeLevel,
    physicalDamageTrainingUpgradeCost:
        RunProgression.familyDamageTrainingUpgradeBaseCost,
    canUpgradePhysicalDamageTraining: false,
    physicalDamageTrainingBonusRate: physicalDamageTrainingBonusRate,
    elementalDamageTrainingUpgradeLevel: elementalDamageTrainingUpgradeLevel,
    elementalDamageTrainingUpgradeCost:
        RunProgression.familyDamageTrainingUpgradeBaseCost,
    canUpgradeElementalDamageTraining: false,
    elementalDamageTrainingBonusRate: elementalDamageTrainingBonusRate,
    criticalChanceUpgradeLevel: criticalChanceUpgradeLevel,
    criticalChanceUpgradeCost: criticalChanceUpgradeCost,
    canUpgradeCriticalChance: canUpgradeCriticalChance,
    criticalChanceProgressionBonusRate: criticalChanceProgressionBonusRate,
    criticalDamageUpgradeLevel: criticalDamageUpgradeLevel,
    criticalDamageUpgradeCost: criticalDamageUpgradeCost,
    canUpgradeCriticalDamage: canUpgradeCriticalDamage,
    criticalDamageProgressionBonusRate: criticalDamageProgressionBonusRate,
    killGoldUpgradeLevel: killGoldUpgradeLevel,
    killGoldUpgradeCost: 7,
    canUpgradeKillGold: false,
    killGoldProgressionBonusRate: killGoldProgressionBonusRate,
    emergencySaleUpgradeLevel: emergencySaleUpgradeLevel,
    emergencySaleUpgradeCost: emergencySaleUpgradeCost,
    canUpgradeEmergencySale: canUpgradeEmergencySale,
    turretRefundPercent: turretRefundPercent,
    linkCostOptimizationUpgradeLevel: linkCostOptimizationUpgradeLevel,
    linkCostOptimizationUpgradeCost: linkCostOptimizationUpgradeCost,
    canUpgradeLinkCostOptimization: canUpgradeLinkCostOptimization,
    turretLevelUpOptimizationUpgradeLevel:
        turretLevelUpOptimizationUpgradeLevel,
    turretLevelUpOptimizationUpgradeCost: turretLevelUpOptimizationUpgradeCost,
    canUpgradeTurretLevelUpOptimization: canUpgradeTurretLevelUpOptimization,
    researchSlotCount: researchSlotTwoUnlocked ? 2 : 1,
    researchLevels: researchLevels,
    researchElapsedMillis: const {},
    activeResearches: activeResearches,
    startingGemShards: 0,
  );
}

class ResearchRefreshGame extends RuneNexusGame {
  ResearchRefreshGame() : super(saveRepository: MemorySaveRepository());

  int researchRefreshCount = 0;

  @override
  bool refreshResearchProgress() {
    researchRefreshCount += 1;
    return true;
  }
}

class ResearchInstantCompleteGame extends RuneNexusGame {
  ResearchInstantCompleteGame() : super(saveRepository: MemorySaveRepository());

  ResearchType? completedResearchType;

  @override
  void completeResearchWithDiamonds(ResearchType type) {
    completedResearchType = type;
  }
}

class ResearchSlotUnlockGame extends RuneNexusGame {
  ResearchSlotUnlockGame() : super(saveRepository: MemorySaveRepository());

  bool unlockedResearchSlotTwo = false;

  @override
  bool unlockResearchSlotTwo() {
    unlockedResearchSlotTwo = true;
    return true;
  }
}

class CoreEquipGame extends RuneNexusGame {
  CoreEquipGame() : super(saveRepository: MemorySaveRepository());

  CoreCombatSkill? equippedCombatSkill;
  bool unequippedCombatSkill = false;
  Map<CorePassiveNodeId, int>? assignedCorePassiveRanks;
  int corePassiveBatchAssignmentCount = 0;

  @override
  bool equipCoreCombatSkill(CoreCombatSkill skill) {
    equippedCombatSkill = skill;
    return true;
  }

  @override
  bool unequipCoreCombatSkill() {
    unequippedCombatSkill = true;
    return true;
  }

  @override
  bool setCorePassiveNodeRanks(Map<CorePassiveNodeId, int> ranks) {
    assignedCorePassiveRanks = Map.unmodifiable(ranks);
    corePassiveBatchAssignmentCount += 1;
    return true;
  }
}

class CoreTreeGame extends RuneNexusGame {
  CoreTreeGame(this.snapshots) : super(saveRepository: MemorySaveRepository());

  final ValueNotifier<GameSnapshot> snapshots;
  Map<CorePassiveNodeId, int>? lastAssignedCorePassiveRanks;
  int corePassiveBatchAssignmentCount = 0;

  @override
  bool setCorePassiveNodeRanks(Map<CorePassiveNodeId, int> ranks) {
    lastAssignedCorePassiveRanks = Map.unmodifiable(ranks);
    corePassiveBatchAssignmentCount += 1;
    final current = snapshots.value;
    _publishRanks(current.totalCorePoints, ranks);
    return true;
  }

  @override
  bool resetCorePassiveTree() {
    _publishRanks(snapshots.value.totalCorePoints, const {});
    return true;
  }

  void _publishRanks(int totalCorePoints, Map<CorePassiveNodeId, int> ranks) {
    final spentCorePoints = corePassiveSpentPoints(ranks);
    snapshots.value = resultSnapshot(
      phase: GamePhase.preparation,
      currentStageNumber: 1,
      totalCorePoints: totalCorePoints,
      spentCorePoints: spentCorePoints,
      availableCorePoints: totalCorePoints - spentCorePoints,
      corePassiveNodeRanks: Map.unmodifiable(ranks),
    );
  }
}

class TurretModuleDrawGame extends RuneNexusGame {
  TurretModuleDrawGame() : super(saveRepository: MemorySaveRepository());

  int? drawCount;
  TurretType? requestedTurretType;
  bool? boughtMissingTicketsWithDiamonds;

  static final List<TurretModuleInventoryItem> results = [
    TurretModuleInventoryItem(
      id: 'test-module-1',
      key: TurretModuleKey(
        turretType: TurretType.arrow,
        part: TurretModulePart.core,
        family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.core),
        grade: TurretModuleGrade.normal,
      ),
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.damageIncrease,
          value: 5,
        ),
      ],
      acquiredOrder: 1,
      equipped: false,
    ),
    TurretModuleInventoryItem(
      id: 'test-module-2',
      key: TurretModuleKey(
        turretType: TurretType.cannon,
        part: TurretModulePart.barrel,
        family: turretModuleFamilyFor(
          TurretType.cannon,
          TurretModulePart.barrel,
        ),
        grade: TurretModuleGrade.magic,
      ),
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.attackRateIncrease,
          value: 5,
        ),
      ],
      acquiredOrder: 2,
      equipped: false,
    ),
    TurretModuleInventoryItem(
      id: 'test-module-3',
      key: TurretModuleKey(
        turretType: TurretType.magic,
        part: TurretModulePart.frame,
        family: turretModuleFamilyFor(TurretType.magic, TurretModulePart.frame),
        grade: TurretModuleGrade.rare,
      ),
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.levelUpCostDiscount,
          value: 10,
        ),
      ],
      acquiredOrder: 3,
      equipped: false,
    ),
    TurretModuleInventoryItem(
      id: 'test-module-4',
      key: TurretModuleKey(
        turretType: TurretType.frost,
        part: TurretModulePart.core,
        family: turretModuleFamilyFor(TurretType.frost, TurretModulePart.core),
        grade: TurretModuleGrade.normal,
      ),
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.slowDurationIncrease,
          value: 4,
        ),
      ],
      acquiredOrder: 4,
      equipped: false,
    ),
    TurretModuleInventoryItem(
      id: 'test-module-5',
      key: TurretModuleKey(
        turretType: TurretType.arrow,
        part: TurretModulePart.frame,
        family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.frame),
        grade: TurretModuleGrade.magic,
      ),
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.buildCostDiscount,
          value: 6,
        ),
      ],
      acquiredOrder: 5,
      equipped: false,
    ),
  ];

  @override
  List<TurretModuleInventoryItem> drawTurretModules(
    int count, {
    TurretType? turretType,
    bool buyMissingTicketsWithDiamonds = false,
  }) {
    drawCount = count;
    requestedTurretType = turretType;
    boughtMissingTicketsWithDiamonds = buyMissingTicketsWithDiamonds;
    snapshotNotifier.value = resultSnapshot(
      phase: GamePhase.preparation,
      currentStageNumber: 1,
      diamonds: 0,
      turretModuleTickets: 0,
      turretModuleDrawCount:
          snapshotNotifier.value.turretModuleDrawCount + count,
      ownedTurretModules: results,
    );
    return results;
  }
}

class TurretModuleDisassembleGame extends RuneNexusGame {
  TurretModuleDisassembleGame() : super(saveRepository: MemorySaveRepository());

  String? disassembledId;
  Set<String>? bulkDisassembledIds;

  @override
  bool disassembleTurretModule(String id) {
    disassembledId = id;
    return true;
  }

  @override
  int disassembleTurretModules(Iterable<String> ids) {
    bulkDisassembledIds = ids.toSet();
    return bulkDisassembledIds!.length;
  }
}

GameSaveData saveWithResearch({
  required Set<int> clearedStageNumbers,
  required Map<ResearchType, int> researchLevels,
  int gold = 170,
  int gemShards = 0,
  int roundIndex = 0,
  GamePhase phase = GamePhase.preparation,
  String? mapSignature,
  int linkCostOptimizationUpgradeLevel = 0,
  int turretLevelUpOptimizationUpgradeLevel = 0,
}) {
  return GameSaveData(
    version: GameSaveData.currentVersion,
    savedAtMillis: 0,
    gold: gold,
    gemShards: gemShards,
    nexusHp: 20,
    stageNumber: 1,
    mapSignature: mapSignature,
    roundIndex: roundIndex,
    completedRounds: 0,
    phase: phase,
    autoStartMode: AutoStartMode.pauseEachRound,
    progression: SavedProgression(
      runes: 0,
      lastRunRuneReward: 0,
      startingGoldUpgradeLevel: 0,
      nexusHpUpgradeLevel: 0,
      supplyUpgradeLevel: 0,
      fireTrainingUpgradeLevel: 0,
      criticalChanceUpgradeLevel: 0,
      criticalDamageUpgradeLevel: 0,
      killGoldUpgradeLevel: 0,
      emergencySaleUpgradeLevel: 0,
      linkCostOptimizationUpgradeLevel: linkCostOptimizationUpgradeLevel,
      turretLevelUpOptimizationUpgradeLevel:
          turretLevelUpOptimizationUpgradeLevel,
      unlockedStageCount: 4,
      bestRoundsByStage: const {},
      clearedStageNumbers: clearedStageNumbers,
      researchLevels: researchLevels,
      researchElapsedMillis: const {},
      activeResearches: const [],
    ),
    runUpgradeLevels: const {},
    killGoldFractionWallet: 0,
    gemInventory: const {},
    rewardOptions: const [],
    isPurchasedGemReward: false,
    turrets: const [],
    enemies: const [],
    spawnQueue: const [],
  );
}
