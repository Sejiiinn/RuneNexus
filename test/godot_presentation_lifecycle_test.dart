import 'package:vector_math/vector_math_64.dart' show Vector2;
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/data/definitions/game_stage_data.dart';
import 'package:rune_nexus/domain/stage/stage_definition.dart';
import 'package:rune_nexus/domain/map/map_definition.dart';
import 'package:rune_nexus/domain/map/tile_type.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_frame.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/ui/hud/godot_battlefield_view.dart';

/// Presentation frames remain immutable; combat uses the normal ACK protocol.
class _SnapshotGame extends RuneNexusGame {
  _SnapshotGame({this.stage})
    : super(stage: stage, saveRepository: MemorySaveRepository());

  final StageDefinition? stage;

  @override
  BattlefieldFrame get battlefieldFrame => BattlefieldFrame(
    map:
        stage?.map ??
        MapDefinition(
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

Future<_SnapshotGame> _snapshotGame({StageDefinition? stage}) async {
  final game = _SnapshotGame(stage: stage);
  game.onGameResize(Vector2(300, 300));
  await game.onLoad();
  return game;
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
  String statusError = '';
  double originX = .4;
  List<String> groups = ['labels'];
  final frames = <Map<String, dynamic>>[];
  final pending = <_PendingPresentation>[];
  final clears = <int>[];
  final combatPackets = <Map>[];
  int stateRevision = 0;
  int sessionPolls = 0;
  int ackSequence = 0;
  Map<String, Object?>? combatResponseOverride;

  Future<Object?> _call(MethodCall call) async {
    switch (call.method) {
      case 'beginScene':
      case 'setOptions':
        return null;
      case 'clearScene':
        clears.add((call.arguments as Map)['sceneEpoch'] as int);
        return null;
      case 'getStatus':
        return {
          'ready': true,
          'nativeCombatVersion': 1,
          'nativeSessionVersion': 1,
          'error': statusError,
        };
      case 'submitCombat':
        final envelope = call.arguments as Map;
        final packet = jsonDecode(envelope['command'] as String) as Map;
        expectSync(packet['epoch'], envelope['sceneEpoch']);
        combatPackets.add(packet);
        final override = combatResponseOverride;
        if (override != null) return jsonEncode(override);
        ackSequence = packet['sequence'] as int;
        return jsonEncode({
          'stateRevision': ++stateRevision,
          'epoch': packet['epoch'],
          'ackSequence': packet['sequence'],
          'accepted': true,
          'enemies': [],
          'turrets': [],
          'events': [],
        });
      case 'getSessionState':
        sessionPolls++;
        return jsonEncode({
          'epoch': (call.arguments as Map)['sceneEpoch'],
          'ackSequence': ackSequence,
          'stateRevision': ++stateRevision,
          'accepted': true,
          'enemies': [],
          'turrets': [],
          'events': [],
        });
      case 'getPresentation':
        if (frames.isEmpty) return null;
        final query = _PendingPresentation(Map.of(frames.last));
        if (!hold) return query.response(originX: originX, groups: groups);
        pending.add(query);
        return query.result.future;
      case 'submitFrameV2':
        final envelope = call.arguments as Map;
        frames.add(
          jsonDecode(envelope['frame'] as String) as Map<String, dynamic>,
        );
        expectSync(envelope['sceneEpoch'], frames.last['sceneEpoch']);
        final item = _PendingPresentation(Map.of(frames.last));
        if (!hold) return item.response(originX: originX, groups: groups);
        pending.add(item);
        return item.result.future;
      case 'submitFrame':
        fail('본게임은 단일 submitFrameV2 왕복으로 전송과 적용 응답을 받는다');
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

Widget _host(
  RuneNexusGame game, {
  double width = 300,
  bool tickerEnabled = true,
  ValueChanged<bool>? onLoadingChanged,
  ValueChanged<bool>? onAvailabilityChanged,
}) => MaterialApp(
  home: TickerMode(
    enabled: tickerEnabled,
    child: Center(
      child: SizedBox(
        width: width,
        height: 300,
        child: GodotBattlefieldView(
          key: const ValueKey('view'),
          game: game,
          onLoadingChanged: onLoadingChanged,
          onAvailabilityChanged: onAvailabilityChanged,
        ),
      ),
    ),
  ),
);

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  testWidgets('세션은 100ms 주기로 읽고 제어 변경은 즉시 전송한다', (tester) async {
    final native = _Native(tester)..hold = false;
    final game = await _snapshotGame();
    await tester.pumpWidget(_host(game));
    await _frames(tester, 16);
    expect(game.nativeSessionClock, isTrue);
    final beforePolls = native.sessionPolls;
    final beforeCommands = native.combatPackets.length;
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(native.sessionPolls - beforePolls, 1);
    expect(native.combatPackets.length, beforeCommands);
    game.pauseEngine();
    await tester.pump();
    expect((native.combatPackets.last['session'] as Map)['paused'], isTrue);
    game.setSpeedMultiplier(2);
    await tester.pump();
    expect((native.combatPackets.last['session'] as Map)['speed'], 2);
    final stoppedAt = native.sessionPolls;
    await native.finish();
    await tester.pump(const Duration(seconds: 1));
    expect(native.sessionPolls, stoppedAt);
    game.disposeAppResources();
  }, variant: android);

  for (final userPaused in [false, true]) {
    testWidgets('업데이트 UI 차단은 네이티브 세션을 멈추고 사용자 정지 $userPaused 상태를 보존한다', (
      tester,
    ) async {
      final native = _Native(tester)..hold = false;
      final game = await _snapshotGame();
      if (userPaused) game.pauseEngine();
      await tester.pumpWidget(_host(game));
      await _frames(tester, 16);
      expect(
        (native.combatPackets.last['session'] as Map)['paused'],
        userPaused,
      );
      final initialEpoch = game.nativeBattlefieldSceneEpoch;
      final before = native.combatPackets.length;
      await tester.pumpWidget(_host(game, tickerEnabled: false));
      await tester.pump();
      expect(game.nativeSessionUiBlocked, isTrue);
      expect(game.paused, userPaused);
      expect((native.combatPackets.last['session'] as Map)['paused'], isTrue);
      expect(native.frames.last['inputBlocked'], isTrue);
      if (!userPaused) expect(native.combatPackets.length, greaterThan(before));
      await tester.pumpWidget(_host(game));
      await tester.pump();
      expect(game.nativeSessionUiBlocked, isFalse);
      expect(game.paused, userPaused);
      expect(
        (native.combatPackets.last['session'] as Map)['paused'],
        userPaused,
      );
      expect(native.frames.last['inputBlocked'], userPaused);
      expect(game.nativeBattlefieldSceneEpoch, initialEpoch);
      expect(game.nativeBattlefieldError, isNull);
      await native.finish();
      game.disposeAppResources();
    }, variant: android);
  }

  testWidgets('맵 ACK 전 재전송과 ACK 후 생략·복구·복귀를 실제 호출 경로로 보존한다', (tester) async {
    final native = _Native(tester);
    final game = await _snapshotGame();
    await tester.pumpWidget(_host(game));
    await _frames(tester);
    final first = native.pending.single;
    first.result.complete('{}');
    await _frames(tester);
    expect(native.frames.last, contains('map'));
    final applied = jsonDecode(first.response()) as Map<String, dynamic>;
    applied['mapRevision'] = first.frame['mapRevision'];
    native.pending.last.result.complete(jsonEncode(applied));
    await _frames(tester);
    expect(native.frames.last, isNot(contains('map')));
    final projection = game.battlefieldProjection;
    final rejected = native.pending.last;
    rejected.result.complete(
      jsonEncode({
        'presentationVersion': 2,
        'sceneEpoch': rejected.frame['sceneEpoch'],
        'viewportRevision': rejected.frame['viewportRevision'],
        'viewport': rejected.frame['viewport'],
        'sequence': rejected.frame['seq'],
        'mapRevision': rejected.frame['mapRevision'],
        'mapRequired': true,
      }),
    );
    await _frames(tester);
    expect(native.frames.last, contains('map'));
    expect(game.battlefieldProjection, same(projection));
    final old = native.pending.last;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _frames(tester);
    expect(native.frames.last, contains('map'));
    expect(native.frames.last['sceneEpoch'], old.frame['sceneEpoch']);
    expect(
      native.frames.last['viewportRevision'],
      greaterThan(old.frame['viewportRevision'] as int),
    );
    old.result.complete(jsonEncode(applied));
    await tester.pump();
    expect(game.nativeBattlefieldLoading, isTrue);
    await native.finish();
  }, variant: android);

  testWidgets('맵 복구 메타데이터만으로 로딩을 해제하지 않는다', (tester) async {
    final native = _Native(tester);
    final game = await _snapshotGame();
    await tester.pumpWidget(_host(game));
    await _frames(tester);
    final first = native.pending.single;
    final metadata = jsonDecode(first.response()) as Map<String, dynamic>;
    metadata['mapRevision'] = first.frame['mapRevision'];
    metadata['mapRequired'] = true;
    first.result.complete(jsonEncode(metadata));
    await _frames(tester);
    expect(game.nativeBattlefieldLoading, isTrue);
    expect(game.battlefieldProjection, isNull);
    expect(native.frames.last, contains('map'));
    await native.finish();
  }, variant: android);

  testWidgets('리사이즈 전 맵 ACK는 생략을 허용하지 않고 현재 viewport ACK만 허용한다', (
    tester,
  ) async {
    final native = _Native(tester);
    final game = await _snapshotGame();
    await tester.pumpWidget(_host(game));
    await _frames(tester);
    final old = native.pending.single;
    final oldAck = jsonDecode(old.response()) as Map<String, dynamic>;
    oldAck['mapRevision'] = old.frame['mapRevision'];
    await tester.pumpWidget(_host(game, width: 320));
    old.result.complete(jsonEncode(oldAck));
    await _frames(tester);
    expect(native.frames.last, contains('map'));
    expect(game.nativeBattlefieldLoading, isTrue);
    final current = native.pending.last;
    final ack = jsonDecode(current.response()) as Map<String, dynamic>;
    ack['mapRevision'] = current.frame['mapRevision'];
    current.result.complete(jsonEncode(ack));
    await _frames(tester);
    expect(native.frames.last, isNot(contains('map')));
    expect(game.nativeBattlefieldLoading, isFalse);
    await native.finish();
  }, variant: android);

  testWidgets('엔진 ready 뒤에도 유효한 첫 전장 응답까지 로딩을 유지한다', (tester) async {
    final native = _Native(tester);
    final game = await _snapshotGame();
    final loading = <bool>[];
    final availability = <bool>[];
    await tester.pumpWidget(
      _host(
        game,
        onLoadingChanged: loading.add,
        onAvailabilityChanged: availability.add,
      ),
    );
    await _frames(tester);
    expect(native.frames, isNotEmpty);
    expect(game.nativeBattlefieldLoading, isTrue);
    expect(loading, [true]);
    expect(availability, isEmpty);
    final first = native.pending.single;
    first.result.complete(first.response());
    await tester.pump();
    expect(game.nativeBattlefieldLoading, isFalse);
    expect(loading, [true, false]);
    expect(availability, [true]);
    await native.finish();
  }, variant: android);

  testWidgets('첫 전장 표시 전 초기 오류도 로딩을 해제한다', (tester) async {
    final native = _Native(tester)..statusError = 'renderer unavailable';
    final game = await _snapshotGame();
    final loading = <bool>[];
    await tester.pumpWidget(_host(game, onLoadingChanged: loading.add));
    await _frames(tester);
    expect(native.frames, isEmpty);
    expect(game.nativeBattlefieldLoading, isFalse);
    expect(game.battlefieldProjection, isNull);
    expect(loading, [true, false]);
    await native.finish();
  }, variant: android);

  testWidgets('제출 응답이 비어 있으면 ACK로 보지 않고 다음 전송을 허용한다', (tester) async {
    final native = _Native(tester);
    final game = await _snapshotGame();
    await tester.pumpWidget(_host(game));
    await _frames(tester);
    final first = native.pending.single;
    expect(native.frames, hasLength(1));
    first.result.complete('{}');
    await _frames(tester);
    expect(game.nativeBattlefieldLoading, isTrue);
    expect(game.battlefieldProjection, isNull);
    expect(native.frames, hasLength(2));
    // 두 번째 제출은 첫 번째 프레임의 실제 적용 결과를 반환할 수 있다.
    native.pending.last.result.complete(first.response(groups: ['effects']));
    await tester.pump();
    expect(game.nativeBattlefieldLoading, isFalse);
    expect(game.nativeBattlefieldGroups, {'effects'});
    await native.finish();
  }, variant: android);

  testWidgets('같은 적용 sequence의 카메라 투영 변화도 반영한다', (tester) async {
    final native = _Native(tester);
    final game = await _snapshotGame();
    await tester.pumpWidget(_host(game));
    await _frames(tester);
    final first = native.pending.single;
    first.result.complete(first.response(originX: .1));
    await tester.pump();
    expect(game.battlefieldProjection!.origin.dx, closeTo(30, .001));
    await _frames(tester);
    native.pending.last.result.complete(first.response(originX: .3));
    await tester.pump();
    expect(game.battlefieldProjection!.origin.dx, closeTo(90, .001));
    await native.finish();
  }, variant: android);

  testWidgets('앱 복귀는 새 전장을 기다리며 복귀 전 지연 응답으로 로딩을 해제하지 않는다', (tester) async {
    final native = _Native(tester);
    final game = await _snapshotGame();
    await tester.pumpWidget(_host(game));
    await _frames(tester);
    final old = native.pending.single;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _frames(tester);
    expect(game.nativeBattlefieldSceneEpoch, old.frame['sceneEpoch']);
    expect(
      native.frames.last['viewportRevision'],
      greaterThan(old.frame['viewportRevision'] as int),
    );
    expect(game.nativeBattlefieldLoading, isTrue);
    old.result.complete(old.response());
    await tester.pump();
    expect(game.nativeBattlefieldLoading, isTrue);
    expect(game.battlefieldProjection, isNull);
    final current = native.pending.last;
    expect(current, isNot(same(old)));
    current.result.complete(current.response());
    await tester.pump();
    expect(game.nativeBattlefieldLoading, isFalse);
    expect(game.battlefieldProjection, isNotNull);
    await native.finish();
  }, variant: android);

  for (final staleAck in [false, true]) {
    testWidgets(
      '명령 ACK 대기 중 장기 백그라운드 복귀는 ${staleAck ? '구 ACK' : '빈 응답'}에도 재시도와 메뉴 정지를 유지한다',
      (tester) async {
        final native = _Native(tester)..hold = false;
        final game = await _snapshotGame();
        await tester.pumpWidget(_host(game));
        await _frames(tester, 16);
        final previousAck = native.ackSequence;
        native.combatResponseOverride = staleAck
            ? {
                'epoch': game.nativeBattlefieldSceneEpoch,
                'ackSequence': previousAck,
                'stateRevision': native.stateRevision,
                'accepted': true,
                'enemies': [],
                'turrets': [],
                'events': [],
              }
            : {};
        game.pauseEngine();
        await tester.pump();
        expect(game.nativeCommandPending, isTrue);
        final pending = Map.of(native.combatPackets.last);
        expect((pending['session'] as Map)['paused'], isTrue);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        // The transport deadline uses DateTime.now(), outside Flutter's fake
        // scheduler clock. Advance real wall time to exercise that exact path.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5100)),
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _frames(tester);
        expect(game.nativeBattlefieldError, isNull);
        expect(game.nativeCommandPending, isTrue);
        expect(native.combatPackets.last, pending);
        expect(game.paused, isTrue);
        native.combatResponseOverride = null;
        await _frames(tester, 16);
        expect(game.nativeCombatActive, isTrue);
        expect(game.nativeCommandPending, isFalse);
        expect(game.nativeBattlefieldError, isNull);
        expect(game.paused, isTrue);
        expect((native.combatPackets.last['session'] as Map)['paused'], isTrue);
        await native.finish();
        game.disposeAppResources();
      },
      variant: android,
    );
  }

  testWidgets('30초 넘게 준비해도 로딩을 유지하고 실제 전장 응답 뒤 해제한다', (tester) async {
    final native = _Native(tester);
    final game = await _snapshotGame();
    final loading = <bool>[];
    await tester.pumpWidget(_host(game, onLoadingChanged: loading.add));
    await _frames(tester);
    final first = native.pending.single;
    expect(game.nativeBattlefieldLoading, isTrue);
    await tester.pump(const Duration(seconds: 45));
    expect(game.nativeBattlefieldLoading, isTrue);
    expect(game.battlefieldProjection, isNull);
    expect(loading, [true]);
    first.result.complete(first.response());
    await tester.pump();
    expect(game.battlefieldProjection, isNotNull);
    expect(game.nativeBattlefieldLoading, isFalse);
    expect(loading, [true, false]);
    await native.finish();
  }, variant: android);

  testWidgets('로딩 중 view 제거는 게임 정지를 해제한다', (tester) async {
    final native = _Native(tester);
    final game = await _snapshotGame();
    await tester.pumpWidget(_host(game));
    await _frames(tester);
    expect(game.nativeBattlefieldLoading, isTrue);
    await native.finish();
    expect(game.nativeBattlefieldLoading, isFalse);
  }, variant: android);

  testWidgets('스테이지 2에서 5로 전환하면 이전 투영을 지우고 새 전장을 기다린다', (tester) async {
    final native = _Native(tester)..hold = false;
    final previous = await _snapshotGame(stage: gameStages[1]);
    final current = await _snapshotGame(stage: gameStages[4]);
    await tester.pumpWidget(_host(previous));
    await _frames(tester);
    expect(previous.battlefieldProjection, isNotNull);
    expect(previous.nativeBattlefieldLoading, isFalse);
    native.hold = true;
    await _frames(tester);
    final old = native.pending.single;
    await tester.pumpWidget(_host(current));
    await _frames(tester);
    expect(previous.battlefieldProjection, isNull);
    expect(previous.nativeBattlefieldLoading, isFalse);
    expect(current.battlefieldProjection, isNull);
    expect(current.nativeBattlefieldLoading, isTrue);
    final next = native.pending.last;
    expect(next.frame['sceneEpoch'], isNot(old.frame['sceneEpoch']));
    final map = next.frame['map'] as Map;
    expect(map['columns'], gameStages[4].map.columns);
    expect(map['rows'], gameStages[4].map.rows);
    expect(map['tiles'], [
      for (final row in gameStages[4].map.tiles)
        for (final tile in row) tile.name,
    ]);
    old.result.complete(old.response());
    await tester.pump();
    expect(current.nativeBattlefieldLoading, isTrue);
    expect(current.battlefieldProjection, isNull);
    next.result.complete(next.response());
    await tester.pump();
    expect(current.nativeBattlefieldLoading, isFalse);
    expect(current.battlefieldProjection, isNotNull);
    await native.finish();
  }, variant: android);

  testWidgets('교체 전 지연 투영은 새 game과 이전 game 어느 쪽에도 적용하지 않는다', (tester) async {
    final native = _Native(tester);
    final previous = await _snapshotGame();
    final current = await _snapshotGame();
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
    expect(previous.nativeBattlefieldLoading, isFalse);
    expect(current.nativeBattlefieldLoading, isFalse);
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
    final game = await _snapshotGame();
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

  testWidgets('응답의 지원 표시 그룹만 반영하고 지원 철회도 다음 확인에 반영한다', (tester) async {
    final native = _Native(tester)..hold = false;
    final game = await _snapshotGame();
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
    final game = await _snapshotGame();
    Widget host(bool next, {bool includeOld = true}) => MaterialApp(
      home: Stack(
        children: [
          if (includeOld)
            SizedBox(
              key: const ValueKey('old-container'),
              width: 300,
              height: 300,
              child: GodotBattlefieldView(
                key: const ValueKey('old'),
                game: game,
              ),
            ),
          if (next)
            SizedBox(
              key: const ValueKey('new-container'),
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
    game.suspendNativeCombat();
    await tester.pumpWidget(host(true));
    await _frames(tester);
    final currentEpoch = game.nativeBattlefieldSceneEpoch;
    expect(currentEpoch, isNot(old.frame['sceneEpoch']));
    expect(game.battlefieldProjection!.origin.dx, closeTo(120, .001));
    old.result.complete(old.response(originX: .05, groups: ['effects']));
    await tester.pump();
    expect(game.battlefieldProjection!.origin.dx, closeTo(120, .001));
    expect(game.nativeBattlefieldGroups, {'labels'});
    await tester.pumpWidget(host(true, includeOld: false));
    await _frames(tester);
    expect(game.nativeBattlefieldSceneEpoch, currentEpoch);
    expect(game.nativeCombatActive, isTrue);
    await native.finish();
  }, variant: android);
}
