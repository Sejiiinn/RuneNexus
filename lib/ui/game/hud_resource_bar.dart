import 'package:flutter/material.dart';

import 'game_palette.dart';
import 'game_panel.dart';
import 'game_text_styles.dart';

class HudResourceBar extends StatelessWidget {
  const HudResourceBar({
    required this.value,
    required this.color,
    this.label,
    this.icon,
    this.iconWidget,
    this.valueChild,
    this.progress,
    this.compact = false,
    this.width,
    super.key,
  }) : assert(icon != null || iconWidget != null);

  final String? label;
  final String value;
  final Color color;
  final IconData? icon;
  final Widget? iconWidget;
  final Widget? valueChild;
  final double? progress;
  final bool compact;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress?.clamp(0.0, 1.0);
    return GamePanel(
      width: width,
      variant: GamePanelVariant.inset,
      accentColor: color,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? GamePalette.gapSmall : GamePalette.gap,
        vertical: compact ? GamePalette.gapTiny : GamePalette.gapSmall,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: clampedProgress == null
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget ?? Icon(icon, size: compact ? 13 : 15, color: color),
              const SizedBox(width: GamePalette.gapTiny),
              if (label != null) ...[
                Flexible(
                  child: Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTextStyles.caption,
                  ),
                ),
                const SizedBox(width: GamePalette.gapTiny),
              ],
              Flexible(
                child: DefaultTextStyle(
                  style: GameTextStyles.withColor(
                    compact
                        ? GameTextStyles.buttonSmall
                        : GameTextStyles.button,
                    GamePalette.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child:
                      valueChild ??
                      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
          if (clampedProgress != null) ...[
            const SizedBox(height: GamePalette.gapTiny),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: clampedProgress,
                minHeight: compact ? 3 : 4,
                color: color,
                backgroundColor: GamePalette.stoneDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
