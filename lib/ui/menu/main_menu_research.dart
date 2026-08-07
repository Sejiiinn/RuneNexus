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
    final secondSlotPurchaseUnlocked = widget.snapshot.clearedStageNumbers
        .contains(RunProgression.researchSlotTwoUnlockRequiredStage);
    final showLockedSecondSlot =
        widget.snapshot.researchSlotCount < 2 &&
        (secondSlotPurchaseUnlocked ||
            widget.snapshot.clearedStageNumbers.contains(8));
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
          showLockedSecondSlot: showLockedSecondSlot,
          secondSlotPurchaseUnlocked: secondSlotPurchaseUnlocked,
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
    showGameDialog<void>(
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
