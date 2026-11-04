import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_enemy_data.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/game/components/enemy_component.dart';
import 'package:rune_nexus/game/components/nexus_core_beam_component.dart';
import 'package:rune_nexus/game/components/rift_mark_pulse_component.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_effects.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_projection.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/godot_battlefield_frame.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';

mixin CountWork on PositionComponent implements BattlefieldEffectSource {
  int updates = 0;
  int snapshots = 0;
}

class CountedBeam extends NexusCoreBeamComponent with CountWork {
  CountedBeam(RuneNexusGame game, EnemyComponent target)
    : super(
        game: game,
        target: target,
        start: Vector2(100, 110),
        color: const Color(0xffaabbff),
      );
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

class CountedRift extends RiftMarkPulseComponent with CountWork {
  CountedRift(RuneNexusGame game, List<EnemyComponent> targets)
    : super(
        game: game,
        targets: targets,
        source: Vector2(100, 110),
        color: const Color(0xffcfa7ff),
      );
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

Future<Map<String, Object>> measure({
  required bool native,
  required int beamCount,
  required int riftCount,
  required int enemyCount,
  required int ticks,
}) async {
  final game = RuneNexusGame(saveRepository: MemorySaveRepository());
  game.onGameResize(Vector2(400, 800));
  // ignore: invalid_use_of_internal_member
  await game.load();
  // ignore: invalid_use_of_internal_member
  game.mount();
  await game.ready();
  game.nativeBattlefieldSceneEpoch = 10;
  game.resetNativeBattlefieldEffects(10);
  game.battlefieldProjection = const BattlefieldProjection(
    origin: Offset(20, 30),
    xAxis: Offset(40, 0),
    yAxis: Offset(0, 40),
    heightAxis: Offset(0, -20),
  );
  game.nativeBattlefieldGroups = {'effects'};
  game.nativeBattlefieldEffectEvents = true;
  game.nativeBattlefieldLinkedEffectEvents = native;
  final targets = [
    for (var i = 0; i < enemyCount; i++)
      EnemyComponent(
        definition: gameEnemies[EnemyType.normal]!,
        maxHp: 1000,
        path: [Vector2(140 + i * 2, 150), Vector2(300, 150)],
        game: game,
      ),
  ];
  for (final target in targets) {
    game.add(target);
  }
  game.enemies.addAll(targets);
  await game.ready();
  final effects = <CountWork>[
    for (var i = 0; i < beamCount; i++)
      CountedBeam(game, targets[i % targets.length]),
    for (var i = 0; i < riftCount; i++)
      CountedRift(game, targets.take(4).toList()),
  ];
  for (final effect in effects) {
    game.add(effect);
  }
  await game.ready();
  var records = 0,
      bytes = 0,
      enemyBytes = 0,
      logicalBytes = 0,
      logicalRecords = 0;
  final frames = <Map<String, int>>[];
  for (var tick = 0; tick <= ticks; tick++) {
    if (tick > 0) {
      // Repeatable moving target input, including movement after beam expiry.
      for (var i = 0; i < targets.length; i++) {
        targets[i].position += Vector2(0.5, i.isEven ? 0.25 : -0.25);
      }
      game.update(1 / 60);
    }
    final frame = game.battlefieldFrame!;
    final payload = encodeGodotBattlefieldFrame(frame, sequence: tick);
    final presentation = frame.effects!;
    final effectBytes = utf8.encode(jsonEncode(presentation.toJson())).length;
    final enemies = payload['enemies']! as List;
    final actualEnemyBytes = utf8.encode(jsonEncode(enemies)).length;
    final noLogicalBytes = utf8
        .encode(
          jsonEncode([
            for (final enemy in enemies) (enemy as List).take(12).toList(),
          ]),
        )
        .length;
    final extraBytes = actualEnemyBytes - noLogicalBytes;
    final n = presentation.items.length + presentation.events.length;
    records += n;
    bytes += effectBytes;
    enemyBytes += actualEnemyBytes;
    logicalBytes += extraBytes;
    logicalRecords += enemies.where((e) => (e as List).length > 12).length;
    frames.add({
      'frame': tick,
      'effect_records': n,
      'effect_bytes': effectBytes,
      'logical_position_bytes': extraBytes,
    });
    game.markNativeBattlefieldEffectsSubmitted(10, tick, [
      for (final e in presentation.items) e.id,
      for (final e in presentation.events) e['id'] as int,
    ], eventGeneration: presentation.generation);
    game.acknowledgeNativeBattlefieldEffects(10, tick);
  }
  final result = <String, Object>{
    'native_linked_events': native,
    'beams': beamCount,
    'rifts': riftCount,
    'enemies': enemyCount,
    'ticks': ticks,
    'seconds': ticks / 60,
    'flame_update_calls': effects.fold<int>(0, (n, e) => n + e.updates),
    'snapshot_calls': effects.fold<int>(0, (n, e) => n + e.snapshots),
    'serialized_effect_records': records,
    'effects_json_bytes': bytes,
    'logical_position_records': logicalRecords,
    'logical_position_json_overhead_bytes': logicalBytes,
    'effects_plus_logical_overhead_bytes': bytes + logicalBytes,
    'effects_plus_entire_enemy_arrays_bytes': bytes + enemyBytes,
    'frames': frames,
  };
  game.disposeAppResources();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('production linked effects work and wire comparison', () async {
    final cases = <Map<String, Object>>[];
    for (final config in [
      (
        name: 'single_beam_one_target',
        beams: 1,
        rifts: 0,
        enemies: 1,
        ticks: 10,
      ),
      (
        name: 'single_beam_forty_enemies',
        beams: 1,
        rifts: 0,
        enemies: 40,
        ticks: 10,
      ),
      (
        name: 'single_rift_four_targets',
        beams: 0,
        rifts: 1,
        enemies: 4,
        ticks: 27,
      ),
      (
        name: 'mixed_four_beams_two_rifts_shared_four_targets',
        beams: 4,
        rifts: 2,
        enemies: 4,
        ticks: 27,
      ),
    ]) {
      final before = await measure(
        native: false,
        beamCount: config.beams,
        riftCount: config.rifts,
        enemyCount: config.enemies,
        ticks: config.ticks,
      );
      final after = await measure(
        native: true,
        beamCount: config.beams,
        riftCount: config.rifts,
        enemyCount: config.enemies,
        ticks: config.ticks,
      );
      expect(after['flame_update_calls'], 0);
      expect(after['snapshot_calls'], config.beams + config.rifts);
      expect(after['serialized_effect_records'], config.beams + config.rifts);
      cases.add({'case': config.name, 'before': before, 'after': after});
    }
    final sparseOne = cases[0]['after']! as Map<String, Object>;
    final sparseForty = cases[1]['after']! as Map<String, Object>;
    expect(
      sparseForty['logical_position_records'],
      sparseOne['logical_position_records'],
    );
    expect(
      sparseForty['logical_position_json_overhead_bytes'],
      sparseOne['logical_position_json_overhead_bytes'],
    );
    expect(
      sparseForty['effects_plus_logical_overhead_bytes'],
      sparseOne['effects_plus_logical_overhead_bytes'],
    );
    final result = {
      'conditions':
          'Flutter test; actual RuneNexusGame update/frame/encode path; default beam 0.14s, rift 0.42s; 60Hz until expiry plus one tick; immediate valid ACK; deterministic moving logical targets; no combat damage or spawn changes. Capability off uses snapshot path. Enemy row overhead is counted from actual encoded rows; the forty-enemy case includes unrelated enemies to check sparse-target overhead.',
      'not_measured':
          'CPU duration, platform-channel serialization, Godot render/CPU, GPU, FPS, heat, device performance; effect+logical bytes exclude unchanged payload fields.',
      'cases': cases,
    };
    File(
      'design/stage1_3d/presentation_migration/core_effect_lifecycle/work-results.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
    stdout.writeln(jsonEncode(result));
  });
}
