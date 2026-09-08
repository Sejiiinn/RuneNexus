import 'dart:ui' show Canvas, Offset, Paint;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_turret_data.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/gem/gem_equip_rules.dart';
import 'package:rune_nexus/domain/gem/gem_type.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/game/components/turret_component.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';

void main() {
  test('explosion grants its base radius and area increase together', () {
    final game = RuneNexusGame();
    final turret = createTurret(game, TurretType.arrow);
    expect(turret.effectAreaMultiplier, 1);
    expect(turret.splashRadius, 0);
    final originalRange = turret.range;
    turret.equipGem(GemType.explosion, 0);
    expect(
      turret.splashRadius,
      closeTo(34 * 1.25 * game.boardDistanceScale, 1e-8),
    );
    expect(turret.splashSecondaryDamageMultiplier, 0.5);
    expect(turret.range, originalRange);
  });

  test('native cannon radius preserves its base and sums gem increases', () {
    final game = RuneNexusGame();
    final turret = createTurret(game, TurretType.cannon);
    turret.upgradeLink();
    turret.equipGem(GemType.explosion, 0);
    turret.equipGem(GemType.heavyWeapon, 1);
    expect(turret.effectAreaMultiplier, closeTo(1.45, 1e-8));
    expect(
      turret.splashRadius,
      closeTo(
        gameTurrets[TurretType.cannon]!.splashRadius *
            1.45 *
            game.boardDistanceScale,
        1e-8,
      ),
    );
    expect(
      turret.damage,
      closeTo(gameTurrets[TurretType.cannon]!.damage * 1.3, 1e-8),
    );
    final snapshot = turret.createAttackSnapshot();
    expect(snapshot.effectAreaMultiplier, turret.effectAreaMultiplier);
    expect(snapshot.splashRadius, turret.splashRadius);
  });

  test(
    'frost area expands without granting a second explosion or changing range',
    () {
      final turret = createTurret(RuneNexusGame(), TurretType.frost);
      final originalRange = turret.range;
      turret.equipGem(GemType.explosion, 0);
      expect(turret.range, originalRange);
      expect(turret.centeredAreaRadius, closeTo(originalRange * 1.25, 1e-8));
      expect(
        turret.createAttackSnapshot().centeredAreaRadius,
        turret.centeredAreaRadius,
      );
      expect(turret.splashRadius, 0);
    },
  );

  test('frost selection and upgrade rings match its actual expanded area', () {
    final game = _RangePreviewGame();
    final turret = createTurret(game, TurretType.frost);
    turret.equipGem(GemType.explosion, 0);
    final canvas = _CircleRecordingCanvas();
    turret.render(canvas);
    expect(canvas.radii.take(4), [
      turret.centeredAreaRadius,
      200 * 1.25,
      200 * 1.25,
      turret.centeredAreaRadius,
    ]);
  });

  test('chain eligibility follows projectile or native chain capability', () {
    for (final type in TurretType.values) {
      final allowed = type != TurretType.sniper && type != TurretType.frost;
      final turret = createTurret(RuneNexusGame(), type);
      expect(
        canEquipGemOnTurret(GemType.chain, turret.definition),
        allowed,
        reason: '$type',
      );
      turret.equipGem(GemType.chain, 0);
      expect(turret.hasGem(GemType.chain), allowed);
      expect(
        turret.createAttackSnapshot().chainCount,
        type == TurretType.lightning ? 4 : (allowed ? 2 : 0),
      );
    }
  });

  test(
    'legacy incompatible gem is returned once and survives another restore',
    () async {
      final repository = MemorySaveRepository();
      final game = RuneNexusGame(saveRepository: repository);
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.tryBuildTurret(const GridPoint(2, 0));
      await game.saveNow();
      final json = repository.data!.toJson();
      final run = json['activeRun']! as Map<String, Object?>;
      final turretJson =
          (run['turrets']! as List).single as Map<String, Object?>;
      turretJson['equippedGemSlots'] = ['heavyWeapon'];
      turretJson['equippedGems'] = ['heavyWeapon'];
      repository.data = GameSaveData.fromJson(json);

      for (var restoration = 0; restoration < 2; restoration++) {
        final restored = RuneNexusGame(saveRepository: repository);
        restored.onGameResize(Vector2(400, 800));
        await restored.onLoad();
        expect(
          restored.snapshotNotifier.value.gemInventory[GemType.heavyWeapon],
          1,
        );
        await restored.saveNow();
        expect(
          repository.data!.activeRun!.turrets.single.equippedGems,
          isEmpty,
        );
      }
    },
  );

  test('heavy gem cannot enter a light tower through direct equipment', () {
    final turret = createTurret(RuneNexusGame(), TurretType.arrow);
    turret.equipGem(GemType.heavyWeapon, 0);
    expect(turret.equippedGems, isEmpty);
  });
}

TurretComponent createTurret(RuneNexusGame game, TurretType type) =>
    TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[type]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 48,
    );

class _RangePreviewGame extends RuneNexusGame {
  @override
  bool isTurretSelected(GridPoint point) => true;

  @override
  double? levelUpPreviewRangeFor(GridPoint point) => 200;
}

class _CircleRecordingCanvas implements Canvas {
  final radii = <double>[];

  @override
  void drawCircle(Offset center, double radius, Paint paint) {
    radii.add(radius);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
