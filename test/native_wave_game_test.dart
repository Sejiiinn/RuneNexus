import 'dart:convert';
import 'dart:io';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';

Map<String, dynamic> copyMap(Object value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real Godot consumes Dart authored wave/core packet and returns a save-compatible spawn',
    () async {
      final executable =
          Platform.environment['GODOT_BIN'] ??
          '${Directory.current.path}/build/godot-preview/tools/Godot.app/Contents/MacOS/Godot';
      if (!File(executable).existsSync()) {
        markTestSkipped('Godot executable unavailable');
        return;
      }
      final repository = Repository();
      final game = await fixture(repository);
      addTearDown(game.disposeAppResources);
      game.startNextWave();
      final packet = game.buildNativeCombatCommand(90);
      final wave = copyMap((packet['bootstrap'] as Map)['wave']);
      final planned = wave['spawnQueue'] as List;
      final delay = (planned.first['delay'] as num).toDouble();
      final nativePacket = copyMap(packet)
        ..['steps'] = [
          {'dt': delay + .01, 'running': true},
        ];
      final temporary = await Directory.systemTemp.createTemp(
        'native-wave-contract-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      await Directory('${temporary.path}/combat').create();
      for (final source in Directory(
        'godot/combat',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.gd'))) {
        await source.copy(
          '${temporary.path}/combat/${source.uri.pathSegments.last}',
        );
      }
      await File('${temporary.path}/project.godot').writeAsString(
        '[application]\nconfig/name="Native wave test"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',
      );
      await File(
        '${temporary.path}/packet.json',
      ).writeAsString(jsonEncode(nativePacket));
      await File('${temporary.path}/probe.gd').writeAsString("""
extends SceneTree
const Runtime = preload('res://combat/native_combat_runtime.gd')
func _initialize():
    var runtime = Runtime.new()
    var packet = JSON.parse_string(FileAccess.get_file_as_string('res://packet.json'))
    print('NATIVE_RESULT=' + JSON.stringify(runtime.process_command(packet)))
    quit()
""");
      final process = await Process.run(executable, [
        '--headless',
        '--path',
        temporary.path,
        '--script',
        'res://probe.gd',
      ]);
      expect(
        process.exitCode,
        0,
        reason: '${process.stdout}\n${process.stderr}',
      );
      final line = (process.stdout as String)
          .split('\n')
          .firstWhere((e) => e.startsWith('NATIVE_RESULT='));
      final native = copyMap(
        jsonDecode(line.substring('NATIVE_RESULT='.length)),
      );
      expect(native['enemies'], hasLength(1));
      expect(native['enemies'].single['id'], planned.first['enemy']['id']);
      expect(
        (native['core']['cooldown'] as num).toDouble(),
        closeTo(5 - delay - .01, 1e-8),
      );
      expect(game.applyNativeCombatResponse(native), isTrue);
      expect(game.enemies, hasLength(1));
      await game.saveAccountCheckpoint();
      expect(repository.data!.activeRun!.spawnQueue.length, planned.length - 1);
      expect(
        repository.data!.activeRun!.enemies.single.type.name,
        planned.first['enemyType'],
      );
    },
  );

  test(
    'native wave owns spawning/core clock and mirrors unknown IDs and remaining queue',
    () async {
      final repository = Repository();
      final game = await fixture(repository);
      addTearDown(game.disposeAppResources);
      game.startNextWave();
      final initial = game.buildNativeCombatCommand(70);
      final wave = copyMap((initial['bootstrap'] as Map)['wave']);
      final plans = wave['spawnQueue'] as List;
      final core = copyMap(wave['core']);
      expect(plans, isNotEmpty);
      final first = copyMap(plans.first['enemy']);
      expect(game.enemies, isEmpty);
      expect(
        game.applyNativeCombatResponse(
          response(initial, wave: wave, core: core),
        ),
        isTrue,
      );
      final cooldown = game.nexusCoreBeamCooldownSeconds;
      game.update(2);
      expect(
        game.enemies,
        isEmpty,
        reason: 'Dart may not execute the spawn queue',
      );
      expect(
        game.nexusCoreBeamCooldownSeconds,
        cooldown,
        reason: 'Dart may not advance the core clock',
      );
      final next = game.buildNativeCombatCommand(70);
      final remaining = [
        {'enemyType': plans.last['enemyType'], 'delay': 0.025},
      ];
      final nativeState = {...first, 'hp': 7.0, 'distanceTravelled': 3.0};
      expect(
        game.applyNativeCombatResponse(
          response(
            next,
            enemies: [nativeState],
            wave: {'id': wave['id'], 'spawnQueue': remaining},
            core: {
              ...core,
              'cooldown': 2.0,
              'activationCount': 1,
              'directDamageDealt': 5.0,
            },
            events: [
              {
                'id': 1,
                'kind': 'coreDamage',
                'enemyId': first['id'],
                'damage': 5.0,
              },
            ],
          ),
        ),
        isTrue,
      );
      expect(game.enemies, hasLength(1));
      expect(game.nativeCombatEntityId(game.enemies.single), first['id']);
      expect(game.enemies.single.hp, 7);
      expect(game.nexusCoreBeamCooldownSeconds, 2);
      expect(
        game.coreCombatSkillDirectDamageDealt,
        5,
        reason: 'event does not duplicate authoritative stats',
      );
      final later = game.buildNativeCombatCommand(70);
      final commands = [
        for (final step in later['steps'] as List)
          ...step['commandsAfter'] as List,
      ];
      expect(
        commands.where((e) => e['kind'] == 'spawn'),
        isEmpty,
        reason: 'native spawn mirror must not echo a spawn',
      );
      await game.saveAccountCheckpoint();
      expect(repository.data!.activeRun!.spawnQueue.single.delay, .025);
      expect(repository.data!.activeRun!.enemies.single.hp, 7);
      expect(
        repository.data!.activeRun!.runCoreCombatSkillStats.activationCount,
        1,
      );
    },
  );

  test(
    'native wave completion commits rewards and checkpoint once at the same ACK',
    () async {
      final repository = Repository();
      final game = await fixture(repository);
      addTearDown(game.disposeAppResources);
      game.startNextWave();
      final initial = game.buildNativeCombatCommand(71);
      final wave = copyMap((initial['bootstrap'] as Map)['wave']);
      game.applyNativeCombatResponse(response(initial, wave: wave));
      final gold = game.snapshotNotifier.value.gold;
      final next = game.buildNativeCombatCommand(71);
      final event = {'id': 1, 'kind': 'waveCompleted', 'waveId': wave['id']};
      game.applyNativeCombatResponse(
        response(
          next,
          wave: {'id': wave['id'], 'spawnQueue': [], 'completed': true},
          events: [event],
        ),
      );
      final rewardGold = game.snapshotNotifier.value.gold;
      expect(rewardGold, greaterThan(gold));
      expect(game.snapshotNotifier.value.phase, isNot(GamePhase.wave));
      await game.saveAccountCheckpoint();
      expect(repository.data!.activeRun!.roundIndex, 1);
      expect(repository.data!.activeRun!.completedRounds, 1);
      expect(repository.data!.activeRun!.gold, rewardGold);
      expect(repository.data!.activeRun!.spawnQueue, isEmpty);
      final repeated = game.buildNativeCombatCommand(71);
      game.applyNativeCombatResponse(
        response(
          repeated,
          wave: {'id': wave['id'], 'spawnQueue': [], 'completed': true},
          events: [event],
        ),
      );
      expect(game.snapshotNotifier.value.gold, rewardGold);
      await game.saveAccountCheckpoint();
      expect(repository.data!.activeRun!.roundIndex, 1);
    },
  );

  test(
    'fatal arrival wins over waveCompleted and confirmed save cannot grant the next round',
    () async {
      final repository = Repository();
      final original = await fixture(repository);
      addTearDown(original.disposeAppResources);
      final map = original.battlefieldFrame!.map;
      final point = [
        for (var y = 0; y < map.rows; y++)
          for (var x = 0; x < map.columns; x++)
            if (map.canBuildAt(GridPoint(x, y))) GridPoint(x, y),
      ].first;
      original.tryBuildTurret(point);
      original.startNextWave();
      await original.saveAccountCheckpoint();
      final saved = copyMap(repository.data!.toJson());
      saved['activeRun']['nexusHp'] = .5;
      repository.data = GameSaveData.fromJson(saved);
      final game = await fixture(repository);
      addTearDown(game.disposeAppResources);
      game.continueRestoredRun();
      final initial = game.buildNativeCombatCommand(73);
      final wave = copyMap((initial['bootstrap'] as Map)['wave']);
      final first = copyMap((wave['spawnQueue'] as List).first['enemy']);
      game.applyNativeCombatResponse(response(initial, wave: wave));
      final gold = game.snapshotNotifier.value.gold;
      final next = game.buildNativeCombatCommand(73);
      game.applyNativeCombatResponse(
        response(
          next,
          wave: {'id': wave['id'], 'spawnQueue': []},
          enemies: [first],
          defense: {
            'hp': 0.0,
            'roundHpLost': .5,
            'finalDefenseUsedThisRound': false,
            'emergencyChargeUsedThisRound': false,
            'failed': true,
          },
          events: [
            {'id': 1, 'kind': 'arrival', 'enemyId': first['id']},
            {'id': 2, 'kind': 'coreDefeated'},
            {'id': 3, 'kind': 'waveCompleted', 'waveId': wave['id']},
          ],
        ),
      );
      expect(game.snapshotNotifier.value.phase, GamePhase.coreDestruction);
      expect(game.snapshotNotifier.value.gold, gold);
      await game.saveAccountCheckpoint();
      expect(repository.data!.activeRun!.phase, GamePhase.failure);
      expect(repository.data!.activeRun!.roundIndex, 0);
      final failed = game.buildNativeCombatCommand(73);
      expect(failed.containsKey('commands'), isFalse);
    },
  );

  test('native arrival requires no Dart barrier acknowledgement', () async {
    final repository = Repository();
    final game = await fixture(repository);
    addTearDown(game.disposeAppResources);
    game.startNextWave();
    final initial = game.buildNativeCombatCommand(72);
    final wave = copyMap((initial['bootstrap'] as Map)['wave']);
    final first = copyMap((wave['spawnQueue'] as List).first['enemy']);
    game.applyNativeCombatResponse(response(initial, wave: wave));
    final next = game.buildNativeCombatCommand(72);
    game.applyNativeCombatResponse(
      response(
        next,
        wave: wave,
        enemies: [first],
        events: [
          {'id': 1, 'kind': 'arrival', 'enemyId': first['id']},
        ],
      ),
    );
    final resumed = game.buildNativeCombatCommand(72);
    expect(resumed.containsKey('commands'), isFalse);
    expect(game.enemies, isEmpty);
  });
}

Map<String, dynamic> response(
  Map<String, Object?> packet, {
  List<Object?> enemies = const [],
  List<Object?> events = const [],
  Map<String, dynamic>? wave,
  Map<String, dynamic>? core,
  Map<String, dynamic>? defense,
}) => {
  'epoch': packet['epoch'],
  'ackSequence': packet['sequence'],
  'accepted': true,
  'enemies': enemies,
  'turrets': [],
  'events': events,
  'wave': ?wave,
  'core': ?core,
  'defense': ?defense,
};

Future<RuneNexusGame> fixture(Repository repository) async {
  final game = RuneNexusGame(saveRepository: repository);
  game.onGameResize(Vector2(400, 800));
  await game.onLoad();
  return game;
}

class Repository implements SaveRepository {
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
