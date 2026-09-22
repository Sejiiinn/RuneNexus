// Temporary build-time bridge. Gameplay definitions remain the single source.
// Run through Flutter tests because the definitions use Flutter Color types.
import 'package:rune_nexus/domain/combat/content_spawn_defaults.dart';
import 'package:rune_nexus/domain/enemy/diamond_carrier_rules.dart';
import 'dart:convert';
import 'package:vector_math/vector_math_64.dart';
import 'package:rune_nexus/data/definitions/game_enemy_data.dart';
import 'package:rune_nexus/data/definitions/game_core_passive_tree_data.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';
import '../combat/turret_stat_fixture.dart';
import 'package:rune_nexus/data/definitions/game_stage_data.dart';
import 'package:rune_nexus/data/definitions/game_turret_data.dart';
import 'package:rune_nexus/domain/enemy/enemy_scaling.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/game/components/enemy_component.dart';
import 'package:rune_nexus/game/components/turret_component.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/game/systems/wave_spawner.dart';

const contentOutputPath = 'godot/content/game_content.json';

Map<String, Object?> contentEnemyState(
  RuneNexusGame game,
  EnemyType type, {
  int stageNumber = 1,
  int round = 1,
  int id = 0,
  double tileSize = 48,
  double laneOffsetRatio = 0,
  double visualPhase = 0,
  int diamondReward = 0,
  List<Vector2>? path,
}) {
  final definition = gameEnemies[type]!;
  final points = path ?? [Vector2.zero(), Vector2(48, 0)];
  final enemy = EnemyComponent(
    definition: definition,
    maxHp: scaledEnemyMaxHp(definition, round, stageNumber: stageNumber),
    maxShield: scaledEnemyMaxShield(
      definition,
      round,
      stageNumber: stageNumber,
    ),
    maxArmor: scaledEnemyMaxArmor(definition, round, stageNumber: stageNumber),
    path: points,
    laneOffsetRatio: laneOffsetRatio,
    visualPhase: visualPhase,
    diamondReward: diamondReward,
    game: game,
  )..updateLayout(tileSize: tileSize, newPath: points);
  return {
    ...enemy.nativeCombatState(id),
    'coreDamage': definition.coreDamage,
    'isDebug': false,
  };
}

Map<String, Object?> exportGameContent() {
  // No onLoad: no persistence, platform APIs, assets, or random rolls are used.
  final game = RuneNexusGame();
  return {
    'schemaVersion': 1,
    'units': {'tileSize': 48.0, 'boardDistanceScale': 1.0, 'time': 'seconds'},
    'defaults': {
      'portalAlertDuration': portalAlertDuration,
      'postPortalAlertSpawnDelay': postPortalAlertSpawnDelay,
      'initialDelay': portalAlertDuration + postPortalAlertSpawnDelay,
    },
    'randomization': {
      'laneOffsetAmplitudes': {
        for (final type in gameEnemies.keys)
          type.name: enemyLaneOffsetAmplitude(type),
      },
      'carrierChance': DiamondCarrierRules.carrierChance,
      'oneDiamondChanceGivenCarrier':
          DiamondCarrierRules.oneDiamondChanceGivenCarrier,
      'twoDiamondChanceGivenCarrier':
          DiamondCarrierRules.twoDiamondChanceGivenCarrier,
      'threeDiamondChanceGivenCarrier':
          DiamondCarrierRules.threeDiamondChanceGivenCarrier,
      'bossTypes': [
        for (final type in gameEnemies.keys)
          if (type.isBoss) type.name,
      ],
    },
    'defenseConfig': {
      'maxHp':
          RunProgression.baseNexusHp.toDouble() *
          corePassiveNexusMaxHpMultiplier({}),
      'impactDispersionRate':
          1 - corePassiveNexusDamageMultiplier({}, lostDurabilityRatio: 0),
      'threatWeakeningRate':
          1 -
          corePassiveNexusDamageMultiplier({}, lostDurabilityRatio: 1) /
              corePassiveNexusDamageMultiplier({}, lostDurabilityRatio: 0),
      'hasFinalDefense': corePassiveHasFinalDefense({}),
      'emergencyRecoveryRate': corePassiveEmergencyChargeRecoveryRate({}),
      'roundRecoveryRate': corePassiveRoundRecoveryRate({}),
      'damageRestorationRate': corePassiveDamageRestorationRate({}),
    },
    'enemyDefinitions': {
      for (final entry in gameEnemies.entries)
        entry.key.name: {
          'name': entry.value.name,
          'maxHp': entry.value.maxHp,
          'maxShield': entry.value.maxShield,
          'maxArmor': entry.value.maxArmor,
          'speed': entry.value.speed,
          'shieldRegenRate': entry.value.shieldRegenRate,
          'rewardGold': entry.value.rewardGold,
          'coreDamage': entry.value.coreDamage,
          'color': entry.value.color.toARGB32(),
          'isBoss': entry.key.isBoss,
        },
    },
    'enemies': {
      for (final entry in gameEnemies.entries)
        entry.key.name: {
          ...contentEnemyState(game, entry.key),
          'name': entry.value.name,
          'color': entry.value.color.toARGB32(),
          'rewardGold': entry.value.rewardGold,
        },
    },
    'turrets': {
      for (final entry in gameTurrets.entries)
        entry.key.name: {
          'name': entry.value.name,
          'cost': entry.value.cost,
          'configuration': TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: entry.value,
            game: game,
            center: Vector2(24, 24),
            tileSize: 48,
          ).nativeCombatConfiguration(0),
        },
    },
    'stages': [
      for (final stage in gameStages)
        {
          'id': stage.id,
          'name': stage.name,
          'firstClearCorePointReward': stage.firstClearCorePointReward,
          'firstClearTurretModuleTicketReward':
              stage.firstClearTurretModuleTicketReward,
          'map': {
            'columns': stage.map.columns,
            'rows': stage.map.rows,
            'tileTheme': stage.map.tileTheme.kind.name,
            'tiles': [
              for (final row in stage.map.tiles)
                for (final tile in row) tile.name,
            ],
            'path': [
              for (final point in stage.map.path) [point.x, point.y],
            ],
          },
          'waves': [
            for (final wave in stage.waves)
              {
                'round': wave.round,
                'previewText': wave.previewText,
                'clearRewardGold': wave.clearRewardGold,
                'groups': [
                  for (final group in wave.groups)
                    {
                      'enemyType': group.enemyType.name,
                      'count': group.count,
                      'interval': group.interval,
                      'startDelay': group.startDelay,
                      'startAfterPrevious': group.startAfterPrevious,
                      'followDelay': group.followDelay,
                    },
                ],
                'spawnQueue': [
                  for (final request
                      in (WaveSpawner()..start(wave)).toSaveData())
                    request.toJson(),
                ],
                'enemyDurability': {
                  for (final entry in gameEnemies.entries)
                    entry.key.name: {
                      'maxHp': scaledEnemyMaxHp(
                        entry.value,
                        wave.round,
                        stageNumber: stage.id,
                      ),
                      'maxShield': scaledEnemyMaxShield(
                        entry.value,
                        wave.round,
                        stageNumber: stage.id,
                      ),
                      'maxArmor': scaledEnemyMaxArmor(
                        entry.value,
                        wave.round,
                        stageNumber: stage.id,
                      ),
                    },
                },
              },
          ],
        },
    ],
  };
}

