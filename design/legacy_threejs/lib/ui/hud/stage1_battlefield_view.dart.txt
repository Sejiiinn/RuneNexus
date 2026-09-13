import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart' show AngleOptions;
import 'package:three_js/three_js.dart' as three;

import '../../game/rendering/stage1_3d/stage1_scene.dart';
import '../../game/rune_nexus_game.dart';

/// 전투 시뮬레이션은 GameWidget에 두고 3D 전장만 합성하는 표시 계층.
class Stage1BattlefieldView extends StatefulWidget {
  const Stage1BattlefieldView({super.key, required this.game});

  final RuneNexusGame game;

  @override
  State<Stage1BattlefieldView> createState() => _Stage1BattlefieldViewState();
}

class _Stage1BattlefieldViewState extends State<Stage1BattlefieldView> {
  late final three.ThreeJS _view;
  late final Stage1Scene _scene;
  bool _started = false;
  bool _ready = false;
  bool _closing = false;
  bool _released = false;
  bool _showScene = false;
  Object? _error;
  Size _viewport = Size.zero;
  Timer? _resizeTimer;
  Future<void>? _resizeFuture;
  Future<void>? _renderFuture;
  bool _resizing = false;

  @override
  void initState() {
    super.initState();
    _view = three.ThreeJS(
      setup: _load,
      onSetupComplete: _setupComplete,
      loadingWidget: const SizedBox.shrink(),
      settings: three.Settings(
        screenResolution: 1.25,
        antialias: true,
        alpha: true,
        clearAlpha: 0,
        clearColor: 0x101b20,
        toneMapping: three.AgXToneMapping,
        toneMappingExposure: 1.11,
        enableShadowMap: true,
        shadowMapType: three.PCFSoftShadowMap,
      ),
    );
    // 패키지 dispose의 late 필드 접근을 피하는 동기 초기화.
    _view.scene = three.Scene();
    _view.camera = three.OrthographicCamera(-5, 5, 5, -5, 0.1, 100);
    _scene = Stage1Scene(_view);
    _view.customRenderer = (scene, camera, texture, [dt]) {
      final render = _view.render(scene, camera, texture, dt);
      _renderFuture = render;
      return render;
    };
  }

  Future<void> _load() async {
    try {
      await _scene.load();
      if (!_closing) _scene.prepareEnvironment(_view.renderer!);
    } catch (error, stack) {
      _reportError(error, stack);
    }
  }

  void _setupComplete() {
    _ready = true;
    if (_closing || _error != null) {
      _release();
      return;
    }
    _view.addAnimationEvent((_) => _syncFrame());
    _syncFrame();
    _queueResize();
    if (mounted) setState(() {});
  }

  void _syncFrame() {
    if (_closing ||
        _error != null ||
        _viewport.isEmpty ||
        _resizing ||
        _view.screenSize != _viewport) {
      return;
    }
    final frame = widget.game.battlefieldFrame;
    if (frame == null) {
      widget.game.battlefieldProjection = null;
      if (_showScene && mounted) setState(() => _showScene = false);
      return;
    }
    try {
      widget.game.battlefieldProjection = _scene.update(frame, _viewport);
      if (!_showScene && mounted) setState(() => _showScene = true);
    } catch (error, stack) {
      _reportError(error, stack);
    }
  }

  void _reportError(Object error, StackTrace stack) {
    if (_error != null) return;
    _error = error;
    _view.settings.animate = false;
    widget.game.battlefieldProjection = null;
    debugPrint('스테이지 1 3D 표시 오류: $error\n$stack');
    // 프레임/초기화 콜백에서 현재 Flutter build와 충돌하지 않는 오류 알림.
    scheduleMicrotask(() {
      if (mounted && !_closing) setState(() => _showScene = false);
    });
  }

