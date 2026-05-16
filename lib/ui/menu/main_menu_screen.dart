import 'package:flutter/material.dart';

import '../../domain/combat/game_phase.dart';
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

  @override
  Widget build(BuildContext context) {
    final selectedTab = widget.selectedTab;
    final menuTopPadding = selectedTab == MainMenuTab.stage ? 16.0 : 58.0;
    final menuBottomPadding = selectedTab == MainMenuTab.permanentUpgrades
        ? 146.0
        : 92.0;
    return Container(
      color: const Color(0xFF07111D),
      child: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _MainMenuBackdrop()),
            Positioned(
              top: 10,
              right: 16,
              child: RuneBalanceCard(runes: widget.snapshot.runes),
            ),
            if (_showMapEditor)
              Positioned(
                top: 10,
                left: 16,
                child: _MapEditorShortcut(onPressed: widget.onOpenMapEditor),
              ),
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
                  child: Container(
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (selectedTab == MainMenuTab.stage) ...[
                          const _MenuHeader(),
                          const SizedBox(height: 14),
                          _StageMenu(
                            snapshot: widget.snapshot,
                            onStartStage: widget.onStartStage,
                          ),
                        ] else if (selectedTab == MainMenuTab.permanentUpgrades)
                          _PermanentUpgradeMenu(
                            game: widget.game,
                            snapshot: widget.snapshot,
                            group: _selectedUpgradeGroup,
                          )
                        else
                          _ResearchMenu(snapshot: widget.snapshot),
                      ],
                    ),
                  ),
                ),
              ),
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

class _MenuHeader extends StatelessWidget {
  const _MenuHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
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
        Expanded(
          child: Text(
            l10n.appTitle,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
    final stageCount = snapshot.unlockedStageCount.clamp(1, 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activeRunInProgress) ...[
          _ActiveRunSummary(
            snapshot: snapshot,
            onPressed: () => onStartStage(snapshot.currentStageNumber),
          ),
          const SizedBox(height: 10),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 380;
            final singleColumn = constraints.maxWidth < 300;
            final columnCount = singleColumn ? 1 : 2;
            final aspectRatio = singleColumn
                ? 2.7
                : narrow
                ? 1.45
                : 2.05;

            return GridView.count(
              crossAxisCount: columnCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: aspectRatio,
              children: [
                for (var stage = 1; stage <= 5; stage++)
                  _StageSelectionCard(
                    stageNumber: stage,
                    unlocked: stage <= stageCount,
                    active:
                        activeRunInProgress &&
                        stage == snapshot.currentStageNumber,
                    sniperRewardUnlocked: snapshot.availableTurretTypes
                        .contains(TurretType.sniper),
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
                      activeRunInProgress: activeRunInProgress,
                    ),
                    onPressed: stage <= stageCount
                        ? () => onStartStage(stage)
                        : null,
                  ),
              ],
            );
          },
        ),
      ],
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
  required bool activeRunInProgress,
}) {
  if (stageNumber > snapshot.unlockedStageCount) {
    return l10n.stageUnlockRequirement(stageNumber - 1);
  }
  if (activeRunInProgress && stageNumber == snapshot.currentStageNumber) {
    return l10n.stageProgressDetail(
      round: snapshot.round,
      maxRound: snapshot.maxRound,
      turretCount: snapshot.placedTurretCount,
      gold: snapshot.gold,
    );
  }
  return _recordTextForStage(l10n, snapshot, stageNumber);
}

String _recordTextForStage(
  RuneNexusLocalizations l10n,
  GameSnapshot snapshot,
  int stageNumber,
) {
  if (snapshot.clearedStageNumbers.contains(stageNumber)) {
    return l10n.recordCleared;
  }
  final bestRound = snapshot.bestRoundsByStage[stageNumber] ?? 0;
  if (bestRound > 0) {
    return l10n.stageBestRound(bestRound);
  }
  return l10n.recordNone;
}

class _StageSelectionCard extends StatelessWidget {
  const _StageSelectionCard({
    required this.stageNumber,
    required this.unlocked,
    required this.active,
    required this.sniperRewardUnlocked,
    required this.statusText,
    required this.detailText,
    required this.onPressed,
  });