String encodeContent(Object value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

// Exercise native component geometry at both native tile units and design pixels.
class _ContentScaleGame extends RuneNexusGame {
  _ContentScaleGame(this.scale);
  final double scale;
  @override
  double get boardDistanceScale => scale;
}

Map<String, Object?> exportContentCases() => {
  'enemies': [
    for (final stageIndex in [0, 5, 10, 14])
      for (final roundIndex in [0, 39])
        for (final tileSize in [1.0, 48.0])
          for (final type in gameEnemies.keys)
            {
              'stageIndex': stageIndex,
              'roundIndex': roundIndex,
              'tileSize': tileSize,
              'origin': [0.0, 0.0],
              'enemyType': type.name,
              'id': 100000,
              'spawnValues': {
                'laneOffsetRatio': enemyLaneOffsetForRoll(type, .75),
                'visualPhase': .625,
                'diamondReward': type.isBoss ? 0 : 2,
              },
              'expected': contentEnemyState(
                _ContentScaleGame(tileSize / 48),
                type,
                stageNumber: gameStages[stageIndex].id,
                round: gameStages[stageIndex].waves[roundIndex].round,
                id: 100000,
                tileSize: tileSize,
                laneOffsetRatio: enemyLaneOffsetForRoll(type, .75),
                visualPhase: .625,
                diamondReward: type.isBoss ? 0 : 2,
                path: [
                  for (final p in gameStages[stageIndex].map.path)
                    Vector2((p.x + .5) * tileSize, (p.y + .5) * tileSize),
                ],
              ),
            },
  ],
  'turrets': [
    for (final entry in (exportGameContent()['turrets'] as Map).entries)
      for (final grown in [false, true])
        _turretCase(entry.key as String, entry.value as Map, grown),
  ],
};

Map<String, Object?> _turretCase(String type, Map data, bool grown) {
  final input = Map<String, dynamic>.from(
    (data['configuration'] as Map)['statInput'] as Map,
  );
  if (grown) {
    input.addAll({
      'level': 4,
      'gems': ['criticalChance', 'explosion'],
      'towerDamageMultiplier': 1.35,
      'corePassiveTurretDamageMultiplier': 1.15,
      'corePassiveTurretAttackRateMultiplier': 1.1,
      'criticalChanceProgressionBonusRate': .12,
      'criticalDamageProgressionBonusRate': .25,
      'passiveNumericGemEffectMultiplier': 1.2,
    });
  }
  return {
    'type': type,
    'grown': grown,
    'input': input,
    'expected': evaluateTurretFixture(input),
  };
}
