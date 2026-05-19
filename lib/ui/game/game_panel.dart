import 'package:flutter/material.dart';

import 'game_palette.dart';

enum GamePanelVariant { stone, inset, reward, danger }

class GamePanel extends StatelessWidget {
  const GamePanel({
    required this.child,
    this.variant = GamePanelVariant.stone,
    this.padding = const EdgeInsets.all(GamePalette.gapLarge),
    this.margin,
    this.accentColor,
    this.selected = false,
    this.width,
    this.height,
    super.key,
  });

  final Widget child;
  final GamePanelVariant variant;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? accentColor;
  final bool selected;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? _accentForVariant(variant);
    final border = selected ? accent : _borderForVariant(variant);
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GamePalette.radius),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: selected ? 0.26 : 0.08),
            blurRadius: selected ? 16 : 9,
            offset: const Offset(0, 4),
          ),
          const BoxShadow(
            color: Color(0x99000000),
            blurRadius: 16,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _GamePanelFramePainter(
          borderColor: border,
          highlightColor: accent,
          selected: selected,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: _gradientForVariant(variant, selected),
            border: Border.all(color: border, width: selected ? 1.7 : 1.1),
            borderRadius: BorderRadius.circular(GamePalette.radius),
          ),
          child: child,
        ),
      ),
    );
  }

  Color _accentForVariant(GamePanelVariant variant) {
    return switch (variant) {
      GamePanelVariant.stone => GamePalette.cyan,
      GamePanelVariant.inset => GamePalette.metal,
      GamePanelVariant.reward => GamePalette.green,
      GamePanelVariant.danger => GamePalette.danger,
    };
  }

  Color _borderForVariant(GamePanelVariant variant) {
    return switch (variant) {
      GamePanelVariant.stone => const Color(0x88556A78),
      GamePanelVariant.inset => const Color(0x554A6172),
      GamePanelVariant.reward => const Color(0x8863E6A5),
      GamePanelVariant.danger => const Color(0x99FF7043),
    };
  }

  LinearGradient _gradientForVariant(GamePanelVariant variant, bool selected) {
    final top = switch (variant) {
      GamePanelVariant.stone => GamePalette.panelRaised.withValues(
        alpha: selected ? 1 : 0.94,
      ),
      GamePanelVariant.inset => GamePalette.panelInset.withValues(
        alpha: selected ? 0.98 : 0.92,
      ),
      GamePanelVariant.reward =>
        selected ? const Color(0xFF0D2A38) : const Color(0xF00B2230),
      GamePanelVariant.danger =>
        selected ? const Color(0xFF2A1719) : const Color(0xF0221417),
    };
    final bottom = switch (variant) {
      GamePanelVariant.stone => GamePalette.backdrop.withValues(alpha: 0.96),
      GamePanelVariant.inset => GamePalette.voidBlack.withValues(alpha: 0.74),
      GamePanelVariant.reward => const Color(0xF0061712),
      GamePanelVariant.danger => const Color(0xF0100808),
    };
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [top, bottom],
    );
  }
}

class _GamePanelFramePainter extends CustomPainter {
  const _GamePanelFramePainter({
    required this.borderColor,
    required this.highlightColor,
    required this.selected,
  });

  final Color borderColor;
  final Color highlightColor;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final cornerPaint = Paint()
      ..color = highlightColor.withValues(alpha: selected ? 0.88 : 0.42)
      ..strokeWidth = selected ? 1.7 : 1.1
      ..strokeCap = StrokeCap.square;
    const corner = 12.0;
    final rect = Offset.zero & size;

    void drawCorner(Offset a, Offset b, Offset c) {
      canvas.drawLine(a, b, cornerPaint);
      canvas.drawLine(a, c, cornerPaint);
    }

    drawCorner(
      rect.topLeft + const Offset(3, 3),
      rect.topLeft + const Offset(corner, 3),
      rect.topLeft + const Offset(3, corner),
    );
    drawCorner(
      rect.topRight + const Offset(-3, 3),
      rect.topRight + const Offset(-corner, 3),
      rect.topRight + const Offset(-3, corner),
    );
    drawCorner(
      rect.bottomLeft + const Offset(3, -3),
      rect.bottomLeft + const Offset(corner, -3),
      rect.bottomLeft + const Offset(3, -corner),
    );
    drawCorner(
      rect.bottomRight + const Offset(-3, -3),
      rect.bottomRight + const Offset(-corner, -3),
      rect.bottomRight + const Offset(-3, -corner),
    );

    final innerPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(3),
        const Radius.circular(GamePalette.radiusSmall),
      ),
      innerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GamePanelFramePainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.selected != selected;
  }
}
