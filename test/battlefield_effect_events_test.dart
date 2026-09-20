import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_effect_events.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_effects.dart';

BattlefieldEffect effect(int id, {String kind = 'damage'}) => BattlefieldEffect(
  id: id,
  kind: kind,
  age: 0,
  duration: .75,
  position: Offset.zero,
  tileSize: 48,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'single cancellation resends live events without reviving expired acknowledged effects',
    () {
      final events = BattlefieldEffectEvents<String>();
      events.add(effect(1, kind: 'death'), 'old death');
      events.markSubmitted(1, [1]);
      events.acknowledge(1);
      events.advance(.6);
      events.add(effect(2, kind: 'charge'), 'cancelled charge');
      events.add(effect(3), 'live');
      events.markSubmitted(2, [2, 3]);
      events.advance(.2);
      events.cancel(2);
      expect(events.pending().map((event) => event['id']), [3]);
      events.markSubmitted(2, [3], submittedGeneration: 0);
      events.acknowledge(2);
      expect(events.pending().map((event) => event['id']), [3]);
      events.cancel(2);
      expect(events.generation, 1, reason: 'duplicate remove is harmless');
    },
  );

  test(
    'ACK removes payload but preserves the live event journal, pause and bounded capacity',
    () {
      final events = BattlefieldEffectEvents<String>(capacity: 2);
      events.add(effect(1), 'one');
      events.add(effect(2), 'two');
      events.markSubmitted(4, [1, 2]);
      events.acknowledge(3);
      expect(events.pending(), hasLength(2));
      events.acknowledge(4);
      expect(events.pending(), isEmpty);
      events.advance(0);
      events.add(effect(3), 'three');
      expect(events.takeLive().map((e) => e.source), ['two', 'three']);
    },
  );
  test(
    'coalesced one-tick expiry retains one drawable sample, never restores expired sources',
    () {
      final events = BattlefieldEffectEvents<String>();
      events.add(effect(1), 'one');
      events.advance(.1);
      expect(events.pending().single['retainedAge'], .1);
      events.advance(1);
      expect(events.pending().single['retainedAge'], .1);
      events.markSubmitted(10, [1]);
      events.acknowledge(12);
      expect(events.pending(), isEmpty);
      events.add(effect(2), 'two');
      events.advance(1);
      expect(events.takeLive(), isEmpty);
    },
  );
  test(
    'combat clear cancels damage/gem, preserves live death without old ACK',
    () {
      final events = BattlefieldEffectEvents<String>();
      events.add(effect(1), 'damage');
      events.add(effect(2, kind: 'death'), 'death');
      events.markSubmitted(3, [1, 2]);
      events.acknowledge(3);
      events.cancelKinds({'damage', 'gem'});
      expect(events.generation, 1);
      events.markSubmitted(3, [2], submittedGeneration: 0);
      events.acknowledge(3);
      expect(events.pending().single['id'], 2);
      events.markSubmitted(4, [2], submittedGeneration: events.generation);
      events.acknowledge(4);
      expect(events.pending(), isEmpty);
    },
  );
  test('combat cancellation cannot replay an acknowledged expired death', () {
    final events = BattlefieldEffectEvents<String>();
    events.add(effect(1, kind: 'death'), 'death');
    events.markSubmitted(1, [1]);
    events.acknowledge(1);
    events.advance(1);
    events.cancelKinds({'damage', 'gem'});
    expect(events.pending(), isEmpty);
  });
  test(
    'native closed form exactly matches discrete fall arc at variable step sizes',
    () {
      // Frozen 0241ef6 update equation, independent of the removed component.
      const lifetime = 0.75;
      for (final direction in [-1, 1]) {
        var x = 100.0;
        var y = 110.0;
        var age = 0.0;
        final events = BattlefieldEffectEvents<String>();
        events.add(effect(1), 'damage');
        for (final dt in [.016, .04, 0.0, .064, .1, .008]) {
          events.advance(dt);
          age += dt;
          x += direction * 42 * dt;
          y += (-28 + 96 * age / lifetime) * dt;
        }
        final payload = events.pending().single;
        final nativeAge = payload['retainedAge']! as double;
        final nativeSquared = payload['retainedSquared']! as double;
        expect(100 + direction * 42 * nativeAge, closeTo(x, 1e-10));
        expect(
          110 -
              28 * nativeAge +
              48 / lifetime * (nativeAge * nativeAge + nativeSquared),
          closeTo(y, 1e-10),
        );
      }
    },
  );
}
