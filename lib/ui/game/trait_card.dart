import 'package:flutter/material.dart';

import 'game_button.dart';
import 'game_palette.dart';
import 'game_panel.dart';
import 'game_text_styles.dart';
import '../widgets/non_truncating_text.dart';

class TraitCard extends StatefulWidget {
  const TraitCard({
    required this.title,
    required this.description,
    required this.accentColor,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onPressed,
    this.onConfirm,
    this.confirmLabel = '선택',
    this.badge,
    this.width,
    this.height,
    super.key,
  });

  final String title;
  final String description;
  final Color accentColor;
  final Widget icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;
  final VoidCallback? onConfirm;
  final String confirmLabel;
  final String? badge;
  final double? width;
  final double? height;

  @override
  State<TraitCard> createState() => _TraitCardState();
}

class _TraitCardState extends State<TraitCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1 : 0.54,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.enabled
            ? (_) => setState(() => _pressed = false)
            : null,
        onTapCancel: widget.enabled
            ? () => setState(() => _pressed = false)
            : null,
        onTap: widget.enabled ? widget.onPressed : null,
        child: AnimatedScale(
          duration: GamePalette.pressDuration,
          scale: _pressed ? 0.97 : 1,
          child: GamePanel(
            width: widget.width,
            height: widget.height,
            variant: GamePanelVariant.reward,
            selected: widget.selected,
            accentColor: widget.accentColor,
            padding: const EdgeInsets.symmetric(
              horizontal: GamePalette.gap,
              vertical: GamePalette.gapLarge,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.18),
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.78),
                    ),
                    borderRadius: BorderRadius.circular(GamePalette.radius),
                  ),
                  child: IconTheme(
                    data: IconThemeData(color: widget.accentColor, size: 22),
                    child: widget.icon,
                  ),
                ),
                const SizedBox(height: GamePalette.gap),
                FixedSlotText(
                  widget.title,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: GameTextStyles.sectionTitle,
                ),
                const SizedBox(height: GamePalette.gapTiny),
                SizedBox(
                  height: 36,
                  child: FixedSlotText(
                    widget.description,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: GameTextStyles.caption.copyWith(
                      color: GamePalette.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ),
                if (widget.badge != null) ...[
                  const SizedBox(height: GamePalette.gapSmall),
                  _TraitBadge(text: widget.badge!, color: widget.accentColor),
                ],
                if (widget.selected && widget.onConfirm != null) ...[
                  const Spacer(),
                  GameButton(
                    label: widget.confirmLabel,
                    compact: true,
                    width: double.infinity,
                    variant: GameButtonVariant.primary,
                    accentColor: widget.accentColor,
                    onPressed: widget.onConfirm,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TraitBadge extends StatelessWidget {
  const _TraitBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GamePalette.gapSmall,
        vertical: GamePalette.gapTiny,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.48)),
        borderRadius: BorderRadius.circular(GamePalette.radiusSmall),
      ),
      child: ScaleDownText(
        text,
        style: GameTextStyles.withColor(GameTextStyles.chip, color),
      ),
    );
  }
}
