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
        SizedBox(
          height: 10,
          child: Center(
            child: _StageFrameBridge(accentColor: chapterTheme.accent),
          ),
        ),
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
                            runeRewardText: l10n
                                .stageFullClearRuneRewardCompact(
                                  _fullClearRuneReward(snapshot, stage),
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
                            runeRewardText: l10n
                                .stageFullClearRuneRewardCompact(
                                  _fullClearRuneReward(snapshot, stage),
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

class _StageMenuShell extends StatelessWidget {
  const _StageMenuShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth <= 390 ? 12.0 : 16.0;
        return _StageMetalFrame(
          accentColor: GamePalette.metalDim,
          reinforced: true,
          padding: EdgeInsets.all(padding),
          child: child,
        );
      },
    );
  }
}

class _StageMetalFrame extends StatelessWidget {
  const _StageMetalFrame({
    required this.child,
    required this.accentColor,
    this.padding = EdgeInsets.zero,
    this.selected = false,
    this.inset = false,
    this.filledAccent = false,
    this.reinforced = false,
    this.cornerContacts = false,
    this.cornerStuds = false,
    this.showInteriorLines = true,
    this.cutSize = 7,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final Color accentColor;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final bool inset;
  final bool filledAccent;
  final bool reinforced;
  final bool cornerContacts;
  final bool cornerStuds;
  final bool showInteriorLines;
  final double cutSize;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final clipper = _StageMetalFrameClipper(cutSize);
    final surfaceDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: filledAccent
            ? [
                Color.lerp(accentColor, Colors.white, 0.18)!,
                Color.lerp(accentColor, GamePalette.voidBlack, 0.42)!,
              ]
            : inset
            ? reinforced
                  ? const [Color(0xF00A151F), Color(0xFF02070D)]
                  : const [Color(0xE607111D), Color(0xF002070D)]
            : selected
            ? reinforced
                  ? const [Color(0xFF102838), Color(0xFF050D15)]
                  : const [Color(0xF20D2230), Color(0xF006101A)]
            : reinforced
            ? const [Color(0xFF101D28), Color(0xFF040B12)]
            : const [Color(0xF00C1A26), Color(0xF0050D15)],
      ),
    );
    final content = onTap == null
        ? Container(
            padding: padding,
            decoration: surfaceDecoration,
            child: child,
          )
        : Material(
            color: Colors.transparent,
            child: Ink(
              decoration: surfaceDecoration,
              child: InkWell(
                onTap: onTap,
                splashColor: accentColor.withValues(alpha: 0.12),
                highlightColor: accentColor.withValues(alpha: 0.06),
                child: Padding(padding: padding, child: child),
              ),
            ),
          );

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: selected ? 0.18 : 0.05),
              blurRadius: selected ? 11 : 5,
              offset: const Offset(0, 3),
            ),
            const BoxShadow(
              color: Color(0x88000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipPath(
          clipper: clipper,
          child: CustomPaint(
            foregroundPainter: _StageMetalFramePainter(
              accentColor: accentColor,
              selected: selected,
              reinforced: reinforced,
              cornerContacts: cornerContacts,
              cornerStuds: cornerStuds,
              showInteriorLines: showInteriorLines,
              cutSize: cutSize,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _StageMetalFrameClipper extends CustomClipper<Path> {
  const _StageMetalFrameClipper(this.cutSize);

  final double cutSize;

  @override
  Path getClip(Size size) => _stageMetalFramePath(Offset.zero & size, cutSize);

  @override
  bool shouldReclip(covariant _StageMetalFrameClipper oldClipper) {
    return oldClipper.cutSize != cutSize;
  }
}

class _StageMetalFramePainter extends CustomPainter {
  const _StageMetalFramePainter({
    required this.accentColor,
    required this.selected,
    required this.reinforced,
    required this.cornerContacts,
    required this.cornerStuds,
    required this.showInteriorLines,
    required this.cutSize,
  });

  final Color accentColor;
  final bool selected;
  final bool reinforced;
  final bool cornerContacts;
  final bool cornerStuds;
  final bool showInteriorLines;
  final double cutSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final outerRect = (Offset.zero & size).deflate(0.7);
    final outerPath = _stageMetalFramePath(outerRect, cutSize);
    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: selected ? 0.9 : 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 1.65 : (reinforced ? 1.2 : 1);
    canvas.drawPath(outerPath, borderPaint);

    if (showInteriorLines && size.width > 8 && size.height > 8) {
      final innerRect = outerRect.deflate(3);
      final innerPath = _stageMetalFramePath(
        innerRect,
        math.max(2, cutSize - 2),
      );
      canvas.drawPath(
        innerPath,
        Paint()
          ..color = const Color(
            0xFFB9D6E4,
          ).withValues(alpha: reinforced ? 0.16 : 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = reinforced ? 0.9 : 0.7,
      );
    }

    if (showInteriorLines &&
        reinforced &&
        size.width > 14 &&
        size.height > 14) {
      final innerPlate = _stageMetalFramePath(
        outerRect.deflate(5.5),
        math.max(2, cutSize - 3),
      );
      canvas.drawPath(
        innerPlate,
        Paint()
          ..color = const Color(0xFF02070D).withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    if (showInteriorLines) {
      final bevelPaint = Paint()
        ..color = const Color(0xFFDBE9F0).withValues(alpha: 0.13)
        ..strokeWidth = 0.7;
      canvas.drawLine(
        Offset(cutSize + 2, 2.2),
        Offset(size.width - cutSize - 2, 2.2),
        bevelPaint,
      );
    }

    if (showInteriorLines && selected && !cornerContacts) {
      // 선택 상태 상단 에너지 이음선.
      final seamPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            accentColor.withValues(alpha: 0.85),
            accentColor.withValues(alpha: 0.24),
            Colors.transparent,
          ],
          stops: const [0, 0.24, 0.72, 1],
        ).createShader(Rect.fromLTWH(0, 0, size.width, 2))
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(cutSize + 4, 1.3),
        Offset(size.width - cutSize - 4, 1.3),
        seamPaint,
      );
    }

    if (selected && cornerContacts) {
      final contactPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.94)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(
        Offset(size.width - cutSize - 15, 1.4),
        Offset(size.width - cutSize - 3, 1.4),
        contactPaint,
      );
      canvas.drawLine(
        Offset(cutSize + 3, size.height - 1.4),
        Offset(cutSize + 15, size.height - 1.4),
        contactPaint,
      );
    }

    if (cornerStuds && size.width > 24 && size.height > 20) {
      final studPaint = Paint()
        ..color = const Color(0xFFD7E5EC).withValues(alpha: 0.42)
        ..style = PaintingStyle.fill;
      for (final center in [
        const Offset(6.5, 6.5),
        Offset(size.width - 6.5, 6.5),
        Offset(6.5, size.height - 6.5),
        Offset(size.width - 6.5, size.height - 6.5),
      ]) {
        canvas.drawCircle(center, 1.25, studPaint);
        canvas.drawLine(
          center + const Offset(-0.7, 0.7),
          center + const Offset(0.7, -0.7),
          Paint()
            ..color = const Color(0xFF02070D).withValues(alpha: 0.72)
            ..strokeWidth = 0.55,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StageMetalFramePainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.selected != selected ||
        oldDelegate.reinforced != reinforced ||
        oldDelegate.cornerContacts != cornerContacts ||
        oldDelegate.cornerStuds != cornerStuds ||
        oldDelegate.showInteriorLines != showInteriorLines ||
        oldDelegate.cutSize != cutSize;
  }
}

class _StageFrameBridge extends StatelessWidget {
  const _StageFrameBridge({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 10,
      child: CustomPaint(painter: _StageFrameBridgePainter(accentColor)),
    );
  }
}

class _StageFrameBridgePainter extends CustomPainter {
  const _StageFrameBridgePainter(this.accentColor);

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final plate = Path()
      ..moveTo(5, 0.5)
      ..lineTo(size.width - 5, 0.5)
      ..lineTo(size.width - 1, size.height / 2)
      ..lineTo(size.width - 5, size.height - 0.5)
      ..lineTo(5, size.height - 0.5)
      ..lineTo(1, size.height / 2)
      ..close();
    canvas.drawPath(plate, Paint()..color = const Color(0xFF0A151F));
    canvas.drawPath(
      plate,
      Paint()
        ..color = accentColor.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      1.5,
      Paint()..color = accentColor.withValues(alpha: 0.34),
    );
  }

  @override
  bool shouldRepaint(covariant _StageFrameBridgePainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}

Path _stageMetalFramePath(Rect rect, double requestedCut) {
  // 작은 컴포넌트에서도 유지되는 절삭 모서리.
  final cut = math.min(
    requestedCut,
    math.max(0, math.min(rect.width, rect.height) / 4),
  );
  return Path()
    ..moveTo(rect.left + cut, rect.top)
    ..lineTo(rect.right - cut, rect.top)
    ..lineTo(rect.right, rect.top + cut)
    ..lineTo(rect.right, rect.bottom - cut)
    ..lineTo(rect.right - cut, rect.bottom)
    ..lineTo(rect.left + cut, rect.bottom)
    ..lineTo(rect.left, rect.bottom - cut)
    ..lineTo(rect.left, rect.top + cut)
    ..close();
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
      child: _StageMetalFrame(
        accentColor: theme.accent,
        reinforced: true,
        cutSize: 6,
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
                    GamePalette.voidBlack.withValues(alpha: 0.78),
                    GamePalette.voidBlack.withValues(alpha: 0.36),
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
          ],
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
    return SizedBox(
      height: 42,
      child: _StageMetalFrame(
        selected: selected,
        inset: !selected,
        reinforced: true,
        cornerContacts: selected,
        accentColor: selected ? accentColor : GamePalette.metalDim,
        onTap: enabled ? onPressed : null,
        semanticLabel: label,
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
    );
  }
}

// 진행 중 스테이지를 목록 안에서 리치 카드로 표시(이어서 진행 버튼 내장).
