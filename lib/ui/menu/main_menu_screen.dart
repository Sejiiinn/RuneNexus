import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/definitions/demo_research_data.dart';
import '../../domain/combat/game_phase.dart';
import '../../domain/research/research_definition.dart';
import '../../domain/research/research_progress.dart';
import '../../domain/research/research_type.dart';
import '../../domain/turret/turret_type.dart';
import '../../game/game_snapshot.dart';
import '../../game/rendering/turret_shape_renderer.dart';
import '../../game/rune_nexus_game.dart';
import '../../game/systems/run_progression.dart';
import '../../l10n/rune_nexus_localizations.dart';
import '../widgets/rune_balance_card.dart';

const _showMapEditor = bool.fromEnvironment(
  'RUNE_NEXUS_DEBUG_PANEL',
  defaultValue: false,
);

enum MainMenuTab { stage, permanentUpgrades, research }

enum _PermanentUpgradeGroup { combat, economy }

const int _stageChapterSize = 5;
const int _visibleStageChapterCount = 3;

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({
    required this.game,
    required this.snapshot,
    required this.selectedTab,
    required this.onSelectTab,
    required this.onStartStage,
    this.onOpenMapEditor,
    super.key,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final MainMenuTab selectedTab;
  final ValueChanged<MainMenuTab> onSelectTab;
  final ValueChanged<int> onStartStage;
  final VoidCallback? onOpenMapEditor;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  _PermanentUpgradeGroup _selectedUpgradeGroup = _PermanentUpgradeGroup.combat;
  Timer? _researchClockTimer;

  @override
  void initState() {
    super.initState();
    _syncResearchClockTimer();
  }

  @override
  void didUpdateWidget(covariant MainMenuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncResearchClockTimer();
  }

  @override
  void dispose() {
    _researchClockTimer?.cancel();
    super.dispose();
  }

  void _syncResearchClockTimer() {
    final needsClock = widget.snapshot.activeResearches.isNotEmpty;
    if (!needsClock) {
      _researchClockTimer?.cancel();
      _researchClockTimer = null;
      return;
    }
    if (_researchClockTimer != null) {
      return;
    }
    _researchClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (widget.snapshot.activeResearches.isEmpty) {
        _researchClockTimer?.cancel();
        _researchClockTimer = null;
        return;
      }
      if (!widget.game.refreshResearchProgress() &&
          widget.selectedTab == MainMenuTab.research) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = widget.selectedTab;
    const menuTopPadding = 76.0;
    final menuBottomPadding = selectedTab == MainMenuTab.permanentUpgrades
        ? 146.0
        : 92.0;
    return Container(
      color: const Color(0xFF07111D),
      child: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _MainMenuBackdrop()),
            const Positioned(top: 10, left: 0, right: 0, child: _MenuLogo()),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  menuTopPadding,
                  16,
                  menuBottomPadding,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MainMenuPanel(
                        child: selectedTab == MainMenuTab.stage
                            ? _StageMenu(
                                snapshot: widget.snapshot,
                                onStartStage: widget.onStartStage,
                              )
                            : selectedTab == MainMenuTab.permanentUpgrades
                            ? _PermanentUpgradeMenu(
                                game: widget.game,
                                snapshot: widget.snapshot,
                                group: _selectedUpgradeGroup,
                              )
                            : _ResearchMenu(
                                game: widget.game,
                                snapshot: widget.snapshot,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 16,
              child: RuneBalanceCard(
                runes: widget.snapshot.runes,
                frameless: true,
              ),
            ),
            if (_showMapEditor)
              Positioned(
                top: 10,
                left: 16,
                child: _MapEditorShortcut(onPressed: widget.onOpenMapEditor),
              ),
            if (selectedTab == MainMenuTab.permanentUpgrades)
              Positioned(
                left: 0,
                right: 0,
                bottom: 62,
                child: _PermanentUpgradeGroupTabs(
                  selectedGroup: _selectedUpgradeGroup,
                  onSelectGroup: (group) {
                    setState(() => _selectedUpgradeGroup = group);
                  },
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _MenuTabs(
                selectedTab: selectedTab,
                onSelectTab: widget.onSelectTab,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainMenuPanel extends StatelessWidget {
  const _MainMenuPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xF0091624),
        border: Border.all(color: const Color(0x9933D8FF)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MapEditorShortcut extends StatelessWidget {
  const _MapEditorShortcut({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        tooltip: '맵 에디터',
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: const Color(0xFFE8FBFF),
          backgroundColor: const Color(0xE607111D),
          side: const BorderSide(color: Color(0x6650E6FF)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.map_outlined, size: 20),
      ),
    );
  }
}

class _MainMenuBackdrop extends StatelessWidget {
  const _MainMenuBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MainMenuBackdropPainter());
  }
}

class _MainMenuBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x33143A4E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.28),
      size.shortestSide * 0.32,
      paint,
    );

    final linePaint = Paint()
      ..color = const Color(0x1233D8FF)
      ..strokeWidth = 1;
    const spacing = 38.0;
    for (var x = -spacing; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + 90, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MenuLogo extends StatelessWidget {
  const _MenuLogo();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: 0.92,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0x2233D8FF),
                  border: Border.all(color: const Color(0xAA33D8FF)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.diamond_outlined,
                  color: Color(0xFF8EE6FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.appTitle,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTabs extends StatelessWidget {
  const _MenuTabs({required this.selectedTab, required this.onSelectTab});

  final MainMenuTab selectedTab;
  final ValueChanged<MainMenuTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        color: Color(0xF207111D),
        border: Border(top: BorderSide(color: Color(0x9933D8FF))),
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              icon: Icons.flag_outlined,
              label: l10n.stageTab,
              selected: selectedTab == MainMenuTab.stage,
              onPressed: () => onSelectTab(MainMenuTab.stage),
            ),
          ),
          Container(width: 1, height: 32, color: const Color(0x5533D8FF)),
          Expanded(
            child: _TabButton(
              icon: Icons.auto_awesome,
              label: l10n.permanentUpgradeTab,
              selected: selectedTab == MainMenuTab.permanentUpgrades,
              onPressed: () => onSelectTab(MainMenuTab.permanentUpgrades),
            ),
          ),
          Container(width: 1, height: 32, color: const Color(0x5533D8FF)),
          Expanded(
            child: _TabButton(
              icon: Icons.science_outlined,
              label: l10n.researchTab,
              selected: selectedTab == MainMenuTab.research,
              onPressed: () => onSelectTab(MainMenuTab.research),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermanentUpgradeGroupTabs extends StatelessWidget {
  const _PermanentUpgradeGroupTabs({
    required this.selectedGroup,
    required this.onSelectGroup,
  });

  final _PermanentUpgradeGroup selectedGroup;
  final ValueChanged<_PermanentUpgradeGroup> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Container(
        width: 142,
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xF0091624),
          border: Border.all(color: const Color(0x7733D8FF)),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _UpgradeGroupTabButton(
                icon: const _CombatGroupIcon(),
                label: l10n.combatUpgradeGroup,
                activeColor: const Color(0xFFFF7A7A),
                inactiveColor: const Color(0xFFB88989),
                selected: selectedGroup == _PermanentUpgradeGroup.combat,
                onPressed: () => onSelectGroup(_PermanentUpgradeGroup.combat),
              ),
            ),
            Container(width: 1, height: 24, color: const Color(0x5533D8FF)),
            Expanded(
              child: _UpgradeGroupTabButton(
                icon: const Icon(Icons.paid_outlined, size: 19),
                label: l10n.economyUpgradeGroup,
                activeColor: const Color(0xFFE7C66A),
                inactiveColor: const Color(0xFFB6A36D),
                selected: selectedGroup == _PermanentUpgradeGroup.economy,
                onPressed: () => onSelectGroup(_PermanentUpgradeGroup.economy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CombatGroupIcon extends StatelessWidget {
  const _CombatGroupIcon();

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color;
    return SizedBox(
      width: 24,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 20, color: color),
          CustomPaint(
            size: const Size(18, 18),
            painter: _SwordIconPainter(color ?? const Color(0xFFFF7A7A)),
          ),
        ],
      ),
    );
  }
}

class _SwordIconPainter extends CustomPainter {
  const _SwordIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.7;
    final bladeStart = Offset(size.width * 0.36, size.height * 0.72);
    final bladeEnd = Offset(size.width * 0.74, size.height * 0.24);
    canvas.drawLine(bladeStart, bladeEnd, paint);
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.61),
      Offset(size.width * 0.49, size.height * 0.82),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.31, size.height * 0.83),
      Offset(size.width * 0.22, size.height * 0.94),
      paint,
    );
    final tipPath = Path()
      ..moveTo(size.width * 0.74, size.height * 0.24)
      ..lineTo(size.width * 0.68, size.height * 0.36)
      ..lineTo(size.width * 0.83, size.height * 0.32)
      ..close();
    canvas.drawPath(tipPath, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SwordIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _UpgradeGroupTabButton extends StatelessWidget {
  const _UpgradeGroupTabButton({
    required this.icon,
    required this.label,
    required this.activeColor,
    required this.inactiveColor,
    required this.selected,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final Color activeColor;
  final Color inactiveColor;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected ? activeColor : inactiveColor;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            splashColor: activeColor.withAlpha(35),
            highlightColor: const Color(0x1422C7E8),
            child: Container(
              height: double.infinity,
              decoration: BoxDecoration(
                color: selected
                    ? activeColor.withAlpha(42)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: IconTheme(
                data: IconThemeData(color: foregroundColor),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected
        ? const Color(0xFF8EE6FF)
        : const Color(0xFFB9D6E4);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        splashColor: const Color(0x1A8EE6FF),
        highlightColor: const Color(0x1422C7E8),
        child: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            color: selected ? const Color(0x2222C7E8) : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: selected ? const Color(0xFF8EE6FF) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: foregroundColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageMenu extends StatelessWidget {
  const _StageMenu({required this.snapshot, required this.onStartStage});

  final GameSnapshot snapshot;
  final ValueChanged<int> onStartStage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeRunInProgress =
        snapshot.hasStageProgress &&
        snapshot.phase != GamePhase.success &&
        snapshot.phase != GamePhase.failure;
    final stageCount = snapshot.unlockedStageCount.clamp(
      1,
      RunProgression.maxStageCount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StageChapterTabs(),
        const SizedBox(height: 10),
        if (activeRunInProgress) ...[
          _ActiveRunSummary(
            snapshot: snapshot,
            onPressed: () => onStartStage(snapshot.currentStageNumber),
          ),
          const SizedBox(height: 10),
        ],
        for (var stage = 1; stage <= _stageChapterSize; stage++)
          Padding(
            padding: EdgeInsets.only(
              bottom: stage == _stageChapterSize ? 0 : 8,
            ),
            child: _StageSelectionRow(
              stageNumber: stage,
              unlocked: stage <= stageCount,
              active:
                  activeRunInProgress && stage == snapshot.currentStageNumber,
              sniperRewardUnlocked: snapshot.availableTurretTypes.contains(
                TurretType.sniper,
              ),
              stageCleared: snapshot.clearedStageNumbers.contains(stage),
              statusText: _stageStatusText(
                l10n: l10n,
                snapshot: snapshot,
                stageNumber: stage,
                activeRunInProgress: activeRunInProgress,
              ),
              detailText: _stageDetailText(
                l10n: l10n,
                snapshot: snapshot,
                stageNumber: stage,
              ),
              runeBonusText: l10n.stageRuneBonus(
                RunProgression.stageRuneRewardBonusRateFor(stage),
              ),
              onPressed: stage <= stageCount ? () => onStartStage(stage) : null,
            ),
          ),
      ],
    );
  }
}

class _StageChapterTabs extends StatelessWidget {
  const _StageChapterTabs();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Expanded(
            child: _StageChapterTab(
              label: l10n.stageChapterName(1),
              selected: true,
              enabled: true,
            ),
          ),
          for (var chapter = 2; chapter <= _visibleStageChapterCount; chapter++)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _LockedStageChapterTab(tooltip: l10n.plannedUpgrade),
            ),
        ],
      ),
    );
  }
}

class _StageChapterTab extends StatelessWidget {
  const _StageChapterTab({
    required this.label,
    required this.selected,
    required this.enabled,
  });

  final String label;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? const Color(0x2233D8FF) : const Color(0x6607111D),
        border: Border.all(
          color: selected ? const Color(0xAA33D8FF) : const Color(0x33485B68),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: enabled ? const Color(0xFFE8F8FF) : const Color(0xFF667987),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _LockedStageChapterTab extends StatelessWidget {
  const _LockedStageChapterTab({required this.tooltip});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x6607111D),
          border: Border.all(color: const Color(0x33485B68)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.lock_outline,
          size: 18,
          color: Color(0xFF667987),
        ),
      ),
    );
  }
}

class _ActiveRunSummary extends StatelessWidget {
  const _ActiveRunSummary({required this.snapshot, required this.onPressed});

  final GameSnapshot snapshot;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xBB07111D),
        border: Border.all(color: const Color(0xAAE7C66A)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const _StageIcon(unlocked: true, active: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.activeRunTitle(snapshot.currentStageNumber),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE8F8FF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.stageProgressDetail(
                    round: snapshot.round,
                    maxRound: snapshot.maxRound,
                    turretCount: snapshot.placedTurretCount,
                    gold: snapshot.gold,
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB9D6E4),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 34,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(
                l10n.continueRun,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
      GamePhase.restored => l10n.savedCombat,
      _ => l10n.inProgress,
    };
  }
  if (activeRunInProgress) {
    return l10n.startAfterSettling;
  }
  return _recordTextForStage(l10n, snapshot, stageNumber);
}

String _stageDetailText({
  required RuneNexusLocalizations l10n,
  required GameSnapshot snapshot,
  required int stageNumber,
}) {
  if (stageNumber > snapshot.unlockedStageCount) {
    return l10n.stageUnlockRequirement(stageNumber - 1);
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
    required this.sniperRewardUnlocked,
    required this.stageCleared,
    required this.statusText,
    required this.detailText,
    required this.runeBonusText,
    required this.onPressed,
  });

  final int stageNumber;
  final bool unlocked;
  final bool active;
  final bool sniperRewardUnlocked;
  final bool stageCleared;
  final String statusText;
  final String detailText;
  final String runeBonusText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final borderColor = active
        ? const Color(0xFFE7C66A)
        : unlocked
        ? const Color(0x7733D8FF)
        : const Color(0x33485B68);
    final statusColor = active
        ? const Color(0xFFE7C66A)
        : unlocked
        ? const Color(0xFF8EE6FF)
        : const Color(0xFF667987);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: unlocked ? Colors.white : const Color(0xFF7F93A1),
        disabledForegroundColor: const Color(0xFF7F93A1),
        backgroundColor: const Color(0x6607111D),
        side: BorderSide(color: borderColor, width: active ? 1.5 : 1),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _StageIcon(unlocked: unlocked, active: active),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.stageName(stageNumber),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: unlocked
                                ? const Color(0xFFE8F8FF)
                                : const Color(0xFF7F93A1),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _StageInfoChip(
                        text: runeBonusText,
                        unlocked: unlocked,
                        highlighted: active,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StageInfoChip(
                        text: statusText,
                        unlocked: unlocked,
                        highlighted: active,
                        overrideColor: statusColor,
                      ),
                      if (detailText != statusText)
                        _StageInfoChip(
                          text: detailText,
                          unlocked: unlocked,
                          highlighted: false,
                        ),
                      ..._stageUnlockChips(context),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _stageUnlockChips(BuildContext context) {
    final l10n = context.l10n;
    if (stageNumber == 1) {
      return [
        _StageInfoChip(
          text: sniperRewardUnlocked
              ? l10n.stageSniperRewardUnlocked
              : l10n.stageSniperRewardLocked,
          unlocked: unlocked,
          highlighted: sniperRewardUnlocked,
          leading: const _SniperRewardIcon(),
        ),
      ];
    }
    if (stageNumber == 2) {
      return [
        _StageInfoChip(
          text: stageCleared
              ? l10n.unlockedReward(l10n.economicUpgrade)
              : l10n.clearReward(l10n.economicUpgrade),
          unlocked: unlocked,
          highlighted: stageCleared,
          leading: const Icon(Icons.paid_outlined, size: 13),
        ),
      ];
    }
    if (stageNumber == 4) {
      return [
        _StageInfoChip(
          text: stageCleared
              ? l10n.unlockedReward(l10n.combatUpgrade)
              : l10n.clearReward(l10n.combatUpgrade),
          unlocked: unlocked,
          highlighted: stageCleared,
          leading: const Icon(Icons.bolt_outlined, size: 13),
        ),
      ];
    }
    if (stageNumber == 3 || stageNumber == 5) {
      return [
        _StageInfoChip(
          text: stageCleared
              ? l10n.unlockedReward(l10n.researchTab)
              : l10n.clearReward(l10n.researchTab),
          unlocked: unlocked,
          highlighted: stageCleared,
          leading: const Icon(Icons.science_outlined, size: 13),
        ),
      ];
    }
    return const [];
  }
}

class _StageInfoChip extends StatelessWidget {
  const _StageInfoChip({
    required this.text,
    required this.unlocked,
    required this.highlighted,
    this.leading,
    this.overrideColor,
  });

  final String text;
  final bool unlocked;
  final bool highlighted;
  final Widget? leading;
  final Color? overrideColor;

  @override
  Widget build(BuildContext context) {
    final color =
        overrideColor ??
        (highlighted
            ? const Color(0xFFE7C66A)
            : unlocked
            ? const Color(0xFF8EE6FF)
            : const Color(0xFF667987));
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0x22E7C66A)
            : unlocked
            ? const Color(0x1833D8FF)
            : const Color(0x183D4D5A),
        border: Border.all(
          color: highlighted
              ? const Color(0x88E7C66A)
              : unlocked
              ? const Color(0x5533D8FF)
              : const Color(0x33485B68),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            IconTheme(
              data: IconThemeData(color: color, size: 13),
              child: leading!,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
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

class _StageIcon extends StatelessWidget {
  const _StageIcon({required this.unlocked, this.active = false});

  final bool unlocked;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: active
            ? const Color(0x22E7C66A)
            : unlocked
            ? const Color(0x2233D8FF)
            : const Color(0x22485B68),
        border: Border.all(
          color: active
              ? const Color(0xAAE7C66A)
              : unlocked
              ? const Color(0xAA33D8FF)
              : const Color(0x55485B68),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        unlocked ? Icons.flag_outlined : Icons.lock_outline,
        color: active
            ? const Color(0xFFE7C66A)
            : unlocked
            ? const Color(0xFF8EE6FF)
            : const Color(0xFF6D7F8F),
        size: 18,
      ),
    );
  }
}

class _PermanentUpgradeMenu extends StatelessWidget {
  const _PermanentUpgradeMenu({
    required this.game,
    required this.snapshot,
    required this.group,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final _PermanentUpgradeGroup group;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nextStartingGoldLevel = (snapshot.startingGoldUpgradeLevel + 1)
        .clamp(0, RunProgression.maxStartingGoldUpgradeLevel)
        .toInt();
    final nextNexusHpLevel = (snapshot.nexusHpUpgradeLevel + 1)
        .clamp(0, RunProgression.maxNexusHpUpgradeLevel)
        .toInt();
    final nextSupplyLevel = (snapshot.supplyUpgradeLevel + 1)
        .clamp(0, RunProgression.maxSupplyUpgradeLevel)
        .toInt();
    final nextKillGoldLevel = (snapshot.killGoldUpgradeLevel + 1)
        .clamp(0, RunProgression.maxKillGoldUpgradeLevel)
        .toInt();
    final nextEmergencySaleLevel = (snapshot.emergencySaleUpgradeLevel + 1)
        .clamp(0, RunProgression.maxEmergencySaleUpgradeLevel)
        .toInt();
    final nextFireTrainingLevel = (snapshot.fireTrainingUpgradeLevel + 1)
        .clamp(0, RunProgression.maxFireTrainingUpgradeLevel)
        .toInt();
    final nextCriticalChanceLevel = (snapshot.criticalChanceUpgradeLevel + 1)
        .clamp(0, RunProgression.maxCriticalChanceUpgradeLevel)
        .toInt();
    final nextCriticalDamageLevel = (snapshot.criticalDamageUpgradeLevel + 1)
        .clamp(0, RunProgression.maxCriticalDamageUpgradeLevel)
        .toInt();
    final stageTwoCleared = snapshot.clearedStageNumbers.contains(2);
    final stageFourCleared = snapshot.clearedStageNumbers.contains(4);
    final combatTiles = [
      _PermanentUpgradeTile(
        icon: Icons.favorite_border,
        title: l10n.nexusHp,
        description: l10n.permanentUpgradeDescription(l10n.nexusHp),
        level: snapshot.nexusHpUpgradeLevel,
        maxLevel: RunProgression.maxNexusHpUpgradeLevel,
        globalMaxLevel: RunProgression.maxNexusHpUpgradeLevel,
        valueText: '+${snapshot.nexusHpUpgradeLevel}',
        nextValueText: '+$nextNexusHpLevel',
        cost: snapshot.nexusHpUpgradeCost,
        enabled: snapshot.canUpgradeNexusHp,
        lockText: l10n.maxLevelReached,
        onPressed: game.upgradeNexusHpProgression,
      ),
      _PermanentUpgradeTile(
        icon: Icons.local_fire_department_outlined,
        title: l10n.basicFireTraining,
        description: l10n.permanentUpgradeDescription(l10n.basicFireTraining),
        level: snapshot.fireTrainingUpgradeLevel,
        maxLevel: RunProgression.maxFireTrainingUpgradeLevel,
        globalMaxLevel: RunProgression.maxFireTrainingUpgradeLevel,
        valueText: '+${(snapshot.fireTrainingDamageBonusRate * 100).round()}%',
        nextValueText:
            '+${(nextFireTrainingLevel * RunProgression.fireTrainingDamagePerUpgradeLevel * 100).round()}%',
        cost: snapshot.fireTrainingUpgradeCost,
        enabled: snapshot.canUpgradeFireTraining,
        lockText: l10n.maxLevelReached,
        onPressed: game.upgradeFireTrainingProgression,
      ),
      if (stageFourCleared)
        _PermanentUpgradeTile(
          icon: Icons.gps_fixed,
          title: l10n.criticalChanceTraining,
          description: l10n.permanentUpgradeDescription(
            l10n.criticalChanceTraining,
          ),
          level: snapshot.criticalChanceUpgradeLevel,
          maxLevel: RunProgression.maxCriticalChanceUpgradeLevel,
          globalMaxLevel: RunProgression.maxCriticalChanceUpgradeLevel,
          valueText:
              '+${(snapshot.criticalChanceProgressionBonusRate * 100).round()}%p',
          nextValueText:
              '+${(nextCriticalChanceLevel * RunProgression.criticalChanceBonusPerUpgradeLevel * 100).round()}%p',
          cost: snapshot.criticalChanceUpgradeCost,
          enabled: snapshot.canUpgradeCriticalChance,
          lockText: l10n.maxLevelReached,
          onPressed: game.upgradeCriticalChanceProgression,
        ),
      if (stageFourCleared)
        _PermanentUpgradeTile(
          icon: Icons.bolt,
          title: l10n.criticalDamageTraining,
          description: l10n.permanentUpgradeDescription(
            l10n.criticalDamageTraining,
          ),
          level: snapshot.criticalDamageUpgradeLevel,
          maxLevel: RunProgression.maxCriticalDamageUpgradeLevel,
          globalMaxLevel: RunProgression.maxCriticalDamageUpgradeLevel,
          valueText:
              '+${(snapshot.criticalDamageProgressionBonusRate * 100).round()}%p',
          nextValueText:
              '+${(nextCriticalDamageLevel * RunProgression.criticalDamageBonusPerUpgradeLevel * 100).round()}%p',
          cost: snapshot.criticalDamageUpgradeCost,
          enabled: snapshot.canUpgradeCriticalDamage,
          lockText: l10n.maxLevelReached,
          onPressed: game.upgradeCriticalDamageProgression,
        ),
    ];
    final economyTiles = [
      _PermanentUpgradeTile(
        icon: Icons.toll_outlined,
        title: l10n.startGold,
        description: l10n.permanentUpgradeDescription(l10n.startGold),
        level: snapshot.startingGoldUpgradeLevel,
        maxLevel: RunProgression.maxStartingGoldUpgradeLevel,
        globalMaxLevel: RunProgression.maxStartingGoldUpgradeLevel,
        valueText:
            '+${snapshot.startingGoldUpgradeLevel * RunProgression.startingGoldPerUpgradeLevel}G',
        nextValueText:
            '+${nextStartingGoldLevel * RunProgression.startingGoldPerUpgradeLevel}G',
        cost: snapshot.startingGoldUpgradeCost,
        enabled: snapshot.canUpgradeStartingGold,
        lockText: l10n.maxLevelReached,
        onPressed: game.upgradeStartingGoldProgression,
      ),
      _PermanentUpgradeTile(
        icon: Icons.inventory_2_outlined,
        title: l10n.maintenanceSupply,
        description: l10n.permanentUpgradeDescription(l10n.maintenanceSupply),
        level: snapshot.supplyUpgradeLevel,
        maxLevel: RunProgression.maxSupplyUpgradeLevel,
        globalMaxLevel: RunProgression.maxSupplyUpgradeLevel,
        valueText: '+${snapshot.waveClearGoldProgressionBonus}G',
        nextValueText:
            '+${nextSupplyLevel * RunProgression.supplyGoldPerUpgradeLevel}G',
        cost: snapshot.supplyUpgradeCost,
        enabled: snapshot.canUpgradeSupply,
        lockText: l10n.maxLevelReached,
        onPressed: game.upgradeSupplyProgression,
      ),
      if (stageTwoCleared)
        _PermanentUpgradeTile(
          icon: Icons.monetization_on_outlined,
          title: l10n.killRewardBonus,
          description: l10n.permanentUpgradeDescription(l10n.killRewardBonus),
          level: snapshot.killGoldUpgradeLevel,
          maxLevel: RunProgression.maxKillGoldUpgradeLevel,
          globalMaxLevel: RunProgression.maxKillGoldUpgradeLevel,
          valueText:
              '+${(snapshot.killGoldProgressionBonusRate * 100).round()}%',
          nextValueText:
              '+${(nextKillGoldLevel * RunProgression.killGoldBonusPerUpgradeLevel * 100).round()}%',
          cost: snapshot.killGoldUpgradeCost,
          enabled: snapshot.canUpgradeKillGold,
          lockText: l10n.maxLevelReached,
          onPressed: game.upgradeKillGoldProgression,
        ),
      if (stageTwoCleared)
        _PermanentUpgradeTile(
          icon: Icons.sell_outlined,
          title: l10n.emergencySale,
          description: l10n.permanentUpgradeDescription(l10n.emergencySale),
          level: snapshot.emergencySaleUpgradeLevel,
          maxLevel: RunProgression.maxEmergencySaleUpgradeLevel,
          globalMaxLevel: RunProgression.maxEmergencySaleUpgradeLevel,
          valueText: '${snapshot.turretRefundPercent}%',
          nextValueText:
              '${RunProgression.baseTurretRefundPercent + nextEmergencySaleLevel * RunProgression.emergencySaleRefundPercentPerLevel}%',
          cost: snapshot.emergencySaleUpgradeCost,
          enabled: snapshot.canUpgradeEmergencySale,
          lockText: l10n.maxLevelReached,
          onPressed: game.upgradeEmergencySaleProgression,
        ),
    ];
    return _PermanentUpgradeBoard(
      tiles: group == _PermanentUpgradeGroup.combat
          ? combatTiles
          : economyTiles,
    );
  }
}

class _ResearchMenu extends StatefulWidget {
  const _ResearchMenu({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  State<_ResearchMenu> createState() => _ResearchMenuState();
}

class _ResearchMenuState extends State<_ResearchMenu> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final activeResearches = widget.snapshot.activeResearches;
    final completedTypes =
        ResearchType.values
            .where(
              (type) =>
                  _researchLevel(widget.snapshot, type) >=
                  demoResearchDefinitions[type]!.maxLevel,
            )
            .toList()
          ..sort(_compareResearchRequirement);
    final availableTypes =
        ResearchType.values
            .where((type) => !completedTypes.contains(type))
            .toList()
          ..sort(_compareResearchRequirement);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.science_outlined,
              color: Color(0xFF8EE6FF),
              size: 19,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.researchBoard,
              style: const TextStyle(
                color: Color(0xFFE8FBFF),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ResearchSlotPanel(
          slots: widget.snapshot.researchSlotCount,
          activeResearches: activeResearches,
          nowMillis: nowMillis,
          game: widget.game,
        ),
        const SizedBox(height: 10),
        _ResearchSection(
          icon: Icons.science_outlined,
          title: l10n.availableResearch,
          children: [
            _ResearchCardGrid(
              types: availableTypes,
              game: widget.game,
              snapshot: widget.snapshot,
              nowMillis: nowMillis,
              onSelectType: _openResearchDetails,
            ),
          ],
        ),
        if (completedTypes.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ResearchSection(
            icon: Icons.done_all,
            title: l10n.completedResearch,
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
      ],
    );
  }

  void _openResearchDetails(ResearchType type) {
    showDialog<void>(
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
  final leftStage = demoResearchDefinitions[left]!.requiredClearedStage;
  final rightStage = demoResearchDefinitions[right]!.requiredClearedStage;
  final stageOrder = leftStage.compareTo(rightStage);
  if (stageOrder != 0) {
    return stageOrder;
  }
  return left.index.compareTo(right.index);
}

class _ResearchSlotPanel extends StatelessWidget {
  const _ResearchSlotPanel({
    required this.slots,
    required this.activeResearches,
    required this.nowMillis,
    required this.game,
  });

  final int slots;
  final List<ResearchProgress> activeResearches;
  final int nowMillis;
  final RuneNexusGame game;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ResearchSection(
      icon: Icons.view_module_outlined,
      title: l10n.researchSlot,
      children: [
        for (var index = 0; index < slots; index++) ...[
          if (index > 0) const SizedBox(height: 7),
          _ResearchSlotCard(
            research: index < activeResearches.length
                ? activeResearches[index]
                : null,
            nowMillis: nowMillis,
            game: game,
          ),
        ],
      ],
    );
  }
}

class _ResearchSlotCard extends StatelessWidget {
  const _ResearchSlotCard({
    required this.research,
    required this.nowMillis,
    required this.game,
  });

  final ResearchProgress? research;
  final int nowMillis;
  final RuneNexusGame game;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = research;
    final progress = active == null || active.durationMillis <= 0
        ? 0.0
        : active.progressRatioAt(nowMillis);
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
            child: Row(
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
                  child: Text(
                    active == null
                        ? l10n.emptyResearchSlot
                        : '${_researchTitle(l10n, active.type)} ${l10n.researchLevel(active.targetLevel - 1, demoResearchDefinitions[active.type]!.maxLevel)}',
                    style: const TextStyle(
                      color: Color(0xFFE8FBFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (active != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PermanentUpgradeStatusChip(
                        text: l10n.researchRemaining(
                          active.remainingMillisAt(nowMillis),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: l10n.cancel,
                        child: InkResponse(
                          onTap: () => _confirmCancelResearch(
                            context,
                            game: game,
                            research: active,
                          ),
                          radius: 15,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmCancelResearch(
  BuildContext context, {
  required RuneNexusGame game,
  required ResearchProgress research,
}) async {
  final l10n = context.l10n;
  final title = _researchTitle(l10n, research.type);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF0B1725),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xAA33D8FF)),
      ),
      title: Text(
        l10n.cancelResearchTitle,
        style: const TextStyle(
          color: Color(0xFFE8FBFF),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Text(
        l10n.cancelResearchMessage(title),
        style: const TextStyle(
          color: Color(0xFFB9D6E4),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.cancelResearchConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return;
  }
  game.cancelResearch(research.type);
}

class _ResearchSection extends StatelessWidget {
  const _ResearchSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x3307111D),
        border: Border.all(color: const Color(0x55485B68)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFB9D6E4), size: 17),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFE8FBFF),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _ResearchCardGrid extends StatelessWidget {
  const _ResearchCardGrid({
    required this.types,
    required this.game,
    required this.snapshot,
    required this.nowMillis,
    required this.onSelectType,
  });

  final List<ResearchType> types;
  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final int nowMillis;
  final ValueChanged<ResearchType> onSelectType;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 220;
        final tileWidth = useTwoColumns
            ? (constraints.maxWidth - 8) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in types)
              SizedBox(
                width: tileWidth,
                child: _ResearchTile(
                  game: game,
                  snapshot: snapshot,
                  type: type,
                  nowMillis: nowMillis,
                  onPressed: () => onSelectType(type),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ResearchTile extends StatelessWidget {
  const _ResearchTile({
    required this.game,
    required this.snapshot,
    required this.type,
    required this.nowMillis,
    required this.onPressed,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final ResearchType type;
  final int nowMillis;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final definition = demoResearchDefinitions[type]!;
    final level = _researchLevel(snapshot, type);
    final active = _activeResearch(snapshot, type);
    final complete = level >= definition.maxLevel;
    final unlocked = _researchUnlocked(snapshot, definition);
    final slotAvailable =
        active != null ||
        snapshot.activeResearches.length < snapshot.researchSlotCount;
    final cost = _researchCost(snapshot, type);
    final duration = _researchDuration(snapshot, type);
    final canStart =
        active == null &&
        !complete &&
        unlocked &&
        slotAvailable &&
        snapshot.runes >= cost;
    final statusText = active != null
        ? null
        : complete
        ? l10n.researchComplete
        : !unlocked
        ? l10n.lockedResearch
        : !slotAvailable
        ? null
        : snapshot.runes < cost
        ? l10n.notEnoughRunes
        : l10n.researchAvailable;
    final borderColor = canStart
        ? const Color(0xFFE7C66A)
        : active != null
        ? const Color(0xAA8EE6FF)
        : complete
        ? const Color(0x6657C88B)
        : const Color(0x55485B68);
    final titleColor = complete
        ? const Color(0xFFBDEFCF)
        : canStart
        ? const Color(0xFFE8FBFF)
        : const Color(0xFFB9D6E4);
    final clickable = active == null && unlocked;
    final showStatusChip =
        statusText != null &&
        (complete || (!canStart && unlocked && slotAvailable));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: clickable ? onPressed : null,
        borderRadius: BorderRadius.circular(7),
        splashColor: const Color(0x1A8EE6FF),
        highlightColor: const Color(0x1422C7E8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 106),
          decoration: BoxDecoration(
            color: clickable
                ? const Color(0x3307111D)
                : const Color(0x22000000),
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(7),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (active != null) ...[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x2633D8FF),
                          Color(0x10000000),
                          Color(0x22E7C66A),
                        ],
                      ),
                    ),
                  ),
                ),
                const _ResearchActiveEffect(),
              ],
              Padding(
                padding: const EdgeInsets.all(9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _researchIcon(type),
                          color: active == null
                              ? const Color(0xFF8EE6FF)
                              : const Color(0xFFE7C66A),
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _researchTitle(l10n, type),
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 5),
                        if (!unlocked)
                          const Icon(
                            Icons.lock_outline,
                            color: Color(0xFF607587),
                            size: 14,
                          )
                        else if (clickable)
                          const Icon(
                            Icons.open_in_new,
                            color: Color(0xFF8DA5B3),
                            size: 13,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ResearchEffectLine(
                      effect: _researchEffectText(
                        l10n,
                        type,
                        level,
                        active?.targetLevel,
                      ),
                      enabled:
                          unlocked && (canStart || complete || active != null),
                    ),
                    const SizedBox(height: 8),
                    _ResearchMetaStrip(
                      levelText: l10n.researchLevel(level, definition.maxLevel),
                      cost: complete ? null : cost,
                      durationText: complete
                          ? null
                          : l10n.researchDuration(duration),
                      enabled: canStart || active != null,
                    ),
                    if (showStatusChip) ...[
                      const SizedBox(height: 6),
                      _PermanentUpgradeStatusChip(text: statusText),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResearchEffectLine extends StatelessWidget {
  const _ResearchEffectLine({required this.effect, required this.enabled});

  final _ResearchEffectText effect;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final currentColor = enabled
        ? const Color(0xFF8EE6FF)
        : const Color(0xFF8DA5B3);
    final nextColor = enabled
        ? const Color(0xFFE7C66A)
        : const Color(0xFF8DA5B3);
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        children: [
          TextSpan(
            text: effect.currentText,
            style: TextStyle(color: currentColor),
          ),
          if (effect.nextText != null) ...[
            const TextSpan(
              text: ' -> ',
              style: TextStyle(color: Color(0xFF8DA5B3)),
            ),
            TextSpan(
              text: effect.nextText,
              style: TextStyle(color: nextColor),
            ),
          ],
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ResearchActiveEffect extends StatefulWidget {
  const _ResearchActiveEffect();

  @override
  State<_ResearchActiveEffect> createState() => _ResearchActiveEffectState();
}

class _ResearchActiveEffectState extends State<_ResearchActiveEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ResearchActiveBorderPainter(_controller.value),
            );
          },
        ),
      ),
    );
  }
}

class _ResearchActiveBorderPainter extends CustomPainter {
  const _ResearchActiveBorderPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(7);
    final borderPath = Path()
      ..addRRect(RRect.fromRectAndRadius(rect.deflate(1.1), radius));
    final glowPaint = Paint()
      ..color = const Color(0x44E7C66A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final highlightPaint = Paint()
      ..color = const Color(0xFFE7C66A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(borderPath, glowPaint);
    for (final metric in borderPath.computeMetrics()) {
      final length = metric.length;
      final segmentLength = length * 0.22;
      final start = length * progress;
      _drawMetricSegment(canvas, metric, start, segmentLength, highlightPaint);
      _drawMetricSegment(
        canvas,
        metric,
        (start + length * 0.5) % length,
        segmentLength * 0.55,
        glowPaint,
      );
    }
  }

  void _drawMetricSegment(
    Canvas canvas,
    ui.PathMetric metric,
    double start,
    double length,
    Paint paint,
  ) {
    final end = start + length;
    if (end <= metric.length) {
      canvas.drawPath(metric.extractPath(start, end), paint);
      return;
    }
    canvas
      ..drawPath(metric.extractPath(start, metric.length), paint)
      ..drawPath(metric.extractPath(0, end - metric.length), paint);
  }

  @override
  bool shouldRepaint(_ResearchActiveBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ResearchEffectText {
  const _ResearchEffectText(this.currentText, [this.nextText]);

  final String currentText;
  final String? nextText;
}

class _ResearchMetaStrip extends StatelessWidget {
  const _ResearchMetaStrip({
    required this.levelText,
    required this.cost,
    required this.durationText,
    required this.enabled,
  });

  final String levelText;
  final int? cost;
  final String? durationText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? const Color(0xFFE7C66A)
        : const Color(0xFF8DA5B3);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        border: Border.all(color: const Color(0x33485B68)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              levelText,
              style: const TextStyle(
                color: Color(0xFFB9D6E4),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (cost != null) ...[
            _ResearchMetaDivider(),
            Icon(Icons.diamond_outlined, size: 12, color: foreground),
            const SizedBox(width: 2),
            Text(
              '$cost',
              style: TextStyle(
                color: foreground,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (durationText != null) ...[
            _ResearchMetaDivider(),
            Flexible(
              child: Text(
                durationText!,
                style: const TextStyle(
                  color: Color(0xFFB9D6E4),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResearchMetaDivider extends StatelessWidget {
  const _ResearchMetaDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: const Color(0x33485B68),
    );
  }
}

class _ResearchDetailDialog extends StatelessWidget {
  const _ResearchDetailDialog({
    required this.game,
    required this.snapshot,
    required this.type,
    required this.nowMillis,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final ResearchType type;
  final int nowMillis;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final definition = demoResearchDefinitions[type]!;
    final level = _researchLevel(snapshot, type);
    final active = _activeResearch(snapshot, type);
    final complete = level >= definition.maxLevel;
    final unlocked = _researchUnlocked(snapshot, definition);
    final slotAvailable =
        active != null ||
        snapshot.activeResearches.length < snapshot.researchSlotCount;
    final cost = _researchCost(snapshot, type);
    final duration = _researchDuration(snapshot, type);
    final canStart =
        active == null &&
        !complete &&
        unlocked &&
        slotAvailable &&
        snapshot.runes >= cost;
    final statusText = active != null
        ? null
        : complete
        ? l10n.researchComplete
        : !unlocked
        ? l10n.lockedResearch
        : !slotAvailable
        ? null
        : snapshot.runes < cost
        ? l10n.notEnoughRunes
        : l10n.researchAvailable;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1725),
          border: Border.all(color: const Color(0xAA33D8FF)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: const BoxDecoration(
                color: Color(0x2A33D8FF),
                border: Border(bottom: BorderSide(color: Color(0x5533D8FF))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x2233D8FF),
                      border: Border.all(color: const Color(0x7733D8FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _researchIcon(type),
                      color: const Color(0xFF8EE6FF),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _researchTitle(l10n, type),
                      style: const TextStyle(
                        color: Color(0xFFE8FBFF),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    color: const Color(0xFFE8FBFF),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0x33000000),
                      border: Border.all(color: const Color(0x33485B68)),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      l10n.researchDescription(_researchTitle(l10n, type)),
                      style: const TextStyle(
                        color: Color(0xFFE0F4FF),
                        fontSize: 12,
                        height: 1.28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = (constraints.maxWidth - 8) / 2;
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _ResearchDialogMetric(
                              icon: Icons.auto_graph,
                              label: l10n.researchLevelLabel,
                              value: l10n.researchLevel(
                                level,
                                definition.maxLevel,
                              ),
                              accent: const Color(0xFF8EE6FF),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _ResearchDialogMetric(
                              icon: Icons.flag_outlined,
                              label: l10n.researchRequirementLabel,
                              value: l10n.stageClearRequirement(
                                definition.requiredClearedStage,
                              ),
                              accent: unlocked
                                  ? const Color(0xFF8EE6FF)
                                  : const Color(0xFF8DA5B3),
                            ),
                          ),
                          if (!complete)
                            SizedBox(
                              width: itemWidth,
                              child: _ResearchDialogMetric(
                                icon: Icons.diamond_outlined,
                                label: l10n.researchCostLabel,
                                value: '$cost',
                                accent: canStart
                                    ? const Color(0xFFE7C66A)
                                    : const Color(0xFF8DA5B3),
                              ),
                            ),
                          if (!complete)
                            SizedBox(
                              width: itemWidth,
                              child: _ResearchDialogMetric(
                                icon: Icons.schedule,
                                label: l10n.researchTimeLabel,
                                value: l10n.researchDuration(duration),
                                accent: const Color(0xFFB9D6E4),
                              ),
                            ),
                          if (statusText != null)
                            SizedBox(
                              width: constraints.maxWidth,
                              child: _ResearchDialogMetric(
                                icon: active == null
                                    ? Icons.info_outline
                                    : Icons.hourglass_bottom,
                                label: l10n.researchStatusLabel,
                                value: statusText,
                                accent: canStart
                                    ? const Color(0xFFE7C66A)
                                    : const Color(0xFFB9D6E4),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (!complete) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 34,
                      child: FilledButton(
                        onPressed: canStart
                            ? () {
                                game.startResearch(type);
                                Navigator.of(context).pop();
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF8EE6FF),
                          disabledBackgroundColor: const Color(0x33485B68),
                          foregroundColor: const Color(0xFF07111D),
                          disabledForegroundColor: const Color(0xFF607587),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        child: Text(
                          l10n.startResearch,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResearchDialogMetric extends StatelessWidget {
  const _ResearchDialogMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x221B2C3D),
        border: Border.all(color: const Color(0x44485B68)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8DA5B3),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFE8FBFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

int _researchLevel(GameSnapshot snapshot, ResearchType type) {
  return snapshot.researchLevels[type] ?? 0;
}

bool _researchUnlocked(GameSnapshot snapshot, ResearchDefinition definition) {
  return definition.requiredClearedStage <= 0 ||
      snapshot.clearedStageNumbers.contains(definition.requiredClearedStage);
}

int _researchCost(GameSnapshot snapshot, ResearchType type) {
  final definition = demoResearchDefinitions[type]!;
  final baseCost = definition.costForCurrentLevel(
    _researchLevel(snapshot, type),
  );
  final efficiencyRate =
      _researchLevel(snapshot, ResearchType.researchCostEfficiency) *
      RunProgression.researchCostEfficiencyPerLevel;
  return RunProgression.applyResearchCostEfficiency(baseCost, efficiencyRate);
}

int _researchDuration(GameSnapshot snapshot, ResearchType type) {
  final definition = demoResearchDefinitions[type]!;
  final baseDuration = definition.durationForCurrentLevel(
    _researchLevel(snapshot, type),
  );
  final efficiencyRate =
      _researchLevel(snapshot, ResearchType.researchEfficiency) *
      RunProgression.researchEfficiencyPerLevel;
  final duration = RunProgression.applyResearchEfficiency(
    baseDuration,
    efficiencyRate,
  );
  final elapsed = _researchSavedElapsed(
    snapshot,
    type,
  ).clamp(0, duration <= 0 ? 0 : duration - 1).toInt();
  return duration - elapsed;
}

int _researchSavedElapsed(GameSnapshot snapshot, ResearchType type) {
  return snapshot.researchElapsedMillis[type] ?? 0;
}

ResearchProgress? _activeResearch(GameSnapshot snapshot, ResearchType type) {
  for (final research in snapshot.activeResearches) {
    if (research.type == type) {
      return research;
    }
  }
  return null;
}

String _researchTitle(RuneNexusLocalizations l10n, ResearchType type) {
  return switch (type) {
    ResearchType.researchEfficiency => l10n.researchEfficiency,
    ResearchType.researchCostEfficiency => l10n.researchCostEfficiency,
    ResearchType.linkExpansionOne => l10n.linkExpansionOne,
    ResearchType.gemAttunement => l10n.gemAttunement,
  };
}

_ResearchEffectText _researchEffectText(
  RuneNexusLocalizations l10n,
  ResearchType type,
  int level,
  int? activeTargetLevel,
) {
  final definition = demoResearchDefinitions[type]!;
  final nextLevel = activeTargetLevel ?? (level + 1);
  final clampedNextLevel = nextLevel.clamp(0, definition.maxLevel).toInt();
  final hasNext = clampedNextLevel > level;
  return switch (type) {
    ResearchType.researchEfficiency => _ResearchEffectText(
      l10n.researchEfficiencyEffect(_researchEfficiencyPercent(level)),
      hasNext
          ? _signedPercent(_researchEfficiencyPercent(clampedNextLevel))
          : null,
    ),
    ResearchType.researchCostEfficiency => _ResearchEffectText(
      l10n.researchCostEfficiencyEffect(_researchCostEfficiencyPercent(level)),
      hasNext
          ? _signedPercent(_researchCostEfficiencyPercent(clampedNextLevel))
          : null,
    ),
    ResearchType.linkExpansionOne => _ResearchEffectText(
      l10n.researchLinkSlotEffect,
    ),
    ResearchType.gemAttunement => _ResearchEffectText(
      l10n.researchGemShardEffect(
        level * RunProgression.gemShardsPerGemAttunementLevel,
      ),
      hasNext
          ? '+${clampedNextLevel * RunProgression.gemShardsPerGemAttunementLevel}'
          : null,
    ),
  };
}

int _researchEfficiencyPercent(int level) {
  return (level * RunProgression.researchEfficiencyPerLevel * 100).round();
}

int _researchCostEfficiencyPercent(int level) {
  return (level * RunProgression.researchCostEfficiencyPerLevel * 100).round();
}

String _signedPercent(int percent) {
  return '+$percent%';
}

IconData _researchIcon(ResearchType type) {
  return switch (type) {
    ResearchType.researchEfficiency => Icons.speed_outlined,
    ResearchType.researchCostEfficiency => Icons.savings_outlined,
    ResearchType.linkExpansionOne => Icons.hub_outlined,
    ResearchType.gemAttunement => Icons.auto_awesome_outlined,
  };
}

class _PermanentUpgradeBoard extends StatelessWidget {
  const _PermanentUpgradeBoard({required this.tiles});

  final List<_PermanentUpgradeTile> tiles;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.grid_view_rounded,
              color: Color(0xFF8EE6FF),
              size: 19,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.upgradeBoard,
              style: const TextStyle(
                color: Color(0xFFE8FBFF),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final useTwoColumns = constraints.maxWidth >= 320;
            final tileWidth = useTwoColumns
                ? (constraints.maxWidth - 8) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tile in tiles)
                  SizedBox(width: tileWidth, child: tile),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PermanentUpgradeTile extends StatelessWidget {
  const _PermanentUpgradeTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.level,
    required this.maxLevel,
    required this.globalMaxLevel,
    required this.valueText,
    required this.nextValueText,
    required this.cost,
    required this.enabled,
    required this.lockText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final int level;
  final int maxLevel;
  final int globalMaxLevel;
  final String valueText;
  final String nextValueText;
  final int cost;
  final bool enabled;
  final String lockText;
  final VoidCallback onPressed;

  bool get _isMaxed => level >= globalMaxLevel;
  bool get _isTierLocked => level >= maxLevel && level < globalMaxLevel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final borderColor = enabled
        ? const Color(0xFFE7C66A)
        : const Color(0x55485B68);
    final titleColor = enabled
        ? const Color(0xFFE8FBFF)
        : const Color(0xFFB9D6E4);
    return Container(
      constraints: const BoxConstraints(minHeight: 154),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0x3307111D),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: titleColor, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Lv.$level/$maxLevel',
            style: const TextStyle(
              color: Color(0xFFB9D6E4),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF9EB3BF), fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CompactUpgradeValueSummary(
                currentValueText: valueText,
                nextValueText: nextValueText,
                enabled: enabled,
              ),
              const SizedBox(height: 7),
              SizedBox(
                height: 30,
                child: OutlinedButton(
                  onPressed: enabled ? onPressed : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFF6D7F8F),
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: _buttonChild(l10n),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buttonChild(RuneNexusLocalizations l10n) {
    if (_isMaxed) {
      return Text(
        l10n.maxLevelReached,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        overflow: TextOverflow.ellipsis,
      );
    }
    if (_isTierLocked) {
      return Text(
        lockText,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        overflow: TextOverflow.ellipsis,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.levelUp,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 5),
        _RuneCostChip(cost: cost, enabled: enabled),
      ],
    );
  }
}

class _PermanentUpgradeStatusChip extends StatelessWidget {
  const _PermanentUpgradeStatusChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x55485B68)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF8DA5B3),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactUpgradeValueSummary extends StatelessWidget {
  const _CompactUpgradeValueSummary({
    required this.currentValueText,
    required this.nextValueText,
    required this.enabled,
  });

  final String currentValueText;
  final String nextValueText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '현재 $currentValueText',
            style: const TextStyle(
              color: Color(0xFFE8FBFF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '다음 $nextValueText',
          style: TextStyle(
            color: enabled ? const Color(0xFFE7C66A) : const Color(0xFF6D7F8F),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _RuneCostChip extends StatelessWidget {
  const _RuneCostChip({required this.cost, required this.enabled});

  final int cost;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? const Color(0xFFE7C66A)
        : const Color(0xFF6D7F8F);
    return Container(
      height: 23,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: enabled ? const Color(0x1AE7C66A) : const Color(0x14485B68),
        border: Border.all(
          color: enabled ? const Color(0x88E7C66A) : const Color(0x33485B68),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.diamond_outlined, size: 13, color: foreground),
          const SizedBox(width: 3),
          Text(
            '$cost',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
