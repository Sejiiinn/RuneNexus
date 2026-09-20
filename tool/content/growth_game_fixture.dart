// Real coordinator transactions, isolated to memory-only save repositories.
import 'package:vector_math/vector_math_64.dart';
import 'package:rune_nexus/data/definitions/game_core_passive_tree_data.dart';
import 'package:rune_nexus/data/definitions/game_research_data.dart';
import 'package:rune_nexus/data/definitions/game_turret_module_data.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/run_upgrade/run_upgrade_type.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/turret_module/turret_module_type.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';

Future<Map<String, Object?>> exportGrowthGameCases() async {
  final seedRepository = MemorySaveRepository();
  final seed = RuneNexusGame(saveRepository: seedRepository);
  seed.onGameResize(Vector2(400, 800));
  await seed.onLoad();
  seed.restartRun();
  final seedMap = seed.battlefieldFrame!.map;
  final seedPoint = [
    for (var y = 0; y < seedMap.rows; y++)
      for (var x = 0; x < seedMap.columns; x++)
        if (seedMap.canBuildAt(GridPoint(x, y))) GridPoint(x, y),
  ].first;
  seed.tryBuildTurret(seedPoint);
  await seed.saveNow();
  final seedData = seedRepository.data!;
  final coreConfig =
      (seed.buildNativeCombatCommand(1)['bootstrap'] as Map)['coreConfig'];
  seed.disposeAppResources();
  final cases = <Object?>[];
  for (final scenario in ['base', 'advanced', 'poor']) {
    final advanced = scenario == 'advanced';
    final progression = RunProgression();
    progression.clearedStageNumbers.addAll(List.generate(15, (i) => i + 1));
    progression.unlockedStageCount = 15;
    if (advanced) {
      progression.fireTrainingUpgradeLevel = 17;
      progression.physicalDamageTrainingUpgradeLevel = 7;
      progression.elementalDamageTrainingUpgradeLevel = 9;
      progression.criticalDamageUpgradeLevel = 4;
      progression.linkCostOptimizationUpgradeLevel = 13;
      progression.turretLevelUpOptimizationUpgradeLevel = 11;
      progression.totalCorePoints = 10000;
      for (final e in corePassiveNodeDefinitions.entries) {
        progression.corePassiveNodeRanks[e.key] = e.value.maxRank;
      }
      for (final e in gameResearchDefinitions.entries) {
        progression.researchLevels[e.key] = e.value.maxLevel;
      }
    }
    final modules = SavedTurretModuleInventory(
      items: advanced
          ? [
              for (final type in TurretType.values)
                for (final part in TurretModulePart.values)
                  SavedTurretModule(
                    id: '${type.name}_${part.name}',
                    turretType: type,
                    part: part,
                    family: turretModuleFamilyFor(type, part),
                    grade: TurretModuleGrade.unique,
                    options: [
                      for (final option in turretModuleOptionPoolFor(
                        type,
                        part,
                      ).take(3))
                        SavedTurretModuleOption(
                          type: option,
                          value:
                              turretModuleOptionRollRanges[option]![TurretModuleGrade
                                      .unique]!
                                  .max,
                        ),
                    ],
                    acquiredOrder: type.index * 3 + part.index,
                    equipped: true,
                  ),
            ]
          : [],
    );
    final json = seedData.toJson();
    json['progression'] = progression.toSaveData().toJson();
    json['turretModules'] = modules.toJson();
    final active = json['activeRun'] as Map<String, Object?>;
    active['gold'] = scenario == 'poor' ? 0 : 1000000;
    active['turrets'] = <Object?>[];
    final repository = MemorySaveRepository()
      ..data = GameSaveData.fromJson(json)!;
    final game = RuneNexusGame(saveRepository: repository);
    game.onGameResize(Vector2(400, 800));
    try {
      await game.onLoad();
      game.continueRestoredRun();
      final map = game.battlefieldFrame!.map;
      final points = [
        for (var y = 0; y < map.rows; y++)
          for (var x = 0; x < map.columns; x++)
            if (map.canBuildAt(GridPoint(x, y))) GridPoint(x, y),
      ];
      Map<String, Object?> snapshot() {
        final s = game.snapshotNotifier.value;
        return {
          'gold': s.gold,
          'gemShards': s.gemShards,
          'phase': s.phase.name,
          'runUpgradeLevels': {
            for (final e in s.runUpgradeLevels.entries) e.key.name: e.value,
          },
          'turrets': [for (final t in game.turrets) t.toSaveData().toJson()],
          'statInputs': [
            for (final t in game.turrets)
              t.nativeCombatConfiguration(0)['statInput'],
          ],
        };
      }

      void step(Map<String, Object?> command, void Function() action) {
        final before = snapshot();
        action();
        final after = snapshot();
        cases.add({
          'name': '${scenario}_${cases.length}',
          'progression': progression.toSaveData().toJson(),
          'moduleInventory': modules.toJson(),
          'before': before,
          'command': command,
          'after': after,
        });
      }

      for (final type in TurretType.values) {
        final point = points[type.index];
        game.selectTurretType(type);
        step({
          'kind': 'build',
          'type': type.name,
          'x': point.x,
          'y': point.y,
        }, () => game.tryBuildTurret(point));
        step({
          'kind': 'build',
          'type': type.name,
          'x': point.x,
          'y': point.y,
        }, () => game.tryBuildTurret(point));
      }
      step({
        'kind': 'build',
        'type': 'arrow',
        'x': -1,
        'y': -1,
      }, () => game.tryBuildTurret(const GridPoint(-1, -1)));
      for (final type in RunUpgradeType.values) {
        for (
          var level = 0;
          level <= (scenario == 'poor' ? 0 : game.runUpgradeMaxLevelFor(type));
          level++
        ) {
          step({
            'kind': 'runUpgrade',
            'type': type.name,
          }, () => game.buyRunUpgrade(type));
        }
      }
      game.startNextWave();
      game.suspendCurrentRunForMenu();
      step({
        'kind': 'build',
        'type': 'arrow',
        'x': points.last.x,
        'y': points.last.y,
      }, () => game.tryBuildTurret(points.last));
      step({
        'kind': 'runUpgrade',
        'type': 'towerDamage',
      }, () => game.buyRunUpgrade(RunUpgradeType.towerDamage));
    } finally {
      game.disposeAppResources();
    }
  }
  return {'schemaVersion': 1, 'coreConfig': coreConfig, 'cases': cases};
}
