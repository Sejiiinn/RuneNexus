part of 'main_menu_screen.dart';

class _ResearchSlotPanel extends StatelessWidget {
  const _ResearchSlotPanel({
    required this.slots,
    required this.activeResearches,
    required this.nowMillis,
    required this.game,
    required this.diamonds,
    required this.showLockedSecondSlot,
    required this.secondSlotPurchaseUnlocked,
  });

  final int slots;
  final List<ResearchProgress> activeResearches;
  final int nowMillis;
  final RuneNexusGame game;
  final int diamonds;
  final bool showLockedSecondSlot;
  final bool secondSlotPurchaseUnlocked;

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
        if (showLockedSecondSlot) ...[
          const SizedBox(height: 7),
          _LockedResearchSlotCard(
            purchaseUnlocked: secondSlotPurchaseUnlocked,
            diamonds: diamonds,
            game: game,
          ),
        ],
      ],
    );
  }
}

class _LockedResearchSlotCard extends StatelessWidget {
  const _LockedResearchSlotCard({
    required this.purchaseUnlocked,
    required this.diamonds,
    required this.game,
  });

  final bool purchaseUnlocked;
  final int diamonds;
  final RuneNexusGame game;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const cost = RunProgression.researchSlotTwoUnlockCost;
    final canPurchase = purchaseUnlocked && diamonds >= cost;
    final accent = purchaseUnlocked
        ? const Color(0xFFE7C66A)
        : const Color(0xFF607587);
    return Container(
      key: const ValueKey('research-slot-two-locked-card'),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: purchaseUnlocked
            ? const Color(0x22E7C66A)
            : const Color(0x22000000),
        border: Border.all(
          color: purchaseUnlocked
              ? const Color(0x66E7C66A)
              : const Color(0x33485B68),
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(
            purchaseUnlocked ? Icons.lock_open_outlined : Icons.lock_outline,
            color: accent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.researchSlotTwo,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(
                    color: Color(0xFFE8FBFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  purchaseUnlocked
                      ? l10n.researchSlotTwoBenefit
                      : l10n.researchSlotTwoPurchaseRequirement,
                  softWrap: true,
                  style: const TextStyle(
                    color: Color(0xFF9EB3BF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GameButton(
            key: const ValueKey('research-slot-two-unlock-button'),
            onPressed: canPurchase
                ? () => _confirmUnlockResearchSlotTwo(
                    context,
                    game: game,
                    diamonds: diamonds,
                  )
                : null,
            label: '${l10n.researchSlotTwoUnlockAction} $cost',
            compact: true,
            height: 30,
            width: 104,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
            variant: GameButtonVariant.primary,
            accentColor: const Color(0xFFE7C66A),
            tooltip: !purchaseUnlocked
                ? l10n.researchSlotTwoPurchaseRequirement
                : canPurchase
                ? l10n.researchSlotTwoUnlockAction
                : l10n.notEnoughDiamonds,
            child: _ResearchSlotUnlockButtonLabel(
              text: l10n.researchSlotTwoUnlockAction,
              cost: cost,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResearchSlotUnlockButtonLabel extends StatelessWidget {
  const _ResearchSlotUnlockButtonLabel({
    required this.text,
    required this.cost,
  });

  final String text;
  final int cost;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
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
    );
  }
}

Future<void> _confirmUnlockResearchSlotTwo(
  BuildContext context, {
  required RuneNexusGame game,
  required int diamonds,
}) async {
  final l10n = context.l10n;
  const cost = RunProgression.researchSlotTwoUnlockCost;
  final confirmed = await showGameDialog<bool>(
    context: context,
    builder: (context) => GameModalFrame(
      key: const ValueKey('research-slot-two-unlock-dialog'),
      maxWidth: 350,
      accentColor: GamePalette.gold,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_open_rounded,
                color: GamePalette.goldBright,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.researchSlotTwoUnlockTitle,
                  style: GameTextStyles.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.researchSlotTwoUnlockMessage(cost),
            style: GameTextStyles.body,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x2215283A),
              border: Border.all(color: const Color(0x5533D8FF)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Column(
              children: [
                _ResearchSlotUnlockBalanceRow(
                  label: l10n.ownedDiamonds,
                  value: diamonds,
                ),
                const SizedBox(height: 6),
                _ResearchSlotUnlockBalanceRow(
                  label: l10n.spendDiamondsLabel,
                  value: cost,
                ),
                const SizedBox(height: 6),
                _ResearchSlotUnlockBalanceRow(
                  label: l10n.remainingDiamonds,
                  value: diamonds - cost,
                  highlight: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GameButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  label: l10n.cancel,
                  variant: GameButtonVariant.ghost,
                  accentColor: GamePalette.metal,
                  height: 38,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                  key: const ValueKey('research-slot-two-unlock-confirm'),
                  onPressed: () => Navigator.of(context).pop(true),
                  label: '${l10n.researchSlotTwoUnlockAction} $cost',
                  variant: GameButtonVariant.primary,
                  accentColor: GamePalette.gold,
                  height: 38,
                  child: _ResearchSlotUnlockButtonLabel(
                    text: l10n.researchSlotTwoUnlockAction,
                    cost: cost,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  if (confirmed == true) {
    game.unlockResearchSlotTwo();
  }
}

class _ResearchSlotUnlockBalanceRow extends StatelessWidget {
  const _ResearchSlotUnlockBalanceRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final int value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9EB3BF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const DiamondCurrencyIcon(size: 13),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: TextStyle(
            color: highlight
                ? const Color(0xFFE7C66A)
                : const Color(0xFFE8FBFF),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
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
  final confirmed = await showGameDialog<bool>(
    context: context,
    builder: (context) => GameModalFrame(
      maxWidth: 340,
      accentColor: _researchInstantCompleteAccent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: _diamondCurrencyColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.completeResearchInstantlyTitle,
                  style: GameTextStyles.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.completeResearchInstantlyMessage(title, cost),
            style: GameTextStyles.body,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GameButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  label: l10n.cancel,
                  variant: GameButtonVariant.ghost,
                  accentColor: GamePalette.metal,
                  height: 38,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  label: l10n.completeResearchInstantly,
                  variant: GameButtonVariant.primary,
                  accentColor: _researchInstantCompleteAccent,
                  height: 38,
                ),
              ),
            ],
          ),
        ],
      ),
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
  final confirmed = await showGameDialog<bool>(
    context: context,
    builder: (context) => GameModalFrame(
      maxWidth: 340,
      accentColor: GamePalette.cyan,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cancel_outlined,
                color: GamePalette.cyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.cancelResearchTitle,
                  style: GameTextStyles.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(l10n.cancelResearchMessage(title), style: GameTextStyles.body),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GameButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  label: l10n.cancel,
                  variant: GameButtonVariant.ghost,
                  accentColor: GamePalette.metal,
                  height: 38,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  label: l10n.cancelResearchConfirm,
                  variant: GameButtonVariant.primary,
                  accentColor: GamePalette.cyan,
                  height: 38,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  if (confirmed != true) {
    return;
  }
  game.cancelResearch(research.type);
}
