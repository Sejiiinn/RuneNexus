// Isolated, memory-only comparison runner. Does not touch production saves.
// Build with RUNE_NEXUS_DEBUG_PANEL=true. All existing visual options stay on.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:rune_nexus/data/save/online_save_repository.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/game/components/enemy_component.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/godot_battlefield_frame.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/ui/hud/game_hud.dart';

const _channel = MethodChannel('rune_nexus/godot_preview');
const _seconds = int.fromEnvironment('RN_VALIDATION_SECONDS', defaultValue: 20);
const _warmSeconds = int.fromEnvironment(
  'RN_VALIDATION_WARMUP',
  defaultValue: 8,
);
const _stressCount = int.fromEnvironment(
  'RN_VALIDATION_ENEMIES',
  defaultValue: 96,
);
const _only = String.fromEnvironment('RN_VALIDATION_SCENARIO');
const _handoff = bool.fromEnvironment('RN_VALIDATION_HANDOFF');
const _snapshots = bool.fromEnvironment(
  'RN_VALIDATION_SNAPSHOTS',
  defaultValue: true,
);

void _record(Map<String, Object?> record) {
  final data = jsonEncode({
    'schema': 1,
    'runner': 'flutter_flame_godot',
    ...record,
  });
  for (var offset = 0; offset < data.length; offset += 700) {
    // ignore: avoid_print
    print(
      'RN_VALIDATION_CHUNK ${offset == 0 ? 'START' : 'CONT'} ${data.substring(offset, (offset + 700).clamp(0, data.length))}',
    );
  }
  // ignore: avoid_print
  print('RN_VALIDATION_END');
}

Map<String, Object> _summary(List<int> values) {
  if (values.isEmpty) return {'samples': 0};
  final sorted = List<int>.of(values)..sort();
  int p(double fraction) => sorted[(sorted.length * fraction).ceil() - 1];
  return {
    'samples': sorted.length,
    'mean': sorted.fold<double>(0, (a, b) => a + b) / sorted.length,
    'p50': p(.5),
    'p95': p(.95),
    'p99': p(.99),
    'max': sorted.last,
    'over_16_667_ms_ratio':
        sorted.where((v) => v > 16667).length / sorted.length,
    'over_33_334_ms_ratio':
        sorted.where((v) => v > 33334).length / sorted.length,
  };
}

class _MeasuredGame extends RuneNexusGame {
  _MeasuredGame()
    : super(
        transparentBackground: true,
        saveRepository: MemorySaveRepository(),
        onlineSaveRepository: const NoopOnlineSaveRepository(),
      );
  bool measuring = false;
  final updates = <int>[];
  final gaps = <int>[];
  int? previous;
  @override
  void render(Canvas canvas) {
    if (const bool.fromEnvironment('RN_VALIDATION_HIDE_OVERLAY') &&
        battlefieldProjection != null) {
      return;
    }
    super.render(canvas);
  }

  @override
  void update(double dt) {
    final now = developer.Timeline.now;
    super.update(dt);
    if (measuring) {
      updates.add(developer.Timeline.now - now);
      if (previous != null) gaps.add(now - previous!);
      previous = now;
    }
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _Runner(),
    ),
  );
}

class _Runner extends StatefulWidget {
  const _Runner();
  @override
  State<_Runner> createState() => _RunnerState();
}

class _RunnerState extends State<_Runner> {
  final game = _MeasuredGame();
  final builds = <int>[];
  final rasters = <int>[];
  final totals = <int>[];
  bool started = false;
  String label = '60 FPS 검증 준비';
  @override
  void initState() {
    super.initState();
    game.readyNotifier.addListener(_start);
    SchedulerBinding.instance.addTimingsCallback(_timings);
  }

  void _timings(List<FrameTiming> timings) {
    if (!game.measuring) return;
    for (final t in timings) {
      builds.add(t.buildDuration.inMicroseconds);
      rasters.add(t.rasterDuration.inMicroseconds);
      totals.add(t.totalSpan.inMicroseconds);
    }
  }

  Future<Map<String, dynamic>> _metrics() async =>
      jsonDecode(await _channel.invokeMethod<String>('getMetrics') ?? '{}')
          as Map<String, dynamic>;
  Future<void> _options() => _channel.invokeMethod<void>(
    'setOptions',
    jsonEncode({
      'sceneEpoch': game.nativeBattlefieldSceneEpoch,
      'profile': false,
      'runic_fire_mode': 'all',
      'diagnostic_skip_canvas': '',
    }),
  );
  Map<String, Object?> _counts() {
    final frame = game.battlefieldFrame;
    return {
      'enemies': game.enemies.length,
      'burning': game.enemies.where((e) => e.maxBurnRemaining > 0).length,
      'turrets': frame?.turrets.length,
      'projectiles': frame?.projectiles.length,
      'effects': frame?.effects?.items.length,
    };
  }

