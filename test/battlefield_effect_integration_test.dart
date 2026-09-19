import 'package:rune_nexus/game/components/lightning_charge_component.dart';
import 'package:rune_nexus/game/components/turret_component.dart';
import 'package:rune_nexus/data/definitions/game_turret_data.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'dart:math' as math;
import 'package:rune_nexus/game/components/lightning_chain_beam_component.dart';
import 'package:rune_nexus/data/definitions/game_enemy_data.dart';
import 'package:rune_nexus/game/components/enemy_component.dart';
import 'package:rune_nexus/game/components/nexus_core_beam_component.dart';
import 'package:rune_nexus/game/components/rift_mark_pulse_component.dart';
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

class _CountingCoreBeam extends NexusCoreBeamComponent {
  _CountingCoreBeam(RuneNexusGame game, EnemyComponent target)
    : super(
        game: game,
        target: target,
        start: Vector2(100, 120),
        color: const Color(0xff88ffff),
      );
  int updates = 0;
  int snapshots = 0;
  @override
  void update(double dt) {
    updates++;
    super.update(dt);
  }

  @override
  BattlefieldEffect? battlefieldEffect(
    int id,
    Offset origin,
    double tileSize, {
    bool includeTargets = false,
  }) {
    snapshots++;
    return super.battlefieldEffect(
      id,
      origin,
      tileSize,
      includeTargets: includeTargets,
    );
  }
}

class _CountingRift extends RiftMarkPulseComponent {
  _CountingRift(RuneNexusGame game, List<EnemyComponent> targets)
    : super(
        game: game,
        targets: targets,
        source: Vector2(100, 120),
        color: const Color(0xff88ffff),
      );
  int updates = 0;
  int snapshots = 0;
  @override
  void update(double dt) {
    updates++;
    super.update(dt);
  }

  @override
  BattlefieldEffect? battlefieldEffect(
    int id,
    Offset origin,
    double tileSize, {
    bool includeTargets = false,
  }) {
    snapshots++;
    return super.battlefieldEffect(
      id,
      origin,
      tileSize,
      includeTargets: includeTargets,
    );
  }
}

class _CountingChain extends LightningChainBeamComponent {
  _CountingChain(EnemyComponent target, {super.source})
    : super(
        sourcePosition: Vector2(100, 120),
        target: target,
        color: const Color(0xff8cfff3),
        duration: .37,
        visualScale: 1.4,
      );
  int updates = 0;
  int snapshots = 0;
  int creations = 0;
  @override
  void update(double dt) {
    updates++;
    super.update(dt);
  }

  @override
  BattlefieldEffect? battlefieldEffect(int id, Offset origin, double tileSize) {
    snapshots++;
    return super.battlefieldEffect(id, origin, tileSize);
  }

  @override
  BattlefieldEffect nativeChainEffect(
    int id,
    Offset origin,
    double tileSize,
    int Function(EnemyComponent) targetId,
  ) {
    creations++;
    return super.nativeChainEffect(id, origin, tileSize, targetId);
  }
}

Future<EnemyComponent> _linkedTarget(RuneNexusGame game) async {
  final enemy = EnemyComponent(
    definition: gameEnemies[EnemyType.normal]!,
    maxHp: 100,
    path: [Vector2(150, 150), Vector2(250, 250)],
    game: game,
    laneOffsetRatio: .12,
  );
  game.enemies.add(enemy);
  game.add(enemy);
  await game.ready();
  return enemy;
}

