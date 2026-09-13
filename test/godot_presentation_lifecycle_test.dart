import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/map/map_definition.dart';
import 'package:rune_nexus/domain/map/tile_type.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_frame.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/ui/hud/godot_battlefield_view.dart';

/// Lifecycle tests use an immutable combat snapshot: no loading, rules or clock.
class _SnapshotGame extends RuneNexusGame {
  _SnapshotGame() : super(saveRepository: MemorySaveRepository());

  @override
  BattlefieldFrame get battlefieldFrame => BattlefieldFrame(
    map: MapDefinition(
      columns: 1,
      rows: 1,
      tiles: const [
        [TileType.build],
      ],
      path: const [],
    ),
    turrets: const [],
    enemies: const [],
    projectiles: const [],
    time: 0,
    pixelsPerTile: 48,
    zoom: 1,
    screenCenter: Offset.zero,
    nexusHpRatio: 1,
    nexusHit: 0,
    portalAlert: 0,
  );
}

class _PendingPresentation {
  _PendingPresentation(this.frame);
  final Map<String, dynamic> frame;
  final result = Completer<String>();

  String response({double originX = .1, List<String> groups = const []}) =>
      jsonEncode({
        'presentationVersion': 2,
        'sceneEpoch': frame['sceneEpoch'],
        'viewportRevision': frame['viewportRevision'],
        'viewport': frame['viewport'],
        'sequence': frame['seq'],
        'appliedGroups': groups,
        'nativeTurretLevels': false,
        'projection': {
          'origin': [originX, .2],
          'xAxis': [.1, 0],
          'yAxis': [0, .1],
          'heightAxis': [0, -.1],
        },
      });
}

class _Native {
  _Native(this.tester) {
    addTearDown(finish);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        if (call.method == 'create') createdViews++;
        return null;
      },
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      _call,
    );
  }
  static const channel = MethodChannel('rune_nexus/godot_preview');
  final WidgetTester tester;
  bool _finished = false;
  int createdViews = 0;
  bool hold = true;
  double originX = .4;
  List<String> groups = ['labels'];
  final frames = <Map<String, dynamic>>[];
  final pending = <_PendingPresentation>[];
  final clears = <int>[];

  Future<Object?> _call(MethodCall call) async {
    switch (call.method) {
      case 'beginScene':
      case 'setOptions':
        return null;
      case 'clearScene':
        clears.add((call.arguments as Map)['sceneEpoch'] as int);
        return null;
      case 'getStatus':
        return {'ready': true, 'error': ''};
      case 'submitFrame':
        frames.add(
          jsonDecode(call.arguments as String) as Map<String, dynamic>,
        );
        return null;
      case 'getPresentation':
        final item = _PendingPresentation(Map.of(frames.last));
        if (!hold) return item.response(originX: originX, groups: groups);
        pending.add(item);
        return item.result.future;
    }
    return null;
  }

  Future<void> finish() async {
    if (_finished) return;
    _finished = true;
    await tester.pumpWidget(const SizedBox.shrink());
    for (final item in pending) {
      if (!item.result.isCompleted) item.result.complete(item.response());
    }
    await tester.pump();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      null,
    );
  }
}

Widget _host(RuneNexusGame game, {double width = 300}) => MaterialApp(
  home: Center(
    child: SizedBox(
      width: width,
      height: 300,
      child: GodotBattlefieldView(key: const ValueKey('view'), game: game),
    ),
  ),
);

