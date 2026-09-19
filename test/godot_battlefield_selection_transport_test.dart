import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_selection.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/godot_battlefield_selection_transport.dart';

BattlefieldSelection selection({
  double clock = 1,
  bool selected = false,
  int level = 5,
  List<Color> gems = const [Color(0xffaabbcc)],
  bool reward = false,
  bool replacement = false,
  bool build = false,
  double? preview,
  Offset? aim,
  double phaseOrigin = .2,
}) => BattlefieldSelection(
  logicalTileSize: 48,
  visualScale: 1,
  time: clock,
  clock: clock,
  rewardTargeting: reward,
  turrets: [
    BattlefieldTurretSelection(
      position: const Offset(2.5, 3.5),
      color: const Color(0xffabcdef),
      range: 3,
      selected: selected,
      auraTier: 0,
      level: level,
      phaseOrigin: phaseOrigin,
      animationPhase: 0,
      gemColors: gems,
      previewRange: preview,
      aimTarget: aim,
      aimProgress: aim == null ? 0 : .4,
    ),
  ],
  tiles: [
    if (build)
      const BattlefieldTileSelection(
        position: Offset(1.5, 1.5),
        kind: 'build',
        range: 2,
      ),
  ],
  rewardTargets: [
    if (reward)
      BattlefieldRewardTarget(
        position: const Offset(2.5, 3.5),
        requiresReplacement: replacement,
      ),
  ],
);

void main() {
  test('static state remains pending through coalescing and stale ACKs', () {
    final transport = GodotBattlefieldSelectionTransport();
    Map<String, Object?> send(
      BattlefieldSelection value,
      int sequence, {
      int epoch = 1,
    }) => transport.prepare(value, sceneEpoch: epoch, sequence: sequence);
    final first = send(selection(), 10);
    expect(first['state'], isNotNull);
    expect(send(selection(clock: 2), 11)['state'], first['state']);
    transport.acknowledge(
      sceneEpoch: 1,
      sequence: 9,
      revision: 1,
      applied: true,
    );
    expect(send(selection(), 12)['state'], isNotNull);
    transport.acknowledge(
      sceneEpoch: 1,
      sequence: 11,
      revision: 1,
      applied: true,
    );
    final dynamic = send(selection(clock: 3, aim: const Offset(4, 5)), 13);
    expect(dynamic.containsKey('state'), isFalse);
    expect(dynamic['clock'], 3);
    final fullBytes = utf8
        .encode(
          jsonEncode(selection(clock: 3, aim: const Offset(4, 5)).toJson()),
        )
        .length;
    final steadyBytes = utf8.encode(jsonEncode(dynamic)).length;
    expect(steadyBytes, lessThan(fullBytes));
    // Fixture measurement only: not a whole-frame or FPS claim.
    // ignore: avoid_print
    print(
      'SELECTION_PAYLOAD fixture=1_turret full=$fullBytes steady=$steadyBytes',
    );
    expect(dynamic['aim'], [
      [0, 4.0, 5.0, .4],
    ]);
    final changed = send(selection(selected: true), 14);
    expect(changed['revision'], 2);
    transport.acknowledge(
      sceneEpoch: 1,
      sequence: 13,
      revision: 1,
      applied: true,
    );
    expect(send(selection(selected: true), 15)['state'], isNotNull);
    transport.acknowledge(
      sceneEpoch: 1,
      sequence: 15,
      revision: 2,
      applied: true,
    );
    expect(send(selection(selected: true), 16).containsKey('state'), isFalse);
    expect(send(selection(selected: true), 0, epoch: 2)['state'], isNotNull);
    transport.acknowledge(
      sceneEpoch: 1,
      sequence: 100,
      revision: 1,
      applied: true,
    );
    expect(send(selection(selected: true), 1, epoch: 2)['state'], isNotNull);
  });

  test(
    'upgrade equip construction reward replacement and cache loss resend',
    () {
      final transport = GodotBattlefieldSelectionTransport();
      var sequence = 0;
      for (final frame in [
        selection(),
        selection(level: 8),
        selection(gems: const [Color(0xff112233), Color(0xff223344)]),
        selection(build: true),
        selection(preview: 4),
        selection(reward: true),
        selection(reward: true, replacement: true),
        selection(phaseOrigin: 2),
        selection(),
      ]) {
        final packet = transport.prepare(
          frame,
          sceneEpoch: 4,
          sequence: sequence++,
        );
        expect(packet['state'], isNotNull);
        transport.acknowledge(
          sceneEpoch: 4,
          sequence: sequence - 1,
          revision: packet['revision'],
          applied: true,
        );
        expect(
          transport
              .prepare(frame, sceneEpoch: 4, sequence: sequence++)
              .containsKey('state'),
          isFalse,
        );
      }
      transport.acknowledge(
        sceneEpoch: 4,
        sequence: sequence,
        revision: -1,
        applied: false,
      );
      expect(
        transport.prepare(
          selection(),
          sceneEpoch: 4,
          sequence: sequence++,
        )['state'],
        isNotNull,
      );
      transport.reset();
      expect(
        transport.prepare(
          selection(),
          sceneEpoch: 4,
          sequence: sequence++,
        )['state'],
        isNotNull,
      );
    },
  );
}
