part of 'main_menu_screen.dart';

class _StageMenuPanel extends StatelessWidget {
  const _StageMenuPanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(child: child);
  }
}

const Size _stageReferenceSize = Size(789, 1566);
const List<double> _stageReferenceActiveRowTops = [658, 789, 920, 1051];
const List<double> _stageReferenceListRowTops = [289, 420, 551, 682, 813];

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
    final activeRunInChapter =
        activeRunInProgress &&
        snapshot.currentStageNumber >= chapterStart &&
        snapshot.currentStageNumber <= chapterEnd;
    final chapterStages = [
      for (var stage = chapterStart; stage <= chapterEnd; stage++) stage,
    ];
    final rowStages = activeRunInChapter
        ? chapterStages
              .where((stage) => stage != snapshot.currentStageNumber)
              .toList()
        : chapterStages;
    final rowTops = activeRunInChapter
        ? _stageReferenceActiveRowTops
        : _stageReferenceListRowTops;

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleX = constraints.maxWidth / _stageReferenceSize.width;
        final scaleY = constraints.maxHeight / _stageReferenceSize.height;
        final textScale = math.min(scaleX, scaleY);

        return Stack(
          fit: StackFit.expand,
          children: [
            _referenceAsset(
              asset: stageReferenceShellFillAsset,
              rect: Offset.zero & _stageReferenceSize,
              scaleX: scaleX,
              scaleY: scaleY,
            ),
            _referenceAsset(
              asset: stageReferenceShellFrameAsset,
              rect: Offset.zero & _stageReferenceSize,
              scaleX: scaleX,
              scaleY: scaleY,
            ),
            ..._buildReferenceChapterTabs(
              chapterTheme,
              scaleX,
              scaleY,
              textScale,
            ),
            ..._buildReferenceBanner(
              l10n,
              chapterStart,
              chapterEnd,
              chapterTheme,
              scaleX,
              scaleY,
              textScale,
            ),
            if (!activeRunInChapter)
              _referenceAsset(
                asset: stageReferenceBridgeAsset,
                rect: const Rect.fromLTWH(338, 280, 114, 36),
                scaleX: scaleX,
                scaleY: scaleY,
              ),
            if (activeRunInChapter) ...[
              _referenceAsset(
                asset: stageReferenceActivePanelAsset,
                rect: const Rect.fromLTWH(24, 282, 740, 366),
                scaleX: scaleX,
                scaleY: scaleY,
              ),
              _referenceAsset(
                asset: stageReferenceNumberSocketAsset,
                rect: const Rect.fromLTWH(24, 296, 145, 150),
                scaleX: scaleX,
                scaleY: scaleY,
              ),
              _referenceAsset(
                asset: stageReferenceStatStripAsset,
                rect: const Rect.fromLTWH(56, 431, 682, 81),
                scaleX: scaleX,
                scaleY: scaleY,
              ),
              _referenceAsset(
                asset: stageReferenceContinueButtonAsset,
                rect: const Rect.fromLTWH(57, 527, 678, 84),
                scaleX: scaleX,
                scaleY: scaleY,
              ),
              ..._buildReferenceActiveRun(
                context,
                l10n,
                snapshot,
                stageCount,
                activeRunInProgress,
                chapterTheme,
                scaleX,
                scaleY,
                textScale,
              ),
            ],
            for (var index = 0; index < rowStages.length; index++) ...[
              _referenceAsset(
                asset: stageReferenceLockedRowAsset,
                rect: Rect.fromLTWH(24, rowTops[index], 740, 123),
                scaleX: scaleX,
                scaleY: scaleY,
                opacity: rowStages[index] <= stageCount ? 1 : 0.76,
              ),
              _referenceAsset(
                asset: stageReferenceNumberPlateAsset,
                rect: Rect.fromLTWH(42, rowTops[index] + 18, 114, 90),
                scaleX: scaleX,
                scaleY: scaleY,
                opacity: rowStages[index] <= stageCount ? 1 : 0.76,
              ),
              Positioned.fromRect(
                rect: _scaledRect(
                  Rect.fromLTWH(24, rowTops[index], 740, 123),
                  scaleX,
                  scaleY,
                ),
                child: _StageSelectionRow(
                  stageNumber: rowStages[index],
                  unlocked: rowStages[index] <= stageCount,
                  active: false,
                  theme: chapterTheme,
                  sniperRewardUnlocked: snapshot.availableTurretTypes.contains(
                    TurretType.sniper,
                  ),
                  stageCleared: snapshot.clearedStageNumbers.contains(
                    rowStages[index],
                  ),
                  statusText: _stageStatusText(
                    l10n: l10n,
                    snapshot: snapshot,
                    stageNumber: rowStages[index],
                    activeRunInProgress: activeRunInProgress,
                  ),
                  runeRewardText: l10n.stageFullClearRuneRewardCompact(
                    _fullClearRuneReward(snapshot, rowStages[index]),
                  ),
                  showSurface: false,
                  onPressed: () => _openStageDetails(
                    context: context,
                    stageNumber: rowStages[index],
                    unlocked: rowStages[index] <= stageCount,
                    activeRunInProgress: activeRunInProgress,
                    theme: chapterTheme,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _buildReferenceChapterTabs(
    _StageChapterTheme chapterTheme,
    double scaleX,
    double scaleY,
    double textScale,
  ) {
    const rects = [
      Rect.fromLTWH(31, 28, 247, 91),
      Rect.fromLTWH(288, 28, 237, 91),
      Rect.fromLTWH(531, 28, 233, 91),
    ];
    return [
      for (var index = 0; index < rects.length; index++) ...[
        _referenceAsset(
          asset: index + 1 == _selectedChapter
              ? stageReferenceChapterTabSelectedAsset
              : stageReferenceChapterTabIdleAsset,
          rect: rects[index],
          scaleX: scaleX,
          scaleY: scaleY,
          opacity: _chapterIsPlayable(index + 1) ? 1 : 0.48,
          color: index + 1 == _selectedChapter ? chapterTheme.accent : null,
        ),
        Positioned.fromRect(
          rect: _scaledRect(rects[index], scaleX, scaleY),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _chapterIsPlayable(index + 1)
                  ? () => setState(() => _selectedChapter = index + 1)
                  : null,
              child: Center(
                child: Text(
                  context.l10n.stageChapterName(index + 1),
                  style: TextStyle(
                    color: _chapterIsPlayable(index + 1)
                        ? GamePalette.textPrimary
                        : GamePalette.textDisabled,
                    fontSize: 25 * textScale,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildReferenceBanner(
    RuneNexusLocalizations l10n,
    int chapterStart,
    int chapterEnd,
    _StageChapterTheme chapterTheme,
    double scaleX,
    double scaleY,
    double textScale,
  ) {
    return [
      _referenceAsset(
        asset: chapterTheme.bannerAsset,
        rect: const Rect.fromLTWH(35, 135, 724, 134),
        scaleX: scaleX,
        scaleY: scaleY,
      ),
      _referenceAsset(
        asset: stageReferenceBannerFrameAsset,
        rect: const Rect.fromLTWH(35, 135, 724, 134),
        scaleX: scaleX,
        scaleY: scaleY,
      ),
      _referenceText(
        text: l10n.stageChapterThemeName(_selectedChapter),
        rect: const Rect.fromLTWH(62, 164, 360, 52),
        scaleX: scaleX,
        scaleY: scaleY,
        style: TextStyle(
          color: GamePalette.textPrimary,
          fontSize: 42 * textScale,
          fontWeight: FontWeight.w900,
        ),
      ),
      _referenceText(
        text: l10n.stageChapterRange(chapterStart, chapterEnd),
        rect: const Rect.fromLTWH(62, 211, 280, 35),
        scaleX: scaleX,
        scaleY: scaleY,
        style: TextStyle(
          color: GamePalette.textSecondary,
          fontSize: 24 * textScale,
          fontWeight: FontWeight.w700,
        ),
      ),
    ];
  }

  List<Widget> _buildReferenceActiveRun(
    BuildContext context,
    RuneNexusLocalizations l10n,
    GameSnapshot snapshot,
    int stageCount,
    bool activeRunInProgress,
    _StageChapterTheme chapterTheme,
    double scaleX,
    double scaleY,
    double textScale,
  ) {
    final stage = snapshot.currentStageNumber;
    final statRects = const [
      Rect.fromLTWH(57, 432, 226, 78),
      Rect.fromLTWH(283, 432, 229, 78),
      Rect.fromLTWH(512, 432, 226, 78),
    ];
    final statValues = [
      '${snapshot.round}/${snapshot.maxRound}',
      '${snapshot.placedTurretCount}',
      _formatReferenceGold(snapshot.gold),
    ];
    final statLabels = ['라운드', '포탑', '골드'];

    return [
      _referenceText(
        text: stage.toString().padLeft(2, '0'),
        rect: const Rect.fromLTWH(61, 340, 72, 65),
        scaleX: scaleX,
        scaleY: scaleY,
        alignment: Alignment.center,
        style: TextStyle(
          color: GamePalette.textPrimary,
          fontSize: 34 * textScale,
          fontWeight: FontWeight.w900,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
      Positioned.fromRect(
        rect: _scaledRect(
          const Rect.fromLTWH(157, 326, 80, 34),
          scaleX,
          scaleY,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC087F78),
            borderRadius: BorderRadius.circular(5 * textScale),
          ),
          child: Center(
            child: Text(
              l10n.inProgress,
              style: TextStyle(
                color: const Color(0xFF68FFF0),
                fontSize: 20 * textScale,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
      _referenceText(
        text: l10n.stageName(stage),
        rect: const Rect.fromLTWH(157, 370, 330, 53),
        scaleX: scaleX,
        scaleY: scaleY,
        style: TextStyle(
          color: GamePalette.textPrimary,
          fontSize: 34 * textScale,
          fontWeight: FontWeight.w900,
        ),
      ),
      Positioned.fromRect(
        rect: _scaledRect(
          const Rect.fromLTWH(595, 346, 145, 48),
          scaleX,
          scaleY,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xB928261F),
            borderRadius: BorderRadius.circular(7 * textScale),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                l10n.stageFullClearRuneRewardCompact(
                  _fullClearRuneReward(snapshot, stage),
                ),
                style: TextStyle(
                  color: GamePalette.goldBright,
                  fontSize: 24 * textScale,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
      for (var index = 0; index < statRects.length; index++)
        Positioned.fromRect(
          rect: _scaledRect(statRects[index], scaleX, scaleY),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                statValues[index],
                style: TextStyle(
                  color: index == 2
                      ? GamePalette.goldBright
                      : GamePalette.textPrimary,
                  fontSize: 30 * textScale,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3 * textScale),
              Text(
                statLabels[index],
                style: TextStyle(
                  color: GamePalette.textSecondary,
                  fontSize: 22 * textScale,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      Positioned.fromRect(
        rect: _scaledRect(
          const Rect.fromLTWH(57, 528, 678, 82),
          scaleX,
          scaleY,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onStartStage(stage),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_arrow_rounded,
                  color: const Color(0xFF06141E),
                  size: 31 * textScale,
                ),
                SizedBox(width: 9 * textScale),
                Text(
                  l10n.continueRun,
                  style: TextStyle(
                    color: const Color(0xFF06141E),
                    fontSize: 30 * textScale,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned.fromRect(
        rect: _scaledRect(
          const Rect.fromLTWH(52, 309, 500, 113),
          scaleX,
          scaleY,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _openStageDetails(
            context: context,
            stageNumber: stage,
            unlocked: stage <= stageCount,
            activeRunInProgress: activeRunInProgress,
            theme: chapterTheme,
          ),
        ),
      ),
    ];
  }

  Widget _referenceText({
    required String text,
    required Rect rect,
    required double scaleX,
    required double scaleY,
    required TextStyle style,
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Positioned.fromRect(
      rect: _scaledRect(rect, scaleX, scaleY),
      child: Align(
        alignment: alignment,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: style.copyWith(height: 1),
          ),
        ),
      ),
    );
  }

  Widget _referenceAsset({
    required String asset,
    required Rect rect,
    required double scaleX,
    required double scaleY,
    double opacity = 1,
    Color? color,
  }) {
    Widget image = Image.asset(
      asset,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
    if (color != null) {
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(color, BlendMode.hue),
        child: image,
      );
    }
    if (opacity != 1) {
      image = Opacity(opacity: opacity, child: image);
    }
    return Positioned.fromRect(
      rect: _scaledRect(rect, scaleX, scaleY),
      child: IgnorePointer(child: image),
    );
  }

  Rect _scaledRect(Rect rect, double scaleX, double scaleY) {
    return Rect.fromLTWH(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.width * scaleX,
      rect.height * scaleY,
    );
  }

  bool _chapterIsPlayable(int chapter) {
    final chapterStart = (chapter - 1) * _stageChapterSize + 1;
    return chapterStart <= RunProgression.maxStageCount;
  }

  String _formatReferenceGold(int gold) {
    return gold >= 1000 ? '${(gold / 1000).toStringAsFixed(1)}K' : '$gold';
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

// 이전 카드형 레이아웃의 소형 배너. 상세 화면 호환을 위해 유지.
// ignore: unused_element
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
            IgnorePointer(
              child: Image.asset(
                stageReferenceBannerFrameAsset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 이전 카드형 레이아웃의 소형 탭. 상세 화면 호환을 위해 유지.
// ignore: unused_element
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
    return SizedBox(
      height: 42,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: enabled ? 1 : 0.48,
            child: selected
                ? ColorFiltered(
                    colorFilter: ColorFilter.mode(accentColor, BlendMode.hue),
                    child: Image.asset(
                      stageReferenceChapterTabSelectedAsset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  )
                : Image.asset(
                    stageReferenceChapterTabIdleAsset,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
          ),
          Material(
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
                      enabled
                          ? GamePalette.textPrimary
                          : GamePalette.textDisabled,
                    ),
                    overflow: TextOverflow.clip,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 진행 중 스테이지를 목록 안에서 리치 카드로 표시(이어서 진행 버튼 내장).
