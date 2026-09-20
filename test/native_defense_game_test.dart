import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'native_wave_game_test.dart' as helper;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'absolute native defense state saves once and arrival has no local HP calculation',
    () async {
      final repository = helper.Repository();
      final game = await helper.fixture(repository);
      addTearDown(game.disposeAppResources);
      game.startNextWave();
      final initial = game.buildNativeCombatCommand(101);
      final wave = helper.copyMap((initial['bootstrap'] as Map)['wave']);
      final enemy = helper.copyMap((wave['spawnQueue'] as List).first['enemy']);
      expect(enemy['coreDamage'], greaterThan(0));
      game.applyNativeCombatResponse(helper.response(initial, wave: wave));
      final next = game.buildNativeCombatCommand(101);
      final packet = helper.response(
        next,
        wave: wave,
        enemies: [enemy],
        defense: {
          'hp': 17.25,
          'roundHpLost': 2.75,
          'finalDefenseUsedThisRound': true,
          'emergencyChargeUsedThisRound': true,
        },
        events: [
          {
            'id': 1,
            'kind': 'arrival',
            'enemyId': enemy['id'],
            'damage': 2.75,
            'prevented': false,
          },
        ],
      );
      expect(game.applyNativeCombatResponse(packet), true);
      expect(game.snapshotNotifier.value.nexusHp, 17.25);
      expect(game.enemies, isEmpty);
      expect(game.applyNativeCombatResponse(packet), false);
      await game.saveAccountCheckpoint();
      final saved = repository.data!.activeRun!;
      expect(saved.nexusHp, 17.25);
      expect(saved.roundNexusHpLost, 2.75);
      expect(saved.finalDefenseUsedThisRound, true);
      expect(saved.emergencyChargeUsedThisRound, true);
      final later = game.buildNativeCombatCommand(101);
      expect(
        later.containsKey('commands'),
        false,
        reason: 'no arrivalResult handshake',
      );
    },
  );

  test(
    'in-flight construction and its paid economy survive save and older native ACK',
    () async {
      final repository = helper.Repository();
      final game = await helper.fixture(repository);
      addTearDown(game.disposeAppResources);
      final map = game.battlefieldFrame!.map;
      final points = [
        for (var y = 0; y < map.rows; y++)
          for (var x = 0; x < map.columns; x++)
            if (map.canBuildAt(GridPoint(x, y))) GridPoint(x, y),
      ];
      game.tryBuildTurret(points.first);
      final initial = game.buildNativeCombatCommand(102);
      game.applyNativeCombatResponse(helper.response(initial));
      final inFlight = game.buildNativeCombatCommand(102);
      game.tryBuildTurret(points[1]);
      final paidGold = game.snapshotNotifier.value.gold;
      await game.saveAccountCheckpoint();
      expect(repository.data!.activeRun!.turrets, hasLength(2));
      expect(repository.data!.activeRun!.gold, paidGold);
      game.applyNativeCombatResponse(helper.response(inFlight));
      await game.saveAccountCheckpoint();
      expect(repository.data!.activeRun!.turrets, hasLength(2));
      expect(repository.data!.activeRun!.gold, paidGold);
    },
  );

  test(
    'save requested by a synchronous HUD listener waits for the entire native batch',
    () async {
      final repository = helper.Repository();
      final game = await helper.fixture(repository);
      addTearDown(game.disposeAppResources);
      game.startNextWave();
      final initial = game.buildNativeCombatCommand(103);
      final wave = helper.copyMap((initial['bootstrap'] as Map)['wave']);
      game.applyNativeCombatResponse(helper.response(initial, wave: wave));
      final planned = wave['spawnQueue'] as List;
      final first = helper.copyMap(planned[0]['enemy'])..['hp'] = 0.0;
      final second = helper.copyMap(planned[1]['enemy'])..['hp'] = 0.0;
      Future<bool>? checkpoint;
      void listener() {
        checkpoint ??= game.saveAccountCheckpoint();
      }

      game.snapshotNotifier.addListener(listener);
      addTearDown(() => game.snapshotNotifier.removeListener(listener));
      final next = game.buildNativeCombatCommand(103);
      game.applyNativeCombatResponse(
        helper.response(
          next,
          wave: wave,
          enemies: [first, second],
          events: [
            {'id': 1, 'kind': 'kill', 'enemyId': first['id']},
            {'id': 2, 'kind': 'kill', 'enemyId': second['id']},
          ],
        ),
      );
      final finalGold = game.snapshotNotifier.value.gold;
      expect(checkpoint, isNotNull);
      await checkpoint!;
      expect(repository.data!.activeRun!.gold, finalGold);
      expect(repository.data!.activeRun!.enemies, isEmpty);
    },
  );
}
