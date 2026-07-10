part of 'main_menu_screen.dart';

class _ResearchMenu extends StatefulWidget {
  const _ResearchMenu({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  State<_ResearchMenu> createState() => _ResearchMenuState();
}

class _ResearchMenuState extends State<_ResearchMenu> {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _syncClockTimer();
  }

  @override
  void didUpdateWidget(covariant _ResearchMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncClockTimer();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _syncClockTimer() {
    if (widget.snapshot.activeResearches.isEmpty) {
      _clockTimer?.cancel();
      _clockTimer = null;
      return;
    }
    if (_clockTimer != null) {
      return;
    }
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (widget.snapshot.activeResearches.isEmpty) {
        _clockTimer?.cancel();
        _clockTimer = null;
        return;
      }
      if (!widget.game.refreshResearchProgress()) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final activeResearches = widget.snapshot.activeResearches;
    final unlockedIncompleteTypes = <ResearchType>[];
    final lockedIncompleteTypes = <ResearchType>[];
    final completedTypes = <ResearchType>[];
    for (final type in ResearchType.values) {
      final definition = gameResearchDefinitions[type]!;
      final complete =
          _researchLevel(widget.snapshot, type) >= definition.maxLevel;
      if (complete) {
        completedTypes.add(type);
      } else if (_researchUnlocked(widget.snapshot, definition)) {
        unlockedIncompleteTypes.add(type);
      } else {
        lockedIncompleteTypes.add(type);
      }
    }
    unlockedIncompleteTypes.sort(_compareResearchRequirement);
    lockedIncompleteTypes.sort(_compareResearchRequirement);
    completedTypes.sort(_compareResearchRequirement);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResearchSlotPanel(
          slots: widget.snapshot.researchSlotCount,
          activeResearches: activeResearches,
          nowMillis: nowMillis,
          game: widget.game,
          diamonds: widget.snapshot.diamonds,
        ),
        const SizedBox(height: 10),
        _ResearchSection(
          icon: Icons.science_outlined,
          title: l10n.availableResearch,
          tone: _ResearchSectionTone.available,
          children: [
            _ResearchCardGrid(
              types: unlockedIncompleteTypes,
              game: widget.game,
              snapshot: widget.snapshot,
              nowMillis: nowMillis,
              onSelectType: _openResearchDetails,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ResearchSection(
          icon: Icons.lock_outline,
          title: l10n.lockedResearchSection,
          tone: _ResearchSectionTone.locked,
          children: [
            _ResearchCardGrid(
              types: lockedIncompleteTypes,
              game: widget.game,
              snapshot: widget.snapshot,
              nowMillis: nowMillis,
              onSelectType: _openResearchDetails,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ResearchSection(
          icon: Icons.done_all,
          title: l10n.completedResearch,
          tone: _ResearchSectionTone.completed,
          children: [
            _ResearchCardGrid(
              types: completedTypes,
              game: widget.game,
              snapshot: widget.snapshot,
              nowMillis: nowMillis,
              onSelectType: _openResearchDetails,
            ),
          ],
        ),
      ],
    );
  }

  void _openResearchDetails(ResearchType type) {
    showDialog<void>(
      context: context,
      builder: (context) => _ResearchDetailDialog(
        game: widget.game,
        snapshot: widget.snapshot,
        type: type,
        nowMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

int _compareResearchRequirement(ResearchType left, ResearchType right) {
  final leftStage = gameResearchDefinitions[left]!.requiredClearedStage;
  final rightStage = gameResearchDefinitions[right]!.requiredClearedStage;
  final stageOrder = leftStage.compareTo(rightStage);
  if (stageOrder != 0) {
    return stageOrder;
  }
  return left.index.compareTo(right.index);
}

class _ResearchSlotPanel extends StatelessWidget {
  const _ResearchSlotPanel({
    required this.slots,
    required this.activeResearches,
    required this.nowMillis,
    required this.game,
    required this.diamonds,
  });

  final int slots;
  final List<ResearchProgress> activeResearches;
  final int nowMillis;
  final RuneNexusGame game;
  final int diamonds;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ResearchSection(
      icon: Icons.view_module_outlined,
      title: l10n.researchSlot,
      tone: _ResearchSectionTone.slots,
      children: [
        for (var index = 0; index < slots; index++) ...[
          if (index > 0) const SizedBox(height: 7),
          _ResearchSlotCard(
            research: index < activeResearches.length
                ? activeResearches[index]
                : null,
            nowMillis: nowMillis,
            game: game,
            diamonds: diamonds,
          ),
        ],
      ],
    );
  }
}

class _ResearchSlotCard extends StatelessWidget {
  const _ResearchSlotCard({
    required this.research,
    required this.nowMillis,
    required this.game,
    required this.diamonds,
  });

  final ResearchProgress? research;
  final int nowMillis;
  final RuneNexusGame game;
  final int diamonds;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = research;
    final progress = active == null || active.durationMillis <= 0
        ? 0.0
        : active.progressRatioAt(nowMillis);
    final instantCompleteCost = active == null
        ? 0
        : RunProgression.researchInstantCompleteCostFor(
            active,
            nowMillis: nowMillis,
          );
    final canCompleteInstantly =
        active != null && diamonds >= instantCompleteCost;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        border: Border.all(color: const Color(0x33485B68)),
        borderRadius: BorderRadius.circular(7),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (active != null)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 850),
                  curve: Curves.easeOutCubic,
                  widthFactor: progress.clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x22E7C66A),
                      border: Border(
                        right: BorderSide(color: Color(0x88E7C66A)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      active == null
                          ? Icons.add_circle_outline
                          : Icons.hourglass_bottom,
                      color: active == null
                          ? const Color(0xFF607587)
                          : const Color(0xFFE7C66A),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AdaptiveResearchTitle(
                        text: active == null
                            ? l10n.emptyResearchSlot
                            : '${_researchTitle(l10n, active.type)} ${l10n.researchLevel(active.targetLevel - 1, gameResearchDefinitions[active.type]!.maxLevel)}',
                        style: const TextStyle(
                          color: Color(0xFFE8FBFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (active != null)
                      Tooltip(
                        message: l10n.cancel,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _confirmCancelResearch(
                            context,
                            game: game,
                            research: active,
                          ),
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: Icon(
                              Icons.close,
                              color: Color(0xFFE8FBFF),
                              size: 15,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (active != null) ...[
                  const SizedBox(height: 7),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        children: [
                          Expanded(
                            child: _PermanentUpgradeStatusChip(
                              text: l10n.researchRemaining(
                                active.remainingMillisAt(nowMillis),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GameButton(
                            key: const ValueKey(
                              'research-instant-complete-button',
                            ),
                            onPressed: canCompleteInstantly
                                ? () => _confirmInstantCompleteResearch(
                                    context,
                                    game: game,
                                    research: active,
                                    cost: instantCompleteCost,
                                  )
                                : null,
                            label:
                                '${l10n.completeResearchInstantly} ${l10n.researchInstantCompleteCost(instantCompleteCost)}',
                            compact: true,
                            height: 26,
                            width: 104,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            variant: GameButtonVariant.primary,
                            accentColor: _researchInstantCompleteAccent,
                            tooltip: canCompleteInstantly
                                ? l10n.researchInstantCompleteCost(
                                    instantCompleteCost,
                                  )
                                : l10n.notEnoughDiamonds,
                            child: _ResearchInstantCompleteButtonLabel(
                              text: l10n.completeResearchInstantly,
                              cost: instantCompleteCost,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResearchInstantCompleteButtonLabel extends StatelessWidget {
  const _ResearchInstantCompleteButtonLabel({
    required this.text,
    required this.cost,
  });

  final String text;
  final int cost;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, maxLines: 1),
            const SizedBox(width: 5),
            const DiamondCurrencyIcon(size: 12),
            const SizedBox(width: 2),
            Text('$cost', maxLines: 1),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmInstantCompleteResearch(
  BuildContext context, {
  required RuneNexusGame game,
  required ResearchProgress research,
  required int cost,
}) async {
  final l10n = context.l10n;
  final title = _researchTitle(l10n, research.type);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF0B1725),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xAA33D8FF)),
      ),
      title: Text(
        l10n.completeResearchInstantlyTitle,
        style: const TextStyle(
          color: Color(0xFFE8FBFF),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Text(
        l10n.completeResearchInstantlyMessage(title, cost),
        style: const TextStyle(
          color: Color(0xFFB9D6E4),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        SizedBox(
          width: 86,
          child: GameButton(
            onPressed: () => Navigator.of(context).pop(false),
            label: l10n.cancel,
            compact: true,
            variant: GameButtonVariant.ghost,
            accentColor: GamePalette.metal,
          ),
        ),
        SizedBox(
          width: 94,
          child: GameButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: l10n.completeResearchInstantly,
            compact: true,
            variant: GameButtonVariant.primary,
            accentColor: _researchInstantCompleteAccent,
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return;
  }
  game.completeResearchWithDiamonds(research.type);
}

Future<void> _confirmCancelResearch(
  BuildContext context, {
  required RuneNexusGame game,
  required ResearchProgress research,
}) async {
  final l10n = context.l10n;
  final title = _researchTitle(l10n, research.type);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF0B1725),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xAA33D8FF)),
      ),
      title: Text(
        l10n.cancelResearchTitle,
        style: const TextStyle(
          color: Color(0xFFE8FBFF),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Text(
        l10n.cancelResearchMessage(title),
        style: const TextStyle(
          color: Color(0xFFB9D6E4),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        SizedBox(
          width: 86,
          child: GameButton(
            onPressed: () => Navigator.of(context).pop(false),
            label: l10n.cancel,
            compact: true,
            variant: GameButtonVariant.ghost,
            accentColor: GamePalette.metal,
          ),
        ),
        SizedBox(
          width: 94,
          child: GameButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: l10n.cancelResearchConfirm,
            compact: true,
            variant: GameButtonVariant.primary,
            accentColor: GamePalette.cyan,
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return;
  }
  game.cancelResearch(research.type);
}

Future<bool> _confirmUnlockCorePassiveSlot(
  BuildContext context, {
  required RuneNexusGame game,
  required GameSnapshot snapshot,
}) async {
  if (!snapshot.canUnlockCorePassiveSlot) {
    return false;
  }
  final slotNumber = snapshot.corePassiveSlotCount + 1;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF0B1725),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xAAE7C66A)),
      ),
      title: const Text(
        '패시브 슬롯을 해금할까요?',
        style: TextStyle(
          color: Color(0xFFE8FBFF),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Text(
        '$slotNumber번 코어 패시브 슬롯을 ${snapshot.corePassiveSlotUnlockCost} 다이아로 해금합니다.',
        style: const TextStyle(
          color: Color(0xFFB9D6E4),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        SizedBox(
          width: 76,
          child: GameButton(
            onPressed: () => Navigator.of(context).pop(false),
            label: '취소',
            compact: true,
            variant: GameButtonVariant.ghost,
            accentColor: GamePalette.metal,
          ),
        ),
        SizedBox(
          width: 82,
          child: GameButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: '해금',
            compact: true,
            variant: GameButtonVariant.primary,
            accentColor: GamePalette.gold,
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return false;
  }
  return game.unlockCorePassiveSlot();
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
        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: tone.backgroundColor,
            border: Border.all(color: tone.borderColor),
            borderRadius: BorderRadius.circular(7),
          ),
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
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.lineColor,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color lineColor;

  static const available = _ResearchSectionTone(
    backgroundColor: Color(0x3307111D),
    borderColor: Color(0x66E7C66A),
    iconColor: Color(0xFFE7C66A),
    lineColor: Color(0x88E7C66A),
  );

  static const slots = _ResearchSectionTone(
    backgroundColor: Color(0x3307111D),
    borderColor: Color(0x55485B68),
    iconColor: Color(0xFFB9D6E4),
    lineColor: Color(0x5533D8FF),
  );

  static const locked = _ResearchSectionTone(
    backgroundColor: Color(0x26050B12),
    borderColor: Color(0x55485B68),
    iconColor: Color(0xFF8DA5B3),
    lineColor: Color(0x66485B68),
  );

  static const completed = _ResearchSectionTone(
    backgroundColor: Color(0x22071412),
    borderColor: Color(0x6657C88B),
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
    final borderColor = canStart
        ? const Color(0xFFE7C66A)
        : active != null
        ? const Color(0xAA8EE6FF)
        : complete
        ? const Color(0x6657C88B)
        : const Color(0x55485B68);
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
      child: InkWell(
        onTap: clickable ? onPressed : null,
        borderRadius: BorderRadius.circular(7),
        splashColor: const Color(0x1A8EE6FF),
        highlightColor: const Color(0x1422C7E8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 106),
          decoration: BoxDecoration(
            color: clickable
                ? const Color(0x3307111D)
                : const Color(0x22000000),
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(7),
          ),
          clipBehavior: Clip.antiAlias,
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
                      children: [
                        Icon(
                          _researchIcon(type),
                          color: active == null
                              ? const Color(0xFF8EE6FF)
                              : const Color(0xFFE7C66A),
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _AdaptiveResearchTitle(
                            text: _researchTitle(l10n, type),
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        if (!unlocked)
                          const Icon(
                            Icons.lock_outline,
                            color: Color(0xFF607587),
                            size: 14,
                          )
                        else if (clickable)
                          const Icon(
                            Icons.open_in_new,
                            color: Color(0xFF8DA5B3),
                            size: 13,
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
                    const SizedBox(height: 6),
                    _ResearchMetaStrip(
                      levelText: l10n.researchLevel(level, definition.maxLevel),
                      cost: complete ? null : cost,
                      durationText: complete
                          ? null
                          : l10n.researchDuration(duration),
                      enabled: canStart || active != null,
                    ),
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

class _ResearchMetaStrip extends StatelessWidget {
  const _ResearchMetaStrip({
    required this.levelText,
    required this.cost,
    required this.durationText,
    required this.enabled,
  });

  final String levelText;
  final int? cost;
  final String? durationText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? const Color(0xFFE7C66A)
        : const Color(0xFF8DA5B3);
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        border: Border.all(color: const Color(0x33485B68)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            levelText,
            style: const TextStyle(
              color: Color(0xFFB9D6E4),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (cost != null)
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
          if (durationText != null)
            Text(
              durationText!,
              style: const TextStyle(
                color: Color(0xFFB9D6E4),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _ResearchDetailDialog extends StatelessWidget {
  const _ResearchDetailDialog({
    required this.game,
    required this.snapshot,
    required this.type,
    required this.nowMillis,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final ResearchType type;
  final int nowMillis;

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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1725),
          border: Border.all(color: const Color(0xAA33D8FF)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: const BoxDecoration(
                color: Color(0x2A33D8FF),
                border: Border(bottom: BorderSide(color: Color(0x5533D8FF))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x2233D8FF),
                      border: Border.all(color: const Color(0x7733D8FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _researchIcon(type),
                      color: const Color(0xFF8EE6FF),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AdaptiveResearchTitle(
                      text: _researchTitle(l10n, type),
                      style: const TextStyle(
                        color: Color(0xFFE8FBFF),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                      minSingleLineScale: 0.82,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    color: const Color(0xFFE8FBFF),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0x33000000),
                      border: Border.all(color: const Color(0x33485B68)),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      l10n.researchDescription(_researchTitle(l10n, type)),
                      style: const TextStyle(
                        color: Color(0xFFE0F4FF),
                        fontSize: 12,
                        height: 1.28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = (constraints.maxWidth - 8) / 2;
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _ResearchDialogMetric(
                              icon: Icons.auto_graph,
                              label: l10n.researchLevelLabel,
                              value: l10n.researchLevel(
                                level,
                                definition.maxLevel,
                              ),
                              accent: const Color(0xFF8EE6FF),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _ResearchDialogMetric(
                              icon: Icons.flag_outlined,
                              label: l10n.researchRequirementLabel,
                              value: l10n.stageClearRequirement(
                                definition.requiredClearedStage,
                              ),
                              accent: unlocked
                                  ? const Color(0xFF8EE6FF)
                                  : const Color(0xFF8DA5B3),
                            ),
                          ),
                          if (!complete)
                            SizedBox(
                              width: itemWidth,
                              child: _ResearchDialogMetric(
                                icon: Icons.diamond_outlined,
                                label: l10n.researchCostLabel,
                                value: '$cost',
                                accent: canStart
                                    ? const Color(0xFFE7C66A)
                                    : const Color(0xFF8DA5B3),
                              ),
                            ),
                          if (!complete)
                            SizedBox(
                              width: itemWidth,
                              child: _ResearchDialogMetric(
                                icon: Icons.schedule,
                                label: l10n.researchTimeLabel,
                                value: l10n.researchDuration(duration),
                                accent: const Color(0xFFB9D6E4),
                              ),
                            ),
                          if (statusText != null)
                            SizedBox(
                              width: constraints.maxWidth,
                              child: _ResearchDialogMetric(
                                icon: active == null
                                    ? Icons.info_outline
                                    : Icons.hourglass_bottom,
                                label: l10n.researchStatusLabel,
                                value: statusText,
                                accent: canStart
                                    ? const Color(0xFFE7C66A)
                                    : const Color(0xFFB9D6E4),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (!complete) ...[
                    const SizedBox(height: 10),
                    GameButton(
                      onPressed: canStart
                          ? () {
                              game.startResearch(type);
                              Navigator.of(context).pop();
                            }
                          : null,
                      label: l10n.startResearch,
                      compact: true,
                      height: 34,
                      variant: GameButtonVariant.primary,
                      accentColor: GamePalette.cyan,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResearchDialogMetric extends StatelessWidget {
  const _ResearchDialogMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x221B2C3D),
        border: Border.all(color: const Color(0x44485B68)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8DA5B3),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFE8FBFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

int _researchLevel(GameSnapshot snapshot, ResearchType type) {
  return snapshot.researchLevels[type] ?? 0;
}

bool _researchUnlocked(GameSnapshot snapshot, ResearchDefinition definition) {
  return definition.requiredClearedStage <= 0 ||
      snapshot.clearedStageNumbers.contains(definition.requiredClearedStage);
}

int _researchCost(GameSnapshot snapshot, ResearchType type) {
  final definition = gameResearchDefinitions[type]!;
  final baseCost = definition.costForCurrentLevel(
    _researchLevel(snapshot, type),
  );
  final efficiencyRate =
      _researchLevel(snapshot, ResearchType.researchCostEfficiency) *
      RunProgression.researchCostEfficiencyPerLevel;
  return RunProgression.applyResearchCostEfficiency(baseCost, efficiencyRate);
}

int _researchDuration(GameSnapshot snapshot, ResearchType type) {
  final definition = gameResearchDefinitions[type]!;
  final baseDuration = definition.durationForCurrentLevel(
    _researchLevel(snapshot, type),
  );
  final efficiencyRate =
      _researchLevel(snapshot, ResearchType.researchEfficiency) *
      RunProgression.researchEfficiencyPerLevel;
  final duration = RunProgression.applyResearchEfficiency(
    baseDuration,
    efficiencyRate,
  );
  final elapsed = _researchSavedElapsed(
    snapshot,
    type,
  ).clamp(0, duration <= 0 ? 0 : duration - 1).toInt();
  return duration - elapsed;
}

int _researchSavedElapsed(GameSnapshot snapshot, ResearchType type) {
  return snapshot.researchElapsedMillis[type] ?? 0;
}

ResearchProgress? _activeResearch(GameSnapshot snapshot, ResearchType type) {
  for (final research in snapshot.activeResearches) {
    if (research.type == type) {
      return research;
    }
  }
  return null;
}

String _researchTitle(RuneNexusLocalizations l10n, ResearchType type) {
  return switch (type) {
    ResearchType.researchEfficiency => l10n.researchEfficiency,
    ResearchType.researchCostEfficiency => l10n.researchCostEfficiency,
    ResearchType.turretTargetPriority => l10n.tacticalCommand,
    ResearchType.linkExpansionOne => l10n.linkExpansionOne,
    ResearchType.gemAttunement => l10n.gemAttunement,
    ResearchType.bossBounty => l10n.bossBounty,
    ResearchType.linkMaintenance => l10n.linkMaintenance,
    ResearchType.crystalRecovery => l10n.crystalRecovery,
    ResearchType.runeResonance => l10n.runeResonance,
    ResearchType.towerDamageLimitExpansion => l10n.towerDamageLimitExpansion,
    ResearchType.killGoldLimitExpansion => l10n.killGoldLimitExpansion,
    ResearchType.waveGoldLimitExpansion => l10n.waveGoldLimitExpansion,
  };
}

_ResearchEffectText _researchEffectText(
  RuneNexusLocalizations l10n,
  ResearchType type,
  int level,
  int? activeTargetLevel,
) {
  final definition = gameResearchDefinitions[type]!;
  final nextLevel = activeTargetLevel ?? (level + 1);
  final clampedNextLevel = nextLevel.clamp(0, definition.maxLevel).toInt();
  final hasNext = clampedNextLevel > level;
  return switch (type) {
    ResearchType.researchEfficiency => _ResearchEffectText(
      l10n.researchEfficiencyEffect(_researchEfficiencyPercent(level)),
      hasNext
          ? _signedPercent(_researchEfficiencyPercent(clampedNextLevel))
          : null,
    ),
    ResearchType.researchCostEfficiency => _ResearchEffectText(
      l10n.researchCostEfficiencyEffect(_researchCostEfficiencyPercent(level)),
      hasNext
          ? _signedPercent(_researchCostEfficiencyPercent(clampedNextLevel))
          : null,
    ),
    ResearchType.linkExpansionOne => _ResearchEffectText(
      l10n.researchLinkSlotEffect,
    ),
    ResearchType.turretTargetPriority => _ResearchEffectText(
      l10n.researchTargetPriorityEffect,
    ),
    ResearchType.gemAttunement => _ResearchEffectText(
      l10n.researchGemShardEffect(
        level * RunProgression.gemShardsPerGemAttunementLevel,
      ),
      hasNext
          ? '+${clampedNextLevel * RunProgression.gemShardsPerGemAttunementLevel}'
          : null,
    ),
    ResearchType.bossBounty => _ResearchEffectText(
      l10n.researchBossBountyEffect(_bossBountyPercentText(level)),
      hasNext ? '+${_bossBountyPercentText(clampedNextLevel)}%' : null,
    ),
    ResearchType.linkMaintenance => _ResearchEffectText(
      l10n.researchLinkMaintenanceEffect(_linkMaintenancePercent(level)),
      hasNext ? '-${_linkMaintenancePercent(clampedNextLevel)}%' : null,
    ),
    ResearchType.crystalRecovery => _ResearchEffectText(
      l10n.researchCrystalRecoveryEffect(
        level * RunProgression.bossGemShardsPerCrystalRecoveryLevel,
      ),
      hasNext
          ? '+${clampedNextLevel * RunProgression.bossGemShardsPerCrystalRecoveryLevel}'
          : null,
    ),
    ResearchType.runeResonance => _ResearchEffectText(
      l10n.researchRuneResonanceEffect(_runeResonancePercent(level)),
      hasNext ? _signedPercent(_runeResonancePercent(clampedNextLevel)) : null,
    ),
    ResearchType.towerDamageLimitExpansion => _ResearchEffectText(
      l10n.researchRunUpgradeLimitExpansionEffect(
        l10n.towerDamageRunUpgrade,
        _runUpgradeLimitExpansionLevelBonus(level),
      ),
      hasNext
          ? '+${_runUpgradeLimitExpansionLevelBonus(clampedNextLevel)}'
          : null,
    ),
    ResearchType.killGoldLimitExpansion => _ResearchEffectText(
      l10n.researchRunUpgradeLimitExpansionEffect(
        l10n.killGoldRunUpgrade,
        _runUpgradeLimitExpansionLevelBonus(level),
      ),
      hasNext
          ? '+${_runUpgradeLimitExpansionLevelBonus(clampedNextLevel)}'
          : null,
    ),
    ResearchType.waveGoldLimitExpansion => _ResearchEffectText(
      l10n.researchRunUpgradeLimitExpansionEffect(
        l10n.waveGoldRunUpgrade,
        _runUpgradeLimitExpansionLevelBonus(level),
      ),
      hasNext
          ? '+${_runUpgradeLimitExpansionLevelBonus(clampedNextLevel)}'
          : null,
    ),
  };
}

int _researchEfficiencyPercent(int level) {
  return (level * RunProgression.researchEfficiencyPerLevel * 100).round();
}

int _researchCostEfficiencyPercent(int level) {
  return (level * RunProgression.researchCostEfficiencyPerLevel * 100).round();
}

String _signedPercent(int percent) {
  return '+$percent%';
}

String _bossBountyPercentText(int level) {
  final percent = level * RunProgression.bossBountyBonusPerLevel * 100;
  return percent.toStringAsFixed(percent.truncateToDouble() == percent ? 0 : 1);
}

int _linkMaintenancePercent(int level) {
  return (level * RunProgression.linkMaintenanceDiscountPerLevel * 100).round();
}

int _runeResonancePercent(int level) {
  return (level * RunProgression.runeResonanceBonusPerLevel * 100).round();
}

int _runUpgradeLimitExpansionLevelBonus(int level) {
  return level * RunProgression.runUpgradeLimitExpansionMaxLevelPerLevel;
}

IconData _researchIcon(ResearchType type) {
  return switch (type) {
    ResearchType.researchEfficiency => Icons.speed_outlined,
    ResearchType.researchCostEfficiency => Icons.savings_outlined,
    ResearchType.turretTargetPriority => Icons.ads_click,
    ResearchType.linkExpansionOne => Icons.hub_outlined,
    ResearchType.gemAttunement => Icons.auto_awesome_outlined,
    ResearchType.bossBounty => Icons.monetization_on_outlined,
    ResearchType.linkMaintenance => Icons.device_hub_outlined,
    ResearchType.crystalRecovery => Icons.diamond_outlined,
    ResearchType.runeResonance => Icons.all_inclusive,
    ResearchType.towerDamageLimitExpansion =>
      Icons.local_fire_department_outlined,
    ResearchType.killGoldLimitExpansion => Icons.toll_outlined,
    ResearchType.waveGoldLimitExpansion => Icons.inventory_2_outlined,
  };
}
