part of 'main_menu_screen.dart';

class _StageMenu extends StatefulWidget {
  const _StageMenu({
    required this.game,
    required this.snapshot,
    required this.onStartStage,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final ValueChanged<int> onStartStage;

  @override
  State<_StageMenu> createState() => _StageMenuState();
}

class _StageMenuState extends State<_StageMenu> {
  late int _selectedChapter = _initialChapterFor(widget.snapshot);

  @override
  void didUpdateWidget(covariant _StageMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    final maxChapter = _chapterForStage(RunProgression.maxStageCount);
    if (_selectedChapter > maxChapter) {
      _selectedChapter = maxChapter;
    }
    if (widget.snapshot.hasStageProgress &&
        widget.snapshot.currentStageNumber !=
            oldWidget.snapshot.currentStageNumber) {
      _selectedChapter = _chapterForStage(widget.snapshot.currentStageNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snapshot = widget.snapshot;
    final activeRunInProgress =
        snapshot.hasStageProgress &&
        snapshot.phase != GamePhase.success &&
        snapshot.phase != GamePhase.failure;
    final stageCount = snapshot.unlockedStageCount.clamp(
      1,
      RunProgression.maxStageCount,
    );
    final chapterStart = (_selectedChapter - 1) * _stageChapterSize + 1;
    final chapterEnd = math.min(
      chapterStart + _stageChapterSize - 1,
      RunProgression.maxStageCount,
    );
    final chapterTheme = _StageChapterTheme.forChapter(_selectedChapter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageChapterTabs(
          selectedChapter: _selectedChapter,
          selectedTheme: chapterTheme,
          onSelected: (chapter) {
            setState(() {
              _selectedChapter = chapter;
            });
          },
        ),
        const SizedBox(height: 10),
        _StageChapterThemeBanner(
          chapter: _selectedChapter,
          startStage: chapterStart,
          endStage: chapterEnd,
          theme: chapterTheme,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var stage = chapterStart; stage <= chapterEnd; stage++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: stage == chapterEnd ? 0 : 8,
                    ),
                    child:
                        activeRunInProgress &&
                            stage == snapshot.currentStageNumber
                        // 진행 중 스테이지는 별도 패널 대신 목록 내 리치 카드로 통합.
                        ? _ActiveStageCard(
                            snapshot: snapshot,
                            runeBonusText: l10n.stageRuneBonus(
                              RunProgression.stageRuneRewardBonusRateFor(stage),
                            ),
                            onContinue: () => widget.onStartStage(
                              snapshot.currentStageNumber,
                            ),
                            onDetails: () => _openStageDetails(
                              context: context,
                              stageNumber: stage,
                              unlocked: stage <= stageCount,
                              activeRunInProgress: activeRunInProgress,
                              theme: chapterTheme,
                            ),
                          )
                        : _StageSelectionRow(
                            stageNumber: stage,
                            unlocked: stage <= stageCount,
                            active: false,
                            theme: chapterTheme,
                            sniperRewardUnlocked: snapshot.availableTurretTypes
                                .contains(TurretType.sniper),
                            stageCleared: snapshot.clearedStageNumbers.contains(
                              stage,
                            ),
                            statusText: _stageStatusText(
                              l10n: l10n,
                              snapshot: snapshot,
                              stageNumber: stage,
                              activeRunInProgress: activeRunInProgress,
                            ),
                            runeBonusText: l10n.stageRuneBonus(
                              RunProgression.stageRuneRewardBonusRateFor(stage),
                            ),
                            onPressed: () => _openStageDetails(
                              context: context,
                              stageNumber: stage,
                              unlocked: stage <= stageCount,
                              activeRunInProgress: activeRunInProgress,
                              theme: chapterTheme,
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openStageDetails({
    required BuildContext context,
    required int stageNumber,
    required bool unlocked,
    required bool activeRunInProgress,
    required _StageChapterTheme theme,
  }) async {
    final snapshot = widget.snapshot;
    final active =
        activeRunInProgress && stageNumber == snapshot.currentStageNumber;
    final stageCleared = snapshot.clearedStageNumbers.contains(stageNumber);
    final action = await showGameDialog<_StageDetailsAction>(
      context: context,
      builder: (context) => _StageDetailsDialog(
        snapshot: snapshot,
        stageNumber: stageNumber,
        unlocked: unlocked,
        active: active,
        theme: theme,
        statusText: _stageStatusText(
          l10n: context.l10n,
          snapshot: snapshot,
          stageNumber: stageNumber,
          activeRunInProgress: activeRunInProgress,
        ),
        rewardInfo: _stageRewardInfoFor(
          l10n: context.l10n,
          stageNumber: stageNumber,
          stageCleared: stageCleared,
          sniperRewardUnlocked: snapshot.availableTurretTypes.contains(
            TurretType.sniper,
          ),
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _StageDetailsAction.start:
      case _StageDetailsAction.continueRun:
        widget.onStartStage(stageNumber);
    }
  }

  int _initialChapterFor(GameSnapshot snapshot) {
    final stageNumber = snapshot.hasStageProgress
        ? snapshot.currentStageNumber
        : snapshot.unlockedStageCount;
    return _chapterForStage(
      stageNumber.clamp(1, RunProgression.maxStageCount).toInt(),
    );
  }
}

int _chapterForStage(int stageNumber) {
  return ((stageNumber - 1) ~/ _stageChapterSize) + 1;
}

class _StageChapterTheme {
  const _StageChapterTheme({
    required this.accent,
    required this.secondary,
    required this.bannerAsset,
  });

  final Color accent;
  final Color secondary;
  final String bannerAsset;

  static _StageChapterTheme forChapter(int chapter) {
    if (chapter == 3) {
      return const _StageChapterTheme(
        accent: Color(0xFFFF8A3D),
        secondary: Color(0xFF5CF9E9),
        bannerAsset: stageChapterThreeBannerAsset,
      );
    }
    if (chapter == 2) {
      return const _StageChapterTheme(
        accent: Color(0xFF5CF9E9),
        secondary: Color(0xFFB68BFF),
        bannerAsset: stageChapterTwoBannerAsset,
      );
    }
    return const _StageChapterTheme(
      accent: Color(0xFF8EE6FF),
      secondary: Color(0xFFE7C66A),
      bannerAsset: stageChapterOneBannerAsset,
    );
  }
}

class _StageChapterThemeBanner extends StatelessWidget {
  const _StageChapterThemeBanner({
    required this.chapter,
    required this.startStage,
    required this.endStage,
    required this.theme,
  });

  final int chapter;
  final int startStage;
  final int endStage;
  final _StageChapterTheme theme;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 66,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.accent.withValues(alpha: 0.72)),
          boxShadow: [
            BoxShadow(
              color: theme.accent.withValues(alpha: 0.14),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                theme.bannerAsset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      GamePalette.voidBlack.withValues(alpha: 0.72),
                      GamePalette.voidBlack.withValues(alpha: 0.34),
                      GamePalette.voidBlack.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.42, 0.76],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n.stageChapterThemeName(chapter),
                          style: GameTextStyles.withColor(
                            GameTextStyles.title,
                            GamePalette.textPrimary,
                          ).copyWith(fontSize: 20),
                          overflow: TextOverflow.clip,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.stageChapterRange(startStage, endStage),
                          style: GameTextStyles.withColor(
                            GameTextStyles.caption,
                            GamePalette.textSecondary,
                          ),
                          overflow: TextOverflow.clip,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageChapterTabs extends StatelessWidget {
  const _StageChapterTabs({
    required this.selectedChapter,
    required this.selectedTheme,
    required this.onSelected,
  });

  final int selectedChapter;
  final _StageChapterTheme selectedTheme;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          for (var chapter = 1; chapter <= _visibleStageChapterCount; chapter++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: chapter == 1 ? 0 : 8),
                child: _StageChapterTab(
                  label: l10n.stageChapterName(chapter),
                  selected: selectedChapter == chapter,
                  enabled: _chapterIsPlayable(chapter),
                  accentColor: selectedChapter == chapter
                      ? selectedTheme.accent
                      : _StageChapterTheme.forChapter(chapter).accent,
                  onPressed: () => onSelected(chapter),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _chapterIsPlayable(int chapter) {
    final chapterStart = (chapter - 1) * _stageChapterSize + 1;
    return chapterStart <= RunProgression.maxStageCount;
  }
}

class _StageChapterTab extends StatelessWidget {
  const _StageChapterTab({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.accentColor,
    this.onPressed,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final Color accentColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      height: 42,
      selected: selected,
      accentColor: accentColor,
      variant: selected ? GamePanelVariant.stone : GamePanelVariant.inset,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: GamePalette.gapSmall,
              ),
              child: Text(
                label,
                style: GameTextStyles.withColor(
                  GameTextStyles.button,
                  enabled ? GamePalette.textPrimary : GamePalette.textDisabled,
                ),
                overflow: TextOverflow.clip,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 진행 중 스테이지를 목록 안에서 리치 카드로 표시(이어서 진행 버튼 내장).
class _ActiveStageCard extends StatelessWidget {
  const _ActiveStageCard({
    required this.snapshot,
    required this.runeBonusText,
    required this.onContinue,
    required this.onDetails,
  });

  final GameSnapshot snapshot;
  final String runeBonusText;
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
                _buildRuneChip(runeBonusText),
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
    required this.runeBonusText,
    required this.onPressed,
  });

  final int stageNumber;
  final bool unlocked;
  final bool active;
  final _StageChapterTheme theme;
  final bool sniperRewardUnlocked;
  final bool stageCleared;
  final String statusText;
  final String runeBonusText;
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
          final runeWidth = dense ? 48.0 : 60.0;
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
                  child: _StageRuneBonusText(
                    text: runeBonusText,
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

enum _StageDetailsAction { start, continueRun }

class _StageDetailsDialog extends StatelessWidget {
  const _StageDetailsDialog({
    required this.snapshot,
    required this.stageNumber,
    required this.unlocked,
    required this.active,
    required this.theme,
    required this.statusText,
    required this.rewardInfo,
  });

  final GameSnapshot snapshot;
  final int stageNumber;
  final bool unlocked;
  final bool active;
  final _StageChapterTheme theme;
  final String statusText;
  final _StageRewardInfo? rewardInfo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fullClearRuneReward = _fullClearRuneReward(snapshot, stageNumber);
    final unlockItems = rewardInfo?.items ?? const <_StageUnlockItem>[];
    return GameModalFrame(
      maxWidth: 420,
      accentColor: unlocked ? theme.accent : GamePalette.metalDim,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _StageIcon(unlocked: unlocked, active: active),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.stageName(stageNumber),
                      style: GameTextStyles.withColor(
                        GameTextStyles.title,
                        unlocked
                            ? GamePalette.textPrimary
                            : GamePalette.textDisabled,
                      ),
                      overflow: TextOverflow.clip,
                    ),
                    const SizedBox(height: 4),
                    _StageInfoChip(
                      text: statusText,
                      unlocked: unlocked,
                      highlighted:
                          active ||
                          snapshot.clearedStageNumbers.contains(stageNumber),
                      overrideColor: active
                          ? const Color(0xFFE7C66A)
                          : unlocked
                          ? theme.accent
                          : const Color(0xFF667987),
                      accentColor: theme.accent,
                    ),
                  ],
                ),
              ),
              GameModalCloseButton(
                tooltip: l10n.cancel,
                onPressed: () => Navigator.of(context).pop(),
                accentColor: unlocked ? theme.accent : GamePalette.metalDim,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StageQuickStats(
            theme: theme,
            stats: [
              _StageQuickStatData(
                label: l10n.stageBestRecordLabel,
                value: _recordTextForStage(l10n, snapshot, stageNumber),
                icon: Icons.workspace_premium_outlined,
              ),
              _StageQuickStatData(
                label: l10n.stageTotalRoundsLabel,
                value: l10n.stageTotalRounds(snapshot.maxRound),
                icon: Icons.flag_outlined,
              ),
              _StageQuickStatData(
                label: l10n.stageRuneRewardLabel,
                value: l10n.stageFullClearRuneReward(fullClearRuneReward),
                icon: Icons.hexagon_outlined,
              ),
            ],
          ),
          if (!unlocked) ...[
            const SizedBox(height: 10),
            _StageLockedNotice(
              text: l10n.stageLockedRequirement(stageNumber),
              theme: theme,
            ),
          ],
          if (unlockItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            _StageUnlockPanel(
              title: rewardInfo!.label ?? l10n.clearRewardLabel,
              items: unlockItems,
              theme: theme,
            ),
          ],
          const SizedBox(height: 16),
          _StageDetailsActions(
            unlocked: unlocked,
            active: active,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _StageQuickStatData {
  const _StageQuickStatData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _StageQuickStats extends StatelessWidget {
  const _StageQuickStats({required this.stats, required this.theme});

  final List<_StageQuickStatData> stats;
  final _StageChapterTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: _StageQuickStat(data: stats[index], theme: theme),
          ),
        ],
      ],
    );
  }
}

class _StageQuickStat extends StatelessWidget {
  const _StageQuickStat({required this.data, required this.theme});

  final _StageQuickStatData data;
  final _StageChapterTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x6607111D),
        border: Border.all(color: theme.accent.withValues(alpha: 0.26)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, size: 17, color: theme.accent),
          const SizedBox(height: 5),
          Text(
            data.label,
            style: GameTextStyles.withColor(
              GameTextStyles.caption,
              GamePalette.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              data.value,
              maxLines: 1,
              softWrap: false,
              style: GameTextStyles.withColor(
                GameTextStyles.body,
                GamePalette.textPrimary,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageUnlockPanel extends StatelessWidget {
  const _StageUnlockPanel({
    required this.title,
    required this.items,
    required this.theme,
  });

  final String title;
  final List<_StageUnlockItem> items;
  final _StageChapterTheme theme;

  @override
  Widget build(BuildContext context) {
    final sections = _stageUnlockSections(context, items);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.10),
        border: Border.all(color: theme.accent.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, size: 16, color: theme.accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: GameTextStyles.withColor(
                  GameTextStyles.caption,
                  GamePalette.textSecondary,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final section in sections) ...[
            _StageUnlockSection(section: section, theme: theme),
            if (section != sections.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _StageUnlockSection extends StatelessWidget {
  const _StageUnlockSection({required this.section, required this.theme});

  final _StageUnlockSectionData section;
  final _StageChapterTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('stage-unlock-section-${section.category.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              section.label,
              style: GameTextStyles.withColor(
                GameTextStyles.caption,
                GamePalette.textSecondary,
              ).copyWith(fontSize: 10, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(height: 1, color: const Color(0x33485B68)),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final item in section.items)
              _StageUnlockChip(item: item, theme: theme),
          ],
        ),
      ],
    );
  }
}

List<_StageUnlockSectionData> _stageUnlockSections(
  BuildContext context,
  List<_StageUnlockItem> items,
) {
  final l10n = context.l10n;
  final result = <_StageUnlockSectionData>[];
  for (final category in _StageUnlockCategory.values) {
    final sectionItems = items
        .where((item) => item.category == category)
        .toList(growable: false);
    if (sectionItems.isEmpty) {
      continue;
    }
    result.add(
      _StageUnlockSectionData(
        category: category,
        label: category.label(l10n),
        items: sectionItems,
      ),
    );
  }
  return result;
}

class _StageUnlockChip extends StatelessWidget {
  const _StageUnlockChip({required this.item, required this.theme});

  final _StageUnlockItem item;
  final _StageChapterTheme theme;

  @override
  Widget build(BuildContext context) {
    final color = item.highlighted ? theme.secondary : GamePalette.textPrimary;
    return Container(
      constraints: const BoxConstraints(maxWidth: 178),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x7707111D),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.researchType case final researchType?)
            ResearchIcon(researchType, size: 15, color: color)
          else if (item.upgradeIconType case final upgradeIconType?)
            UpgradeIcon(upgradeIconType, size: 15, color: color)
          else if (item.coreCombatSkill case final coreCombatSkill?)
            CoreAbilityIcon(coreCombatSkill, size: 15, color: color)
          else if (item.gemType case final gemType?)
            GemIcon(gemType, size: 15)
          else if (item.asset case final asset?)
            Image.asset(
              asset,
              width: 17,
              height: 17,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            )
          else
            Icon(item.icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              item.label,
              style: GameTextStyles.withColor(
                GameTextStyles.buttonSmall,
                color,
              ).copyWith(fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageLockedNotice extends StatelessWidget {
  const _StageLockedNotice({required this.text, required this.theme});

  final String text;
  final _StageChapterTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x183D4D5A),
        border: Border.all(color: const Color(0x33485B68)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: theme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GameTextStyles.withColor(
                GameTextStyles.caption,
                GamePalette.textSecondary,
              ),
              overflow: TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageDetailsActions extends StatelessWidget {
  const _StageDetailsActions({
    required this.unlocked,
    required this.active,
    required this.theme,
  });

  final bool unlocked;
  final bool active;
  final _StageChapterTheme theme;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!unlocked) {
      return GameButton(
        onPressed: null,
        label: l10n.stageUnavailableAction,
        icon: const Icon(Icons.lock_outline, size: 16),
        variant: GameButtonVariant.secondary,
        accentColor: GamePalette.metalDim,
      );
    }
    if (active) {
      return GameButton(
        onPressed: () =>
            Navigator.of(context).pop(_StageDetailsAction.continueRun),
        label: l10n.continueRun,
        icon: const Icon(Icons.play_arrow_rounded, size: 16),
        variant: GameButtonVariant.primary,
        accentColor: theme.accent,
      );
    }
    return GameButton(
      onPressed: () => Navigator.of(context).pop(_StageDetailsAction.start),
      label: l10n.startStageAction,
      icon: const Icon(Icons.play_arrow_rounded, size: 16),
      variant: GameButtonVariant.primary,
      accentColor: theme.accent,
    );
  }
}

_StageRewardInfo? _stageRewardInfoFor({
  required RuneNexusLocalizations l10n,
  required int stageNumber,
  required bool stageCleared,
  required bool sniperRewardUnlocked,
}) {
  final visual = _stageRewardVisualFor(stageNumber);
  if (visual == null) {
    return null;
  }
  final highlighted = _stageRewardHighlightedFor(
    stageNumber: stageNumber,
    stageCleared: stageCleared,
    sniperRewardUnlocked: sniperRewardUnlocked,
  );
  final String label;
  if (stageNumber == 11) {
    label = highlighted ? l10n.claimedRewardLabel : l10n.firstClearRewardLabel;
  } else {
    label = highlighted ? l10n.unlockedRewardLabel : l10n.clearRewardLabel;
  }
  return _StageRewardInfo(
    label: label,
    icon: visual.icon,
    extraIcons: visual.extraIcons,
    highlighted: highlighted,
    items: _stageUnlockItemsFor(
      l10n: l10n,
      stageNumber: stageNumber,
      highlighted: highlighted,
    ),
  );
}

_StageRewardVisual? _stageRewardVisualFor(int stageNumber) {
  return switch (stageNumber) {
    1 || 4 || 7 => const _StageRewardVisual(
      icon: _StageRewardAssetIcon(asset: stageRewardUpgradeIconAsset),
    ),
    2 || 8 => const _StageRewardVisual(
      icon: _StageRewardAssetIcon(asset: stageRewardResearchIconAsset),
    ),
    3 => const _StageRewardVisual(
      icon: _SniperRewardIcon(),
      extraIcons: [_StageRewardAssetIcon(asset: stageRewardGemIconAsset)],
    ),
    5 => const _StageRewardVisual(
      icon: _StageRewardAssetIcon(asset: stageRewardResearchIconAsset),
      extraIcons: [_StageRewardAssetIcon(asset: stageRewardCoreIconAsset)],
    ),
    6 => const _StageRewardVisual(icon: _LightningRewardIcon()),
    10 => const _StageRewardVisual(
      icon: _StageRewardAssetIcon(asset: stageRewardGemIconAsset),
      extraIcons: [_StageRewardAssetIcon(asset: stageRewardResearchIconAsset)],
    ),
    11 => const _StageRewardVisual(
      icon: _StageRewardAssetIcon(asset: turretModuleTicketIconAsset),
    ),
    12 => const _StageRewardVisual(
      icon: _StageRewardAssetIcon(asset: stageRewardResearchIconAsset),
    ),
    _ => null,
  };
}

bool _stageRewardHighlightedFor({
  required int stageNumber,
  required bool stageCleared,
  required bool sniperRewardUnlocked,
}) {
  if (stageNumber == 3) {
    return sniperRewardUnlocked;
  }
  return stageCleared;
}

List<_StageUnlockItem> _stageUnlockItemsFor({
  required RuneNexusLocalizations l10n,
  required int stageNumber,
  required bool highlighted,
}) {
  return switch (stageNumber) {
    1 => [
      _StageUnlockItem(
        label: l10n.killRewardBonus,
        upgradeIconType: GameUpgradeIconType.killGold,
        category: _StageUnlockCategory.upgrade,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.emergencySale,
        upgradeIconType: GameUpgradeIconType.turretRefund,
        category: _StageUnlockCategory.upgrade,
        highlighted: highlighted,
      ),
    ],
    2 => [
      _StageUnlockItem(
        label: l10n.tacticalCommand,
        researchType: ResearchType.turretTargetPriority,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.gemAttunement,
        researchType: ResearchType.gemAttunement,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
    ],
    3 => [
      _StageUnlockItem(
        label: l10n.sniperTurret,
        icon: Icons.center_focus_strong_outlined,
        category: _StageUnlockCategory.turret,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.aimSpeedGem,
        gemType: GemType.aimSpeed,
        category: _StageUnlockCategory.gem,
        highlighted: highlighted,
      ),
    ],
    4 => [
      _StageUnlockItem(
        label: l10n.criticalChanceTraining,
        upgradeIconType: GameUpgradeIconType.criticalChance,
        category: _StageUnlockCategory.upgrade,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.criticalDamageTraining,
        upgradeIconType: GameUpgradeIconType.criticalDamage,
        category: _StageUnlockCategory.upgrade,
        highlighted: highlighted,
      ),
    ],
    5 => [
      _StageUnlockItem(
        label: l10n.linkExpansionOne,
        researchType: ResearchType.linkExpansionOne,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.crystalRecovery,
        researchType: ResearchType.crystalRecovery,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.riftMarkSkill,
        coreCombatSkill: CoreCombatSkill.riftMark,
        category: _StageUnlockCategory.core,
        highlighted: highlighted,
      ),
    ],
    6 => [
      _StageUnlockItem(
        label: l10n.lightningTurret,
        icon: Icons.bolt_outlined,
        category: _StageUnlockCategory.turret,
        highlighted: highlighted,
      ),
    ],
    7 => [
      _StageUnlockItem(
        label: l10n.physicalDamageTraining,
        upgradeIconType: GameUpgradeIconType.physicalDamage,
        category: _StageUnlockCategory.upgrade,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.elementalDamageTraining,
        upgradeIconType: GameUpgradeIconType.elementalDamage,
        category: _StageUnlockCategory.upgrade,
        highlighted: highlighted,
      ),
    ],
    8 => [
      _StageUnlockItem(
        label: l10n.runeResonance,
        researchType: ResearchType.runeResonance,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.runUpgradeCostOptimization,
        researchType: ResearchType.runUpgradeCostOptimization,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
    ],
    10 => [
      _StageUnlockItem(
        label: l10n.armorPiercingGem,
        gemType: GemType.armorPiercing,
        category: _StageUnlockCategory.gem,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.researchSlotTwoPurchaseAccess,
        icon: Icons.view_module_outlined,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
    ],
    11 => [
      _StageUnlockItem(
        label: l10n.turretModuleTicketReward(
          stageElevenFirstClearTurretModuleTicketReward,
        ),
        asset: turretModuleTicketIconAsset,
        category: _StageUnlockCategory.moduleTicket,
        highlighted: highlighted,
      ),
    ],
    12 => [
      _StageUnlockItem(
        label: l10n.towerDamageLimitExpansion,
        researchType: ResearchType.towerDamageLimitExpansion,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.killGoldLimitExpansion,
        researchType: ResearchType.killGoldLimitExpansion,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.waveGoldLimitExpansion,
        researchType: ResearchType.waveGoldLimitExpansion,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
    ],
    _ => const [],
  };
}

int _fullClearRuneReward(GameSnapshot snapshot, int stageNumber) {
  final completedRounds = snapshot.maxRound;
  final rewardProgress =
      (math.pow(RunProgression.runeRewardGrowthPerRound, completedRounds) - 1) /
      (math.pow(
            RunProgression.runeRewardGrowthPerRound,
            RunProgression.runeRewardFullClearRoundCount,
          ) -
          1);
  final baseReward =
      RunProgression.baseStageOneFullClearRuneReward * rewardProgress;
  final bonusRate = RunProgression.stageRuneRewardBonusRateFor(stageNumber);
  final resonanceLevel =
      snapshot.researchLevels[ResearchType.runeResonance] ?? 0;
  final resonanceMultiplier =
      1 + resonanceLevel * RunProgression.runeResonanceBonusPerLevel;
  return math.max(
    1,
    (baseReward * (1 + bonusRate) * resonanceMultiplier).round(),
  );
}

class _StageRuneBonusText extends StatelessWidget {
  const _StageRuneBonusText({
    required this.text,
    required this.unlocked,
    required this.active,
    required this.theme,
  });

  final String text;
  final bool unlocked;
  final bool active;
  final _StageChapterTheme theme;

  @override
  Widget build(BuildContext context) {
    final color = unlocked
        ? active
              ? const Color(0xFFE7C66A)
              : theme.secondary
        : const Color(0xFF667987);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(
        text,
        textAlign: TextAlign.right,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StageRewardInfo {
  const _StageRewardInfo({
    this.label,
    required this.icon,
    this.extraIcons = const [],
    required this.highlighted,
    this.items = const [],
  });

  final String? label;
  final Widget icon;
  final List<Widget> extraIcons;
  final bool highlighted;
  final List<_StageUnlockItem> items;
}

class _StageRewardVisual {
  const _StageRewardVisual({required this.icon, this.extraIcons = const []});

  final Widget icon;
  final List<Widget> extraIcons;
}

class _StageUnlockItem {
  const _StageUnlockItem({
    required this.label,
    this.icon,
    this.asset,
    this.researchType,
    this.upgradeIconType,
    this.coreCombatSkill,
    this.gemType,
    required this.category,
    this.highlighted = false,
  }) : assert(
         (icon != null ? 1 : 0) +
                 (asset != null ? 1 : 0) +
                 (researchType != null ? 1 : 0) +
                 (upgradeIconType != null ? 1 : 0) +
                 (coreCombatSkill != null ? 1 : 0) +
                 (gemType != null ? 1 : 0) ==
             1,
       );

  final String label;
  final IconData? icon;
  final String? asset;
  final ResearchType? researchType;
  final GameUpgradeIconType? upgradeIconType;
  final CoreCombatSkill? coreCombatSkill;
  final GemType? gemType;
  final _StageUnlockCategory category;
  final bool highlighted;
}

class _StageUnlockSectionData {
  const _StageUnlockSectionData({
    required this.category,
    required this.label,
    required this.items,
  });

  final _StageUnlockCategory category;
  final String label;
  final List<_StageUnlockItem> items;
}

enum _StageUnlockCategory {
  upgrade,
  research,
  turret,
  gem,
  core,
  moduleTicket;

  String label(RuneNexusLocalizations l10n) {
    return switch (this) {
      _StageUnlockCategory.upgrade => l10n.permanentUpgradeTab,
      _StageUnlockCategory.research => l10n.researchTab,
      _StageUnlockCategory.turret => l10n.turretSection,
      _StageUnlockCategory.gem => l10n.gemSection,
      _StageUnlockCategory.core => l10n.coreTab,
      _StageUnlockCategory.moduleTicket => l10n.moduleTicketSection,
    };
  }
}

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
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0x22E7C66A)
            : unlocked
            ? accent.withValues(alpha: 0.12)
            : const Color(0x183D4D5A),
        border: Border.all(
          color: highlighted
              ? const Color(0x88E7C66A)
              : unlocked
              ? accent.withValues(alpha: 0.34)
              : const Color(0x33485B68),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
              ),
              overflow: TextOverflow.clip,
              maxLines: 1,
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
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: active
            ? const Color(0x22E7C66A)
            : unlocked
            ? accent.withValues(alpha: 0.18)
            : const Color(0x22485B68),
        border: Border.all(
          color: active
              ? const Color(0xAAE7C66A)
              : unlocked
              ? accent.withValues(alpha: 0.72)
              : const Color(0x55485B68),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        unlocked ? Icons.flag_outlined : Icons.lock_outline,
        color: active
            ? const Color(0xFFE7C66A)
            : unlocked
            ? accent
            : const Color(0xFF6D7F8F),
        size: 18,
      ),
    );
  }
}
