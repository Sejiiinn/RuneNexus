import 'dart:math' as math;

import 'package:flame/events.dart' show TapDownEvent;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_enemy_data.dart';
import 'package:rune_nexus/data/definitions/game_stage_data.dart';
import 'package:rune_nexus/data/definitions/game_turret_data.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/domain/combat/auto_start_mode.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
import 'package:rune_nexus/domain/core/core_ability.dart';
import 'package:rune_nexus/domain/core/core_passive_tree.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/domain/gem/gem_type.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/map/map_definition.dart';
import 'package:rune_nexus/domain/map/tile_type.dart';
import 'package:rune_nexus/domain/research/research_type.dart';
import 'package:rune_nexus/domain/run_upgrade/run_upgrade_type.dart';
import 'package:rune_nexus/domain/turret/attack_tag.dart';
import 'package:rune_nexus/domain/turret/damage_family.dart';
import 'package:rune_nexus/domain/turret/turret_definition.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/turret_module/turret_module_type.dart';
import 'package:rune_nexus/domain/wave/wave_definition.dart';
import 'package:rune_nexus/game/components/enemy_component.dart';
import 'package:rune_nexus/game/components/turret_component.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/game/systems/game_save_adapter.dart';

export 'package:flame/events.dart' show TapDownEvent;
export 'package:flame/game.dart' show GameWidget, Vector2;
export 'package:flutter/material.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:rune_nexus/data/definitions/game_core_passive_tree_data.dart';
export 'package:rune_nexus/data/definitions/game_daily_quest_data.dart';
export 'package:rune_nexus/data/definitions/game_enemy_data.dart';
export 'package:rune_nexus/data/definitions/game_run_upgrade_data.dart';
export 'package:rune_nexus/data/definitions/game_stage_data.dart';
export 'package:rune_nexus/data/definitions/game_turret_data.dart';
export 'package:rune_nexus/data/definitions/game_weekly_quest_data.dart';
export 'package:rune_nexus/data/save/game_save_data.dart';
export 'package:rune_nexus/data/save/save_repository.dart';
export 'package:rune_nexus/domain/combat/auto_start_mode.dart';
export 'package:rune_nexus/domain/combat/game_phase.dart';
export 'package:rune_nexus/domain/combat/run_panel_tab.dart';
export 'package:rune_nexus/domain/core/core_ability.dart';
export 'package:rune_nexus/domain/core/core_passive_tree.dart';
export 'package:rune_nexus/domain/daily_quest/daily_quest_type.dart';
export 'package:rune_nexus/domain/enemy/enemy_definition.dart';
export 'package:rune_nexus/domain/enemy/enemy_resistance_profile.dart';
export 'package:rune_nexus/domain/enemy/enemy_scaling.dart';
export 'package:rune_nexus/domain/enemy/enemy_type.dart';
export 'package:rune_nexus/domain/gem/gem_equip_rules.dart';
export 'package:rune_nexus/domain/gem/gem_type.dart';
export 'package:rune_nexus/domain/map/grid_point.dart';
export 'package:rune_nexus/domain/map/map_definition.dart';
export 'package:rune_nexus/domain/map/map_tile_theme.dart';
export 'package:rune_nexus/domain/map/tile_type.dart';
export 'package:rune_nexus/domain/research/research_progress.dart';
export 'package:rune_nexus/domain/research/research_type.dart';
export 'package:rune_nexus/domain/run_upgrade/run_upgrade_type.dart';
export 'package:rune_nexus/domain/stage/stage_definition.dart';
export 'package:rune_nexus/domain/turret/attack_tag.dart';
export 'package:rune_nexus/domain/turret/damage_family.dart';
export 'package:rune_nexus/domain/turret/turret_definition.dart';
export 'package:rune_nexus/domain/turret/turret_target_priority.dart';
export 'package:rune_nexus/domain/turret/turret_trait_type.dart';
export 'package:rune_nexus/domain/turret/turret_type.dart';
export 'package:rune_nexus/domain/turret_module/turret_module_type.dart';
export 'package:rune_nexus/domain/wave/wave_definition.dart';
export 'package:rune_nexus/game/components/chain_projectile_component.dart';
export 'package:rune_nexus/game/components/enemy_component.dart';
export 'package:rune_nexus/game/components/gem_equip_effect_component.dart';
export 'package:rune_nexus/game/components/lightning_charge_component.dart';
export 'package:rune_nexus/game/components/lightning_chain_beam_component.dart';
export 'package:rune_nexus/game/components/projectile_component.dart';
export 'package:rune_nexus/game/components/rift_mark_pulse_component.dart';
export 'package:rune_nexus/game/components/sequential_lightning_chain_component.dart';
export 'package:rune_nexus/game/components/sniper_chain_beam_component.dart';
export 'package:rune_nexus/game/components/turret_component.dart';
export 'package:rune_nexus/game/rune_nexus_game.dart';
export 'package:rune_nexus/game/systems/game_save_adapter.dart';
export 'package:rune_nexus/game/systems/gem_reward_generator.dart';
export 'package:rune_nexus/game/systems/run_progression.dart';
export 'package:rune_nexus/game/systems/wave_spawner.dart';

