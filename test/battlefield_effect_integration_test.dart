import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rune_nexus/ui/hud/godot_battlefield_view.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/game/components/damage_number_component.dart';
import 'package:rune_nexus/game/components/death_burst_effect_component.dart';
import 'package:rune_nexus/game/components/gem_equip_effect_component.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
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

class _CountingImpact extends ImpactEffectComponent {
  _CountingImpact(ImpactEffectStyle style, {double duration = .42})
    : super(
        position: Vector2(100, 100),
        color: const Color(0xffff6600),
        style: style,
        radius: 16,
        blastDuration: duration,
      );
  int renderCalls = 0;
  int updateCalls = 0;
  int snapshotCalls = 0;
  @override
  void update(double dt) {
    updateCalls++;
    super.update(dt);
  }

  @override
  BattlefieldEffect? battlefieldEffect(int id, Offset origin, double tileSize) {
    snapshotCalls++;
    return super.battlefieldEffect(id, origin, tileSize);
  }

  @override
  void render(Canvas canvas) => renderCalls++;
}

void _renderOnce(RuneNexusGame game) {
  final recorder = ui.PictureRecorder();
  game.render(Canvas(recorder));
  recorder.endRecording().dispose();
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
    'blast event keeps exact lifetime, shared clock and resize fallback without ticks',
    () async {
      final game = await _fixture();
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      game.nativeBattlefieldBlastEffectEvents = true;
      final blast = _CountingImpact(ImpactEffectStyle.blast, duration: 1.7);
      game.add(blast);
      await game.ready();
      expect(blast.parent, isNull);
      final initial = game.battlefieldFrame!;
      final event = initial.effects!.events.single;
      expect(event['kind'], 'blast');
      expect(event['duration'], 1.7);
      expect(event['radius'], 16);
      expect(initial.impacts, isEmpty);
      expect(initial.effects!.items, isEmpty);
      game.markNativeBattlefieldEffectsSubmitted(10, 2, [event['id'] as int]);
      game.acknowledgeNativeBattlefieldEffects(9, 2);
      expect(game.battlefieldFrame!.effects!.events, hasLength(1));
      game.acknowledgeNativeBattlefieldEffects(10, 1);
      expect(game.battlefieldFrame!.effects!.events, hasLength(1));
      game.acknowledgeNativeBattlefieldEffects(10, 2);
      game.update(.1);
      game.setSpeedMultiplier(4);
      game.update(.1);
      expect(
        game.battlefieldEffectCombatClock - initial.effects!.clock,
        closeTo(.5, 1e-10),
      );
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      expect(game.battlefieldFrame!.impacts, isEmpty);
      expect(blast.updateCalls, 0);
      expect(blast.visualProgress, 0);
      game.nativeBattlefieldLoading = true;
      game.update(5);
      expect(
        game.battlefieldEffectCombatClock - initial.effects!.clock,
        closeTo(.5, 1e-10),
      );
      game.nativeBattlefieldLoading = false;
      game.onGameResize(Vector2(600, 1000));
      final resized = game.battlefieldFrame!;
      game.nativeBattlefieldBlastEffectEvents = false;
      await game.ready();
      expect(blast.parent, same(game));
      expect(blast.visualProgress, closeTo(.5 / 1.7, 1e-10));
      expect(
        blast.radius,
        closeTo(
          16 * resized.pixelsPerTile / (event['tileSize'] as double),
          1e-8,
        ),
      );
      final legacy = game.battlefieldFrame!.impacts.single;
      expect(legacy.id, event['id']);
      expect(legacy.position.dx, closeTo(event['x'] as double, 1e-6));
      expect(legacy.position.dy, closeTo(event['y'] as double, 1e-6));
      expect(legacy.radius, closeTo(16 / (event['tileSize'] as double), 1e-8));
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      expect(game.battlefieldFrame!.effects!.items, isEmpty);
    },
  );

  test(
    'blast capability is independent and combat cancellation cannot restore it',
    () async {
      final game = await _fixture();
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      game.nativeBattlefieldImpactEffectEvents = true;
      final legacy = _CountingImpact(ImpactEffectStyle.blast);
      game.add(legacy);
      await game.ready();
      game.update(.1);
      expect(legacy.parent, same(game));
      expect(
        game.battlefieldFrame!.impacts.single.progress,
        closeTo(.1 / .42, 1e-10),
      );
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      expect(game.battlefieldFrame!.effects!.items, isEmpty);
      game.nativeBattlefieldBlastEffectEvents = true;
      final native = _CountingImpact(ImpactEffectStyle.blast);
      game.add(native);
      expect(game.battlefieldFrame!.effects!.events.single['kind'], 'blast');
      game.debugForceDefeat();
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      game.setSpeedMultiplier(4);
      final coreBlast = _CountingImpact(ImpactEffectStyle.blast, duration: 1.7);
      game.add(coreBlast);
      final before = game.battlefieldEffectCombatClock;
      game.update(.4);
      expect(game.battlefieldEffectCombatClock - before, closeTo(.1, 1e-10));
      game.resetNativeBattlefieldEffects(10);
      await game.ready();
      expect(native.parent, isNull);
      expect(coreBlast.visualProgress, closeTo(.1 / 1.7, 1e-10));
      expect(coreBlast.updateCalls, 0);
    },
  );

  for (final style in ImpactEffectStyle.values.where(
    (style) => style != ImpactEffectStyle.blast,
  )) {
    test(
      '${style.name} event owns lifetime and restores exact 2D age',
      () async {
        final game = await _fixture();
        game.battlefieldProjection = _projection;
        game.nativeBattlefieldGroups = {'effects'};
        game.nativeBattlefieldEffectEvents = true;
        game.nativeBattlefieldImpactEffectEvents = true;
        final impact = _CountingImpact(style);
        final reference = _CountingImpact(style);
        game.add(impact);
        await game.ready();
        expect(impact.parent, isNull);
        final first = game.battlefieldFrame!.effects!;
        expect(first.items, isEmpty);
        final event = first.events.single;
        expect(event['style'], style.name);
        expect(
          event['duration'],
          [
                ImpactEffectStyle.sniperBlast,
                ImpactEffectStyle.lightningBlast,
              ].contains(style)
              ? .36
              : .28,
        );
        game.markNativeBattlefieldEffectsSubmitted(10, 1, [event['id'] as int]);
        game.acknowledgeNativeBattlefieldEffects(10, 1);
        game.update(.04);
        reference.update(.04);
        game.setSpeedMultiplier(4);
        game.update(.025);
        reference.update(.1);
        final advanced = game.battlefieldFrame!.effects!;
        expect(advanced.clock - first.clock, closeTo(.14, 1e-10));
        expect(advanced.events, isEmpty);
        expect(advanced.items, isEmpty);
        expect(impact.updateCalls, 0);
        expect(impact.snapshotCalls, 1);
        game.nativeBattlefieldLoading = true;
        game.update(10);
        expect(game.battlefieldFrame!.effects!.clock, advanced.clock);
        game.nativeBattlefieldLoading = false;
        game.resetNativeBattlefieldEffects(10);
        game.battlefieldProjection = null;
        await game.ready();
        expect(impact.parent, same(game));
        expect(impact.visualProgress, closeTo(reference.visualProgress, 1e-10));
        expect(impact.position.x, closeTo(100, 1e-5));
        expect(impact.position.y, closeTo(100, 1e-5));
        _renderOnce(game);
        expect(impact.renderCalls, 1);
        game.update(.1); // Fourfold dt expires both 0.28 and 0.36 styles.
        game.processLifecycleEvents();
        expect(impact.parent, isNull);
      },
    );
  }

  test(
    'old native runtime keeps impact snapshots and capability loss restores',
    () async {
      final game = await _fixture();
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      final legacy = _CountingImpact(ImpactEffectStyle.spark);
      game.add(legacy);
      await game.ready();
      expect(legacy.parent, same(game));
      expect(game.battlefieldFrame!.effects!.items.single.style, 'spark');
      game.nativeBattlefieldImpactEffectEvents = true;
      final cache = DamageNumberImageCache();
      addTearDown(cache.dispose);
      final damage = DamageNumberComponent.cached(
        position: Vector2(100, 110),
        imageCache: cache,
        text: '12',
        color: Colors.white,
      );
      final gem = GemEquipEffectComponent(
        position: Vector2(100, 110),
        gemColor: Colors.red,
        visualScale: 1,
      );
      final death = DeathBurstEffectComponent(
        position: Vector2(100, 110),
        color: Colors.white,
        type: EnemyType.normal,
        radius: 12,
      );
      for (final source in [damage, gem, death]) {
        game.add(source);
      }
      final transferred = _CountingImpact(ImpactEffectStyle.lightning);
      game.add(transferred);
      game.update(.1);
      expect(transferred.parent, isNull);
      game.nativeBattlefieldImpactEffectEvents = false;
      await game.ready();
      expect(transferred.parent, same(game));
      expect([
        damage.parent,
        gem.parent,
        death.parent,
      ], everyElement(same(game)));
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      expect(
        game.battlefieldFrame!.effects!.items.map((e) => e.kind),
        containsAll(['damage', 'gem', 'death', 'impact']),
      );
      expect(transferred.visualProgress, closeTo(.1 / .28, 1e-10));
    },
  );

  test(
    'combat clear cancels transferred impacts but retains death events',
    () async {
      final game = await _fixture();
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      game.nativeBattlefieldImpactEffectEvents = true;
      final impact = _CountingImpact(ImpactEffectStyle.sniperBlast);
      final death = DeathBurstEffectComponent(
        position: Vector2(100, 110),
        color: Colors.white,
        type: EnemyType.normal,
        radius: 12,
      );
      game.add(impact);
      game.add(death);
      game.debugForceDefeat();
      expect(game.battlefieldFrame!.effects!.events.map((e) => e['kind']), [
        'death',
      ]);
      game.resetNativeBattlefieldEffects(10);
      await game.ready();
      expect(impact.parent, isNull);
      expect(death.parent, same(game));
    },
  );

  test(
    'native creation owns all three effects without Flame ticks and restores live fallback',
    () async {
      final game = await _fixture();
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      final cache = DamageNumberImageCache();
      addTearDown(cache.dispose);
      final damage = DamageNumberComponent.cached(
        position: Vector2(100, 110),
        imageCache: cache,
        text: '12',
        color: Colors.white,
        motion: DamageNumberMotion.fallArc,
      );
      final gem = GemEquipEffectComponent(
        position: Vector2(100, 110),
        gemColor: Colors.red,
        visualScale: 1,
      );
      final death = DeathBurstEffectComponent(
        position: Vector2(100, 110),
        color: Colors.white,
        type: EnemyType.normal,
        radius: 12,
      );
      for (final component in [damage, gem, death]) {
        game.add(component);
      }
      await game.ready();
      expect([damage.parent, gem.parent, death.parent], everyElement(isNull));
      final initial = game.battlefieldFrame!.effects!;
      expect(initial.events.map((e) => e['kind']), ['damage', 'gem', 'death']);
      game.markNativeBattlefieldEffectsSubmitted(
        10,
        5,
        initial.events.map((e) => e['id'] as int),
      );
      game.acknowledgeNativeBattlefieldEffects(10, 5);
      game.update(.05);
      game.setSpeedMultiplier(4);
      game.update(.025);
      final native = game.battlefieldFrame!.effects!;
      expect(native.clock - initial.clock, closeTo(.15, 1e-10));
      expect(
        native.events,
        isEmpty,
        reason: 'ACK ends repeated creation serialization',
      );
      expect(damage.battlefieldEffect(0, Offset.zero, 48)!.age, 0);
      game.nativeBattlefieldLoading = true;
      game.update(5);
      expect(game.battlefieldFrame!.effects!.clock, native.clock);
      game.nativeBattlefieldLoading = false;
      game.resetNativeBattlefieldEffects(9);
      expect(
        damage.parent,
        isNull,
        reason: 'stale view cannot restore effects',
      );
      game.resetNativeBattlefieldEffects(10);
      await game.ready();
      expect([
        damage.parent,
        gem.parent,
        death.parent,
      ], everyElement(same(game)));
      expect(
        damage.battlefieldEffect(0, Offset.zero, 48)!.age,
        closeTo(.15, 1e-10),
      );
      expect(damage.position.x, closeTo(100 - 42 * .15, 1e-5));
      expect(
        damage.position.y,
        closeTo(110 - 28 * .15 + 64 * (.15 * .15 + .05 * .05 + .1 * .1), 1e-5),
      );
    },
  );

  test(
    'core destruction effect clock ignores speed and uses the existing quarter-time dt',
    () async {
      final game = await _fixture();
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      game.setSpeedMultiplier(4);
      game.debugForceDefeat();
      final initial = game.battlefieldFrame!.effects!;
      final gem = GemEquipEffectComponent(
        position: Vector2(100, 110),
        gemColor: Colors.red,
        visualScale: 1,
      );
      game.add(gem);
      game.nativeBattlefieldImpactEffectEvents = true;
      final impact = _CountingImpact(ImpactEffectStyle.spark);
      game.add(impact);
      game.update(.4);
      final current = game.battlefieldFrame!.effects!;
      expect(current.clock - initial.clock, closeTo(.1, 1e-10));
      expect(current.squaredSteps - initial.squaredSteps, closeTo(.01, 1e-10));
      expect(gem.parent, isNull);
      expect(impact.parent, isNull);
      expect(impact.updateCalls, 0);
      game.resetNativeBattlefieldEffects(10);
      await game.ready();
      expect(impact.visualProgress, closeTo(.1 / .28, 1e-10));
    },
  );

  test('reward freezes native lifetime and its squared-step clock', () async {
    final game = await _fixture();
    game.battlefieldProjection = _projection;
    game.nativeBattlefieldGroups = {'effects'};
    game.nativeBattlefieldEffectEvents = true;
    game.debugOpenGemReward();
    final gem = GemEquipEffectComponent(
      position: Vector2(100, 110),
      gemColor: Colors.red,
      visualScale: 1,
    );
    game.add(gem);
    final initial = game.battlefieldFrame!.effects!;
    game.setSpeedMultiplier(4);
    game.update(100);
    final current = game.battlefieldFrame!.effects!;
    expect(current.clock, initial.clock);
    expect(current.squaredSteps, initial.squaredSteps);
    expect(current.events, hasLength(1));
  }, skip: !const bool.fromEnvironment('RUNE_NEXUS_DEBUG_PANEL'));

  test(
    'native expiry and stage replacement cannot restore old effects',
    () async {
      final game = await _fixture();
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      final gem = GemEquipEffectComponent(
        position: Vector2(100, 110),
        gemColor: Colors.red,
        visualScale: 1,
      );
      game.add(gem);
      game.update(1);
      expect(
        game.battlefieldFrame!.effects!.events,
        hasLength(1),
        reason: 'one drawable delivery survives one-tick expiry',
      );
      game.resetNativeBattlefieldEffects(10);
      await game.ready();
      expect(gem.parent, isNull);
      game.nativeBattlefieldEffectEvents = true;
      final second = GemEquipEffectComponent(
        position: Vector2(100, 110),
        gemColor: Colors.red,
        visualScale: 1,
      );
      game.add(second);
      game.startStage(2);
      await game.ready();
      expect(second.parent, isNull);
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
    },
  );

  test(
    '3D flame and frost impacts stay off before ACK and after reset',
    () async {
      final game = await _fixture();
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      final flame = _CountingImpact(ImpactEffectStyle.flame);
      final frost = _CountingImpact(ImpactEffectStyle.frost);
      game.add(flame);
      game.add(frost);
      await game.ready();
      _renderOnce(game);
      expect(
        flame.renderCalls,
        0,
        reason: 'native ACK delay must not restore flame',
      );
      expect(
        frost.renderCalls,
        0,
        reason: 'native ACK delay must not restore frost',
      );
      final ids = game.battlefieldFrame!.effects!.items
          .map((e) => e.id)
          .toList();
      game.markNativeBattlefieldEffectsSubmitted(10, 1, ids);
      game.acknowledgeNativeBattlefieldEffects(10, 1);
      _renderOnce(game);
      game.resetNativeBattlefieldEffects(10);
      game.nativeBattlefieldGroups = {};
      _renderOnce(game);
      expect(flame.renderCalls, 0);
      expect(frost.renderCalls, 0);
      game.battlefieldProjection = null;
      _renderOnce(game);
      expect(
        flame.renderCalls,
        1,
        reason: 'original 2D battlefield must retain effects',
      );
      expect(frost.renderCalls, 1);
    },
  );

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
      game.nativeBattlefieldEffectEvents = true;
      game.nativeBattlefieldImpactEffectEvents = true;
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
      expect(frame.effects!.events, isEmpty);
      expect(blast.parent, same(game));
      game.markNativeBattlefieldEffectsSubmitted(10, 1, []);
      game.acknowledgeNativeBattlefieldEffects(10, 1);
      expect(game.isNativeBattlefieldEffect(blast), isFalse);
    },
  );

  testWidgets(
    'production widget routes blast capability and waits for actual application',
    (tester) async {
      const channel = MethodChannel('rune_nexus/godot_preview');
      final messenger = tester.binding.defaultBinaryMessenger;
      final game = (await tester.runAsync(_fixture))!;
      var applyEvents = false;
      var eventFrames = 0;
      int? priorApplied;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getStatus') return {'ready': true, 'error': ''};
        if (call.method != 'submitFrameV2') return null;
        final frame =
            jsonDecode((call.arguments as Map)['frame'] as String) as Map;
        final effects = (frame['presentation'] as Map)['effects'] as Map;
        if ((effects['events'] as List).isNotEmpty) {
          eventFrames++;
          expect((frame['impacts'] as List), isEmpty);
          if (applyEvents) priorApplied = frame['seq'] as int;
        } else {
          priorApplied = frame['seq'] as int;
        }
        return jsonEncode({
          'presentationVersion': 2,
          'sceneEpoch': frame['sceneEpoch'],
          'viewportRevision': frame['viewportRevision'],
          'viewport': frame['viewport'],
          'sequence': priorApplied,
          'appliedGroups': ['effects'],
          'nativeEffectEvents': true,
          'nativeBlastEffectEvents': true,
          'projection': {
            'origin': [.1, .2],
            'xAxis': [.1, 0],
            'yAxis': [0, .1],
            'heightAxis': [0, -.1],
          },
        });
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      });
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
      expect(game.nativeBattlefieldBlastEffectEvents, isTrue);
      expect(game.nativeBattlefieldImpactEffectEvents, isFalse);
      final blast = _CountingImpact(ImpactEffectStyle.blast);
      game.add(blast);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(eventFrames, greaterThan(1));
      expect(game.battlefieldFrame!.effects!.events, hasLength(1));
      expect(blast.parent, isNull);
      applyEvents = true;
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      expect(game.battlefieldFrame!.impacts, isEmpty);
      expect(blast.updateCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'combined submit response acknowledges only the previously applied effect frame',
    (tester) async {
      const channel = MethodChannel('rune_nexus/godot_preview');
      final messenger = tester.binding.defaultBinaryMessenger;
      Map<String, dynamic>? latest;
      var acknowledge = false;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getStatus') return {'ready': true, 'error': ''};
        if (call.method != 'submitFrameV2') return null;
        final envelope = call.arguments as Map;
        final applied = latest;
        latest =
            jsonDecode(envelope['frame'] as String) as Map<String, dynamic>;
        expect(envelope['sceneEpoch'], latest!['sceneEpoch']);
        if (!acknowledge || applied == null) return '{}';
        return jsonEncode({
          'presentationVersion': 2,
          'sceneEpoch': applied['sceneEpoch'],
          'viewportRevision': applied['viewportRevision'],
          'viewport': applied['viewport'],
          'sequence': applied['seq'],
          'appliedGroups': ['effects'],
          'projection': {
            'origin': [.1, .2],
            'xAxis': [.1, 0],
            'yAxis': [0, .1],
            'heightAxis': [0, -.1],
          },
        });
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
      final effect = _ShortEffect();
      game.add(effect);
      await tester.runAsync(game.ready);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(latest, isNotNull);
      expect(game.isNativeBattlefieldEffect(effect), isFalse);
      acknowledge = true;
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.isNativeBattlefieldEffect(effect), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'in-flight old generation acknowledgement cannot consume a retained death event',
    (tester) async {
      const channel = MethodChannel('rune_nexus/godot_preview');
      final messenger = tester.binding.defaultBinaryMessenger;
      final game = (await tester.runAsync(_fixture))!;
      var cancelDuringSubmit = false;
      var cancelled = false;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getStatus') return {'ready': true, 'error': ''};
        if (call.method != 'submitFrameV2') return null;
        final frame =
            jsonDecode((call.arguments as Map)['frame'] as String) as Map;
        final effects = (frame['presentation'] as Map)['effects'] as Map;
        if (cancelDuringSubmit && (effects['events'] as List).isNotEmpty) {
          cancelDuringSubmit = false;
          cancelled = true;
          game.debugForceDefeat();
        }
        return jsonEncode({
          'presentationVersion': 2,
          'sceneEpoch': frame['sceneEpoch'],
          'viewportRevision': frame['viewportRevision'],
          'viewport': frame['viewport'],
          'sequence': frame['seq'],
          'appliedGroups': ['effects'],
          'nativeEffectEvents': true,
          'nativeBlastEffectEvents': true,
          'projection': {
            'origin': [.1, .2],
            'xAxis': [.1, 0],
            'yAxis': [0, .1],
            'heightAxis': [0, -.1],
          },
        });
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      });
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
      expect(game.nativeBattlefieldEffectEvents, isTrue);
      expect(game.nativeBattlefieldBlastEffectEvents, isTrue);
      expect(game.nativeBattlefieldImpactEffectEvents, isFalse);
      final blast = _CountingImpact(ImpactEffectStyle.blast);
      game.add(blast);
      game.add(
        DeathBurstEffectComponent(
          position: Vector2(100, 110),
          color: Colors.white,
          type: EnemyType.normal,
          radius: 12,
        ),
      );
      cancelDuringSubmit = true;
      await tester.pump(const Duration(milliseconds: 16));
      expect(cancelled, isTrue);
      expect(blast.parent, isNull);
      expect(
        game.battlefieldFrame!.effects!.events,
        hasLength(1),
        reason: 'old submission must not ACK the newly retained generation',
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        game.battlefieldFrame!.effects!.events,
        isEmpty,
        reason: 'new generation is acknowledged normally',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
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
        if (call.method == 'submitFrameV2') {
          final envelope = call.arguments as Map;
          final frame = jsonDecode(envelope['frame'] as String) as Map;
          expect(envelope['sceneEpoch'], frame['sceneEpoch']);
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