  void _addStressTargets() {
    final seed = game.enemies.first;
    final path = seed.path;
    var length = 0.0;
    for (var i = 1; i < path.length; i++) {
      length += path[i].distanceTo(path[i - 1]);
    }
    for (var i = game.enemies.length; i < _stressCount; i++) {
      final enemy = EnemyComponent(
        definition: seed.definition,
        maxHp: seed.maxHp,
        path: path,
        game: game,
        visualPhase: i * .61803398875,
        laneOffsetRatio: ((i % 5) - 2) * .12,
      );
      enemy.distanceTravelled = length * (.05 + .9 * i / _stressCount);
      enemy.updateLayout(tileSize: game.boardDistanceScale * 48, newPath: path);
      game.enemies.add(enemy);
      game.add(enemy);
    }
  }

  Future<void> _phase(
    String name,
    TurretType type,
    int speed, {
    bool stress = false,
  }) async {
    game.debugShowCannonBarrage(turretType: type);
    await game.lifecycleEventsProcessed;
    if (game.enemies.length != 3) {
      throw StateError('Fixture unavailable; enable RUNE_NEXUS_DEBUG_PANEL');
    }
    if (stress) _addStressTargets();
    game.setSpeedMultiplier(speed.toDouble());
    await game.lifecycleEventsProcessed;
    await _options();
    setState(() => label = '$name · 워밍업');
    await Future<void>.delayed(const Duration(seconds: _warmSeconds));
    if (_snapshots && mounted) {
      final frame = game.battlefieldFrame;
      if (frame != null) {
        _record({
          'event': 'snapshot',
          'scenario': name,
          'device_pixel_ratio': View.of(context).devicePixelRatio,
          'physical_size': [
            View.of(context).physicalSize.width,
            View.of(context).physicalSize.height,
          ],
          'path_tiles': [
            for (final point in frame.map.path) [point.x + .5, point.y + .5],
          ],
          'frame': encodeGodotBattlefieldFrame(
            frame,
            sequence: 1,
            sceneEpoch: game.nativeBattlefieldSceneEpoch,
            viewport: Size(game.size.x, game.size.y),
          ),
        });
      }
    }
    // Separate snapshot serialization/logging from the measurement window.
    await Future<void>.delayed(const Duration(seconds: 2));
    game.updates.clear();
    game.gaps.clear();
    game.previous = null;
    builds.clear();
    rasters.clear();
    totals.clear();
    setState(() => label = '$name · 측정');
    final timer = Stopwatch()..start();
    _record({
      'event': 'begin',
      'scenario': name,
      'speed': speed,
      'duration_seconds': _seconds,
      'fixture': 'six_turrets_stationary_immortal_tanks',
      'stress': stress,
      'target_fps': 60,
      ..._counts(),
    });
    game.measuring = true;
    for (var sample = 0; sample < _seconds; sample++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final metrics = await _metrics();
      _record({
        'event': 'sample',
        'scenario': name,
        'sample': sample,
        'elapsed_ms': timer.elapsedMilliseconds,
        'rss_bytes': ProcessInfo.currentRss,
        ..._counts(),
        'metrics': metrics,
      });
    }
    game.measuring = false;
    timer.stop();
    _record({
      'event': 'end',
      'scenario': name,
      ..._counts(),
      'elapsed_ms': timer.elapsedMilliseconds,
      'flutter_update_fps':
          game.updates.length * 1000 / timer.elapsedMilliseconds,
      'game_update_us': _summary(game.updates),
      'flutter_update_gap_us': _summary(game.gaps),
      'flutter_build_us': _summary(builds),
      'flutter_raster_us': _summary(rasters),
      'flutter_total_span_us': _summary(totals),
      'rss_bytes': ProcessInfo.currentRss,
    });
  }

  Future<void> _start() async {
    if (started || !game.readyNotifier.value) return;
    started = true;
    try {
      game.startStage(1);
      await game.lifecycleEventsProcessed;
      final deadline = DateTime.now().add(const Duration(seconds: 90));
      while (game.nativeBattlefieldLoading ||
          game.battlefieldProjection == null) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('Godot readiness timeout');
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      for (final scenario in ['normal', 'fire', 'fire_4x', 'stress_4x']) {
        if (_only.isNotEmpty && _only != scenario) continue;
        await _phase(
          scenario,
          scenario == 'normal' ? TurretType.cannon : TurretType.magic,
          scenario.endsWith('4x') ? 4 : 1,
          stress: scenario == 'stress_4x',
        );
      }
      game.pauseEngine();
      _record({'event': 'complete'});
      if (mounted) setState(() => label = '검증 완료');
      if (_handoff) {
        _record({
          'event': 'handoff',
          'scenario': 'fire_4x',
          'duration_seconds': 30,
        });
        await const MethodChannel(
          'rune_nexus/godot_benchmark',
        ).invokeMethod<void>('openBenchmark', {
          'scenario': 'fire_4x',
          'mode': 'flutter_handoff',
          'duration': 30,
        });
      }
    } on Object catch (error, stack) {
      game.measuring = false;
      _record({'event': 'error', 'error': '$error', 'stack': '$stack'});
      if (mounted) setState(() => label = '$error');
    }
  }

  @override
  void dispose() {
    game.readyNotifier.removeListener(_start);
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Positioned.fill(child: GameHud(game: game)),
        Positioned(
          top: 2,
          right: 8,
          child: SafeArea(
            child: IgnorePointer(
              child: Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
