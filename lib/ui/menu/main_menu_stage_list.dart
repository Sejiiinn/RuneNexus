part of 'main_menu_screen.dart';

class _ActiveStageCard extends StatelessWidget {
  const _ActiveStageCard({
    required this.snapshot,
    required this.runeRewardText,
    required this.onContinue,
    required this.onDetails,
  });

  final GameSnapshot snapshot;
  final String runeRewardText;
  final VoidCallback onContinue;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GamePanel(
      padding: const EdgeInsets.all(11),
      selected: true,
      accentColor: GamePalette.cyan,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDetails,
            child: Row(
              children: [
                _buildMedallion(snapshot.currentStageNumber),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: GamePalette.cyan.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          l10n.inProgress,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF5CF9E9),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.stageName(snapshot.currentStageNumber),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFE8F8FF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildRuneChip(runeRewardText),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatBox('라운드', '${snapshot.round}/${snapshot.maxRound}'),
              const SizedBox(width: 6),
              _buildStatBox('포탑', '${snapshot.placedTurretCount}'),
              const SizedBox(width: 6),
              _buildStatBox(
                '골드',
                _formatGold(snapshot.gold),
                valueColor: GamePalette.goldBright,
              ),
            ],
          ),
          const SizedBox(height: 10),
          GameButton(
            onPressed: onContinue,
            label: l10n.continueRun,
            icon: const Icon(Icons.play_arrow_rounded, size: 17),
            variant: GameButtonVariant.primary,
            accentColor: GamePalette.cyan,
            height: 38,
          ),
        ],
      ),
    );
  }

  Widget _buildMedallion(int n) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF103247),
        shape: BoxShape.circle,
        border: Border.all(color: GamePalette.cyan, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: GamePalette.cyanDeep.withValues(alpha: 0.5),
            blurRadius: 10,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        n.toString().padLeft(2, '0'),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Color(0xFFE8F8FF),
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, {Color? valueColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: GamePalette.voidBlack.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(GamePalette.radiusSmall),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1,
                color: valueColor ?? GamePalette.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1,
                color: GamePalette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuneChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: GamePalette.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(GamePalette.radiusSmall),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: GamePalette.goldBright,
        ),
      ),
    );
  }

  String _formatGold(int gold) =>
      gold >= 1000 ? '${(gold / 1000).toStringAsFixed(1)}K' : '$gold';
}

String _stageStatusText({
  required RuneNexusLocalizations l10n,
  required GameSnapshot snapshot,
  required int stageNumber,
  required bool activeRunInProgress,
}) {
  if (stageNumber > snapshot.unlockedStageCount) {
    return l10n.locked;
  }
  if (activeRunInProgress && stageNumber == snapshot.currentStageNumber) {
    return switch (snapshot.phase) {
      GamePhase.wave => l10n.combatInProgress,
      GamePhase.reward => l10n.rewardPending,
      GamePhase.restored => l10n.inProgress,
      _ => l10n.inProgress,
    };
  }
  if (snapshot.clearedStageNumbers.contains(stageNumber)) {
    return l10n.recordCleared;
  }
  return _recordTextForStage(l10n, snapshot, stageNumber);
}

String _recordTextForStage(
  RuneNexusLocalizations l10n,
  GameSnapshot snapshot,
  int stageNumber,
) {
  final bestRound = snapshot.bestRoundsByStage[stageNumber] ?? 0;
  if (bestRound > 0) {
    return l10n.stageBestRound(bestRound);
  }
  if (snapshot.clearedStageNumbers.contains(stageNumber)) {
    return l10n.recordCleared;
  }
  return l10n.recordNone;
}

class _StageSelectionRow extends StatelessWidget {
  const _StageSelectionRow({
    required this.stageNumber,
    required this.unlocked,
    required this.active,
    required this.theme,
    required this.sniperRewardUnlocked,
    required this.stageCleared,
    required this.statusText,
    required this.runeRewardText,
    required this.onPressed,
  });

  final int stageNumber;
  final bool unlocked;
  final bool active;
  final _StageChapterTheme theme;
  final bool sniperRewardUnlocked;
  final bool stageCleared;
  final String statusText;
  final String runeRewardText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rewardInfo = _stageRewardInfo(context);
    final borderColor = active
        ? const Color(0xFFE7C66A)
        : unlocked
        ? theme.accent.withValues(alpha: 0.48)
        : const Color(0x33485B68);
    final statusColor = active
        ? const Color(0xFFE7C66A)
        : unlocked
        ? theme.accent
        : const Color(0xFF667987);

    return GameButton(
      key: ValueKey('stage-selection-row-$stageNumber'),
      onPressed: onPressed,
      selected: active,
      variant: unlocked ? GameButtonVariant.ghost : GameButtonVariant.secondary,
      accentColor: borderColor,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dense = constraints.maxWidth < 330;
          final stageNumberWidth = dense ? 38.0 : 48.0;
          final stageDividerHeight = dense ? 28.0 : 31.0;
          final leftGap = dense ? 7.0 : 10.0;
          final leftFlex = dense ? 8 : 9;
          final runeGap = dense ? 5.0 : 8.0;
          final runeWidth = dense ? 62.0 : 76.0;
          final rewardGap = dense ? 5.0 : 8.0;
          final rewardFlex = dense ? 10 : 7;
          final chevronSize = dense ? 18.0 : 22.0;
          final trailingGap = dense ? 2.0 : 6.0;

          return SizedBox(
            height: _stageRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: stageNumberWidth,
                  child: Center(
                    child: Text(
                      stageNumber.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: active
                            ? theme.accent
                            : unlocked
                            ? GamePalette.textSecondary
                            : const Color(0xFF536675),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: stageDividerHeight,
                  color: unlocked
                      ? theme.accent.withValues(alpha: 0.32)
                      : const Color(0x33485B68),
                ),
                SizedBox(width: leftGap),
                Expanded(
                  flex: leftFlex,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n.stageName(stageNumber),
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: unlocked
                                  ? const Color(0xFFE8F8FF)
                                  : const Color(0xFF7F93A1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _StageInfoChip(
                        text: statusText,
                        unlocked: unlocked,
                        highlighted: active || stageCleared,
                        overrideColor: statusColor,
                        accentColor: theme.accent,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: runeGap),
                SizedBox(
                  width: runeWidth,
                  child: _StageRuneRewardText(
                    text: runeRewardText,
                    unlocked: unlocked,
                    active: active,
                    theme: theme,
                  ),
                ),
                SizedBox(width: rewardGap),
                Expanded(
                  flex: rewardFlex,
                  child: _StageRewardSummary(
                    rewardInfo: rewardInfo,
                    unlocked: unlocked,
                    dense: dense,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: unlocked
                      ? theme.accent.withValues(alpha: 0.84)
                      : const Color(0xFF536675),
                  size: chevronSize,
                ),
                SizedBox(width: trailingGap),
              ],
            ),
          );
        },
      ),
    );
  }

  _StageRewardInfo? _stageRewardInfo(BuildContext context) {
    return _stageRewardInfoFor(
      l10n: context.l10n,
      stageNumber: stageNumber,
      stageCleared: stageCleared,
      sniperRewardUnlocked: sniperRewardUnlocked,
    );
  }
}
