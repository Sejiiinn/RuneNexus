import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../game/rendering/stage1_3d/battlefield_presentation_state.dart';
import '../../game/rendering/stage1_3d/godot_battlefield_frame.dart';
import '../../game/rendering/stage1_3d/godot_battlefield_map_transport.dart';
import '../../game/rune_nexus_game.dart';
import '../../data/settings/graphics_settings.dart';
import '../settings/graphics_settings_scope.dart';

/// 실제 전투 HUD 아래 합성하는 네이티브 전장. 입력·전투 판정은 Dart에 유지.
class GodotBattlefieldView extends StatefulWidget {
  const GodotBattlefieldView({
    super.key,
    required this.game,
    this.cameraView = 'angled',
    this.onAvailabilityChanged,
    this.onLoadingChanged,
  });

  final RuneNexusGame game;
  final String cameraView;
  final ValueChanged<bool>? onAvailabilityChanged;
  final ValueChanged<bool>? onLoadingChanged;

  @override
  State<GodotBattlefieldView> createState() => _GodotBattlefieldViewState();
}

class _GodotBattlefieldViewState extends State<GodotBattlefieldView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _channel = MethodChannel('rune_nexus/godot_preview');
  static int _nextEpoch = DateTime.now().microsecondsSinceEpoch;
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
  bool _connecting = false;
  int _sequence = 0;
  int _lastApplied = -1;
  int _sceneEpoch = 0;
  int _viewportRevision = 0;
  final _mapTransport = GodotBattlefieldMapTransport();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((_) => _syncFrame())..start();
    _statusTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _pollStatus(),
    );
    _beginSession();
  }

  void _beginSession() {
    _sceneEpoch = ++_nextEpoch;
    _sequence = 0;
    _lastApplied = -1;
    _ready = false;
    _failed = false;
    _sending = false;
    _polling = false;
    _available = false;
    if (_statusTimer?.isActive != true) {
      _statusTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _pollStatus(),
      );
    }
    widget.game.nativeBattlefieldSceneEpoch = _sceneEpoch;
    _setLoading(true);
    _clearPresentation(widget.game);
    unawaited(_connect());
  }

  void _setLoading(bool loading) {
    widget.game.nativeBattlefieldLoading = loading;
    final epoch = _sceneEpoch;
    // 초기 생성·game 교체 도중 부모 HUD를 다시 빌드하지 않는다.
    scheduleMicrotask(() {
      if (mounted &&
          epoch == _sceneEpoch &&
          widget.game.nativeBattlefieldSceneEpoch == epoch) {
        widget.onLoadingChanged?.call(loading);
      }
    });
  }

  void _clearPresentation(RuneNexusGame game) {
    if (game.nativeBattlefieldSceneEpoch != _sceneEpoch) return;
    game.resetNativeBattlefieldEffects(_sceneEpoch);
    game.nativeBattlefieldTurretLevels = false;
    game.nativeBattlefieldGroups = const {};
    game.battlefieldProjection = null;
  }

  Future<void> _connect() async {
    final epoch = _sceneEpoch;
    _connecting = true;
    try {
      // 이전 스테이지의 마지막 프레임과 투영을 새 HUD에 사용하지 않음.
      await _channel.invokeMethod<void>('beginScene', {'sceneEpoch': epoch});
      if (mounted && epoch == _sceneEpoch) {
        _connecting = false;
        await _pollStatus();
      }
    } on Object catch (error) {
      if (epoch == _sceneEpoch) _fallback(error);
    } finally {
      if (epoch == _sceneEpoch) _connecting = false;
    }
  }

  Future<void> _pollStatus() async {
    if (!mounted || !_foreground || _failed || _polling || _connecting) return;
    final epoch = _sceneEpoch;
    _polling = true;
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>(
        'getStatus',
      );
      if (!mounted ||
          epoch != _sceneEpoch ||
          widget.game.nativeBattlefieldSceneEpoch != epoch) {
        return;
      }
      final error = status?['error'];
      if (error is String && error.isNotEmpty) throw StateError(error);
      if (!_connected) setState(() => _connected = true);
      final becameReady = !_ready && status?['ready'] == true;
      _ready = status?['ready'] == true;
      if (becameReady) await _sendOptions();
    } on Object catch (error) {
      if (epoch == _sceneEpoch) _fallback(error);
    } finally {
      if (epoch == _sceneEpoch) _polling = false;
    }
  }

  GraphicsSettings _graphicsSettings = const GraphicsSettings();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings =
        GraphicsSettingsScope.maybeOf(context)?.value ??
        const GraphicsSettings();
    if (settings.msaaSamples != _graphicsSettings.msaaSamples ||
        settings.shadowMapSize != _graphicsSettings.shadowMapSize) {
      _graphicsSettings = settings;
      unawaited(_sendOptions());
    }
  }

  Future<void> _sendOptions() async {
    if (!_ready || _failed) return;
    final epoch = _sceneEpoch;
    try {
      await _channel.invokeMethod<void>(
        'setOptions',
        jsonEncode({
          'sceneEpoch': epoch,
          'camera': widget.cameraView,
          'msaa_samples': _graphicsSettings.msaaSamples,
          'shadow_map_size': _graphicsSettings.shadowMapSize,
          'turret_levels': true,
          'presentation_groups': ['labels', 'selection', 'effects'],
        }),
      );
    } on Object catch (error) {
      if (epoch == _sceneEpoch) _fallback(error);
    }
  }

  Future<void> _syncFrame() async {
    if (!mounted ||
        !_ready ||
        !_foreground ||
        _failed ||
        _connecting ||
        widget.game.nativeBattlefieldSceneEpoch != _sceneEpoch ||
        _sending ||
        _viewport.isEmpty) {
      return;
    }
    final game = widget.game;
    final epoch = _sceneEpoch;
    final viewport = _viewport;
    final revision = _viewportRevision;
    final frame = game.battlefieldFrame;
    if (frame == null) return;
    _sending = true;
    final submittedSequence = _sequence++;
    try {
      final json = await _channel.invokeMethod<String>('submitFrameV2', {
        'sceneEpoch': epoch,
        'frame': jsonEncode(
          encodeGodotBattlefieldFrame(
            frame,
            sequence: submittedSequence,
            sceneEpoch: epoch,
            viewportRevision: revision,
            viewport: viewport,
            mapTransport: _mapTransport,
          ),
        ),
      });
      if (!mounted || epoch != _sceneEpoch || game != widget.game) return;
      game.markNativeBattlefieldEffectsSubmitted(epoch, submittedSequence, [
        ...?frame.effects?.items.map((effect) => effect.id),
        ...?frame.effects?.events.map((effect) => effect['id'] as int),
      ], eventGeneration: frame.effects?.generation);
      if (!mounted ||
          epoch != _sceneEpoch ||
          !_foreground ||
          game.nativeBattlefieldSceneEpoch != epoch ||
          game != widget.game ||
          revision != _viewportRevision ||
          _failed ||
          json == null) {
        return;
      }
      final state = jsonDecode(json) as Map<String, dynamic>;
      if (state['mapRequired'] == true) {
        final sequence = state['sequence'];
        final size = state['viewport'];
        if (state['presentationVersion'] ==
                BattlefieldPresentationState.protocolVersion &&
            state['sceneEpoch'] == epoch &&
            state['viewportRevision'] == revision &&
            sequence is int &&
            sequence >= _lastApplied &&
            sequence <= submittedSequence &&
            size is List &&
            size.length == 2 &&
            size[0] is num &&
            size[1] is num &&
            (size[0] - viewport.width).abs() < 1e-6 &&
            (size[1] - viewport.height).abs() < 1e-6) {
          _mapTransport.requestMap(
            sceneEpoch: epoch,
            sequence: sequence,
            mapRevision: state['mapRevision'],
          );
        }
        return;
      }
      // A response for the previous map cannot own the current map's overlays.
      if (state.containsKey('mapRevision') &&
          state['mapRevision'] != _mapTransport.revision) {
        return;
      }
      final applied = BattlefieldPresentationState.tryDecode(
        state,
        sceneEpoch: epoch,
        viewportRevision: revision,
        viewport: viewport,
        lastSubmitted: _sequence - 1,
        lastApplied: _lastApplied,
      );
      if (applied == null) return;
      _mapTransport.acknowledge(
        sceneEpoch: epoch,
        sequence: applied.sequence,
        mapRevision: state['mapRevision'],
      );
      _lastApplied = applied.sequence;
      game.nativeBattlefieldTurretLevels = applied.turretLevels;
      game.nativeBattlefieldGroups = applied.groups;
      game.nativeBattlefieldEffectEvents = applied.effectEvents;
      game.nativeBattlefieldImpactEffectEvents = applied.impactEffectEvents;
      game.nativeBattlefieldBlastEffectEvents = applied.blastEffectEvents;
      game.nativeBattlefieldLinkedEffectEvents = applied.linkedEffectEvents;
      game.nativeBattlefieldChainEffectEvents = applied.chainEffectEvents;
      game.nativeBattlefieldChargeEffectEvents = applied.chargeEffectEvents;
      if (applied.groups.contains('effects')) {
        game.acknowledgeNativeBattlefieldEffects(epoch, applied.sequence);
      }
      game.battlefieldProjection = applied.projection;
      if (!_available) {
        _setLoading(false);
        _available = true;
        widget.onAvailabilityChanged?.call(true);
      }
    } on Object catch (error) {
      if (epoch == _sceneEpoch) _fallback(error);
    } finally {
      if (epoch == _sceneEpoch) _sending = false;
    }
  }

  void _fallback(Object error) {
    if (!mounted ||
        _failed ||
        widget.game.nativeBattlefieldSceneEpoch != _sceneEpoch) {
      return;
    }
    _failed = true;
    _ready = false;
    _statusTimer?.cancel();
    _setLoading(false);
    _ticker.stop();
    _clearPresentation(widget.game);
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
      _clearPresentation(oldWidget.game);
      if (oldWidget.game.nativeBattlefieldSceneEpoch == _sceneEpoch) {
        oldWidget.game.nativeBattlefieldLoading = false;
        oldWidget.game.nativeBattlefieldSceneEpoch = 0;
      }
      _beginSession();
      if (!_ticker.isActive) _ticker.start();
    }
    if (oldWidget.cameraView != widget.cameraView) {
      unawaited(_sendOptions());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.game.nativeBattlefieldSceneEpoch != _sceneEpoch) return;
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _clearPresentation(widget.game);
    } else if (!wasForeground) {
      // An old in-flight presentation must not acknowledge a resumed scene.
      _beginSession();
      if (!_ticker.isActive) _ticker.start();
    } else {
      unawaited(_pollStatus());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    _ticker.dispose();
    final game = widget.game;
    final epoch = _sceneEpoch;
    final ownsPresentation = game.nativeBattlefieldSceneEpoch == epoch;
    _clearPresentation(game);
    if (ownsPresentation) {
      game.nativeBattlefieldLoading = false;
      game.nativeBattlefieldSceneEpoch = 0;
    }
    // 전장 종료는 엔진을 파괴하지 않고 다음 화면을 위한 상태만 비움.
    if (_connected) {
      unawaited(
        _channel
            .invokeMethod<void>('clearScene', {'sceneEpoch': epoch})
            .catchError((_) {}),
      );
    }
    if (_available && ownsPresentation) {
      final callback = widget.onAvailabilityChanged;
      scheduleMicrotask(() {
        if (game.nativeBattlefieldSceneEpoch == 0) callback?.call(false);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_viewport != constraints.biggest) {
            _viewport = constraints.biggest;
            _viewportRevision++;
            _clearPresentation(widget.game);
          }
          if (!_connected ||
              _failed ||
              !_viewport.isFinite ||
              _viewport.isEmpty) {
            return const SizedBox.shrink();
          }
          return PlatformViewLink(
            key: ValueKey(_sceneEpoch),
            viewType: 'rune_nexus/godot_view',
            surfaceFactory: (context, controller) => AndroidViewSurface(
              controller: controller as AndroidViewController,
              hitTestBehavior: PlatformViewHitTestBehavior.transparent,
              gestureRecognizers: const {},
            ),
            onCreatePlatformView: (params) {
              final epoch = _sceneEpoch;
              final controller = PlatformViewsService.initExpensiveAndroidView(
                id: params.id,
                viewType: 'rune_nexus/godot_view',
                layoutDirection: TextDirection.ltr,
                creationParams: {'sceneEpoch': epoch},
                creationParamsCodec: const StandardMessageCodec(),
                onFocus: () => params.onFocusChanged(true),
              );
              controller.addOnPlatformViewCreatedListener(
                params.onPlatformViewCreated,
              );
              unawaited(
                controller.create().catchError((Object error) {
                  if (epoch == _sceneEpoch) _fallback(error);
                }),
              );
              return controller;
            },
          );
        },
      ),
    );
  }
}
