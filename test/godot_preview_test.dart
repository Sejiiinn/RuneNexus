import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';

import '../design/stage1_3d/godot_preview/main.dart';

void main() {
  testWidgets(
    'Godot 준비 뒤 정지 장면과 실제 사격 프레임을 전달하고 안전하게 종료한다',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messenger = tester.binding.defaultBinaryMessenger;
      final frames = <Map<String, dynamic>>[];
      const channel = MethodChannel('rune_nexus/godot_preview');
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getStatus':
            return {'ready': true, 'error': ''};
          case 'getMetrics':
            return jsonEncode({
              'fps': 60,
              'frame_ms': 16.7,
              'draw_calls': 12,
              'primitives': 1000,
            });
          case 'submitFrame':
            frames.add(
              jsonDecode(call.arguments as String) as Map<String, dynamic>,
            );
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      });

      await tester.pumpWidget(const MaterialApp(home: GodotPreview()));
      final game =
          tester
                  .widget<GameWidget>(
                    find.byWidgetPredicate((widget) => widget is GameWidget),
                  )
                  .game!
              as RuneNexusGame;
      await tester.runAsync(
        () => game.loaded.timeout(const Duration(seconds: 10)),
      );
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('대포 6문 · 표적 3기 · 정지 장면'), findsOneWidget);
      expect(frames, isNotEmpty);
      expect(frames.last['turrets'], hasLength(6));
      expect(frames.last['enemies'], hasLength(3));
      final stoppedTime = frames.last['time'] as num;
      final stoppedCount = frames.length;
      await tester.pump(const Duration(milliseconds: 250));
      expect(frames, hasLength(stoppedCount));

      await tester.tap(find.text('연속 사격 시작'));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('대포 6문 · 표적 3기 · 연속 사격'), findsOneWidget);
      expect(frames.last['time'] as num, greaterThan(stoppedTime));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      final disposedCount = frames.length;
      await tester.pump(const Duration(seconds: 2));
      expect(frames, hasLength(disposedCount));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    skip: !const bool.fromEnvironment('RUNE_NEXUS_DEBUG_PANEL'),
  );
}
