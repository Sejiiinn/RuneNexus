import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:rune_nexus/ui/hud/godot_battlefield_view.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  const channel = MethodChannel('rune_nexus/godot_preview');

  testWidgets('본게임 Godot 투영으로 건설하고 전투·카메라 전환 후 실패 시 2D로 복귀한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final messenger = tester.binding.defaultBinaryMessenger;
    var camera = 'angled';
    var nativeLevels = false;
    var transitioning = false;
    var failed = false;
    var clears = 0;
    final frames = <Map<String, dynamic>>[];
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'clearScene':
          clears++;
          return null;
        case 'getStatus':
          return {'ready': true, 'error': failed ? 'renderer unavailable' : ''};
        case 'setOptions':
          final options = jsonDecode(call.arguments as String) as Map;
          camera = options['camera'] as String;
          nativeLevels = options['turret_levels'] == true;
          return null;
        case 'submitFrame':
          frames.add(
            jsonDecode(call.arguments as String) as Map<String, dynamic>,
          );
          return null;
        case 'getPresentation':
          return jsonEncode({
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
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    });
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
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
    expect(find.byType(GodotBattlefieldView), findsOneWidget);
    expect(find.text('고정 시점'), findsOneWidget);
    expect(find.text('드론 시점'), findsOneWidget);
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

    // 게임의 투영 결과를 실제 포인터로 입력하여 Flame까지의 경로 검증.
    final local = game.battlefieldProjection!.gridToScreen(
      const Offset(2.5, .5),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byType(GodotBattlefieldView)) + local,
    );
    await pumpGameFrames(tester);
    expect(
      game.snapshotNotifier.value.selectedBuildPoint,
      const GridPoint(2, 0),
    );
    game.previewOrBuildSelectedTile(TurretType.arrow);
    await pumpGameFrames(tester);
    expect(frames.last['buildPreview'], isNotNull);
    expect(frames.last['turrets'], isEmpty);
    game.confirmBuildSelectedTile();
    await pumpGameFrames(tester);
    expect(frames.last['turrets'], hasLength(1));
    expect(frames.last['buildPreview'], isNull);
    final beforeWave = frames.last['time'] as num;
    game.startNextWave();
    await pumpGameFrames(tester, frameCount: 90);
    expect(game.enemies, isNotEmpty);
    expect(frames.last['enemies'], isNotEmpty);
    expect(frames.last['time'] as num, greaterThan(beforeWave));

    transitioning = true;
    await tester.tap(find.text('드론 시점'));
    await pumpGameFrames(tester);
    expect(camera, 'drone');
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
    expect(find.text('드론 시점'), findsNothing);
    expect(game.backgroundColor().a, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    game.disposeAppResources();
    final sentAtDispose = frames.length;
    await tester.pump(const Duration(seconds: 1));
    expect(frames, hasLength(sentAtDispose));
    expect(clears, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Godot 채널 없는 Android에서 본게임과 2D 입력을 유지한다', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw MissingPluginException(),
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
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
    expect(game.nativeBattlefieldTurretLevels, isFalse);
    expect(find.text('드론 시점'), findsNothing);
    expect(find.byType(AndroidViewSurface), findsNothing);
    expect(game.backgroundColor().a, 1);
    final frame = game.battlefieldFrame!;
    final screen =
        frame.screenCenter +
        Offset(2.5 - frame.map.columns / 2, .5 - frame.map.rows / 2) *
            (frame.pixelsPerTile * frame.zoom);
    await tester.tapAt(game.renderBox.localToGlobal(screen));
    await pumpGameFrames(tester);
    expect(
      game.snapshotNotifier.value.selectedBuildPoint,
      const GridPoint(2, 0),
    );
    game.previewOrBuildSelectedTile(TurretType.arrow);
    game.confirmBuildSelectedTile();
    await pumpGameFrames(tester);
    expect(game.battlefieldFrame!.turrets, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    game.disposeAppResources();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