  void _start(BuildContext context) {
    if (_started) return;
    _started = true;
    // ANGLE의 내부 Future에서 발생하는 초기화 실패까지 2D 폴백으로 연결.
    runZonedGuarded(
      () {
        _view.initSize(context);
        // 패키지의 추적 불가능한 resize Future 대신 아래 수명 관리 경로 사용.
        WidgetsBinding.instance.removeObserver(_view);
      },
      (error, stack) {
        _reportError(error, stack);
        if (!_ready) _release();
      },
    );
  }

  @override
  void didUpdateWidget(covariant Stage1BattlefieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      oldWidget.game.battlefieldProjection = null;
      if (_ready) _syncFrame();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
          final resized = _viewport != size;
          _viewport = size;
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(size: size),
            child: Builder(
              builder: (context) {
                _start(context);
                if (resized) _queueResize();
                if (_error != null) {
                  return const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        '3D 전장을 불러오지 못해 기존 화면으로 표시합니다.',
                        style: TextStyle(
                          color: Color(0xFFFFD59A),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                }
                return Opacity(
                  opacity: _showScene ? 1 : 0,
                  child: _view.build(),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _queueResize() {
    if (!_ready ||
        _closing ||
        _released ||
        _error != null ||
        _view.screenSize == _viewport) {
      return;
    }
    _resizeTimer?.cancel();
    _resizeTimer = Timer(const Duration(milliseconds: 150), () {
      if (_resizing || _closing || _released) return;
      _resizeFuture = _resizeToViewport();
    });
  }

  Future<void> _resizeToViewport() async {
    _resizing = true;
    _view.settings.animate = false;
    try {
      // 마지막 네이티브 프레임 제출과 화면 크기 변경을 직렬화.
      await _renderFuture;
      while (!_closing && !_released && _view.screenSize != _viewport) {
        final target = _viewport;
        final texture = _view.texture!;
        await _view.angle!.resize(
          texture,
          AngleOptions(
            width: target.width.toInt(),
            height: target.height.toInt(),
            dpr: _view.dpr,
            alpha: true,
            antialias: true,
            customRenderer: true,
            useSurfaceProducer: _view.settings.useSurfaceProducer,
          ),
        );
        if (_closing || _released) return;
        _view.screenSize = target;
        _view.renderer!.setSize(target.width, target.height, false);
      }
    } catch (error, stack) {
      _reportError(error, stack);
    } finally {
      _resizing = false;
      if (!_closing && !_released && _error == null) {
        _view.settings.animate = true;
        _syncFrame();
        if (mounted) setState(() {});
      }
    }
  }

  void _release() {
    if (_released) return;
    _released = true;
    _resizeTimer?.cancel();
    _view.settings.animate = false;
    _view.ticker?.stop();
    unawaited(_finishRelease());
  }

  Future<void> _finishRelease() async {
    try {
      // 진행 중인 플랫폼 작업이 renderer/EGL을 참조한 뒤 해제.
      await Future.wait([?_renderFuture, ?_resizeFuture]);
    } catch (error, stack) {
      debugPrint('스테이지 1 그래픽 작업 종료 오류: $error\n$stack');
    }
    // ANGLE은 init 이전 dispose에서 미초기화 EGL을 참조하므로 별도 해제.
    final angle = _view.angle;
    _view.angle = null;
    _view.dispose();
    if (_started) {
      try {
        angle?.dispose([_view.texture]);
      } catch (error, stack) {
        // 플랫폼 초기화 실패 뒤의 정리가 기존 2D 폴백까지 중단하지 않도록 격리.
        debugPrint('스테이지 1 그래픽 자원 정리 오류: $error\n$stack');
      }
    }
  }

  @override
  void dispose() {
    _closing = true;
    _resizeTimer?.cancel();
    widget.game.battlefieldProjection = null;
    // 진행 중 GLB 로딩은 완료 콜백에서 해제하여 재생성되는 ticker 방지.
    if (!_started || _ready || _error != null) _release();
    super.dispose();
  }
}
