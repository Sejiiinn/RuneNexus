import 'package:flutter/material.dart';

import '../../domain/combat/game_phase.dart';
import '../../game/game_snapshot.dart';
import '../../game/rune_nexus_game.dart';
import '../../l10n/rune_nexus_localizations.dart';
import '../widgets/rune_balance_card.dart';

enum MainMenuTab { stage, permanentUpgrades }

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({
    required this.game,
    required this.snapshot,
    required this.selectedTab,
    required this.onSelectTab,
    required this.onStartStage,
    super.key,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final MainMenuTab selectedTab;
  final ValueChanged<MainMenuTab> onSelectTab;
  final ValueChanged<int> onStartStage;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF07111D),
      child: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _MainMenuBackdrop()),
            Positioned(
              top: 10,
              right: 16,
              child: RuneBalanceCard(runes: snapshot.runes),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
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
                        const _MenuHeader(),
                        const SizedBox(height: 14),
                        _MenuTabs(
                          selectedTab: selectedTab,
                          onSelectTab: onSelectTab,
                        ),
                        const SizedBox(height: 14),
                        if (selectedTab == MainMenuTab.stage)
                          _StageMenu(
                            snapshot: snapshot,
                            onStartStage: onStartStage,
                          )
                        else
                          _PermanentUpgradeMenu(game: game, snapshot: snapshot),
                      ],
                    ),
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
    return Row(
      children: [
        Expanded(
          child: _TabButton(
            icon: Icons.flag_outlined,
            label: l10n.stageTab,
            selected: selectedTab == MainMenuTab.stage,
            onPressed: () => onSelectTab(MainMenuTab.stage),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TabButton(
            icon: Icons.auto_awesome,
            label: l10n.permanentUpgradeTab,
            selected: selectedTab == MainMenuTab.permanentUpgrades,
            onPressed: () => onSelectTab(MainMenuTab.permanentUpgrades),
          ),
        ),
      ],
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
    return SizedBox(
      height: 38,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? const Color(0xFF07111D) : Colors.white,
          backgroundColor: selected ? const Color(0xFF8EE6FF) : null,
          side: BorderSide(
            color: selected ? const Color(0xFF8EE6FF) : const Color(0x5533D8FF),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageCard(
          stageNumber: snapshot.currentStageNumber,
          snapshot: snapshot,
          onPressed: () => onStartStage(snapshot.currentStageNumber),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.35,
          children: [
            for (var stage = 1; stage <= 5; stage++)
              if (stage != snapshot.currentStageNumber)
                if (stage <= snapshot.unlockedStageCount)
                  _UnlockedStageCard(
                    stageNumber: stage,
                    statusText: activeRunInProgress
                        ? l10n.startAfterSettling
                        : _recordTextForStage(l10n, snapshot, stage),
                    onPressed: () => onStartStage(stage),
                  )
                else
                  _LockedStageCard(stageNumber: stage),
          ],
        ),
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.stageNumber,
    required this.snapshot,
    required this.onPressed,
  });

  final int stageNumber;
  final GameSnapshot snapshot;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final phaseText = switch (snapshot.phase) {
      GamePhase.success => l10n.cleared,
      GamePhase.failure => l10n.settled,
      GamePhase.wave => l10n.combatInProgress,
      GamePhase.reward => l10n.rewardPending,
      GamePhase.restored => l10n.savedCombat,
      GamePhase.preparation =>
        snapshot.hasStageProgress ? l10n.inProgress : l10n.newRun,
    };
    final actionText = switch (snapshot.phase) {
      GamePhase.success || GamePhase.failure => l10n.restartRun,
      GamePhase.wave ||
      GamePhase.reward ||
      GamePhase.restored => l10n.continueRun,
      _ => snapshot.hasStageProgress ? l10n.continueRun : l10n.startStage,
    };
    final detailText = snapshot.hasStageProgress
        ? l10n.stageProgressDetail(
            round: snapshot.round,
            maxRound: snapshot.maxRound,
            turretCount: snapshot.placedTurretCount,
            gold: snapshot.gold,
          )
        : l10n.stageFreshDetail(
            round: snapshot.round,
            maxRound: snapshot.maxRound,
            nexusHp: snapshot.nexusHp,
            maxNexusHp: snapshot.maxNexusHp,
          );
    final recordText = _recordTextForStage(l10n, snapshot, stageNumber);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xAA07111D),
        border: Border.all(color: const Color(0xAA33D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _StageIcon(unlocked: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.stageName(stageNumber),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phaseText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8EE6FF),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            detailText,
            style: const TextStyle(fontSize: 12, color: Color(0xFFB9D6E4)),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            recordText,
            style: const TextStyle(fontSize: 11, color: Color(0xFF8AA6B8)),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: FilledButton(onPressed: onPressed, child: Text(actionText)),
          ),
        ],
      ),
    );
  }
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

class _UnlockedStageCard extends StatelessWidget {
  const _UnlockedStageCard({
    required this.stageNumber,
    required this.statusText,
    required this.onPressed,
  });

  final int stageNumber;
  final String statusText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0x6607111D),
        side: const BorderSide(color: Color(0x7733D8FF)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        children: [
          const _StageIcon(unlocked: true),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.stageName(stageNumber),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8EE6FF),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedStageCard extends StatelessWidget {
  const _LockedStageCard({required this.stageNumber});

  final int stageNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x6607111D),
        border: Border.all(color: const Color(0x33485B68)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const _StageIcon(unlocked: false),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.stageName(stageNumber),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7F93A1),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.locked,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF667987),
                  ),
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

class _StageIcon extends StatelessWidget {
  const _StageIcon({required this.unlocked});

  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: unlocked ? const Color(0x2233D8FF) : const Color(0x22485B68),
        border: Border.all(
          color: unlocked ? const Color(0xAA33D8FF) : const Color(0x55485B68),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        unlocked ? Icons.flag_outlined : Icons.lock_outline,
        color: unlocked ? const Color(0xFF8EE6FF) : const Color(0xFF6D7F8F),
        size: 18,
      ),
    );
  }
}

class _PermanentUpgradeMenu extends StatelessWidget {
  const _PermanentUpgradeMenu({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressionUpgradeButton(
          title: l10n.startGold,
          level: snapshot.startingGoldUpgradeLevel,
          valueText: '+${snapshot.startingGoldUpgradeLevel * 10}G',
          cost: snapshot.startingGoldUpgradeCost,
          enabled: snapshot.canUpgradeStartingGold,
          onPressed: game.upgradeStartingGoldProgression,
        ),
        const SizedBox(height: 8),
        _ProgressionUpgradeButton(
          title: l10n.nexusHp,
          level: snapshot.nexusHpUpgradeLevel,
          valueText: '+${snapshot.nexusHpUpgradeLevel}',
          cost: snapshot.nexusHpUpgradeCost,
          enabled: snapshot.canUpgradeNexusHp,
          onPressed: game.upgradeNexusHpProgression,
        ),
      ],
    );
  }
}

class _ProgressionUpgradeButton extends StatelessWidget {
  const _ProgressionUpgradeButton({
    required this.title,
    required this.level,
    required this.valueText,
    required this.cost,
    required this.enabled,
    required this.onPressed,
  });

  final String title;
  final int level;
  final String valueText;
  final int cost;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFF6D7F8F),
          side: BorderSide(
            color: enabled ? const Color(0xFFE7C66A) : const Color(0x55485B68),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.upgradeLevel(title, level),
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              valueText,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB9D6E4)),
            ),
            const SizedBox(width: 10),
            Text(l10n.runeCost(cost), style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
