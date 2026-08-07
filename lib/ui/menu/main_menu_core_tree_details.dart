part of 'main_menu_screen.dart';

class _CorePassiveNodeDetails extends StatelessWidget {
  const _CorePassiveNodeDetails({
    required this.snapshot,
    required this.draftRanks,
    required this.selectedNodeId,
    required this.allocating,
    required this.onDecrease,
    required this.onIncrease,
    required this.onAssign,
  });

  final GameSnapshot snapshot;
  final Map<CorePassiveNodeId, int> draftRanks;
  final CorePassiveNodeId selectedNodeId;
  final bool allocating;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onAssign;

  @override
  Widget build(BuildContext context) {
    final l10n = RuneNexusLocalizations.of(context);
    final id = selectedNodeId;
    final definition = corePassiveNodeById(id);
    final currentRank = snapshot.corePassiveNodeRanks[id] ?? 0;
    final targetRank = draftRanks[id] ?? 0;
    final accessible = accessibleCorePassiveNodeIds(draftRanks).contains(id);
    final previewingFirstRank = targetRank == 0;
    final effect = l10n.corePassiveNodeEffect(
      id,
      previewingFirstRank ? 1 : targetRank,
    );
    final nextRankCost = targetRank < definition.maxRank
        ? '${definition.rankCosts[targetRank]}'
        : l10n.corePassiveMaxRank;
    final costDelta =
        corePassiveSpentPoints(draftRanks) - snapshot.spentCorePoints;
    final accent = _corePassiveBranchColor(definition.branch);

    return Container(
      key: const ValueKey('core-passive-node-details'),
      constraints: const BoxConstraints(minHeight: 182),
      padding: const EdgeInsets.all(12),
      decoration: _detailDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  border: Border.all(color: accent.withValues(alpha: 0.75)),
                  shape: BoxShape.circle,
                ),
                child: CorePassiveNodeIcon(id, size: 22, color: accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.corePassiveNodeName(id),
                      maxLines: 2,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                        color: Color(0xFFE8FBFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      currentRank == targetRank
                          ? '$currentRank / ${definition.maxRank}'
                          : '${l10n.corePassivePlannedRank} $currentRank → $targetRank / ${definition.maxRank}',
                      key: const ValueKey('core-passive-selected-rank'),
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!accessible && currentRank == 0)
            Text(
              l10n.corePassiveUnlockHint,
              style: const TextStyle(
                color: Color(0xFFFFC66A),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (!accessible && currentRank == 0) const SizedBox(height: 6),
          _CorePassiveEffectLine(
            label: l10n.corePassiveEffect,
            value: effect,
            accent: accent,
            muted: previewingFirstRank,
            highlightNumbers: true,
          ),
          const SizedBox(height: 4),
          _CorePassiveEffectLine(
            label: l10n.corePassiveRequiredPoints,
            value: nextRankCost,
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              _CorePassiveRankButton(
                key: const ValueKey('core-passive-rank-decrease'),
                icon: Icons.remove,
                onPressed: onDecrease,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 54, minHeight: 38),
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF07131E),
                  border: Border.all(color: const Color(0x665D7182)),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$targetRank/${definition.maxRank}',
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFFE8FBFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _CorePassiveRankButton(
                key: const ValueKey('core-passive-rank-increase'),
                icon: Icons.add,
                onPressed: onIncrease,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('core-passive-assign'),
                  onPressed: onAssign,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(70, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    backgroundColor: accent.withValues(alpha: 0.3),
                    foregroundColor: const Color(0xFFE8FBFF),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        allocating
                            ? l10n.corePassiveAllocationInProgress
                            : l10n.corePassiveAssign,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (costDelta != 0)
                        Text(
                          costDelta > 0
                              ? '${l10n.corePassiveRequiredPoints} $costDelta'
                              : '${l10n.corePassiveReturnedPoints} ${-costDelta}',
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(fontSize: 8),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration get _detailDecoration => BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xD90B1B2B), Color(0xCC06101A)],
    ),
    border: Border.all(color: const Color(0x775D7182)),
    borderRadius: BorderRadius.circular(9),
  );
}

class _CorePassiveEffectLine extends StatelessWidget {
  const _CorePassiveEffectLine({
    required this.label,
    required this.value,
    this.accent,
    this.muted = false,
    this.highlightNumbers = false,
  }) : assert(!highlightNumbers || accent != null);

  final String label;
  final String value;
  final Color? accent;
  final bool muted;
  final bool highlightNumbers;

  @override
  Widget build(BuildContext context) {
    final baseColor = muted ? const Color(0xFF778995) : const Color(0xFFC8D9E2);
    final numericColor = accent?.withValues(alpha: muted ? 0.55 : 0.95);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8FA8BA),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: highlightNumbers
              ? RichText(
                  key: const ValueKey('core-passive-selected-effect'),
                  text: TextSpan(
                    style: TextStyle(
                      color: baseColor,
                      fontSize: 9,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                    children: _highlightedEffectSpans(
                      value,
                      numericColor: numericColor!,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    color: baseColor,
                    fontSize: 9,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  List<TextSpan> _highlightedEffectSpans(
    String text, {
    required Color numericColor,
  }) {
    final spans = <TextSpan>[];
    var offset = 0;
    for (final match in RegExp(
      r'\d+(?:\.\d+)?(?:%|초|라운드|중첩|종|회|기|HP)?',
    ).allMatches(text)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(color: numericColor, fontWeight: FontWeight.w900),
        ),
      );
      offset = match.end;
    }
    if (offset < text.length) {
      spans.add(TextSpan(text: text.substring(offset)));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }
    return spans;
  }
}

class _CorePassiveRankButton extends StatelessWidget {
  const _CorePassiveRankButton({
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

Offset _corePassiveNodePosition(CorePassiveNodeId id) {
  final polar = _corePassiveNodePolarPositions[id]!;
  final radians = polar.angle * math.pi / 180;
  return _corePassiveTreeCenter +
      Offset(math.cos(radians), math.sin(radians)) * polar.radius;
}

Color _corePassiveBranchColor(CorePassiveBranch branch) {
  return switch (branch) {
    CorePassiveBranch.attack => const Color(0xFFFFB84D),
    CorePassiveBranch.control => const Color(0xFF56D9E8),
    CorePassiveBranch.efficiency => const Color(0xFF72E0A2),
  };
}