void tapBuildTile(RuneNexusGame game, GridPoint point) {
  final origin = game.debugBoardOrigin();
  final tileSize = game.debugBoardSize().x / gameMap.columns;
  final position = Offset(
    origin.x + (point.x + 0.5) * tileSize,
    origin.y + (point.y + 0.5) * tileSize,
  );
  final event = TapDownEvent(1, game, TapDownDetails(globalPosition: position))
    ..renderingTrace.add(Vector2(position.dx, position.dy));

  game.onTapDown(event);
}

class LinkResearchUnlockedGame extends RuneNexusGame {
  LinkResearchUnlockedGame({super.waves, super.saveRepository});

  @override
  int get maxTurretLinkSlotLimit => 4;
}

class FirstLinkDiscountGame extends RuneNexusGame {
  @override
  double get firstLinkUpgradeDiscountRate => 0.2;
}

class EfficiencyModuleGame extends RuneNexusGame {
  EfficiencyModuleGame({super.saveRepository});

  @override
  double get firstLinkUpgradeDiscountRate => 0.2;

  @override
  TurretModuleEffect turretModuleEffectFor(TurretType type) {
    return const TurretModuleEffect(
      buildCostDiscountRate: 0.5,
      gemEffectIncreaseRate: 0.2,
    );
  }
}

const maxEfficiencyPassiveRanks = <CorePassiveNodeId, int>{
  CorePassiveNodeId.efficiencySaving: 5,
  CorePassiveNodeId.efficiencySupplyRecovery: 5,
  CorePassiveNodeId.efficiencyFirstDeploy: 3,
  CorePassiveNodeId.efficiencyDiversity: 5,
  CorePassiveNodeId.efficiencyGemSpectrum: 5,
  CorePassiveNodeId.efficiencyFirstLink: 3,
  CorePassiveNodeId.efficiencyCombinedFront: 1,
};

const targetPriorityTestTurret = TurretDefinition(
  type: TurretType.sniper,
  name: 'Target Priority Test',
  cost: 0,
  damage: 10,
  range: 220,
  attackRate: 10,
  projectileSpeed: 0,
  description: 'test',
  damageFamily: DamageFamily.physical,
  attackTags: {AttackTag.heavy},
  color: Color(0xFFFFFFFF),
  instantHit: true,
  criticalChance: 0,
);

EnemyComponent targetPriorityEnemy({
  required RuneNexusGame game,
  required double hp,
  required double progress,
  required Vector2 position,
}) {
  return EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: hp,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    )
    ..position = position
    ..distanceTravelled = progress;
}

EnemyComponent durabilityEnemy(
  RuneNexusGame game, {
  required double hp,
  double armor = 0,
  required double progress,
}) {
  return EnemyComponent(
      definition: armor > 0
          ? gameEnemies[EnemyType.armored]!
          : gameEnemies[EnemyType.normal]!,
      maxHp: math.max(100, hp),
      maxArmor: armor,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    )
    ..hp = hp
    ..armor = armor
    ..distanceTravelled = progress;
}

EnemyComponent chainEnemy(
  RuneNexusGame game,
  Vector2 position,
  double progress,
) {
  return EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    )
    ..position = position
    ..distanceTravelled = progress;
}

TurretComponent levelSevenLightning(RuneNexusGame game) {
  final turret = TurretComponent(
    gridPoint: const GridPoint(0, 0),
    definition: gameTurrets[TurretType.lightning]!,
    game: game,
    center: Vector2.zero(),
    tileSize: 32,
  );
  for (var i = 0; i < 6; i++) {
    turret.upgradeLevel();
  }
  return turret;
}

void expectValidMapPath(MapDefinition map) {
  expect(map.path, isNotEmpty);
  expect(map.tileAt(map.path.first), TileType.spawn);
  expect(map.tileAt(map.path.last), TileType.core);
  for (var i = 0; i < map.path.length; i++) {
    final point = map.path[i];
    expect(map.contains(point), isTrue);
    expect(
      map.tileAt(point),
      isIn(const [TileType.path, TileType.spawn, TileType.core]),
    );
    if (i == 0) {
      continue;
    }
    final previous = map.path[i - 1];
    final distance =
        (point.x - previous.x).abs() + (point.y - previous.y).abs();
    expect(distance, 1);
  }
}