  final int stageNumber;
  final bool unlocked;
  final bool active;
  final bool sniperRewardUnlocked;
  final String statusText;
  final String detailText;
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
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _StageIcon(unlocked: unlocked, active: active),
                const SizedBox(width: 8),
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
              ],
            ),
            const SizedBox(height: 5),
            Text(
              statusText,
              style: TextStyle(fontSize: 11, color: statusColor),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            if (stageNumber == 1)
              _StageSniperRewardPreview(
                unlocked: unlocked,
                rewardUnlocked: sniperRewardUnlocked,
              )
            else
              Text(
                detailText,
                style: TextStyle(
                  fontSize: 10,
                  color: unlocked
                      ? const Color(0xFFB9D6E4)
                      : const Color(0xFF667987),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _StageSniperRewardPreview extends StatelessWidget {
  const _StageSniperRewardPreview({
    required this.unlocked,
    required this.rewardUnlocked,
  });

  final bool unlocked;
  final bool rewardUnlocked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = rewardUnlocked
        ? const Color(0xFFE7C66A)
        : unlocked
        ? const Color(0xFFB9D6E4)
        : const Color(0xFF667987);

    return Row(
      children: [
        Opacity(opacity: unlocked ? 1 : 0.58, child: const _SniperRewardIcon()),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            rewardUnlocked
                ? l10n.stageSniperRewardUnlocked
                : l10n.stageSniperRewardLocked,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: rewardUnlocked ? FontWeight.w800 : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
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
    final nextFireTrainingLevel = (snapshot.fireTrainingUpgradeLevel + 1)
        .clamp(0, RunProgression.maxFireTrainingUpgradeLevel)
        .toInt();
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
    ];
    return _PermanentUpgradeBoard(
      tiles: group == _PermanentUpgradeGroup.combat
          ? combatTiles
          : economyTiles,
    );
  }
}

class _ResearchMenu extends StatelessWidget {
  const _ResearchMenu({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
        _ResearchTrack(
          icon: Icons.account_tree_outlined,
          title: l10n.systemResearch,
          tiles: [
            _ResearchTile(
              icon: Icons.hub_outlined,
              title: l10n.linkExpansionOne,
              description: l10n.researchDescription(l10n.linkExpansionOne),
              statusText: snapshot.unlockedStageCount >= 2
                  ? l10n.researchPending
                  : l10n.stageReachRequirement(2),
            ),
            _ResearchTile(
              icon: Icons.hub,
              title: l10n.linkExpansionTwo,
              description: l10n.researchDescription(l10n.linkExpansionTwo),
              statusText: snapshot.unlockedStageCount >= 3
                  ? l10n.researchPending
                  : l10n.stageReachRequirement(3),
            ),
            _ResearchTile(
              icon: Icons.auto_awesome_outlined,
              title: l10n.gemAttunement,
              description: l10n.researchDescription(l10n.gemAttunement),
              statusText: snapshot.unlockedStageCount >= 3
                  ? l10n.researchPending
                  : l10n.stageReachRequirement(3),
            ),
            _ResearchTile(
              icon: Icons.toll_outlined,
              title: l10n.runeResonance,
              description: l10n.researchDescription(l10n.runeResonance),
              statusText: snapshot.unlockedStageCount >= 4
                  ? l10n.researchPending
                  : l10n.stageReachRequirement(4),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ResearchTrack(
          icon: Icons.precision_manufacturing_outlined,
          title: l10n.towerResearch,
          tiles: [
            _ResearchTile(
              icon: Icons.shield_outlined,
              title: l10n.towerResearch,
              description: l10n.researchDescription(l10n.towerResearch),
              statusText: l10n.designLocked,
            ),
          ],
        ),
      ],
    );
  }
}

class _ResearchTrack extends StatelessWidget {
  const _ResearchTrack({
    required this.icon,
    required this.title,
    required this.tiles,
  });

  final IconData icon;
  final String title;
  final List<_ResearchTile> tiles;

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
          for (var index = 0; index < tiles.length; index++) ...[
            if (index > 0) const SizedBox(height: 7),
            tiles[index],
          ],
        ],
      ),
    );
  }
}

class _ResearchTile extends StatelessWidget {
  const _ResearchTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.statusText,
  });

  final IconData icon;
  final String title;
  final String description;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        border: Border.all(color: const Color(0x33485B68)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF8EE6FF), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFFE8FBFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _PermanentUpgradeStatusChip(text: statusText),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF9EB3BF),
                    fontSize: 10,
                  ),
                  maxLines: 2,
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

  const _PermanentUpgradeTile.locked({
    required this.icon,
    required this.title,
    required this.description,
    required this.lockText,
  }) : level = null,
       maxLevel = null,
       globalMaxLevel = null,
       valueText = null,
       nextValueText = null,
       cost = null,
       enabled = false,
       onPressed = null;

  final IconData icon;
  final String title;
  final String description;
  final int? level;
  final int? maxLevel;
  final int? globalMaxLevel;
  final String? valueText;
  final String? nextValueText;
  final int? cost;
  final bool enabled;
  final String lockText;
  final VoidCallback? onPressed;

  bool get _isActive => level != null && maxLevel != null;
  bool get _isMaxed =>
      level != null && globalMaxLevel != null && level! >= globalMaxLevel!;
  bool get _isTierLocked =>
      level != null &&
      maxLevel != null &&
      globalMaxLevel != null &&
      level! >= maxLevel! &&
      level! < globalMaxLevel!;

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
          if (_isActive)
            Text(
              'Lv.$level/$maxLevel',
              style: const TextStyle(
                color: Color(0xFFB9D6E4),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            _PermanentUpgradeStatusChip(text: _lockedStatusText(l10n)),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF9EB3BF), fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 7),
          if (_isActive &&
              valueText != null &&
              nextValueText != null &&
              cost != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CompactUpgradeValueSummary(
                  currentValueText: valueText!,
                  nextValueText: nextValueText!,
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
        _RuneCostChip(cost: cost!, enabled: enabled),
      ],
    );
  }

  String _lockedStatusText(RuneNexusLocalizations l10n) {
    return lockText == l10n.plannedUpgrade || lockText == l10n.designLocked
        ? lockText
        : lockText;
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
