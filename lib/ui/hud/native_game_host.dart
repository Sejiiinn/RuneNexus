import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../../game/rune_nexus_game.dart';
import '../../game/rendering/game_scene_effect_renderer.dart';

/// Flutter owns layout and input; Godot owns the battlefield and combat.
class NativeGameHost extends StatefulWidget {
  const NativeGameHost({required this.game, super.key});

  final RuneNexusGame game;

  @override
  State<NativeGameHost> createState() => _NativeGameHostState();
}

class _NativeGameHostState extends State<NativeGameHost>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration? _previous;
  Size? _size;
  bool _loaded = false;
  Object? _error;
  final _frame = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final previous = _previous;
      _previous = elapsed;
      if (previous == null || !_loaded || widget.game.paused) return;
      widget.game.update((elapsed - previous).inMicroseconds / 1000000);
      _frame.value++;
    });
  }

  Future<void> _attach(Size size) async {
    if (!mounted) return;
    final game = widget.game;
    game.attachView(context.findRenderObject()! as RenderBox);
    game.onGameResize(Vector2(size.width, size.height));
    try {
      await game.load();
      if (!mounted || widget.game != game) return;
      setState(() => _loaded = true);
      _previous = null;
      if (!_ticker.isActive) _ticker.start();
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void didUpdateWidget(covariant NativeGameHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      oldWidget.game.detachView();
      _loaded = false;
      _error = null;
      _size = null;
      _previous = null;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    widget.game.detachView();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (_size != size) {
        _size = size;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_attach(size));
        });
      }
      if (_error != null) {
        return const Center(child: Text('전장을 준비하지 못했습니다.'));
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => widget.game.onBoardTapDown(
          Vector2(details.localPosition.dx, details.localPosition.dy),
        ),
        onTapUp: (details) => widget.game.onBoardTapUp(
          Vector2(details.localPosition.dx, details.localPosition.dy),
        ),
        onScaleStart: (details) => widget.game.onBoardScaleStart(
          details.pointerCount,
          Vector2(details.localFocalPoint.dx, details.localFocalPoint.dy),
        ),
        onScaleUpdate: (details) => widget.game.onBoardScaleUpdate(
          details.pointerCount,
          details.scale,
          Vector2(details.localFocalPoint.dx, details.localFocalPoint.dy),
        ),
        onScaleEnd: (_) => widget.game.onBoardScaleEnd(),
        child: CustomPaint(
          foregroundPainter: _ScreenFeedback(widget.game, _frame),
          child: const SizedBox.expand(),
        ),
      );
    },
  );
}

class _ScreenFeedback extends CustomPainter {
  _ScreenFeedback(this.game, Listenable repaint) : super(repaint: repaint);
  final RuneNexusGame game;

  @override
  void paint(Canvas canvas, Size size) {
    drawNexusScreenAlert(canvas, size: size, alert: game.nexusScreenAlert);
    if (game.coreDestructionFade > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = const Color(
            0xFF02070D,
          ).withValues(alpha: game.coreDestructionFade * 0.68),
      );
    }
  }

  @override
  bool shouldRepaint(_ScreenFeedback oldDelegate) => oldDelegate.game != game;
}
