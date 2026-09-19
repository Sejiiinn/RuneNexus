import 'dart:math' as math;

import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_projection.dart';
import 'helpers/game_balance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native ring preserves first ACK speed pause fallback and new turret phase',
    () async {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());
      game.onGameResize(Vector2(400, 800));
      // ignore: invalid_use_of_internal_member
      await game.load();
      // ignore: invalid_use_of_internal_member
      game.mount();
      addTearDown(game.disposeAppResources);
      await game.ready();
      final turret = TurretComponent(
        gridPoint: const GridPoint(2, 0),
        definition: gameTurrets[TurretType.arrow]!,
        game: game,
        center: Vector2(100, 100),
        tileSize: 48,
      );
      await game.add(turret);
      await game.ready();
      game.update(.2);
      final before = turret.visualGemRingPhase;
      game.battlefieldProjection = const BattlefieldProjection(
        origin: Offset.zero,
        heightAxis: Offset(0, -48),
        xAxis: Offset(48, 0),
        yAxis: Offset(0, 48),
      );
      game.nativeBattlefieldGroups = {'selection'};
      game.nativeSelectionAnimation = true;
      final initialOrigin = turret.visualGemRingPhaseOrigin;
      expect(
        (initialOrigin + game.battlefieldEffectCombatClock * .45) %
            (math.pi * 2),
        closeTo(before, 1e-9),
      );
      game.update(.1);
      expect(turret.visualGemRingPhase, closeTo(before + .045, 1e-9));
      expect(turret.visualGemRingPhaseOrigin, closeTo(initialOrigin, 1e-9));
      game.setSpeedMultiplier(4);
      final fastBefore = turret.visualGemRingPhase;
      game.update(.1);
      expect(turret.visualGemRingPhase, closeTo(fastBefore + .18, 1e-9));
      final paused = turret.visualGemRingPhase;
      game.nativeBattlefieldLoading = true;
      game.update(3);
      expect(turret.visualGemRingPhase, paused);
      game.nativeSelectionAnimation = false;
      game.update(0);
      expect(turret.visualGemRingPhase, paused);
      game.nativeBattlefieldLoading = false;
      game.update(.1);
      expect(turret.visualGemRingPhase, closeTo(paused + .18, 1e-9));
      game.nativeSelectionAnimation = true;
      game.update(.1);
      final resumed = turret.visualGemRingPhase;
      expect(resumed, closeTo(paused + .36, 1e-9));
      turret.removeFromParent();
      game.update(0);
      final replacement = TurretComponent(
        gridPoint: turret.gridPoint,
        definition: turret.definition,
        game: game,
        center: Vector2(100, 100),
        tileSize: 48,
      );
      await game.add(replacement);
      await game.ready();
      expect(replacement.visualGemRingPhase, 0);
      expect(
        replacement.visualGemRingPhaseOrigin,
        isNot(turret.visualGemRingPhaseOrigin),
      );
      game.update(.1);
      expect(replacement.visualGemRingPhase, closeTo(.18, 1e-9));
    },
  );
}
