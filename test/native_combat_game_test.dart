import 'package:vector_math/vector_math_64.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/enemy/enemy_definition.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
import 'package:rune_nexus/domain/combat/auto_start_mode.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/enemy/enemy_resistance_profile.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/game/components/enemy_component.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native session owns time and sends only changed controls', () async {
    final game = RuneNexusGame(saveRepository: _Repository())
      ..nativeSessionClock = true;
    addTearDown(game.disposeAppResources);
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    final bootstrap = game.buildNativeSessionCommand(40)!;
    expect(bootstrap, isNot(contains('steps')));
    expect(bootstrap, isNot(contains('dt')));
    expect((bootstrap['session'] as Map)['clock'], 'godot');
    expect(
      game.applyNativeCombatResponse({
        'epoch': 40,
        'ackSequence': bootstrap['sequence'],
        'stateRevision': 1,
        'accepted': true,
        'enemies': [],
        'turrets': [],
        'events': [],
      }),
      isTrue,
    );
    game.update(10);
    expect(game.buildNativeSessionCommand(40), isNull);
    game.pauseEngine();
    final paused = game.buildNativeSessionCommand(40)!;
    expect((paused['session'] as Map)['paused'], isTrue);
    expect(
      game.applyNativeCombatResponse({
        'epoch': 40,
        'ackSequence': paused['sequence'],
        'stateRevision': 2,
        'accepted': true,
        'enemies': [],
        'turrets': [],
        'events': [],
      }),
      isTrue,
    );
    game.resumeEngine();
    game.setSpeedMultiplier(2);
    final resumed = game.buildNativeSessionCommand(40)!;
    expect((resumed['session'] as Map)['paused'], isFalse);
    expect((resumed['session'] as Map)['speed'], 2);
    expect(resumed, isNot(contains('steps')));
  });

  for (final wave in [false, true]) {
    test(
      'menu reentry rebuilds acknowledged ${wave ? 'wave' : 'preparation'} turrets under a new epoch',
      () async {
        final repository = _Repository();
        final game = RuneNexusGame(saveRepository: repository);
        addTearDown(game.disposeAppResources);
        game.onGameResize(Vector2(400, 800));
        await game.onLoad();
        final map = game.battlefieldFrame!.map;
        final buildPoint = [
          for (var y = 0; y < map.rows; y++)
            for (var x = 0; x < map.columns; x++)
              if (map.canBuildAt(GridPoint(x, y))) GridPoint(x, y),
        ].first;
        game.tryBuildTurret(buildPoint);
        if (wave) game.startNextWave();
        final initial = game.buildNativeCombatCommand(20);
        final initialTurrets = (initial['bootstrap'] as Map)['turrets'] as List;
        expect(initialTurrets, hasLength(1));
        final response = <String, dynamic>{
          'epoch': 20,
          'ackSequence': initial['sequence'],
          'accepted': true,
          'enemies': [],
          'turrets': [
            {'id': initialTurrets.single['id'], 'cooldown': .33},
          ],
          'events': [],
        };
        expect(game.applyNativeCombatResponse(response), isTrue);
        final pending = game.buildNativeCombatCommand(20);
        game.suspendCurrentRunForMenu();
        game.suspendNativeCombat();
        game.setAutoStartMode(AutoStartMode.values.last);
        await game.saveAccountCheckpoint();
        expect(
          repository.data!.preferences.autoStartMode,
          AutoStartMode.values.last,
        );
        final confirmed = repository.data!.activeRun!;
        game.prepareNativeCombatScene(21);
        await Future<void>.delayed(Duration.zero);
        expect(game.nativeCombatOwned, isFalse);
        expect(game.nativeBattlefieldLoading, isTrue);
        expect(
          game.snapshotNotifier.value.phase,
          wave ? GamePhase.restored : GamePhase.preparation,
        );
        final reentry = game.buildNativeCombatCommand(21);
        expect(reentry['epoch'], 21);
        expect(reentry['sequence'], 1);
        final turrets = (reentry['bootstrap'] as Map)['turrets'] as List;
        expect(turrets, hasLength(1));
        expect(turrets.single['state']['cooldown'], .33);
        expect(turrets.single['state']['x'], confirmed.turrets.single.x);
        expect(
          game.applyNativeCombatResponse({
            ...response,
            'ackSequence': pending['sequence'],
          }),
          isFalse,
        );
        expect(game.nativeCombatActive, isFalse);
        expect(
          game.applyNativeCombatResponse({
            'epoch': 21,
            'ackSequence': reentry['sequence'],
            'accepted': true,
            'enemies': [],
            'turrets': [],
            'events': [],
          }),
          isTrue,
        );
        expect(game.nativeCombatActive, isTrue);
        await game.saveAccountCheckpoint();
        expect(repository.data!.activeRun!.gold, confirmed.gold);
        expect(
          repository.data!.activeRun!.spawnQueue
              .map((e) => e.toJson())
              .toList(),
          confirmed.spawnQueue.map((e) => e.toJson()).toList(),
        );
        expect(
          repository.data!.preferences.autoStartMode,
          AutoStartMode.values.last,
        );
      },
    );
  }

  test(
    'native ownership blocks local movement and restores compatible save mirror',
    () async {
      final repository = _Repository();
      final game = RuneNexusGame(saveRepository: repository);
      addTearDown(game.disposeAppResources);
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.startNextWave();
      final enemy = EnemyComponent(
        definition: const EnemyDefinition(
          type: EnemyType.normal,
          name: 'test',
          maxHp: 100,
          speed: 20,
          rewardGold: 1,
          coreDamage: 1,
          color: Colors.white,
          resistanceProfile: EnemyResistanceProfile.neutral,
        ),
        maxHp: 100,
        path: [Vector2.zero(), Vector2(100, 0)],
        game: game,
      );
      game.registerEnemy(enemy);
      enemy.applyNativeCombatState({
        ...enemy.nativeCombatState(0),
        'slowInstances': [
          {'multiplier': .5, 'remaining': 3.0},
        ],
      });
      final bootstrap = game.buildNativeCombatCommand(10);
      final sentEnemy =
          ((bootstrap['bootstrap'] as Map)['enemies'] as List).single as Map;
      game.update(1);
      expect(enemy.distanceTravelled, 0);
      expect(enemy.slowRemaining, 3);
      final state = Map<String, dynamic>.from(sentEnemy)
        ..addAll({'hp': 83.0, 'distanceTravelled': 12.0, 'x': 12.0, 'y': 0.0});
      expect(
        game.applyNativeCombatResponse({
          'epoch': 10,
          'ackSequence': bootstrap['sequence'],
          'accepted': true,
          'enemies': [state],
          'turrets': [],
          'events': [],
        }),
        isTrue,
      );
      expect(game.nativeCombatActive, isTrue);
      expect(enemy.hp, 83);
      expect(enemy.position.x, 12);
      await game.saveAccountCheckpoint();
      expect(repository.data!.activeRun!.enemies.single.hp, 83);
      expect(
        repository
            .data!
            .activeRun!
            .enemies
            .single
            .slowInstances
            .single
            .remaining,
        3,
      );
      final roundtrip = GameSaveData.fromJson(repository.data!.toJson())!;
      expect(roundtrip.activeRun!.enemies.single.distanceTravelled, 12);
      final goldBefore = game.snapshotNotifier.value.gold;
      final next = game.buildNativeCombatCommand(10);
      final kill = <String, dynamic>{
        'epoch': 10,
        'ackSequence': next['sequence'],
        'accepted': true,
        'enemies': [
          {...state, 'hp': 0.0},
        ],
        'turrets': [],
        'events': [
          {'id': 1, 'kind': 'kill', 'enemyId': sentEnemy['id']},
        ],
      };
      expect(game.applyNativeCombatResponse(kill), isTrue);
      expect(game.enemies, isEmpty);
      expect(game.snapshotNotifier.value.gold, goldBefore + 1);
      expect(game.applyNativeCombatResponse(kill), isFalse);
      expect(game.snapshotNotifier.value.gold, goldBefore + 1);
      await game.saveAccountCheckpoint();
      expect(repository.data!.activeRun!.enemies, isEmpty);
      expect(repository.data!.activeRun!.gold, goldBefore + 1);
      game.suspendNativeCombat();
      game.update(1);
      expect(enemy.position.x, 12);
      expect(game.nativeCombatOwned, isTrue);
    },
  );
}

class _Repository implements SaveRepository {
  GameSaveData? data;
  @override
  Future<GameSaveData?> load() async => data;
  @override
  Future<void> save(GameSaveData value) async {
    data = value;
  }

  @override
  Future<void> clear() async {
    data = null;
  }
}
