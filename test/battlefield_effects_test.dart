import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_effects.dart';
import 'helpers/game_balance_test_helpers.dart';

Future<RuneNexusGame> _game() async {
  final game = RuneNexusGame(saveRepository: MemorySaveRepository());
  game.onGameResize(Vector2(400, 800));
  await game.load();
  game.nativeBattlefieldSceneEpoch = 12;
  addTearDown(game.disposeAppResources);
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'damage creation DTO preserves projection, feedback and motion',
    () async {
      final game = await _game();
      final origin = game.debugBoardOrigin();
      final tile = game.battlefieldFrame!.pixelsPerTile;
      final id = game.emitBattlefieldEffect(
        kind: 'damage',
        position: Vector2(100, 110),
        duration: .75,
        color: const Color(0xffabcdef),
        text: '약점 123',
        feedback: 'weak',
        motion: 'fallArc',
        arcDirection: -1,
        screenOffset: const Offset(3, -5),
      );
      final initial = game.battlefieldFrame!.effects!.events.single;
      expect(initial['id'], id);
      expect(initial['x'], closeTo((100 - origin.x) / tile, 1e-9));
      expect(initial['y'], closeTo((110 - origin.y) / tile, 1e-9));
      expect(initial['text'], '약점 123');
      expect(initial['feedback'], 'weak');
      expect(initial['motion'], 'fallArc');
      expect(initial['arcDirection'], -1);
      expect(initial['screenOffset'], [3.0, -5.0]);
      expect(initial['color'], 0xffabcdef);
      game.update(.1);
      final next = game.battlefieldFrame!.effects!.events.single;
      expect(next['age'], 0, reason: 'immutable creation payload');
      expect(next['retainedAge'], closeTo(.1, 1e-12));
      expect(next['id'], id);
      expect(next['x'], initial['x']);
      expect(game.battlefieldFrame!.effects!.items, isEmpty);
    },
  );

  test(
    'reading a charge DTO cannot mutate combat state or release damage',
    () async {
      final game = await _game();
      final enemy = targetPriorityEnemy(
        game: game,
        hp: 100,
        progress: 0,
        position: Vector2(100, 150),
      );
      game.registerEnemy(enemy);
      game.emitBattlefieldEffect(
        kind: 'charge',
        position: Vector2(60, 70),
        duration: .3,
      );
      final before = enemy.toSaveData().toJson();
      for (var i = 0; i < 20; i++) {
        game.battlefieldFrame!.effects!.toJson();
      }
      game.update(.15);
      expect(game.battlefieldFrame!.effects!.events.single['retainedAge'], .15);
      expect(enemy.toSaveData().toJson(), before);
    },
  );

  test(
    'impact DTOs preserve all native styles and explicit lifetimes',
    () async {
      final game = await _game();
      for (final style in [
        'spark',
        'flame',
        'frost',
        'sniperBlast',
        'lightningBlast',
        'blast',
      ]) {
        final duration = style.endsWith('Blast') ? .36 : .28;
        game.emitBattlefieldEffect(
          kind: style == 'blast' ? 'blast' : 'impact',
          position: Vector2(60, 70),
          duration: duration,
          style: style,
          color: const Color(0xff123456),
          radius: 20,
        );
        final payload = game.battlefieldFrame!.effects!.events.last;
        expect(payload['style'], style);
        expect(payload['duration'], duration);
        expect(payload['radius'], 20);
        expect(payload['color'], 0xff123456);
      }
    },
  );

  test(
    'death, reward and equip DTOs have independent reliable lifetimes',
    () async {
      final game = await _game();
      final death = game.emitBattlefieldEffect(
        kind: 'death',
        position: Vector2.zero(),
        duration: .75,
        radius: 24,
      )!;
      final reward = game.emitBattlefieldEffect(
        kind: 'diamond',
        position: Vector2.zero(),
        duration: 1.2,
        text: '+3',
        hasImage: true,
      )!;
      final equip = game.emitBattlefieldEffect(
        kind: 'gem',
        position: Vector2.zero(),
        duration: .5,
        visualScale: 1.4,
      )!;
      game.markNativeBattlefieldEffectsSubmitted(12, 2, [death, reward, equip]);
      game.acknowledgeNativeBattlefieldEffects(11, 2);
      expect(
        game.battlefieldFrame!.effects!.events,
        hasLength(3),
        reason: 'old scene ACK ignored',
      );
      game.acknowledgeNativeBattlefieldEffects(12, 1);
      expect(
        game.battlefieldFrame!.effects!.events,
        hasLength(3),
        reason: 'earlier sequence ignored',
      );
      game.acknowledgeNativeBattlefieldEffects(12, 2);
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      game.update(2);
      game.resetNativeBattlefieldEffects(11);
      expect(game.nativeBattlefieldSceneEpoch, 12);
      game.resetNativeBattlefieldEffects(12);
      expect(
        game.battlefieldFrame!.effects!.events,
        isEmpty,
        reason: 'expired ACKed events never replay',
      );
    },
  );

  test('effect DTO freezes linked geometry independently of mutable input', () {
    final points = [const Offset(1, 2)];
    final ids = [7];
    final effect = BattlefieldEffect(
      id: 1,
      kind: 'chain',
      age: 0,
      duration: .2,
      position: Offset.zero,
      tileSize: 48,
      points: points,
      targetIds: ids,
      ownerId: 3,
      attachmentRadius: .4,
      boltSeed: .7,
      enemyType: 'boss',
      enemyTypeIndex: 5,
    );
    points.clear();
    ids.clear();
    final json = effect.toJson();
    expect(json['points'], [
      [1.0, 2.0],
    ]);
    expect(json['targetIds'], [7]);
    expect(json['ownerId'], 3);
    expect(json['attachmentRadius'], .4);
    expect(json['boltSeed'], .7);
    expect(json['enemyType'], 'boss');
    expect(json['enemyTypeIndex'], 5);
    expect(() => effect.points.clear(), throwsUnsupportedError);
  });
}
