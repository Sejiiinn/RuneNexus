import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rune_nexus/ui/hud/godot_battlefield_view.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/game/components/impact_effect_component.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_effects.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_projection.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/godot_battlefield_frame.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';

const _projection = BattlefieldProjection(
  origin: Offset(20, 30),
  xAxis: Offset(40, 0),
  yAxis: Offset(0, 40),
  heightAxis: Offset(0, -20),
);

class _ShortEffect extends PositionComponent
    implements BattlefieldEffectSource {
  double age = 0;
  int updateCount = 0;
  @override
  void update(double dt) {
    updateCount++;
    age += dt;
    if (age >= 0.01) removeFromParent();
  }

  @override
  BattlefieldEffect battlefieldEffect(int id, Offset origin, double tileSize) =>
      BattlefieldEffect(
        id: id,
        kind: 'charge',
        age: age,
        duration: 0.01,
        position: Offset.zero,
        tileSize: tileSize,
      );
}

Future<RuneNexusGame> _fixture() async {
  final game = RuneNexusGame(saveRepository: MemorySaveRepository());
  game.onGameResize(Vector2(400, 800));
  // Follow GameWidget's lifecycle without an automatic render/update loop.
  // ignore: invalid_use_of_internal_member
  await game.load();
  // ignore: invalid_use_of_internal_member
  game.mount();
  await game.ready();
  game.nativeBattlefieldSceneEpoch = 10;
  game.resetNativeBattlefieldEffects(10);
  addTearDown(game.disposeAppResources);
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'add captures an effect removed before the first native snapshot',
    () async {
      final game = await _fixture();
      final effect = _ShortEffect();
      game.add(effect);
      await game.ready();
      effect.update(0.016);
      game.processLifecycleEvents();
      expect(effect.parent, isNull);
      final frame = game.battlefieldFrame!;
      final retained = frame.effects!.items.single;
      expect(retained.age, 0);
      expect(effect.updateCount, 1);
      final encoded = encodeGodotBattlefieldFrame(frame, sequence: 1);
      final presentation = encoded['presentation']! as Map;
      expect((presentation['effects'] as Map)['items'], hasLength(1));
      expect((presentation['effects'] as Map)['shake'], [0.0, 0.0]);
      game.markNativeBattlefieldEffectsSubmitted(10, 1, [retained.id]);
      expect(game.battlefieldFrame!.effects!.items, hasLength(1));
      game.acknowledgeNativeBattlefieldEffects(10, 1);
      expect(game.battlefieldFrame!.effects!.items, isEmpty);
      expect(
        effect.updateCount,
        1,
        reason: 'delivery must not update combat sources',
      );
    },
  );

  test(
    'Flame source is hidden only after its exact native frame is applied',
    () async {
      final game = await _fixture();
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      final effect = _ShortEffect();
      game.add(effect);
      await game.ready();
      final id = game.battlefieldFrame!.effects!.items.single.id;
      expect(game.isNativeBattlefieldEffect(effect), isFalse);
      game.markNativeBattlefieldEffectsSubmitted(10, 1, [id]);
      expect(game.isNativeBattlefieldEffect(effect), isFalse);
      game.acknowledgeNativeBattlefieldEffects(10, 1);
      expect(game.isNativeBattlefieldEffect(effect), isTrue);
      // Re-reading an acknowledgement cannot erase its already-applied IDs.
      game.acknowledgeNativeBattlefieldEffects(10, 1);
      expect(game.isNativeBattlefieldEffect(effect), isTrue);
      game.nativeBattlefieldGroups = {};
      expect(game.isNativeBattlefieldEffect(effect), isFalse);
    },
  );

  test(
    'an old view cannot clear or acknowledge the current scene queue',
    () async {
      final game = await _fixture();
      final effect = _ShortEffect();
      game.add(effect);
      await game.ready();
      effect.update(0.016);
      game.processLifecycleEvents();
      final id = game.battlefieldFrame!.effects!.items.single.id;
      game.markNativeBattlefieldEffectsSubmitted(10, 5, [id]);
      game.resetNativeBattlefieldEffects(9);
      game.acknowledgeNativeBattlefieldEffects(9, 5);
      expect(game.battlefieldFrame!.effects!.items, hasLength(1));
      game.resetNativeBattlefieldEffects(10);
      expect(game.battlefieldFrame!.effects!.items, isEmpty);
    },
  );

  test(
    'separate native blast has no duplicate effect snapshot or Flame skip',
    () async {
      final game = await _fixture();
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      final blast = ImpactEffectComponent(
        position: Vector2(100, 100),
        color: const Color(0xffff6600),
        style: ImpactEffectStyle.blast,
        radius: 30,
      );
      game.add(blast);
      await game.ready();
      final frame = game.battlefieldFrame!;
      expect(frame.effects!.items, isEmpty);
      expect(frame.impacts, hasLength(1));
      game.markNativeBattlefieldEffectsSubmitted(10, 1, []);
      game.acknowledgeNativeBattlefieldEffects(10, 1);
      expect(game.isNativeBattlefieldEffect(blast), isFalse);
    },
  );

  testWidgets(
    'background clears orphan delivery and resume starts a new owner epoch',
    (tester) async {
      const channel = MethodChannel('rune_nexus/godot_preview');
      final messenger = tester.binding.defaultBinaryMessenger;
      final submittedEpochs = <int>[];
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getStatus') return {'ready': true, 'error': ''};
        if (call.method == 'submitFrame') {
          final frame = jsonDecode(call.arguments as String) as Map;
          submittedEpochs.add(frame['sceneEpoch'] as int);
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      });
      final game = (await tester.runAsync(_fixture))!;
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 800,
            child: GodotBattlefieldView(game: game),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final epoch = game.nativeBattlefieldSceneEpoch;
      final effect = _ShortEffect();
      game.add(effect);
      await tester.runAsync(game.ready);
      effect.update(0.016);
      game.processLifecycleEvents();
      expect(game.battlefieldFrame!.effects!.items, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(game.battlefieldFrame!.effects!.items, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(game.nativeBattlefieldSceneEpoch, greaterThan(epoch));
      expect(game.battlefieldFrame!.effects!.items, isEmpty);
      expect(submittedEpochs, contains(game.nativeBattlefieldSceneEpoch));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
