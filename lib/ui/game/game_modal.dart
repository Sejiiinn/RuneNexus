import 'package:flutter/material.dart';

import 'game_button.dart';
import 'game_palette.dart';

enum GameModalTone { standard, reward, danger }

Future<T?> showGameDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final disableAnimations =
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierDismissible
        ? MaterialLocalizations.of(context).modalBarrierDismissLabel
        : null,
    barrierColor: const Color(0xD902070D),
    transitionDuration: disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 210),
    pageBuilder: (dialogContext, _, _) {
      return SafeArea(child: builder(dialogContext));
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (disableAnimations) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

Future<T?> showGameBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    elevation: 0,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xD902070D),
    builder: builder,
  );
}

class GameModalFrame extends StatelessWidget {
  const GameModalFrame({
    required this.child,
    this.tone = GameModalTone.standard,
    this.accentColor,
    this.maxWidth = 420,
    this.maxHeight,
    this.padding = const EdgeInsets.all(18),
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 24,
    ),
    super.key,
  });

  final Widget child;
  final GameModalTone tone;
  final Color? accentColor;
  final double maxWidth;
  final double? maxHeight;
  final EdgeInsetsGeometry padding;
  final EdgeInsets insetPadding;

  Color get _resolvedAccent {
    return accentColor ??
        switch (tone) {
          GameModalTone.standard => GamePalette.cyan,
          GameModalTone.reward => GamePalette.gold,
          GameModalTone.danger => GamePalette.danger,
        };
  }

  @override
  Widget build(BuildContext context) {
    final accent = _resolvedAccent;
    return Dialog(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      insetPadding: insetPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: _GameModalSurface(
          tone: tone,
          accent: accent,
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class GameBottomSheetFrame extends StatelessWidget {
  const GameBottomSheetFrame({
    required this.child,
    this.tone = GameModalTone.standard,
    this.accentColor,
    this.maxWidth = 720,
    this.maxHeightFactor = 0.82,
    this.padding = const EdgeInsets.all(14),
    this.insetPadding = const EdgeInsets.all(12),
    super.key,
  });

  final Widget child;
  final GameModalTone tone;
  final Color? accentColor;
  final double maxWidth;
  final double maxHeightFactor;
  final EdgeInsetsGeometry padding;
  final EdgeInsets insetPadding;

  @override
  Widget build(BuildContext context) {
    final accent =
        accentColor ??
        switch (tone) {
          GameModalTone.standard => GamePalette.cyan,
          GameModalTone.reward => GamePalette.gold,
          GameModalTone.danger => GamePalette.danger,
        };
    final screenHeight = MediaQuery.sizeOf(context).height;
    return SafeArea(
      top: false,
      child: Padding(
        padding: insetPadding,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: screenHeight * maxHeightFactor,
            ),
            child: _GameModalSurface(
              tone: tone,
              accent: accent,
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class GameModalCloseButton extends StatelessWidget {
  const GameModalCloseButton({
    required this.onPressed,
    this.tooltip = '닫기',
    this.accentColor = GamePalette.metal,
    super.key,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      onPressed: onPressed,
      tooltip: tooltip,
      compact: true,
      variant: GameButtonVariant.ghost,
      accentColor: accentColor,
      width: 32,
      height: 32,
      padding: EdgeInsets.zero,
      child: const Center(child: Icon(Icons.close_rounded, size: 17)),
    );
  }
}

class _GameModalSurface extends StatelessWidget {
  const _GameModalSurface({
    required this.child,
    required this.tone,
    required this.accent,
    required this.padding,
  });

  final Widget child;
  final GameModalTone tone;
  final Color accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GameModalFramePainter(accent: accent, tone: tone),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(padding: padding, child: child),
          Positioned(
            top: -4,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(child: _FrameRune(accent: accent)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameRune extends StatelessWidget {
  const _FrameRune({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398,
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: GamePalette.voidBlack,
          border: Border.all(color: accent, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.48),
              blurRadius: 9,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _GameModalFramePainter extends CustomPainter {
  const _GameModalFramePainter({required this.accent, required this.tone});

  final Color accent;
  final GameModalTone tone;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final frame = _cutCornerPath(rect.deflate(1), 14);
    final shadowPath = frame.shift(const Offset(0, 5));
    canvas.drawShadow(shadowPath, const Color(0xEE000000), 18, true);

    final colors = switch (tone) {
      GameModalTone.standard => const [Color(0xFF102638), Color(0xFF050C15)],
      GameModalTone.reward => const [Color(0xFF272416), Color(0xFF080D10)],
      GameModalTone.danger => const [Color(0xFF2A1719), Color(0xFF0B090D)],
    };
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(rect);
    canvas.drawPath(frame, fill);

    final ambient = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -1.2),
        radius: 1.15,
        colors: [accent.withValues(alpha: 0.16), Colors.transparent],
      ).createShader(rect);
    canvas.drawPath(frame, ambient);

    final outerBorder = Paint()
      ..color = accent.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;
    canvas.drawPath(frame, outerBorder);

    final innerFrame = _cutCornerPath(rect.deflate(5), 10);
    final innerBorder = Paint()
      ..color = accent.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(innerFrame, innerBorder);

    final rail = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          accent.withValues(alpha: 0.92),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(22, 0, size.width - 44, 2))
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(22, 1.5), Offset(size.width - 22, 1.5), rail);

    final cornerMark = Paint()
      ..color = accent.withValues(alpha: 0.54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    _drawCornerMarks(canvas, rect.deflate(8), cornerMark);
  }

  Path _cutCornerPath(Rect rect, double cut) {
    return Path()
      ..moveTo(rect.left + cut, rect.top)
      ..lineTo(rect.right - cut, rect.top)
      ..lineTo(rect.right, rect.top + cut)
      ..lineTo(rect.right, rect.bottom - cut)
      ..lineTo(rect.right - cut, rect.bottom)
      ..lineTo(rect.left + cut, rect.bottom)
      ..lineTo(rect.left, rect.bottom - cut)
      ..lineTo(rect.left, rect.top + cut)
      ..close();
  }

  void _drawCornerMarks(Canvas canvas, Rect rect, Paint paint) {
    const length = 8.0;
    canvas
      ..drawLine(rect.topLeft, rect.topLeft + const Offset(length, 0), paint)
      ..drawLine(rect.topLeft, rect.topLeft + const Offset(0, length), paint)
      ..drawLine(rect.topRight, rect.topRight + const Offset(-length, 0), paint)
      ..drawLine(rect.topRight, rect.topRight + const Offset(0, length), paint)
      ..drawLine(
        rect.bottomLeft,
        rect.bottomLeft + const Offset(length, 0),
        paint,
      )
      ..drawLine(
        rect.bottomLeft,
        rect.bottomLeft + const Offset(0, -length),
        paint,
      )
      ..drawLine(
        rect.bottomRight,
        rect.bottomRight + const Offset(-length, 0),
        paint,
      )
      ..drawLine(
        rect.bottomRight,
        rect.bottomRight + const Offset(0, -length),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant _GameModalFramePainter oldDelegate) {
    return oldDelegate.accent != accent || oldDelegate.tone != tone;
  }
}
