part of 'main_menu_screen.dart';

// 이전 카드형 레이아웃의 진행 카드. 상세 화면 호환을 위해 유지.
// ignore: unused_element
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
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            stageReferenceActivePanelAsset,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
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
              SizedBox(
                height: 36,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      stageReferenceStatStripAsset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                    Row(
                      children: [
                        _buildStatBox(
                          '라운드',
                          '${snapshot.round}/${snapshot.maxRound}',
                        ),
                        _buildStatBox('포탑', '${snapshot.placedTurretCount}'),
                        _buildStatBox(
                          '골드',
                          _formatGold(snapshot.gold),
                          valueColor: GamePalette.goldBright,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      stageReferenceContinueButtonAsset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onContinue,
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              size: 17,
                              color: Color(0xFF06141E),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              l10n.continueRun,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF06141E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
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
    this.showSurface = true,
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
  final bool showSurface;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rewardInfo = _stageRewardInfo(context);
    final statusColor = active
        ? const Color(0xFFE7C66A)
        : unlocked
        ? theme.accent
        : const Color(0xFF667987);

    return SizedBox(
      key: ValueKey('stage-selection-row-$stageNumber'),
      height: _stageRowHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showSurface)
            Opacity(
              opacity: unlocked ? 1 : 0.76,
              child: Image.asset(
                stageReferenceLockedRowAsset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
          if (showSurface)
            Positioned.fromRect(
              rect: const Rect.fromLTWH(18, 18, 114, 90),
              child: Opacity(
                opacity: unlocked ? 1 : 0.76,
                child: Image.asset(
                  stageReferenceNumberPlateAsset,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final scaleX = constraints.maxWidth / 740;
              final scaleY = constraints.maxHeight / 123;
              final textScale = math.min(scaleX, scaleY);

              Rect scaledRect(Rect rect) => Rect.fromLTWH(
                rect.left * scaleX,
                rect.top * scaleY,
                rect.width * scaleX,
                rect.height * scaleY,
              );

              Widget alignedText({
                required String text,
                required Rect rect,
                required TextStyle style,
                Alignment alignment = Alignment.centerLeft,
              }) {
                return Positioned.fromRect(
                  rect: scaledRect(rect),
                  child: Align(
                    alignment: alignment,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: alignment,
                      child: Text(
                        text,
                        maxLines: 1,
                        softWrap: false,
                        style: style,
                      ),
                    ),
                  ),
                );
              }

              final titleColor = unlocked
                  ? const Color(0xFFE8F8FF)
                  : const Color(0xFF7F93A1);
              final runeColor = unlocked
                  ? active
                        ? const Color(0xFFE7C66A)
                        : theme.secondary
                  : const Color(0xFF667987);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      alignedText(
                        text: stageNumber.toString().padLeft(2, '0'),
                        // 번호판 불투명 영역의 실제 중심축(70.5)에 정렬.
                        rect: const Rect.fromLTWH(33.5, 26, 74, 70),
                        alignment: Alignment.center,
                        style: TextStyle(
                          color: active
                              ? theme.accent
                              : unlocked
                              ? GamePalette.textSecondary
                              : const Color(0xFF536675),
                          fontSize: 38 * textScale,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [ui.FontFeature.tabularFigures()],
                        ),
                      ),
                      alignedText(
                        text: l10n.stageName(stageNumber),
                        rect: const Rect.fromLTWH(145, 17, 270, 48),
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 34 * textScale,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Positioned.fromRect(
                        rect: scaledRect(const Rect.fromLTWH(145, 61, 180, 36)),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!unlocked) ...[
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    color: statusColor,
                                    size: 22 * textScale,
                                  ),
                                  SizedBox(width: 7 * textScale),
                                ],
                                Text(
                                  statusText,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 23 * textScale,
                                    height: 1,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      alignedText(
                        text: runeRewardText,
                        rect: const Rect.fromLTWH(385, 35, 180, 52),
                        alignment: Alignment.center,
                        style: TextStyle(
                          color: runeColor,
                          fontSize: 24 * textScale,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Positioned.fromRect(
                        rect: scaledRect(const Rect.fromLTWH(590, 25, 94, 72)),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: 52,
                            height: 32,
                            child: _StageRewardSummary(
                              rewardInfo: rewardInfo,
                              unlocked: unlocked,
                              dense: true,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fromRect(
                        rect: scaledRect(const Rect.fromLTWH(690, 32, 44, 60)),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: unlocked
                              ? theme.accent.withValues(alpha: 0.84)
                              : const Color(0xFF536675),
                          size: 36 * textScale,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
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
