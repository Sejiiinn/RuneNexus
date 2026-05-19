import 'package:flutter/material.dart';

import 'game_palette.dart';
import 'game_text_styles.dart';

enum GameButtonVariant { primary, secondary, confirm, danger, ghost }

class GameButton extends StatefulWidget {
  const GameButton({
    required this.onPressed,
    this.label,
    this.icon,
    this.child,
    this.variant = GameButtonVariant.secondary,
    this.selected = false,
    this.compact = false,
    this.accentColor,
    this.tooltip,
    this.width,
    this.height,
    this.padding,
    super.key,
  }) : assert(label != null || child != null);

  final VoidCallback? onPressed;
  final String? label;
  final Widget? icon;
  final Widget? child;
  final GameButtonVariant variant;
  final bool selected;
  final bool compact;
  final Color? accentColor;
  final String? tooltip;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (!_enabled || _pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _GameButtonColors.forVariant(
      widget.variant,
      widget.accentColor,
      widget.selected,
      _enabled,
    );
    final content = widget.child ?? _buildDefaultContent(colors.foreground);
    final button = Semantics(
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          duration: GamePalette.pressDuration,
          scale: _pressed ? 0.96 : 1,
          child: AnimatedContainer(
            duration: GamePalette.transitionDuration,
            width: widget.width,
            height:
                widget.height ??
                (widget.child == null ? (widget.compact ? 30 : 38) : null),
            padding:
                widget.padding ??
                EdgeInsets.symmetric(
                  horizontal: widget.compact ? 8 : 12,
                  vertical: widget.compact ? 6 : 9,
                ),
            decoration: BoxDecoration(
              gradient: colors.gradient,
              color: colors.background,
              border: Border.all(
                color: colors.border,
                width: widget.selected ? 1.8 : 1.1,
              ),
              borderRadius: BorderRadius.circular(GamePalette.radius),
              boxShadow: _enabled
                  ? [
                      BoxShadow(
                        color: colors.glow,
                        blurRadius: widget.selected ? 14 : 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            transform: Matrix4.translationValues(0, _pressed ? 1.5 : 0, 0),
            child: DefaultTextStyle(
              style: widget.compact
                  ? GameTextStyles.withColor(
                      GameTextStyles.buttonSmall,
                      colors.foreground,
                    )
                  : GameTextStyles.withColor(
                      GameTextStyles.button,
                      colors.foreground,
                    ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: IconTheme(
                data: IconThemeData(color: colors.foreground),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip == null) {
      return button;
    }
    return Tooltip(message: widget.tooltip!, child: button);
  }

  Widget _buildDefaultContent(Color foreground) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          widget.icon!,
          SizedBox(
            width: widget.compact ? GamePalette.gapTiny : GamePalette.gapSmall,
          ),
        ],
        Flexible(
          child: Text(
            widget.label!,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _GameButtonColors {
  const _GameButtonColors({
    required this.foreground,
    required this.border,
    required this.background,
    required this.gradient,
    required this.glow,
  });

  final Color foreground;
  final Color border;
  final Color? background;
  final Gradient? gradient;
  final Color glow;

  static _GameButtonColors forVariant(
    GameButtonVariant variant,
    Color? accentColor,
    bool selected,
    bool enabled,
  ) {
    final accent =
        accentColor ??
        switch (variant) {
          GameButtonVariant.primary => GamePalette.cyan,
          GameButtonVariant.secondary => GamePalette.metal,
          GameButtonVariant.confirm => GamePalette.green,
          GameButtonVariant.danger => GamePalette.danger,
          GameButtonVariant.ghost => GamePalette.cyan,
        };
    if (!enabled) {
      return const _GameButtonColors(
        foreground: GamePalette.textDisabled,
        border: Color(0x444A6172),
        background: Color(0x44223543),
        gradient: null,
        glow: Colors.transparent,
      );
    }
    if (variant == GameButtonVariant.primary) {
      return _GameButtonColors(
        foreground: GamePalette.voidBlack,
        border: GamePalette.cyanBright,
        background: null,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.94), GamePalette.cyanDeep],
        ),
        glow: accent.withValues(alpha: 0.32),
      );
    }
    if (variant == GameButtonVariant.ghost) {
      return _GameButtonColors(
        foreground: accent,
        border: accent.withValues(alpha: 0.58),
        background: Colors.transparent,
        gradient: null,
        glow: accent.withValues(alpha: 0.08),
      );
    }
    return _GameButtonColors(
      foreground: variant == GameButtonVariant.danger
          ? GamePalette.warning
          : GamePalette.textPrimary,
      border: accent.withValues(alpha: 0.78),
      background: accent.withValues(alpha: 0.14),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0.2),
          GamePalette.backdrop.withValues(alpha: 0.84),
        ],
      ),
      glow: accent.withValues(alpha: 0.16),
    );
  }
}
