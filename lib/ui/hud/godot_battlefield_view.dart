import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../game/rendering/stage1_3d/battlefield_projection.dart';
import '../../game/rendering/stage1_3d/godot_battlefield_frame.dart';
import '../../game/rune_nexus_game.dart';

/// 실제 전투 HUD 아래 합성하는 네이티브 전장. 입력과 상태 표시는 Flame에 유지.
class GodotBattlefieldView extends StatefulWidget {
  const GodotBattlefieldView({
    super.key,
    required this.game,
    this.cameraView = 'angled',
    this.onAvailabilityChanged,
  });

  final RuneNexusGame game;
  final String cameraView;
  final ValueChanged<bool>? onAvailabilityChanged;

  @override
  State<GodotBattlefieldView> createState() => _GodotBattlefieldViewState();
}

class _GodotBattlefieldViewState extends State<GodotBattlefieldView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _channel = MethodChannel('rune_nexus/godot_preview');
  late final Ticker _ticker;
  Timer? _statusTimer;
  Size _viewport = Size.zero;
  bool _connected = false;
  bool _ready = false;
  bool _available = false;
  bool _failed = false;
  bool _foreground = true;
  bool _sending = false;
  bool _polling = false;
  int _sequence = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((_) => _syncFrame())..start();
    _statusTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _pollStatus(),
    );
    unawaited(_connect());
  }

  Future<void> _connect() async {
    try {
      // 이전 스테이지의 마지막 프레임과 투영을 새 HUD에 사용하지 않음.
      await _channel.invokeMethod<void>('clearScene');
      if (mounted) await _pollStatus();
    } on Object catch (error) {
      _fallback(error);
    }
  }

  Future<void> _pollStatus() async {
    if (!mounted || !_foreground || _failed || _polling) return;
    _polling = true;
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>(
        'getStatus',
      );
      if (!mounted) return;
      final error = status?['error'];
      if (error is String && error.isNotEmpty) throw StateError(error);
      if (!_connected) setState(() => _connected = true);
      final becameReady = !_ready && status?['ready'] == true;
      _ready = status?['ready'] == true;
      if (becameReady) await _sendOptions();
    } on Object catch (error) {
      _fallback(error);
    } finally {
      _polling = false;
    }
  }

  Future<void> _sendOptions() async {
    if (!_ready || _failed) return;
    try {
      await _channel.invokeMethod<void>(
        'setOptions',
        jsonEncode({'camera': widget.cameraView, 'turret_levels': true}),
      );
    } on Object catch (error) {
      _fallback(error);
    }
  }

  Future<void> _syncFrame() async {
    if (!mounted ||
        !_ready ||
        !_foreground ||
        _failed ||
        _sending ||
        _viewport.isEmpty) {
      return;
    }
    final game = widget.game;
    final frame = game.battlefieldFrame;
    if (frame == null) return;
    _sending = true;
    try {
      await _channel.invokeMethod<void>(
        'submitFrame',
        jsonEncode(
          encodeGodotBattlefieldFrame(
            frame,
            sequence: _sequence++,
            viewport: _viewport,
          ),
        ),
      );
      final json = await _channel.invokeMethod<String>('getPresentation');
      if (!mounted || game != widget.game || _failed || json == null) return;
      final state = jsonDecode(json) as Map<String, dynamic>;
      final values = state['projection'];
      if (values is! Map<String, dynamic>) return;
      Offset axis(String name) {
        final data = values[name] as List<dynamic>;
        final point = Offset(
          (data[0] as num).toDouble() * _viewport.width,
          (data[1] as num).toDouble() * _viewport.height,
        );
        if (!point.dx.isFinite || !point.dy.isFinite) {
          throw StateError('유효하지 않은 전장 투영');
        }
        return point;
      }

      final projection = BattlefieldProjection(
        origin: axis('origin'),
        xAxis: axis('xAxis'),
        yAxis: axis('yAxis'),
        heightAxis: axis('heightAxis'),
      );
      if (projection.screenToGrid(projection.origin) == null) return;
      game.nativeBattlefieldTurretLevels = state['nativeTurretLevels'] == true;
      game.battlefieldProjection = projection;
      if (!_available) {
        _available = true;
        widget.onAvailabilityChanged?.call(true);
      }
    } on Object catch (error) {
      _fallback(error);
    } finally {
      _sending = false;
    }
  }

  void _fallback(Object error) {
    if (!mounted || _failed) return;
    _failed = true;
    _ready = false;
    _statusTimer?.cancel();
    _ticker.stop();
    widget.game.nativeBattlefieldTurretLevels = false;
    widget.game.battlefieldProjection = null;
    debugPrint('Godot 전장 표시 오류: $error');
    if (_available) {
      _available = false;
      widget.onAvailabilityChanged?.call(false);
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant GodotBattlefieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      oldWidget.game.nativeBattlefieldTurretLevels = false;
      oldWidget.game.battlefieldProjection = null;
      _available = false;
      _sequence = 0;
      unawaited(_connect());
    }
    if (oldWidget.cameraView != widget.cameraView) {
      unawaited(_sendOptions());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_pollStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    _ticker.dispose();
    widget.game.nativeBattlefieldTurretLevels = false;
    widget.game.battlefieldProjection = null;
    // 전장 종료는 엔진을 파괴하지 않고 다음 화면을 위한 상태만 비움.
    if (_connected) {
      unawaited(_channel.invokeMethod<void>('clearScene').catchError((_) {}));
    }
    if (_available) {
      final callback = widget.onAvailabilityChanged;
      scheduleMicrotask(() => callback?.call(false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewport = constraints.biggest;
          if (!_connected ||
              _failed ||
              !_viewport.isFinite ||
              _viewport.isEmpty) {
            return const SizedBox.shrink();
          }
          return PlatformViewLink(
            viewType: 'rune_nexus/godot_view',
            surfaceFactory: (context, controller) => AndroidViewSurface(
              controller: controller as AndroidViewController,
              hitTestBehavior: PlatformViewHitTestBehavior.transparent,
              gestureRecognizers: const {},
            ),
            onCreatePlatformView: (params) {
              final controller = PlatformViewsService.initExpensiveAndroidView(
                id: params.id,
                viewType: 'rune_nexus/godot_view',
                layoutDirection: TextDirection.ltr,
                onFocus: () => params.onFocusChanged(true),
              );
              controller.addOnPlatformViewCreatedListener(
                params.onPlatformViewCreated,
              );
              unawaited(controller.create().catchError(_fallback));
              return controller;
            },
          );
        },
      ),
    );
  }
}
