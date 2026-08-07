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
