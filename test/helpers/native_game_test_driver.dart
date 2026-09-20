import 'package:rune_nexus/game/components/enemy_component.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';

final _eventIds = Expando<int>('native fixture event IDs');

/// Injects an authoritative response, not a second Dart combat implementation.
void acknowledgeNativeState(
  RuneNexusGame game, {
  List<Map<String, Object?>> events = const [],
  List<Map<String, Object?>>? enemies,
  Map<String, Object?>? wave,
  Map<String, Object?>? core,
  Map<String, Object?>? defense,
}) {
  final packet = game.buildNativeCombatCommand(9001);
  final numberedEvents = [
    for (final event in events)
      {...event, 'id': _eventIds[game] = (_eventIds[game] ?? 0) + 1},
  ];
  final accepted = game.applyNativeCombatResponse({
    'epoch': packet['epoch'],
    'ackSequence': packet['sequence'],
    'accepted': true,
    'enemies':
        enemies ??
        [
          for (final enemy in game.enemies)
            enemy.nativeCombatState(game.nativeCombatEntityId(enemy)),
        ],
    'turrets': [],
    'events': numberedEvents,
    'wave': ?wave,
    'core': ?core,
    'defense': ?defense,
  });
  if (!accepted) throw StateError('Native fixture ACK rejected');
}

void acknowledgeNativeKill(RuneNexusGame game, EnemyComponent enemy) {
  game.registerEnemy(enemy);
  final id = game.nativeCombatEntityId(enemy);
  acknowledgeNativeState(
    game,
    enemies: [
      for (final current in game.enemies)
        {
          ...current.nativeCombatState(game.nativeCombatEntityId(current)),
          if (identical(current, enemy)) 'hp': 0.0,
        },
    ],
    events: [
      {'kind': 'kill', 'enemyId': id},
    ],
  );
}

void acknowledgeNativeWaveCompleted(
  RuneNexusGame game, {
  Map<String, Object?>? defense,
}) {
  final waveId = game.snapshotNotifier.value.round;
  acknowledgeNativeState(
    game,
    enemies: [],
    wave: {'id': waveId, 'spawnQueue': [], 'completed': true},
    defense: defense,
    events: [
      {'kind': 'waveCompleted', 'waveId': waveId},
    ],
  );
}

void acknowledgeNativeSpawnQueue(RuneNexusGame game) {
  final packet = game.buildNativeCombatCommand(9001);
  final bootstrap = packet['bootstrap'] as Map;
  final wave = Map<String, Object?>.from(bootstrap['wave'] as Map);
  final queue = wave['spawnQueue'] as List;
  acknowledgeNativeState(
    game,
    enemies: [
      for (final entry in queue)
        Map<String, Object?>.from(entry['enemy'] as Map),
    ],
    wave: {...wave, 'spawnQueue': []},
  );
}

void acknowledgeNativeArrival(
  RuneNexusGame game,
  EnemyComponent enemy, {
  required Map<String, Object?> defense,
}) {
  game.registerEnemy(enemy);
  acknowledgeNativeState(
    game,
    defense: defense,
    events: [
      {'kind': 'arrival', 'enemyId': game.nativeCombatEntityId(enemy)},
      if (defense['failed'] == true) {'kind': 'coreDefeated'},
    ],
  );
}
