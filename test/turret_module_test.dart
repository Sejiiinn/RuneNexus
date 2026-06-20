import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_turret_data.dart';
import 'package:rune_nexus/data/definitions/game_turret_module_data.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/turret_module/turret_module_type.dart';
import 'package:rune_nexus/game/components/turret_component.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';

void main() {
  test(
    'stage clear grants a turret module ticket and persists module state',
    () {
      final progression = RunProgression();
      progression.finishRun(completedRounds: 50, success: true, stageNumber: 1);
      expect(progression.turretModuleTickets, 1);

      final key = TurretModuleKey(
        turretType: TurretType.arrow,
        part: TurretModulePart.frame,
        family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.frame),
        grade: TurretModuleGrade.rare,
      );
      progression.grantTurretModule(key);
      expect(progression.equipTurretModule(key), isTrue);

      final saved = SavedProgression.fromJson(
        progression.toSaveData().toJson(),
      );
      final restored = RunProgression()..restoreFromSaveData(saved);

      expect(restored.turretModuleTickets, 1);
      final restoredModule = restored.turretModuleFor(key);
      expect(restoredModule, isNotNull);
      expect(restoredModule!.equipped, isTrue);
    },
  );

  test('duplicate turret modules fuse manually and keep remaining shards', () {
    final progression = RunProgression();
    final key = TurretModuleKey(
      turretType: TurretType.arrow,
      part: TurretModulePart.barrel,
      family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.barrel),
      grade: TurretModuleGrade.normal,
    );

    progression.grantTurretModule(key);
    for (var i = 0; i < turretModuleFusionShardCost; i++) {
      progression.grantTurretModule(key);
    }

    expect(
      progression.turretModuleFor(key)!.shards,
      turretModuleFusionShardCost,
    );
    expect(progression.fuseTurretModule(key), isTrue);

    final fused = progression.turretModuleFor(key)!;
    expect(fused.stars, 1);
    expect(fused.shards, 0);
  });

  test('equipped turret modules affect turret stats and level up cost', () {
    final progression = RunProgression();
    final barrelKey = TurretModuleKey(
      turretType: TurretType.arrow,
      part: TurretModulePart.barrel,
      family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.barrel),
      grade: TurretModuleGrade.rare,
    );
    final frameKey = TurretModuleKey(
      turretType: TurretType.arrow,
      part: TurretModulePart.frame,
      family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.frame),
      grade: TurretModuleGrade.rare,
    );
    progression
      ..grantTurretModule(barrelKey)
      ..grantTurretModule(frameKey)
      ..equipTurretModule(barrelKey)
      ..equipTurretModule(frameKey);

    final base = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );
    final moduleGame = _ModuleEffectGame(progression);
    final moduleTurret = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: moduleGame,
      center: Vector2.zero(),
      tileSize: 32,
    );

    expect(moduleTurret.damage, closeTo(base.damage * 1.06, 0.001));
    expect(moduleTurret.attackRate, closeTo(base.attackRate * 1.02, 0.001));
    expect(moduleTurret.levelUpCost, 41);
  });
}

class _ModuleEffectGame extends RuneNexusGame {
  _ModuleEffectGame(this.progression);

  final RunProgression progression;

  @override
  TurretModuleEffect turretModuleEffectFor(TurretType type) {
    return progression.turretModuleEffectFor(type);
  }
}