Future<TurretComponent> _chargeOwner(RuneNexusGame game) async {
  final owner = TurretComponent(
    gridPoint: const GridPoint(2, 0),
    definition: gameTurrets[TurretType.lightning]!,
    game: game,
    center: Vector2(100, 100),
    tileSize: game.battlefieldFrame!.pixelsPerTile,
  );
  game.add(owner);
  await game.ready();
  return owner;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native charge keeps combat timer, skips display samples, survives resize and revocation',
    () async {
      final game = await _fixture();
      final owner = await _chargeOwner(game);
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      game.nativeBattlefieldChargeEffectEvents = true;
      var releases = 0;
      var positions = 0;
      final charge = LightningChargeComponent(
        owner: owner,
        chargePosition: () {
          positions++;
          return owner.lightningChargePosition;
        },
        isActive: () => owner.isMounted,
        onRelease: () => releases++,
        color: owner.definition.color,
      );
      game.add(charge);
      await game.ready();
      final initial = game.battlefieldFrame!.effects!;
      final event = initial.events.single;
      expect(
        charge.parent,
        same(game),
        reason: 'the combat timer must remain mounted',
      );
      expect(event['ownerId'], game.battlefieldChargeOwnerId(owner));
      expect(event['attachmentRadius'], closeTo(.82 * .58, 1e-7));
      expect(initial.items, isEmpty);
      expect(positions, 1);
      game.markNativeBattlefieldEffectsSubmitted(10, 2, [event['id'] as int]);
      game.acknowledgeNativeBattlefieldEffects(10, 2);
      game.update(.1);
      game.nativeBattlefieldLoading = true;
      game.update(5);
      expect(releases, 0);
      expect(
        game.battlefieldEffectCombatClock - initial.clock,
        closeTo(.1, 1e-10),
      );
      game.nativeBattlefieldLoading = false;
      game.onGameResize(Vector2(600, 1000));
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      expect(
        positions,
        1,
        reason: 'ACK, pause and resize must not resample the charge position',
      );
      game.nativeBattlefieldChargeEffectEvents = false;
      await game.ready();
      expect(charge.parent, same(game));
      expect(charge.nativePresentation, isFalse);
      expect(game.children.whereType<LightningChargeComponent>(), hasLength(1));
      final fallback = game.battlefieldFrame!.effects!.items.single;
      expect(
        fallback.age,
        closeTo(.1, 1e-10),
        reason: 'fallback cannot advance or restart the timer',
      );
      game.setSpeedMultiplier(4);
      game.update(.049);
      expect(releases, 0);
      game.update(.0011);
      expect(releases, 1);
      await game.ready();
      game.update(.3);
      expect(releases, 1);
    },
  );

  test(
    'native charge cancellation invalidates unacknowledged starts and preserves other events',
    () async {
      final game = await _fixture();
      final owner = await _chargeOwner(game);
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      game.nativeBattlefieldChargeEffectEvents = true;
      var releases = 0;
      LightningChargeComponent charge() => LightningChargeComponent(
        owner: owner,
        chargePosition: () => owner.lightningChargePosition,
        isActive: () => owner.isMounted,
        onRelease: () => releases++,
        color: owner.definition.color,
      );
      final cancelled = charge();
      final live = charge();
      game.add(cancelled);
      game.add(live);
      await game.ready();
      final initial = game.battlefieldFrame!.effects!;
      game.markNativeBattlefieldEffectsSubmitted(
        10,
        2,
        initial.events.map((e) => e['id'] as int),
        eventGeneration: initial.generation,
      );
      cancelled.removeFromParent();
      await game.ready();
      final afterCancel = game.battlefieldFrame!.effects!;
      expect(afterCancel.generation, greaterThan(initial.generation));
      expect(afterCancel.events, hasLength(1));
      game.acknowledgeNativeBattlefieldEffects(10, 2);
      expect(
        game.battlefieldFrame!.effects!.events,
        hasLength(1),
        reason: 'an old ACK cannot consume a new-generation start',
      );
      owner.removeFromParent();
      await game.ready();
      game.update(.31);
      await game.ready();
      expect(
        releases,
        0,
        reason: 'removed tower must not release even when dt exceeds duration',
      );
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      expect(live.parent, isNull);
    },
  );

  test(
    'normal charge completion does not reset other event generations',
    () async {
      final game = await _fixture();
      final owner = await _chargeOwner(game);
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      game.nativeBattlefieldChargeEffectEvents = true;
      var releases = 0;
      final charge = LightningChargeComponent(
        owner: owner,
        chargePosition: () => owner.lightningChargePosition,
        isActive: () => true,
        onRelease: () => releases++,
        color: owner.definition.color,
      );
      game.add(charge);
      await game.ready();
      final initial = game.battlefieldFrame!.effects!;
      game.update(.299);
      expect(releases, 0);
      game.update(.002);
      await game.ready();
      expect(releases, 1);
      final expired = game.battlefieldFrame!.effects!;
      expect(expired.generation, initial.generation);
      expect(expired.items, isEmpty);
      expect(
        expired.events.single['kind'],
        'charge',
        reason: 'pending delivery remains bounded and cannot replay in Godot',
      );
      game.nativeBattlefieldChargeEffectEvents = false;
      await game.ready();
      expect(charge.parent, isNull);
      expect(releases, 1);
    },
  );

  test(
    'chain creates endpoints once, preserves math and restores both dead endpoints after resize',
    () async {
      final game = await _fixture();
      final source = await _linkedTarget(game);
      final target = await _linkedTarget(game);
      final other = await _linkedTarget(game);
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      game.nativeBattlefieldChainEffectEvents = true;
      final chain = _CountingChain(target, source: source);
      final legacy = chain.battlefieldEffect(90, Offset.zero, 48)!;
      chain.snapshots = 0;
      game.add(chain);
      await game.ready();
      expect(chain.parent, isNull);
      final initial = game.battlefieldFrame!;
      final event = initial.effects!.events.single;
      expect(event['duration'], .37);
      expect(event['scale'], 1.4);
      expect(event['boltSeed'], 100 * 17.0 + 120 * 31.0);
      expect(event['points'] as List, hasLength(2));
      expect(legacy.points, hasLength(6));
      final start = legacy.points.first;
      final delta = legacy.points.last - start;
      final normal = Offset(-delta.dy, delta.dx) / delta.distance;
      for (var i = 1; i < 5; i++) {
        final expected =
            start +
            delta * (i / 5) +
            normal *
                (math.sin((event['boltSeed'] as double) + i * 1.7) *
                    .5 *
                    math.min(18 * 1.4 / 48, delta.distance * .16));
        expect((legacy.points[i] - expected).distance, lessThan(1e-12));
      }
      final wire =
          encodeGodotBattlefieldFrame(initial, sequence: 1)['enemies'] as List;
      expect(wire[0], hasLength(14));
      expect(wire[1], hasLength(14));
      expect(wire[2], hasLength(12));
      expect(other.isMounted, isTrue);
      game.markNativeBattlefieldEffectsSubmitted(10, 1, [event['id'] as int]);
      game.acknowledgeNativeBattlefieldEffects(9, 1);
      expect(game.battlefieldFrame!.effects!.events, hasLength(1));
      game.acknowledgeNativeBattlefieldEffects(10, 1);
      game.update(.04);
      final moving = game.battlefieldFrame!;
      final startGrid = moving.enemies[0].logicalPosition!;
      final endGrid = moving.enemies[1].logicalPosition!;
      expect(moving.effects!.events, isEmpty);
      expect(moving.effects!.items, isEmpty);
      expect(chain.updates, 0);
      expect(chain.snapshots, 0);
      expect(chain.creations, 1);
      source.hp = 0;
      target.removeFromParent();
      await game.ready();
      source.position.setValues(999, 999);
      target.position.setValues(888, 888);
      game.nativeBattlefieldLoading = true;
      game.update(1);
      expect(game.battlefieldEffectCombatClock, .04);
      game.onGameResize(Vector2(600, 1000));
      game.nativeBattlefieldChainEffectEvents = false;
      await game.ready();
      expect(chain.parent, same(game));
      final restored = game.battlefieldFrame!.effects!.items.single;
      expect(restored.age, closeTo(.04, 1e-9));
      expect((restored.points.first - startGrid).distance, lessThan(1e-6));
      expect((restored.points.last - endGrid).distance, lessThan(1e-6));
      expect(restored.toJson().containsKey('boltSeed'), isFalse);
      expect(
        game.battlefieldFrame!.effects!.generation,
        greaterThan(initial.effects!.generation),
      );
      chain.update(.33);
      expect(chain.isRemoving, isTrue);
    },
  );

  test(
    'old linked capability retains chain snapshots and fixed/dead endpoints do not subscribe',
    () async {
      final game = await _fixture();
      final target = await _linkedTarget(game);
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      game.nativeBattlefieldLinkedEffectEvents = true;
      final legacy = _CountingChain(target);
      game.add(legacy);
      await game.ready();
      game.update(.02);
      expect(legacy.parent, same(game));
      expect(legacy.updates, 1);
      expect(game.battlefieldFrame!.effects!.items.single.points, hasLength(6));
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      game.nativeBattlefieldChainEffectEvents = true;
      target.hp = 0;
      final dead = _CountingChain(target);
      game.add(dead);
      final event = game.battlefieldFrame!.effects!.events.single;
      expect(event['targetIds'], [-1, -1]);
      target.position.setValues(999, 999);
      game.resetNativeBattlefieldEffects(10);
      await game.ready();
      final restored = dead.battlefieldEffect(0, Offset.zero, 1)!;
      expect(restored.points.first, const Offset(100, 120));
      expect(restored.points.last, isNot(const Offset(999, 999)));
      expect(game.nativeBattlefieldChainEffectEvents, isFalse);
    },
  );

  test(
    'combat cancellation removes native chain and cannot restore it',
    () async {
      final game = await _fixture();
      final target = await _linkedTarget(game);
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      game.nativeBattlefieldChainEffectEvents = true;
      final chain = _CountingChain(target);
      game.add(chain);
      expect(game.battlefieldFrame!.effects!.events.single['kind'], 'chain');
      game.debugForceDefeat();
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      game.resetNativeBattlefieldEffects(10);
      await game.ready();
      expect(chain.parent, isNull);
    },
  );

  test(
    'linked events remove Flame ticks and snapshots, share logical targets and restore resized anchors',
    () async {
      final game = await _fixture();
      final target = await _linkedTarget(game);
      final other = await _linkedTarget(game);
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      game.nativeBattlefieldLinkedEffectEvents = true;
      // No linked effect means no enemy payload expansion.
      expect(
        (encodeGodotBattlefieldFrame(
                  game.battlefieldFrame!,
                  sequence: 0,
                )['enemies']
                as List)
            .first,
        hasLength(12),
      );
      final beam = _CountingCoreBeam(game, target);
      final rift = _CountingRift(game, [target, other]);
      game.add(beam);
      game.add(rift);
      await game.ready();
      expect(beam.parent, isNull);
      expect(rift.parent, isNull);
      final initial = game.battlefieldFrame!;
      final events = initial.effects!.events;
      expect(events.map((e) => e['duration']), [.14, .42]);
      expect(events.first['targetIds'], [initial.enemies.first.id]);
      expect(
        events.last['targetIds'],
        initial.enemies.map((e) => e.id).toList(),
      );
      game.markNativeBattlefieldEffectsSubmitted(
        10,
        1,
        events.map((e) => e['id'] as int),
      );
      game.acknowledgeNativeBattlefieldEffects(10, 1);
      game.update(.03);
      final moving = game.battlefieldFrame!;
      expect(moving.effects!.events, isEmpty);
      expect(moving.effects!.items, isEmpty);
      expect(beam.updates + rift.updates, 0);
      expect(beam.snapshots + rift.snapshots, 2);
      final wire =
          encodeGodotBattlefieldFrame(moving, sequence: 2)['enemies'] as List;
      expect(wire.first, hasLength(14));
      final logical = moving.enemies.first.logicalPosition!;
      expect((wire.first as List).sublist(12), [logical.dx, logical.dy]);
      expect(moving.enemies.first.position, isNot(logical));
      target.hp = 0;
      other.removeFromParent();
      await game.ready();
      game.nativeBattlefieldLoading = true;
      game.update(2);
      expect(game.battlefieldEffectCombatClock, moving.effects!.clock);
      game.onGameResize(Vector2(600, 1000));
      game.nativeBattlefieldLinkedEffectEvents = false;
      await game.ready();
      expect(beam.parent, same(game));
      expect(rift.parent, same(game));
      final restored = game.battlefieldFrame!.effects!.items;
      final beamSnapshot = restored.firstWhere((e) => e.kind == 'coreBeam');
      final riftSnapshot = restored.firstWhere((e) => e.kind == 'rift');
      expect(beamSnapshot.age, closeTo(.03, 1e-9));
      expect(
        beamSnapshot.position.dx,
        closeTo(events.first['x'] as double, 1e-6),
      );
      expect(beamSnapshot.points.last.dx, closeTo(logical.dx, 1e-6));
      expect(beamSnapshot.points.last.dy, closeTo(logical.dy, 1e-6));
      expect(riftSnapshot.points, isEmpty);
      expect(
        riftSnapshot.position.dx,
        closeTo(events.last['x'] as double, 1e-6),
      );
      expect(beam.updates + rift.updates, 0);
    },
  );

  test(
    'legacy runtime keeps linked snapshot lifecycle until explicit capability',
    () async {
      final game = await _fixture();
      final target = await _linkedTarget(game);
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      final beam = _CountingCoreBeam(game, target);
      final rift = _CountingRift(game, [target]);
      game.add(beam);
      game.add(rift);
      await game.ready();
      game.update(.02);
      expect(beam.parent, same(game));
      expect(rift.parent, same(game));
      expect(beam.updates, 1);
      expect(rift.updates, 1);
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      expect(
        game.battlefieldFrame!.effects!.items.map((e) => e.kind),
        containsAll(['coreBeam', 'rift']),
      );
    },
  );

  test(
    'beam target death before first native delivery restores initial endpoint',
    () async {
      final game = await _fixture();
      final target = await _linkedTarget(game);
      game.battlefieldProjection = _projection;
      game.nativeBattlefieldGroups = {'effects'};
      game.nativeBattlefieldEffectEvents = true;
      game.nativeBattlefieldLinkedEffectEvents = true;
      final beam = _CountingCoreBeam(game, target);
      game.add(beam);
      target.hp = 0;
      target.position.setValues(999, 999);
      final killingBeam = _CountingCoreBeam(game, target);
      game.add(killingBeam);
      final events = game.battlefieldFrame!.effects!.events;
      final event = events.first;
      expect(events.last.containsKey('targetIds'), isFalse);
      final endpoint = (event['points'] as List).last as List;
      game.nativeBattlefieldLinkedEffectEvents = false;
      await game.ready();
      final restoredItems = game.battlefieldFrame!.effects!.items;
      final restored = restoredItems.first;
      final killingEndpoint = (events.last['points'] as List).last as List;
      expect(
        restoredItems.last.points.last.dx,
        closeTo(killingEndpoint[0] as double, 1e-6),
      );
      expect(restored.points.last.dx, closeTo(endpoint[0] as double, 1e-6));
      expect(restored.points.last.dy, closeTo(endpoint[1] as double, 1e-6));
    },
  );

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
    'production widget routes and revokes linked capability with live fallback',
    (tester) async {
      const channel = MethodChannel('rune_nexus/godot_preview');
      final messenger = tester.binding.defaultBinaryMessenger;
      final game = (await tester.runAsync(_fixture))!;
      var applyEvents = false;
      var linkedCapability = true;
      final target = (await tester.runAsync(() => _linkedTarget(game)))!;
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
          'nativeLinkedEffectEvents': linkedCapability,
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
      expect(game.nativeBattlefieldLinkedEffectEvents, isTrue);
      expect(game.nativeBattlefieldImpactEffectEvents, isFalse);
      final blast = _CountingCoreBeam(game, target);
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
      expect(blast.updates, 0);
      linkedCapability = false;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(game.ready);
      expect(game.nativeBattlefieldLinkedEffectEvents, isFalse);
      expect(blast.parent, same(game));
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      expect(
        game.battlefieldFrame!.effects!.items.any((e) => e.kind == 'coreBeam'),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'production widget routes and revokes chain capability with live fallback',
    (tester) async {
      const channel = MethodChannel('rune_nexus/godot_preview');
      final messenger = tester.binding.defaultBinaryMessenger;
      final game = (await tester.runAsync(_fixture))!;
      var applyEvents = false;
      var chainCapability = true;
      final target = (await tester.runAsync(() => _linkedTarget(game)))!;
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
          'nativeLinkedEffectEvents': true,
          'nativeChainEffectEvents': chainCapability,
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
      expect(game.nativeBattlefieldChainEffectEvents, isTrue);
      expect(game.nativeBattlefieldImpactEffectEvents, isFalse);
      final blast = _CountingChain(target);
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
      expect(blast.updates, 0);
      chainCapability = false;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(game.ready);
      expect(game.nativeBattlefieldChainEffectEvents, isFalse);
      expect(blast.parent, same(game));
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      expect(
        game.battlefieldFrame!.effects!.items.any((e) => e.kind == 'chain'),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'production widget routes and revokes charge capability with live fallback',
    (tester) async {
      const channel = MethodChannel('rune_nexus/godot_preview');
      final messenger = tester.binding.defaultBinaryMessenger;
      final game = (await tester.runAsync(_fixture))!;
      var applyEvents = false;
      var chargeCapability = true;
      final owner = (await tester.runAsync(() => _chargeOwner(game)))!;
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
          'nativeLinkedEffectEvents': true,
          'nativeChargeEffectEvents': chargeCapability,
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
      expect(game.nativeBattlefieldChargeEffectEvents, isTrue);
      expect(game.nativeBattlefieldImpactEffectEvents, isFalse);
      var releases = 0;
      final blast = LightningChargeComponent(
        owner: owner,
        chargePosition: () => owner.lightningChargePosition,
        isActive: () => true,
        onRelease: () => releases++,
        color: owner.definition.color,
      );
      game.add(blast);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(eventFrames, greaterThan(1));
      expect(game.battlefieldFrame!.effects!.events, hasLength(1));
      await tester.runAsync(game.ready);
      expect(blast.parent, same(game));
      applyEvents = true;
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      expect(game.battlefieldFrame!.impacts, isEmpty);
      expect(releases, 0);
      chargeCapability = false;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(game.ready);
      expect(game.nativeBattlefieldChargeEffectEvents, isFalse);
      expect(blast.parent, same(game));
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
      expect(
        game.battlefieldFrame!.effects!.items.any((e) => e.kind == 'charge'),
        isTrue,
      );
      game.update(.301);
      await tester.runAsync(game.ready);
      game.update(.301);
      expect(releases, 1);
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
