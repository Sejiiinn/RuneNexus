part of 'main_menu_screen.dart';

const double _menuUiAssetScale = 3;
const Rect _menuSectionFrameCenterSlice = Rect.fromLTRB(14, 14, 362, 146);
const Rect _menuCardFrameCenterSlice = Rect.fromLTRB(11, 11, 160, 105);
const Rect _menuSlotFrameCenterSlice = Rect.fromLTRB(11, 10, 346, 34);
const Rect _menuLockedSlotFrameCenterSlice = Rect.fromLTRB(11, 11, 346, 48);
const Rect _menuActionFrameCenterSlice = Rect.fromLTRB(10, 9, 100, 23);
const Rect _menuUpgradeActionFrameCenterSlice = Rect.fromLTRB(8, 8, 143, 26);

class _MenuAssetSurface extends StatelessWidget {
  const _MenuAssetSurface({
    required this.asset,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.opacity = 1,
    this.constraints,
    this.scale,
    this.centerSlice,
    super.key,
  });

  final String asset;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double opacity;
  final BoxConstraints? constraints;
  final double? scale;
  final Rect? centerSlice;

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: opacity,
              child: Image.asset(
                asset,
                scale: scale,
                fit: BoxFit.fill,
                centerSlice: centerSlice,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
    final resolvedConstraints = constraints;
    if (resolvedConstraints == null) {
      return content;
    }
    return ConstrainedBox(constraints: resolvedConstraints, child: content);
  }
}

class _ResearchSection extends StatelessWidget {
  const _ResearchSection({
    required this.icon,
    required this.title,
    required this.tone,
    required this.children,
  });

  final IconData icon;
  final String title;
  final _ResearchSectionTone tone;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth <= 330 ? 8.0 : 10.0;
        return _MenuAssetSurface(
          asset: researchSectionFrameAsset,
          scale: _menuUiAssetScale,
          centerSlice: _menuSectionFrameCenterSlice,
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: tone.iconColor, size: 17),
                  const SizedBox(width: 7),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFE8FBFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [tone.lineColor, const Color(0x00000000)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        );
      },
    );
  }
}

class _ResearchSectionTone {
  const _ResearchSectionTone({
    required this.iconColor,
    required this.lineColor,
  });

  final Color iconColor;
  final Color lineColor;

  static const available = _ResearchSectionTone(
    iconColor: Color(0xFFE7C66A),
    lineColor: Color(0x88E7C66A),
  );

  static const slots = _ResearchSectionTone(
    iconColor: Color(0xFFB9D6E4),
    lineColor: Color(0x5533D8FF),
  );

  static const locked = _ResearchSectionTone(
    iconColor: Color(0xFF8DA5B3),
    lineColor: Color(0x66485B68),
  );

  static const completed = _ResearchSectionTone(
    iconColor: Color(0xFFBDEFCF),
    lineColor: Color(0x6657C88B),
  );
}

class _ResearchCardGrid extends StatelessWidget {
  const _ResearchCardGrid({
    required this.types,
    required this.game,
    required this.snapshot,
    required this.nowMillis,
    required this.onSelectType,
  });

  final List<ResearchType> types;
  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final int nowMillis;
  final ValueChanged<ResearchType> onSelectType;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth <= 300 ? 6.0 : 8.0;
        final useTwoColumns = constraints.maxWidth >= 260;
        final tileWidth = useTwoColumns
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: spacing,
          runSpacing: 8,
          children: [
            for (final type in types)
              SizedBox(
                width: tileWidth,
                child: _ResearchTile(
                  game: game,
                  snapshot: snapshot,
                  type: type,
                  nowMillis: nowMillis,
                  onPressed: () => onSelectType(type),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdaptiveResearchTitle extends StatelessWidget {
  const _AdaptiveResearchTitle({
    required this.text,
    required this.style,
    this.minSingleLineScale = 0.76,
  });

  final String text;
  final TextStyle style;
  final double minSingleLineScale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth <= 0) {
          return _buildWrappedText();
        }

        final inheritedStyle = DefaultTextStyle.of(context).style.merge(style);
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: inheritedStyle),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final textWidth = textPainter.width;
        if (textWidth <= maxWidth) {
          return _buildSingleLineText();
        }

        final singleLineScale = maxWidth / textWidth;
        if (singleLineScale >= minSingleLineScale) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _buildSingleLineText(),
          );
        }

        return _buildWrappedText();
      },
    );
  }

  Text _buildSingleLineText() {
    return Text(text, style: style, maxLines: 1, softWrap: false);
  }

  Text _buildWrappedText() {
    return Text(text, style: style, softWrap: true);
  }
}

