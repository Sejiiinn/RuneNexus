import 'dart:async';
import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:rune_nexus/data/save/online_save_repository.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/godot_battlefield_frame.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: const GodotPreview(),
  ),
);

/// 기존 전투 입력을 공식 Android Godot 엔진으로 전달하는 독립 검수 화면.
class GodotPreview extends StatefulWidget {
  const GodotPreview({super.key});

  @override
  State<GodotPreview> createState() => _GodotPreviewState();
}

class _GodotPreviewState extends State<GodotPreview>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const channel = MethodChannel('rune_nexus/godot_preview');
  late final RuneNexusGame game;
  late final Ticker ticker;
  Timer? metricsTimer;
  bool ready = false;
  bool starting = false;
  bool started = false;
  bool playing = false;
  bool foreground = true;
  bool sending = false;
  bool dirty = true;
  bool shadows = true;
  bool volume = true;
  bool empty = false;
  String camera = 'angled';
  String? error;
  double speed = 1;
  double zoom = 1;
  int sequence = 0;
  Map<String, dynamic> metrics = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game = RuneNexusGame(
      transparentBackground: true,
      saveRepository: MemorySaveRepository(),
      onlineSaveRepository: const NoopOnlineSaveRepository(),
    );
    game.readyNotifier.addListener(startScenario);
    ticker = createTicker((_) => submitFrame())..start();
    metricsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => pollMetrics(),
    );
  }

  Future<void> startScenario() async {
    if (started || starting || !game.readyNotifier.value) return;
    starting = true;
    game.debugShowCannonBarrage();
    await game.lifecycleEventsProcessed;
    if (!mounted) return;
    game.pauseEngine();
    setState(() {
      started = true;
      starting = false;
      dirty = true;
    });
  }

  Future<void> pollMetrics() async {
    if (!mounted || !foreground) return;
    try {
      final status =
          await channel.invokeMapMethod<String, dynamic>('getStatus') ?? {};
      final newMetrics =
          jsonDecode(await channel.invokeMethod<String>('getMetrics') ?? '{}')
              as Map<String, dynamic>;
      if (!mounted) return;
      final becameReady = !ready && status['ready'] == true;
      setState(() {
        ready = status['ready'] == true;
        metrics = newMetrics;
        error = (status['error'] as String?)?.isNotEmpty == true
            ? status['error'] as String
            : null;
      });
      if (becameReady) {
        await sendOptions();
        dirty = true;
      }
    } on PlatformException catch (exception) {
      if (mounted) setState(() => error = exception.message ?? exception.code);
    } on MissingPluginException {
      if (mounted) setState(() => error = 'Godot 전용 Android APK로 실행해 주세요.');
    }
  }

  Future<void> sendOptions() async {
    if (!ready) return;
    await channel.invokeMethod<void>(
      'setOptions',
      jsonEncode({
        'camera': camera,
        'zoom': zoom,
        'shadows': shadows,
        'volume': volume,
        'empty': empty,
      }),
    );
  }

  Future<void> submitFrame() async {
    if (!ready || !started || !foreground || sending || (!playing && !dirty)) {
      return;
    }
    final frame = game.battlefieldFrame;
    if (frame == null) return;
    sending = true;
    dirty = false;
    try {
      // 단일 최신 프레임 전송: 느린 소비자에서 메시지 대기열 누적 방지.
      await channel.invokeMethod<void>(
        'submitFrame',
        jsonEncode(encodeGodotBattlefieldFrame(frame, sequence: sequence++)),
      );
    } on PlatformException catch (exception) {
      if (mounted) setState(() => error = exception.message ?? exception.code);
    } finally {
      sending = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground && playing) {
      game.resumeEngine();
    } else {
      game.pauseEngine();
    }
    dirty = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    metricsTimer?.cancel();
    ticker.dispose();
    game.readyNotifier.removeListener(startScenario);
    game.pauseEngine();
    game.disposeAppResources();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fps = (metrics['fps'] as num?)?.toStringAsFixed(0) ?? '—';
    final ms = (metrics['frame_ms'] as num?)?.toStringAsFixed(1) ?? '—';
    return Scaffold(
      backgroundColor: const Color(0xff101b20),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                'Godot 3D 연결 테스트',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                error ??
                    (ready && started
                        ? '대포 6문 · 표적 3기 · ${playing ? '연속 사격' : '정지 장면'}'
                        : 'Godot 엔진과 전투 준비 중…'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: error == null ? Colors.white70 : Colors.orangeAccent,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: Opacity(opacity: 0, child: GameWidget(game: game)),
                  ),
                  // Godot SurfaceView를 실제 Android 계층에 합성.
                  PlatformViewLink(
                    viewType: 'rune_nexus/godot_view',
                    surfaceFactory: (context, controller) => AndroidViewSurface(
                      controller: controller as AndroidViewController,
                      hitTestBehavior: PlatformViewHitTestBehavior.opaque,
                      gestureRecognizers: const {},
                    ),
                    onCreatePlatformView: (params) {
                      final controller =
                          PlatformViewsService.initExpensiveAndroidView(
                            id: params.id,
                            viewType: 'rune_nexus/godot_view',
                            layoutDirection: TextDirection.ltr,
                            onFocus: () => params.onFocusChanged(true),
                          );
                      controller.addOnPlatformViewCreatedListener(
                        params.onPlatformViewCreated,
                      );
                      unawaited(controller.create());
                      return controller;
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                '$fps FPS · $ms ms · 드로 콜 ${metrics['draw_calls'] ?? '—'} · 삼각형 ${metrics['primitives'] ?? '—'}',
                textAlign: TextAlign.center,
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .35,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton(
                          onPressed: !started || !ready
                              ? null
                              : () {
                                  setState(() => playing = !playing);
                                  playing
                                      ? game.resumeEngine()
                                      : game.pauseEngine();
                                  dirty = true;
                                },
                          child: Text(playing ? '일시 정지' : '연속 사격 시작'),
                        ),
                        OutlinedButton(
                          onPressed: !started
                              ? null
                              : () async {
                                  game.resumeEngine();
                                  game.debugShowCannonBarrage();
                                  await game.lifecycleEventsProcessed;
                                  if (!playing || !foreground) {
                                    game.pauseEngine();
                                  }
                                  dirty = true;
                                },
                          child: const Text('처음 상태로'),
                        ),
                        for (final entry in {
                          'angled': '고정 시점',
                          'drone': '드론 시점',
                        }.entries)
                          ChoiceChip(
                            label: Text(entry.value),
                            selected: camera == entry.key,
                            onSelected: (_) {
                              setState(() => camera = entry.key);
                              unawaited(sendOptions());
                            },
                          ),
                        for (final value in [1.0, 2.0, 4.0])
                          ChoiceChip(
                            label: Text('${value.toInt()}배속'),
                            selected: speed == value,
                            onSelected: (_) {
                              setState(() => speed = value);
                              game.setSpeedMultiplier(value);
                            },
                          ),
                        FilterChip(
                          label: const Text('그림자'),
                          selected: shadows,
                          onSelected: (value) {
                            setState(() => shadows = value);
                            unawaited(sendOptions());
                          },
                        ),
                        FilterChip(
                          label: const Text('폭발 볼륨'),
                          selected: volume,
                          onSelected: (value) {
                            setState(() => volume = value);
                            unawaited(sendOptions());
                          },
                        ),
                        FilterChip(
                          label: const Text('빈 3D 화면'),
                          selected: empty,
                          onSelected: (value) {
                            setState(() => empty = value);
                            unawaited(sendOptions());
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('확대'),
                        Expanded(
                          child: Slider(
                            min: .8,
                            max: 2.2,
                            value: zoom,
                            onChanged: (value) {
                              setState(() => zoom = value);
                              unawaited(sendOptions());
                            },
                          ),
                        ),
                        Text('${zoom.toStringAsFixed(1)}×'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
