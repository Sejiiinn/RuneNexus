import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_effect_queue.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_effects.dart';

BattlefieldEffect effect(int id, {double age = 0, double duration = 0.14}) =>
    BattlefieldEffect(
      id: id,
      kind: 'coreBeam',
      age: age,
      duration: duration,
      position: Offset.zero,
      tileSize: 48,
    );

void main() {
  test('one-tick creation and removal survives until an applied frame', () {
    final queue = BattlefieldEffectQueue();
    final initial = effect(1);
    queue.track(initial, 10);
    expect(queue.snapshot([], 10.016), [initial]);
    queue.markSubmitted(4, [1]);
    expect(queue.snapshot([], 10.032), [initial]);
    queue.acknowledge(4);
    expect(queue.snapshot([], 10.048), isEmpty);
  });

  test(
    'coalesced frames acknowledge effects after skipped sequence numbers',
    () {
      final queue = BattlefieldEffectQueue();
      queue.track(effect(1), 0);
      queue.markSubmitted(10, [1]);
      queue.snapshot([], 0.05);
      queue.markSubmitted(13, [1]);
      queue.acknowledge(13);
      expect(queue.snapshot([], 0.1), isEmpty);
    },
  );

  test('retries keep the latest age and completion cannot replace it', () {
    final queue = BattlefieldEffectQueue();
    queue.track(effect(1), 0);
    final latest = effect(1, age: 0.1);
    expect(queue.snapshot([latest], 0.01), [latest]);
    queue.markSubmitted(1, [1]);
    expect(queue.snapshot([effect(1, age: 0.02)], 0.02), [latest]);
    expect(queue.snapshot([effect(1, age: 0.14)], 0.03), [latest]);
    queue.markSubmitted(2, [1]);
    expect(queue.snapshot([], 0.04), [latest]);
    queue.acknowledge(1);
    expect(queue.snapshot([], 0.05), isEmpty);
  });

  test('acknowledgements are monotonic and preserve still-live effects', () {
    final queue = BattlefieldEffectQueue();
    final first = effect(1);
    queue.track(first, 0);
    queue.track(effect(2), 0);
    queue.markSubmitted(8, [1]);
    queue.markSubmitted(12, [2]);
    queue.acknowledge(10);
    queue.acknowledge(5);
    expect(queue.snapshot([first], 0.1).map((e) => e.id), [1, 2]);
    expect(queue.snapshot([], 0.2).map((e) => e.id), [2]);
    queue.acknowledge(12);
    expect(queue.snapshot([], 0.3), isEmpty);
  });

  test('capacity evicts orphans before live effects and remains bounded', () {
    final queue = BattlefieldEffectQueue(capacity: 2);
    queue.track(effect(1), 0);
    queue.track(effect(2), 0);
    queue.snapshot([effect(2)], 0.1);
    queue.track(effect(3), 0.1);
    expect(queue.snapshot([effect(2), effect(3)], 0.1).map((e) => e.id), [
      2,
      3,
    ]);
    expect(
      queue.snapshot([effect(4), effect(5), effect(6)], 0.2).map((e) => e.id),
      [5, 6],
    );
  });

  test(
    'wall-time retention expires orphans but never expires live sources',
    () {
      final queue = BattlefieldEffectQueue(maxRetentionSeconds: 2);
      queue.track(effect(1), 10);
      expect(queue.snapshot([], 11.999), hasLength(1));
      expect(queue.snapshot([], 12), isEmpty);
      final live = effect(2);
      queue.track(live, 20);
      expect(queue.snapshot([live], 30), [live]);
      expect(queue.snapshot([], 31.999), [live]);
      expect(queue.snapshot([], 32), isEmpty);
    },
  );

  test(
    'clear removes submissions and acknowledges a fresh reused ID separately',
    () {
      final queue = BattlefieldEffectQueue();
      queue.track(effect(1), 0);
      queue.markSubmitted(100, [1]);
      queue.acknowledge(100);
      queue.clear();
      expect(queue.snapshot([], 0), isEmpty);
      queue.track(effect(1), 0);
      queue.markSubmitted(1, [1]);
      expect(queue.snapshot([], 0.1), hasLength(1));
      queue.acknowledge(1);
      expect(queue.snapshot([], 0.2), isEmpty);
    },
  );

  test('invalid or already-finished initial samples are never retained', () {
    final queue = BattlefieldEffectQueue();
    queue.track(effect(1, age: 0.14), 0);
    queue.track(effect(2, age: double.nan), 0);
    queue.track(effect(3, duration: 0), 0);
    expect(queue.snapshot([], 0), isEmpty);
    expect(() => BattlefieldEffectQueue(capacity: 0), throwsRangeError);
    expect(
      () => BattlefieldEffectQueue(maxRetentionSeconds: 0),
      throwsRangeError,
    );
  });
}