class _ResearchTile extends StatelessWidget {
  const _ResearchTile({
    required this.game,
    required this.snapshot,
    required this.type,
    required this.nowMillis,
    required this.onPressed,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final ResearchType type;
  final int nowMillis;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final definition = gameResearchDefinitions[type]!;
    final level = _researchLevel(snapshot, type);
    final active = _activeResearch(snapshot, type);
    final complete = level >= definition.maxLevel;
    final unlocked = _researchUnlocked(snapshot, definition);
    final slotAvailable =
        active != null ||
        snapshot.activeResearches.length < snapshot.researchSlotCount;
    final cost = _researchCost(snapshot, type);
    final duration = _researchDuration(snapshot, type);
    final canStart =
        active == null &&
        !complete &&
        unlocked &&
        slotAvailable &&
        snapshot.runes >= cost;
    final statusText = active != null
        ? null
        : complete
        ? l10n.researchComplete
        : !unlocked
        ? l10n.lockedResearch
        : !slotAvailable
        ? null
        : snapshot.runes < cost
        ? l10n.notEnoughRunes
        : l10n.researchAvailable;
    final titleColor = complete
        ? const Color(0xFFBDEFCF)
        : canStart
        ? const Color(0xFFE8FBFF)
        : const Color(0xFFB9D6E4);
    final clickable = active == null && unlocked;
    final showStatusChip =
        statusText != null &&
        (complete || (!canStart && unlocked && slotAvailable));

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        key: ValueKey('research-tile-${type.name}'),
        onTap: clickable ? onPressed : null,
        borderRadius: BorderRadius.circular(7),
        splashColor: const Color(0x1A8EE6FF),
        highlightColor: const Color(0x1422C7E8),
        child: _MenuAssetSurface(
          asset: researchCardFrameAsset,
          opacity: clickable ? 1 : 0.58,
          constraints: const BoxConstraints(minHeight: 106),
          child: Stack(
            children: [
              if (active != null) ...[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x2633D8FF),
                          Color(0x10000000),
                          Color(0x22E7C66A),
                        ],
                      ),
                    ),
                  ),
                ),
                const _ResearchActiveEffect(),
              ],
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                researchIconSocketAsset,
                                fit: BoxFit.fill,
                                filterQuality: FilterQuality.medium,
                                excludeFromSemantics: true,
                              ),
                              Center(
                                child: ResearchIcon(
                                  type,
                                  color: active == null
                                      ? null
                                      : const Color(0xFFE7C66A),
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _AdaptiveResearchTitle(
                                text: _researchTitle(l10n, type),
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              _ResearchLevelCostLine(
                                levelText: l10n.researchLevel(
                                  level,
                                  definition.maxLevel,
                                ),
                                cost: complete ? null : cost,
                                enabled: canStart || active != null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _ResearchEffectLine(
                      effect: _researchEffectText(
                        l10n,
                        type,
                        level,
                        active?.targetLevel,
                      ),
                      enabled:
                          unlocked && (canStart || complete || active != null),
                    ),
                    if (!complete) ...[
                      const SizedBox(height: 3),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule,
                              color: Color(0xFF8DA5B3),
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              l10n.researchDuration(duration),
                              style: const TextStyle(
                                color: Color(0xFFB9D6E4),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (showStatusChip) ...[
                      const SizedBox(height: 6),
                      _PermanentUpgradeStatusChip(text: statusText),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResearchEffectLine extends StatelessWidget {
  const _ResearchEffectLine({required this.effect, required this.enabled});

  final _ResearchEffectText effect;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final currentColor = enabled
        ? const Color(0xFF8EE6FF)
        : const Color(0xFF8DA5B3);
    final nextColor = enabled
        ? const Color(0xFFE7C66A)
        : const Color(0xFF8DA5B3);
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1.16,
        ),
        children: [
          TextSpan(
            text: effect.currentText,
            style: TextStyle(color: currentColor),
          ),
          if (effect.nextText != null) ...[
            const TextSpan(
              text: ' -> ',
              style: TextStyle(color: Color(0xFF8DA5B3)),
            ),
            TextSpan(
              text: effect.nextText,
              style: TextStyle(color: nextColor),
            ),
          ],
        ],
      ),
      maxLines: 2,
    );
  }
}

class _ResearchActiveEffect extends StatefulWidget {
  const _ResearchActiveEffect();

  @override
  State<_ResearchActiveEffect> createState() => _ResearchActiveEffectState();
}

class _ResearchActiveEffectState extends State<_ResearchActiveEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ResearchActiveBorderPainter(_controller.value),
            );
          },
        ),
      ),
    );
  }
}

class _ResearchActiveBorderPainter extends CustomPainter {
  const _ResearchActiveBorderPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(7);
    final borderPath = Path()
      ..addRRect(RRect.fromRectAndRadius(rect.deflate(1.1), radius));
    final glowPaint = Paint()
      ..color = const Color(0x44E7C66A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final highlightPaint = Paint()
      ..color = const Color(0xFFE7C66A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(borderPath, glowPaint);
    for (final metric in borderPath.computeMetrics()) {
      final length = metric.length;
      final segmentLength = length * 0.22;
      final start = length * progress;
      _drawMetricSegment(canvas, metric, start, segmentLength, highlightPaint);
      _drawMetricSegment(
        canvas,
        metric,
        (start + length * 0.5) % length,
        segmentLength * 0.55,
        glowPaint,
      );
    }
  }

  void _drawMetricSegment(
    Canvas canvas,
    ui.PathMetric metric,
    double start,
    double length,
    Paint paint,
  ) {
    final end = start + length;
    if (end <= metric.length) {
      canvas.drawPath(metric.extractPath(start, end), paint);
      return;
    }
    canvas
      ..drawPath(metric.extractPath(start, metric.length), paint)
      ..drawPath(metric.extractPath(0, end - metric.length), paint);
  }

  @override
  bool shouldRepaint(_ResearchActiveBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ResearchEffectText {
  const _ResearchEffectText(this.currentText, [this.nextText]);

  final String currentText;
  final String? nextText;
}

class _ResearchLevelCostLine extends StatelessWidget {
  const _ResearchLevelCostLine({
    required this.levelText,
    required this.cost,
    required this.enabled,
  });

  final String levelText;
  final int? cost;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? const Color(0xFFE7C66A)
        : const Color(0xFF8DA5B3);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            levelText,
            style: const TextStyle(
              color: Color(0xFFB9D6E4),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (cost != null) ...[
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RuneCurrencyIcon(size: 12),
                const SizedBox(width: 2),
                Text(
                  '$cost',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