GameSaveData saveWithResearch({
  required Set<int> clearedStageNumbers,
  required Map<ResearchType, int> researchLevels,
  int runes = 0,
  int gold = 170,
  int unlockedStageCount = 4,
  int gemShards = 0,
  int roundIndex = 0,
  Map<RunUpgradeType, int> runUpgradeLevels = const {},
  GamePhase phase = GamePhase.preparation,
  bool isPurchasedGemReward = false,
  GamePhase? rewardReturnPhase,
  List<GemType> rewardOptions = const [],
  String? mapSignature,
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
      runes: runes,
      lastRunRuneReward: 0,
      startingGoldUpgradeLevel: 0,
      nexusHpUpgradeLevel: 0,
      supplyUpgradeLevel: 0,
      fireTrainingUpgradeLevel: 0,
      criticalChanceUpgradeLevel: 0,
      criticalDamageUpgradeLevel: 0,
      killGoldUpgradeLevel: 0,
      emergencySaleUpgradeLevel: 0,
      unlockedStageCount: unlockedStageCount,
      bestRoundsByStage: const {},
      clearedStageNumbers: clearedStageNumbers,
      researchLevels: researchLevels,
      researchElapsedMillis: const {},
      activeResearches: const [],
    ),
    runUpgradeLevels: runUpgradeLevels,
    killGoldFractionWallet: 0,
    gemInventory: const {},
    rewardOptions: rewardOptions,
    isPurchasedGemReward: isPurchasedGemReward,
    rewardReturnPhase: rewardReturnPhase,
    turrets: const [],
    enemies: const [],
    spawnQueue: const [],
  );
}

List<WaveDefinition> emptyWaves(int count) {
  return List<WaveDefinition>.generate(
    count,
    (index) => WaveDefinition(
      round: index + 1,
      previewText: 'empty ${index + 1}',
      groups: const [],
      clearRewardGold: 0,
    ),
  );
}

GameSaveData saveWithCorePassiveRun({
  required double nexusHp,
  required int roundIndex,
  required int completedRounds,
  int gold = 170,
  int gemShards = 0,
  int unlockedStageCount = 1,
  Set<int> clearedStageNumbers = const {},
  CoreCombatSkill? coreCombatSkill = CoreCombatSkill.guardianBeam,
  int totalCorePoints = 0,
  Map<CorePassiveNodeId, int> corePassiveNodeRanks = const {},
  Set<int> claimedCorePointStageRewards = const {},
  SavedCoreCombatSkillStats coreCombatSkillStats =
      SavedCoreCombatSkillStats.empty,
  double roundNexusHpLost = 0,
  bool emergencyChargeUsedThisRound = false,
  bool finalDefenseUsedThisRound = false,
  GamePhase phase = GamePhase.preparation,
  int supplyUpgradeLevel = 0,
  Map<RunUpgradeType, int> runUpgradeLevels = const {},
}) {
  return GameSaveData(
    version: GameSaveData.currentVersion,
    savedAtMillis: 0,
    gold: gold,
    gemShards: gemShards,
    nexusHp: nexusHp,
    stageNumber: 1,
    mapSignature: const GameSaveAdapter().mapSignature(gameMap),
    roundIndex: roundIndex,
    completedRounds: completedRounds,
    phase: phase,
    autoStartMode: AutoStartMode.pauseEachRound,
    progression: SavedProgression(
      runes: 0,
      lastRunRuneReward: 0,
      startingGoldUpgradeLevel: 0,
      nexusHpUpgradeLevel: 0,
      supplyUpgradeLevel: supplyUpgradeLevel,
      fireTrainingUpgradeLevel: 0,
      criticalChanceUpgradeLevel: 0,
      criticalDamageUpgradeLevel: 0,
      killGoldUpgradeLevel: 0,
      emergencySaleUpgradeLevel: 0,
      unlockedStageCount: unlockedStageCount,
      bestRoundsByStage: const {},
      clearedStageNumbers: clearedStageNumbers,
      researchLevels: const {},
      researchElapsedMillis: const {},
      activeResearches: const [],
      coreCombatSkill: coreCombatSkill,
      totalCorePoints: totalCorePoints,
      corePassiveNodeRanks: corePassiveNodeRanks,
      claimedCorePointStageRewards: claimedCorePointStageRewards,
    ),
    runUpgradeLevels: runUpgradeLevels,
    killGoldFractionWallet: 0,
    gemInventory: const {},
    rewardOptions: const [],
    isPurchasedGemReward: false,
    runCoreCombatSkill: coreCombatSkill,
    runCoreCombatSkillStats: coreCombatSkillStats,
    roundNexusHpLost: roundNexusHpLost,
    emergencyChargeUsedThisRound: emergencyChargeUsedThisRound,
    finalDefenseUsedThisRound: finalDefenseUsedThisRound,
    turrets: const [],
    enemies: const [],
    spawnQueue: const [],
  );
}
