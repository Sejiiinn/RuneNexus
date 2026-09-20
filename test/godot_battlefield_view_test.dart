import 'dart:convert';

import 'package:rune_nexus/data/settings/graphics_settings.dart';
import 'package:rune_nexus/ui/settings/graphics_settings_scope.dart';

import 'package:flutter/services.dart';
import 'package:rune_nexus/ui/hud/godot_battlefield_view.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  const channel = MethodChannel('rune_nexus/godot_preview');

  testWidgets('Godot ACK로 전투를 인수하고 투영·카메라·오류 정지와 저장을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final messenger = tester.binding.defaultBinaryMessenger;
    final graphics = GraphicsSettingsController(
      repository: _GraphicsRepository(),
    );
    await graphics.load();
    addTearDown(graphics.dispose);
    var msaa = -1;
    var shadowSize = -1;
    var camera = 'angled';
    var nativeLevels = false;
    var transitioning = false;
    var failed = false;
    var holdCombatAck = true;
    var clears = 0;
    final frames = <Map<String, dynamic>>[];
    final combatPackets = <Map<String, dynamic>>[];
    final nativeEnemies = <String, Map<String, dynamic>>{};
    final nativeTurrets = <String, Map<String, dynamic>>{};
    Map<String, dynamic>? nativeWave;
    var eventId = 0;
    var stateRevision = 0;
    var nativeTime = 0.0;
    final inputEvents = <Map<String, Object?>>[];
    void command(Map command) {
      if (command['kind'] == 'turret') {
        final row = Map<String, dynamic>.from(command['turret'] as Map);
        nativeTurrets['${row['id']}'] = row;
      }
      if (command['kind'] == 'waveStart') {
        nativeWave = Map<String, dynamic>.from(command['wave'] as Map);
      }
    }

    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'beginScene':
          nativeEnemies.clear();
          nativeTurrets.clear();
          nativeWave = null;
          clears++;
          return null;
        case 'clearScene':
          clears++;
          return null;
        case 'getStatus':
          return {
            'ready': true,
            'nativeCombatVersion': 1,
            'nativeSessionVersion': 1,
            'error': failed ? 'renderer unavailable' : '',
          };
        case 'setOptions':
          final options = jsonDecode(call.arguments as String) as Map;
          camera = options['camera'] as String;
          msaa = options['msaa_samples'] as int;
          shadowSize = options['shadow_map_size'] as int;
          nativeLevels = options['turret_levels'] == true;
          return null;
        case 'submitCombat':
          final envelope = call.arguments as Map;
          final packet =
              jsonDecode(envelope['command'] as String) as Map<String, dynamic>;
          combatPackets.add(packet);
          if (holdCombatAck) return null;
          expectSync(packet['epoch'], envelope['sceneEpoch']);
          final bootstrap = packet['bootstrap'] as Map?;
          if (bootstrap != null) {
            for (final row in bootstrap['turrets'] as List) {
              nativeTurrets['${row['id']}'] = Map<String, dynamic>.from(
                row as Map,
              );
            }
            for (final row in bootstrap['enemies'] as List) {
              nativeEnemies['${row['id']}'] = Map<String, dynamic>.from(
                row as Map,
              );
            }
            nativeWave = Map<String, dynamic>.from(bootstrap['wave'] as Map);
          }
          expectSync(packet, isNot(contains('steps')));
          expectSync(packet, isNot(contains('dt')));
          expectSync((packet['session'] as Map)['clock'], 'godot');
          for (final item in (packet['commands'] as List? ?? [])) {
            command(item as Map);
          }
          for (final step in packet['steps'] as List? ?? []) {
            for (final item in (step['commands'] as List? ?? [])) {
              command(item as Map);
            }
            for (final item in (step['commandsAfter'] as List? ?? [])) {
              command(item as Map);
            }
          }
          if (nativeWave?['active'] == true && nativeEnemies.isEmpty) {
            final queue = nativeWave!['spawnQueue'] as List;
            if (queue.isNotEmpty) {
              final enemy = Map<String, dynamic>.from(
                queue.first['enemy'] as Map,
              );
              nativeEnemies['${enemy['id']}'] = enemy;
              nativeWave = {
                ...nativeWave!,
                'spawnQueue': queue.skip(1).toList(),
              };
            }
          }
          return jsonEncode({
            'stateRevision': ++stateRevision,
            'epoch': packet['epoch'],
            'ackSequence': packet['sequence'],
            'accepted': true,
            'enemies': nativeEnemies.values.toList(),
            'turrets': nativeTurrets.values.toList(),
            'wave': nativeWave,
            'events': [
              if (bootstrap != null) {'id': ++eventId, 'kind': 'bootstrap'},
            ],
          });
        case 'getSessionState':
          if (holdCombatAck || combatPackets.isEmpty) return null;
          nativeTime += .1;
          final events = List.of(inputEvents);
          inputEvents.clear();
          return jsonEncode({
            'epoch': (call.arguments as Map)['sceneEpoch'],
            'ackSequence': combatPackets.last['sequence'],
            'stateRevision': ++stateRevision,
            'accepted': true,
            'session': {
              'wallElapsed': nativeTime,
              'effectTime': nativeTime,
              'coreDestructionElapsed': 0.0,
              'phase': nativeWave?['active'] == true ? 'wave' : 'preparation',
              'paused': false,
              'speed': 1.0,
            },
            'enemies': nativeEnemies.values.toList(),
            'turrets': nativeTurrets.values.toList(),
            'wave': nativeWave,
            'events': events,
          });
        case 'getPresentation':
        case 'submitFrameV2':
          final envelope = call.arguments as Map;
          if (call.method == 'submitFrameV2') {
            frames.add(
              jsonDecode(envelope['frame'] as String) as Map<String, dynamic>,
            );
          }
          expectSync(envelope['sceneEpoch'], frames.last['sceneEpoch']);
          return jsonEncode({
            'presentationVersion': 2,
            'sceneEpoch': frames.last['sceneEpoch'],
            'viewportRevision': frames.last['viewportRevision'],
            'viewport': frames.last['viewport'],
            'appliedGroups': [],
            'sequence': frames.last['seq'],
            'camera': camera,
            'transitioning': transitioning,
            'nativeTurretLevels': nativeLevels,
            'projection': {
              'origin': [camera == 'drone' ? .12 : .08, .24],
              'xAxis': [.085, camera == 'drone' ? .0 : .012],
              'yAxis': [.0, .040],
              'heightAxis': [.0, -.025],
            },
          });
        case 'submitFrame':
          fail('본게임은 단일 submitFrameV2 왕복으로 전송과 적용 응답을 받는다');
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    });
    final repository = MemorySaveRepository();
    final game = RuneNexusGame(saveRepository: repository);
    await tester.pumpWidget(
      GraphicsSettingsScope(
        controller: graphics,
        child: MaterialApp(
          home: Scaffold(body: GameHud(game: game)),
        ),
      ),
    );
    await tester.runAsync(
      () => game.loaded.timeout(const Duration(seconds: 10)),
    );
    game.startStage(1);
    await pumpGameFrames(tester, frameCount: 40);
    expect(find.byType(GodotBattlefieldView), findsOneWidget);
    expect(game.nativeCombatActive, isFalse);
    expect(combatPackets.map((packet) => packet['sequence']).toSet(), {1});
    holdCombatAck = false;
    await pumpGameFrames(tester, frameCount: 8);
    expect(game.nativeCombatActive, isTrue);
    expect(msaa, 0);
    expect(shadowSize, 512);
    expect(find.text('고정 시점'), findsOneWidget);
    expect(find.text('드론 시점'), findsNothing);
    expect(game.battlefieldProjection, isNotNull);
    expect(game.nativeBattlefieldTurretLevels, isTrue);
    final viewSize = tester.getSize(find.byType(GodotBattlefieldView));
    expect(
      game.battlefieldProjection!.origin.dx,
      closeTo(viewSize.width * .08, .001),
    );
    expect(
      game.battlefieldProjection!.origin.dy,
      closeTo(viewSize.height * .24, .001),
    );

    // Godot picking의 의미 이벤트가 앱의 기존 건설 선택 경로로 이어진다.
    inputEvents.add({
      'id': ++eventId,
      'kind': 'boardTap',
      'column': 2,
      'row': 0,
    });
    await pumpGameFrames(tester, frameCount: 16);
    expect(
      game.snapshotNotifier.value.selectedBuildPoint,
      const GridPoint(2, 0),
    );
    game.previewOrBuildSelectedTile(TurretType.arrow);
    await pumpGameFrames(tester, frameCount: 8);
    expect(frames.last['buildPreview'], isNotNull);
    expect(frames.last['turrets'], isNull);
    game.confirmBuildSelectedTile();
    await pumpGameFrames(tester, frameCount: 8);
    expect(frames.last['turrets'], isNull);
    expect(nativeTurrets, hasLength(1));
    expect(game.nativeCombatActive, isTrue);
    expect(frames.last['buildPreview'], isNull);
    final beforeWave = frames.last['time'] as num;
    game.startNextWave();
    await pumpGameFrames(tester, frameCount: 90);
    expect(game.enemies, isNotEmpty);
    expect(frames.last['enemies'], isNull);
    expect(nativeEnemies, isNotEmpty);
    expect(frames.last['time'] as num, greaterThan(beforeWave));

    transitioning = true;
    await tester.tap(find.text('고정 시점'));
    await pumpGameFrames(tester, frameCount: 8);
    expect(camera, 'drone');
    expect(find.text('드론 시점'), findsOneWidget);
    expect(find.text('고정 시점'), findsNothing);
    expect(msaa, 0);
    expect(shadowSize, 512);
    await graphics.update(const GraphicsSettings());
    await pumpGameFrames(tester, frameCount: 8);
    expect(msaa, 2);
    expect(shadowSize, 2048);
    expect(
      game.battlefieldProjection!.origin.dx,
      closeTo(viewSize.width * .12, .001),
    );
    expect(game.battlefieldProjection!.xAxis.dy, 0);
    expect(tester.takeException(), isNull);

    failed = true;
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(game.battlefieldProjection, isNull);
    expect(game.nativeBattlefieldTurretLevels, isFalse);
    expect(game.nativeBattlefieldError, isNotNull);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(game.nativeCombatActive, isFalse);
    await game.saveAccountCheckpoint();
    expect(repository.data!.activeRun!.turrets, hasLength(1));
    final oldEpoch = combatPackets.last['epoch'];
    final savedGold = repository.data!.activeRun!.gold;
    failed = false;
    await tester.tap(find.text('다시 시도'));
    await pumpGameFrames(tester, frameCount: 40);
    final rebound = combatPackets
        .where((packet) => packet['epoch'] != oldEpoch)
        .last;
    final bootstrap = combatPackets.firstWhere(
      (packet) => packet['epoch'] == rebound['epoch'],
    );
    expect(bootstrap['sequence'], 1);
    expect((bootstrap['bootstrap'] as Map)['turrets'], hasLength(1));
    expect(game.nativeCombatActive, isTrue);
    expect(game.nativeBattlefieldError, isNull);
    expect(game.snapshotNotifier.value.gold, savedGold);
    expect(nativeTurrets, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    game.disposeAppResources();
    final sentAtDispose = frames.length;
    await tester.pump(const Duration(seconds: 1));
    expect(frames, hasLength(sentAtDispose));
    expect(clears, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final versions in <(int?, int?)>[
    (null, null),
    (0, 1),
    (2, 1),
    (1, null),
    (1, 0),
    (1, 2),
  ]) {
    final (version, sessionVersion) = versions;
    testWidgets('사용할 수 없는 Godot 전투/세션 프로토콜 $versions은 오류와 저장을 유지한다', (
      tester,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      var combatCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (version == null) throw MissingPluginException();
        if (call.method == 'getStatus') {
          return {
            'ready': true,
            'nativeCombatVersion': version,
            'nativeSessionVersion': ?sessionVersion,
            'error': '',
          };
        }
        if (call.method == 'submitCombat') combatCalls++;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final repository = MemorySaveRepository();
      final game = RuneNexusGame(saveRepository: repository);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GameHud(game: game)),
        ),
      );
      await tester.runAsync(
        () => game.loaded.timeout(const Duration(seconds: 10)),
      );
      game.startStage(1);
      await pumpGameFrames(tester, frameCount: 40);
      expect(game.battlefieldProjection, isNull);
      expect(game.nativeBattlefieldError, isNotNull);
      expect(find.text('전장을 불러오지 못했습니다.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(game.nativeCombatActive, isFalse);
      expect(game.enemies, isEmpty);
      expect(combatCalls, 0);
      await game.saveAccountCheckpoint();
      expect(repository.data, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      game.disposeAppResources();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}

class _GraphicsRepository implements GraphicsSettingsRepository {
  @override
  Future<GraphicsSettings?> load() async =>
      const GraphicsSettings(msaaSamples: 0, shadowMapSize: 512);

  @override
  Future<void> save(GraphicsSettings settings) async {}
}
