// Local fire turret rendering A/B: same APK, memory-only save, no recording.
// Enemy burn is disabled throughout. Only runic_fire_mode changes per phase.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:rune_nexus/data/save/online_save_repository.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/ui/hud/game_hud.dart';

const variant = String.fromEnvironment(
  'RN_PERF_VARIANT',
  defaultValue: 'turret_same_apk',
);
const canvasProbe = bool.fromEnvironment('RN_CANVAS_PROBE');
const creationProbe = bool.fromEnvironment('RN_CREATION_PROBE');
const profileProbe = bool.fromEnvironment('RN_PROFILE_PROBE');
const samples = int.fromEnvironment('RN_PERF_SAMPLES', defaultValue: 6);
const channel = MethodChannel('rune_nexus/godot_preview');

void record(Map<String, Object?> value) {
  // Android truncates long Flutter log lines. Chunk once per sample.
  final encoded = jsonEncode({'variant': variant, ...value});
  for (var offset = 0; offset < encoded.length; offset += 700) {
    final end = (offset + 700).clamp(0, encoded.length);
    // ignore: avoid_print
    print(
      'RN_AB_CHUNK ${offset == 0 ? 'START' : 'CONT'} ${encoded.substring(offset, end)}',
    );
  }
  // ignore: avoid_print
  print('RN_AB_END');
}

Map<String, Object> summarize(List<int> values) {
  if (values.isEmpty) return {'samples': 0};
  final sorted = List<int>.of(values)..sort();
  int percentile(double fraction) =>
      sorted[(sorted.length * fraction).ceil() - 1];
  return {
    'samples': sorted.length,
    'mean': sorted.fold<int>(0, (a, b) => a + b) / sorted.length,
    'p50': percentile(.5),
    'p95': percentile(.95),
    'p99': percentile(.99),
    'max': sorted.last,
  };
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const PerformanceRun(),
    ),
  );
}

class MeasuredGame extends RuneNexusGame {
  MeasuredGame()
    : super(
        transparentBackground: true,
        saveRepository: MemorySaveRepository(),
        onlineSaveRepository: const NoopOnlineSaveRepository(),
      );
  bool measuring = false;
  final updatesUs = <int>[];
  @override
  void update(double dt) {
    if (!measuring) {
      super.update(dt);
      return;
    }
    final start = developer.Timeline.now;
    super.update(dt);
    updatesUs.add(developer.Timeline.now - start);
  }
}

class PerformanceRun extends StatefulWidget {
  const PerformanceRun({super.key});
  @override
  State<PerformanceRun> createState() => _PerformanceRunState();
}

class _PerformanceRunState extends State<PerformanceRun> {
  final game = MeasuredGame();
  final buildUs = <int>[];
  final rasterUs = <int>[];
  bool started = false;
  String label = '준비 중';

  @override
  void initState() {
    super.initState();
    game.readyNotifier.addListener(_start);
    SchedulerBinding.instance.addTimingsCallback(_timings);
  }

  void _timings(List<FrameTiming> timings) {
    if (!game.measuring) return;
    for (final t in timings) {
      buildUs.add(t.buildDuration.inMicroseconds);
      rasterUs.add(t.rasterDuration.inMicroseconds);
    }
  }

