part of 'main_menu_screen.dart';

class _CorePassiveResetDialog extends StatelessWidget {
  const _CorePassiveResetDialog({
    required this.title,
    required this.message,
    required this.returnedPoints,
    required this.returnedPointsLabel,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final int returnedPoints;
  final String returnedPointsLabel;
  final String cancelLabel;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return GameModalFrame(
      key: const ValueKey('core-passive-reset-dialog'),
      maxWidth: 340,
      tone: GameModalTone.danger,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: KeyedSubtree(
        key: const ValueKey('core-passive-reset-panel'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.restart_alt_rounded,
                  color: GamePalette.danger,
                  size: 21,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: GameTextStyles.title)),
              ],
            ),
            const SizedBox(height: 12),
            Text(message, style: GameTextStyles.body),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                color: GamePalette.danger.withValues(alpha: 0.1),
                border: Border.all(
                  color: GamePalette.danger.withValues(alpha: 0.36),
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Image.asset(
                    stageRewardCoreIconAsset,
                    width: 20,
                    height: 20,
                    filterQuality: FilterQuality.medium,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      returnedPointsLabel,
                      style: GameTextStyles.caption,
                    ),
                  ),
                  Text(
                    '$returnedPoints',
                    style: GameTextStyles.withColor(
                      GameTextStyles.sectionTitle,
                      GamePalette.danger,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    key: const ValueKey('core-passive-reset-cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                    label: cancelLabel,
                    icon: const Icon(Icons.arrow_back, size: 17),
                    variant: GameButtonVariant.ghost,
                    accentColor: GamePalette.metal,
                    height: 38,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GameButton(
                    key: const ValueKey('core-passive-reset-confirm'),
                    onPressed: () => Navigator.of(context).pop(true),
                    label: confirmLabel,
                    icon: const Icon(Icons.restart_alt_rounded, size: 17),
                    variant: GameButtonVariant.danger,
                    height: 38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CorePassiveAllocationStep {
  const _CorePassiveAllocationStep({
    required this.nodeId,
    required this.sourceNodeId,
    required this.lightsConnection,
  });

  final CorePassiveNodeId nodeId;
  final CorePassiveNodeId? sourceNodeId;
  final bool lightsConnection;
}

class _CorePassiveAllocationWave {
  const _CorePassiveAllocationWave({required this.steps});

  final List<_CorePassiveAllocationStep> steps;
}

class _CorePassivePointSummary extends StatelessWidget {
  const _CorePassivePointSummary({
    required this.snapshot,
    required this.draftSpentPoints,
    required this.l10n,
    required this.onCancelPlan,
    required this.onReset,
  });

  final GameSnapshot snapshot;
  final int draftSpentPoints;
  final RuneNexusLocalizations l10n;
  final VoidCallback? onCancelPlan;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('core-passive-point-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xE60A1724),
        border: Border.all(color: const Color(0x665D7182)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub_outlined, color: Color(0xFF8EE6FF), size: 19),
          const SizedBox(width: 7),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  '${l10n.corePoints} ${snapshot.totalCorePoints}',
                  style: const TextStyle(
                    color: Color(0xFFE8FBFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${l10n.corePointsSpent} ${snapshot.spentCorePoints}',
                  style: const TextStyle(
                    color: Color(0xFFFFC66A),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${l10n.corePassivePlanned} $draftSpentPoints',
                  key: const ValueKey('core-passive-planned-points'),
                  style: const TextStyle(
                    color: Color(0xFF8EE6FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${l10n.corePassiveRemainingAfterPlan} ${snapshot.totalCorePoints - draftSpentPoints}',
                  key: const ValueKey('core-passive-planned-remaining'),
                  style: const TextStyle(
                    color: Color(0xFF72E0A2),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                key: const ValueKey('core-passive-cancel-plan'),
                onPressed: onCancelPlan,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  minimumSize: const Size(0, 27),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.corePassiveCancelPlan,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('core-passive-reset-all'),
                onPressed: onReset,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  minimumSize: const Size(0, 27),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.corePassiveResetAll,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