Future<void> _frames(WidgetTester tester, [int count = 5]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  testWidgets('교체 전 지연 투영은 새 game과 이전 game 어느 쪽에도 적용하지 않는다', (tester) async {
    final native = _Native(tester);
    final previous = _SnapshotGame();
    final current = _SnapshotGame();
    await tester.pumpWidget(_host(previous));
    await _frames(tester);
    expect(native.pending, hasLength(1));
    final old = native.pending.single;
    final oldEpoch = previous.nativeBattlefieldSceneEpoch;
    final previousViewCount = native.createdViews;
    native.hold = false;
    await tester.pumpWidget(_host(current));
    await _frames(tester);
    expect(current.nativeBattlefieldSceneEpoch, isNot(oldEpoch));
    expect(
      native.createdViews,
      greaterThan(previousViewCount),
      reason: 'Native PlatformView creation epoch must follow game replacement',
    );
    expect(current.battlefieldProjection!.origin.dx, closeTo(120, .001));
    old.result.complete(old.response(originX: .05, groups: ['effects']));
    await tester.pump();
    expect(previous.battlefieldProjection, isNull);
    expect(previous.nativeBattlefieldSceneEpoch, 0);
    expect(current.battlefieldProjection!.origin.dx, closeTo(120, .001));
    expect(current.nativeBattlefieldGroups, {'labels'});
    await native.finish();
    expect(
      native.clears,
      contains(
        current.nativeBattlefieldSceneEpoch == 0
            ? native.frames.last['sceneEpoch']
            : current.nativeBattlefieldSceneEpoch,
      ),
    );
  }, variant: android);

  testWidgets('리사이즈 전 반환은 버리고 새 viewport 적용 확인 뒤만 표시한다', (tester) async {
    final native = _Native(tester);
    final game = _SnapshotGame();
    await tester.pumpWidget(_host(game));
    await _frames(tester);
    final old = native.pending.single;
    await tester.pumpWidget(_host(game, width: 420));
    old.result.complete(old.response(groups: ['labels']));
    await tester.pump();
    expect(game.battlefieldProjection, isNull);
    expect(game.nativeBattlefieldGroups, isEmpty);
    await _frames(tester);
    final resized = native.pending.last;
    expect(resized.frame['viewport'], [420, 300]);
    expect(
      resized.frame['viewportRevision'],
      greaterThan(old.frame['viewportRevision'] as int),
    );
    resized.result.complete(
      resized.response(originX: .25, groups: ['selection']),
    );
    await tester.pump();
    expect(game.battlefieldProjection!.origin.dx, closeTo(105, .001));
    expect(game.nativeBattlefieldGroups, {'selection'});
    await native.finish();
  }, variant: android);

  testWidgets('미지원 표시 그룹은 2D에 남기고 지원 철회도 다음 확인에 반영한다', (tester) async {
    final native = _Native(tester)..hold = false;
    final game = _SnapshotGame();
    native.groups = ['labels', 'futureUnsupported'];
    await tester.pumpWidget(_host(game));
    await _frames(tester);
    expect(game.battlefieldProjection, isNotNull);
    expect(game.nativeBattlefieldGroups, {'labels'});
    expect(game.nativeBattlefieldTurretLevels, false);
    native.groups = ['futureUnsupported'];
    await _frames(tester);
    expect(game.battlefieldProjection, isNotNull);
    expect(game.nativeBattlefieldGroups, isEmpty);
    await native.finish();
  }, variant: android);

  testWidgets('같은 game 새 view 소유권 취득 후 이전 view 응답은 투영을 덮지 않는다', (tester) async {
    final native = _Native(tester);
    final game = _SnapshotGame();
    Widget host(bool next) => MaterialApp(
      home: Stack(
        children: [
          SizedBox(
            width: 300,
            height: 300,
            child: GodotBattlefieldView(key: const ValueKey('old'), game: game),
          ),
          if (next)
            SizedBox(
              width: 300,
              height: 300,
              child: GodotBattlefieldView(
                key: const ValueKey('new'),
                game: game,
              ),
            ),
        ],
      ),
    );
    await tester.pumpWidget(host(false));
    await _frames(tester);
    final old = native.pending.single;
    native.hold = false;
    await tester.pumpWidget(host(true));
    await _frames(tester);
    final currentEpoch = game.nativeBattlefieldSceneEpoch;
    expect(currentEpoch, isNot(old.frame['sceneEpoch']));
    expect(game.battlefieldProjection!.origin.dx, closeTo(120, .001));
    old.result.complete(old.response(originX: .05, groups: ['effects']));
    await tester.pump();
    expect(game.battlefieldProjection!.origin.dx, closeTo(120, .001));
    expect(game.nativeBattlefieldGroups, {'labels'});
    await native.finish();
  }, variant: android);
}