  Future<void> _ready() async {
    final limit = DateTime.now().add(const Duration(seconds: 90));
    while (game.nativeBattlefieldLoading ||
        game.battlefieldProjection == null) {
      if (DateTime.now().isAfter(limit)) {
        throw StateError('Scene readiness timeout');
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await channel.invokeMethod<void>(
      'setOptions',
      jsonEncode({
        'sceneEpoch': game.nativeBattlefieldSceneEpoch,
        'profile': true,
      }),
    );
  }

  Map<String, Object> _combatCounts() => {
    'enemies': game.enemies.length,
    'actual_burning': game.enemies
        .where((enemy) => enemy.maxBurnRemaining > 0)
        .length,
  };

  String canvasSkip = '';

  Future<void> _fireMode(String mode, {bool profile = true}) async {
    await channel.invokeMethod<void>(
      'setOptions',
      jsonEncode({
        'sceneEpoch': game.nativeBattlefieldSceneEpoch,
        'profile': profile,
        'burn_effects': false,
        'runic_fire_mode': mode,
        'diagnostic_skip_canvas': canvasSkip,
      }),
    );
  }

  Future<void> _measure(
    String phase,
    String mode, {
    bool profile = true,
  }) async {
    await _fireMode(mode, profile: profile);
    const warmSeconds = 3;
    setState(() => label = '$variant · $phase');
    await Future<void>.delayed(Duration(seconds: warmSeconds));
    final initial =
        jsonDecode(await channel.invokeMethod<String>('getMetrics') ?? '{}')
            as Map;
    var window = initial['profile_window_id'];
    game.updatesUs.clear();
    buildUs.clear();
    rasterUs.clear();
    game.measuring = true;
    record({
      'event': 'begin',
      'phase': phase,
      'runic_fire_mode': mode,
      ..._combatCounts(),
    });
    var collected = 0;
    final deadline = DateTime.now().add(Duration(seconds: samples * 3 + 10));
    while (collected < samples) {
      await Future<void>.delayed(const Duration(milliseconds: 1050));
      if (DateTime.now().isAfter(deadline)) throw StateError('Metrics timeout');
      final metrics =
          jsonDecode(await channel.invokeMethod<String>('getMetrics') ?? '{}')
              as Map;
      if (profile &&
          (metrics['profile_window_id'] == null ||
              metrics['profile_window_id'] == window)) {
        continue;
      }
      window = metrics['profile_window_id'];
      record({
        'event': 'sample',
        'phase': phase,
        'runic_fire_mode': mode,
        ..._combatCounts(),
        'metrics': metrics,
      });
      collected++;
    }
    game.measuring = false;
    record({
      'event': 'end',
      'phase': phase,
      'runic_fire_mode': mode,
      ..._combatCounts(),
      'game_update_us': summarize(game.updatesUs),
      'flutter_build_us': summarize(buildUs),
      'flutter_raster_us': summarize(rasterUs),
    });
  }

  Future<void> _start() async {
    if (started || !game.readyNotifier.value) return;
    started = true;
    try {
      game.startStage(1);
      await game.lifecycleEventsProcessed;
      await _ready();
      game.debugShowCannonBarrage(
        turretType: creationProbe ? TurretType.cannon : TurretType.magic,
      );
      game.setSpeedMultiplier(4);
      await game.lifecycleEventsProcessed;
      await _fireMode('all');
      setState(() => label = '$variant · 초기 워밍업');
      await Future<void>.delayed(const Duration(seconds: 12));
      if (game.enemies.length != 3 ||
          (!creationProbe &&
              !game.enemies.any((enemy) => enemy.maxBurnRemaining > 0))) {
        throw StateError('Three-target burning fixture did not initialize');
      }
      if (canvasProbe) {
        await _measure('canvas_all_1', 'all', profile: false);
        canvasSkip = 'flame';
        await _measure('no_flame_impact', 'all', profile: false);
        canvasSkip = '';
        await _measure('canvas_all_2', 'all', profile: false);
        canvasSkip = 'damage';
        await _measure('no_damage_display', 'all', profile: false);
        canvasSkip = '';
        await _measure('canvas_all_3', 'all', profile: false);
      } else if (creationProbe) {
        await _measure('cold_cannon', 'all', profile: false);
        game.debugShowCannonBarrage(turretType: TurretType.magic);
        await game.lifecycleEventsProcessed;
        await _measure('first_magic', 'all', profile: false);
        record({'event': 'stack_capture_ready'});
        await Future<void>.delayed(const Duration(seconds: 35));
        game.debugShowCannonBarrage(turretType: TurretType.cannon);
        await game.lifecycleEventsProcessed;
        await _measure('cannon_after_magic', 'all', profile: false);
      } else if (profileProbe) {
        await _measure('profile_on_1', 'all');
        await _measure('profile_off', 'all', profile: false);
        await _measure('profile_on_2', 'all');
      } else {
        await _measure('stage1_fire_all_1', 'all');
        await _measure('stage1_fire_no_particles_1', 'no_particles');
        await _measure('stage1_fire_off_1', 'off');
        await _measure('stage1_fire_no_model_1', 'no_model');
        await _measure('stage1_fire_off_2', 'off');
        await _measure('stage1_fire_no_particles_2', 'no_particles');
        await _measure('stage1_fire_all_2', 'all');
      }
      game.pauseEngine();
      await channel.invokeMethod<void>(
        'setOptions',
        jsonEncode({
          'sceneEpoch': game.nativeBattlefieldSceneEpoch,
          'profile': false,
          'burn_effects': false,
          'runic_fire_mode': 'all',
        }),
      );
      setState(() => label = '$variant · 측정 완료');
      record({'event': 'complete'});
    } on Object catch (error, stack) {
      game.measuring = false;
      record({'event': 'error', 'error': '$error', 'stack': '$stack'});
      if (mounted) setState(() => label = '$error');
    }
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    game.readyNotifier.removeListener(_start);
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
