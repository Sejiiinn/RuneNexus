part of 'main_menu_screen.dart';

class _StageRewardSummary extends StatelessWidget {
  const _StageRewardSummary({
    required this.rewardInfo,
    required this.unlocked,
    required this.dense,
  });

  final _StageRewardInfo? rewardInfo;
  final bool unlocked;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final rewardInfo = this.rewardInfo;
    if (rewardInfo == null) {
      return const SizedBox.shrink();
    }
    final color = unlocked ? GamePalette.textPrimary : const Color(0xFF7F93A1);
    final icons = [rewardInfo.icon, ...rewardInfo.extraIcons];
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var index = 0; index < icons.length; index++) ...[
          if (index > 0) SizedBox(width: dense ? 4 : 6),
          _StageRewardIconBadge(icon: icons[index], color: color, dense: dense),
        ],
      ],
    );
  }
}

class _StageRewardIconBadge extends StatelessWidget {
  const _StageRewardIconBadge({
    required this.icon,
    required this.color,
    required this.dense,
  });

  final Widget icon;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final size = dense ? 24.0 : 28.0;
    return Semantics(
      label: context.l10n.clearRewardLabel,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x14E8F8FF),
          border: Border.all(color: color.withValues(alpha: 0.34)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: IconTheme(
          data: IconThemeData(color: color, size: dense ? 14 : 16),
          child: icon,
        ),
      ),
    );
  }
}

class _StageRewardAssetIcon extends StatelessWidget {
  const _StageRewardAssetIcon({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final size = IconTheme.of(context).size ?? 16;
    return Image.asset(
      asset,
      width: size + 2,
      height: size + 2,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}

class _StageInfoChip extends StatelessWidget {
  const _StageInfoChip({
    required this.text,
    required this.unlocked,
    required this.highlighted,
    this.overrideColor,
    this.accentColor,
  });

  final String text;
  final bool unlocked;
  final bool highlighted;
  final Color? overrideColor;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? const Color(0xFF8EE6FF);
    final color =
        overrideColor ??
        (highlighted
            ? const Color(0xFFE7C66A)
            : unlocked
            ? accent
            : const Color(0xFF667987));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: unlocked ? 1 : 0.52,
              child: Image.asset(
                stageDetailsStatusChipFrameAsset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: highlighted
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SniperRewardIcon extends StatelessWidget {
  const _SniperRewardIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 16,
      child: CustomPaint(painter: _SniperRewardIconPainter()),
    );
  }
}

class _SniperRewardIconPainter extends CustomPainter {
  const _SniperRewardIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    drawTurretShape(
      canvas,
      size: size,
      type: TurretType.sniper,
      color: const Color(0xFFB7F4FF),
      strokeWidth: 1.1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LightningRewardIcon extends StatelessWidget {
  const _LightningRewardIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _LightningRewardIconPainter()),
    );
  }
}

class _LightningRewardIconPainter extends CustomPainter {
  const _LightningRewardIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    drawTurretShape(
      canvas,
      size: size,
      type: TurretType.lightning,
      color: Color(0xFFCFA7FF),
      strokeWidth: 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StageIcon extends StatelessWidget {
  const _StageIcon({required this.unlocked, this.active = false});

  final bool unlocked;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8EE6FF);
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: unlocked ? 1 : 0.48,
            child: Image.asset(
              stageDetailsHeaderIconSocketAsset,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
          Icon(
            unlocked ? Icons.flag_outlined : Icons.lock_outline,
            color: active
                ? const Color(0xFFE7C66A)
                : unlocked
                ? accent
                : const Color(0xFF6D7F8F),
            size: 18,
          ),
        ],
      ),
    );
  }
}
