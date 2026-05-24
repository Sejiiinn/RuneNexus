import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/definitions/game_research_data.dart';
import '../../domain/combat/game_phase.dart';
import '../../domain/core/core_ability.dart';
import '../../domain/research/research_definition.dart';
import '../../domain/research/research_progress.dart';
import '../../domain/research/research_type.dart';
import '../../domain/turret/turret_type.dart';
import '../../game/game_snapshot.dart';
import '../../game/rendering/turret_shape_renderer.dart';
import '../../game/rune_nexus_game.dart';
import '../../game/systems/run_progression.dart';
import '../../l10n/rune_nexus_localizations.dart';
import '../game/game_ui.dart';
import '../widgets/rune_balance_card.dart';

const _showMapEditor = bool.fromEnvironment(
  'RUNE_NEXUS_DEBUG_PANEL',
  defaultValue: false,
);

enum MainMenuTab { stage, core, permanentUpgrades, research }

enum _PermanentUpgradeGroup { combat, economy }

const int _stageChapterSize = 5;
const int _visibleStageChapterCount = 3;
const double _stageRowHeight = 54;
const String _stageChapterOneBannerAsset = 'assets/images/chapter_1_banner.png';
const String _stageChapterTwoBannerAsset = 'assets/images/chapter_2_banner.png';
const List<String> _stageChapterBannerAssets = [
  _stageChapterOneBannerAsset,
  _stageChapterTwoBannerAsset,
];

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
  bool _showMenuDebugPanel = false;
  bool _chapterBannersPrecached = false;
  Timer? _researchClockTimer;

  @override
  void initState() {
    super.initState();
    _syncResearchClockTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_chapterBannersPrecached) {
      return;
    }
    _chapterBannersPrecached = true;
    for (final asset in _stageChapterBannerAssets) {
      unawaited(precacheImage(AssetImage(asset), context));
    }
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
        : selectedTab == MainMenuTab.stage
        ? 62.0
        : 92.0;
    return Container(
      color: GamePalette.backdrop,
      child: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _MainMenuBackdrop()),
            if (!_showMapEditor)
              const Positioned(top: 14, left: 16, child: _MenuQuickGlyphs()),
            const Positioned(top: 10, left: 0, right: 0, child: _MenuLogo()),
            if (selectedTab == MainMenuTab.stage)
              LayoutBuilder(
                builder: (context, constraints) {
                  final panelHeight = math.max(
                    0.0,
                    constraints.maxHeight - menuTopPadding - menuBottomPadding,
                  );
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        menuTopPadding,
                        16,
                        menuBottomPadding,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: SizedBox(
                          height: panelHeight,
                          child: _MainMenuPanel(
                            child: _StageMenu(
                              snapshot: widget.snapshot,
                              onStartStage: widget.onStartStage,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )
            else
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
                          child: switch (selectedTab) {
                            MainMenuTab.core => _CoreMenu(
                              game: widget.game,
                              snapshot: widget.snapshot,
                            ),
                            MainMenuTab.permanentUpgrades =>
                              _PermanentUpgradeMenu(
                                game: widget.game,
                                snapshot: widget.snapshot,
                                group: _selectedUpgradeGroup,
                              ),
                            MainMenuTab.research => _ResearchMenu(
                              game: widget.game,
                              snapshot: widget.snapshot,
                            ),
                            MainMenuTab.stage => _StageMenu(
                              snapshot: widget.snapshot,
                              onStartStage: widget.onStartStage,
                            ),
                          },
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
                child: _MenuDebugShortcuts(
                  testPanelOpen: _showMenuDebugPanel,
                  onToggleTestPanel: () {
                    setState(() {
                      _showMenuDebugPanel = !_showMenuDebugPanel;
                    });
                  },
                  onOpenMapEditor: widget.onOpenMapEditor,
                ),
              ),
            if (_showMapEditor && _showMenuDebugPanel)
              Positioned(
                top: 58,
                left: 16,
                right: 16,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: _MainMenuDebugPanel(
                      game: widget.game,
                      snapshot: widget.snapshot,
                      onClose: () {
                        setState(() {
                          _showMenuDebugPanel = false;
                        });
                      },
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

class _MainMenuPanel extends StatelessWidget {
  const _MainMenuPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth <= 390 ? 12.0 : 16.0;
        return GamePanel(padding: EdgeInsets.all(padding), child: child);
      },
    );
  }
}

class _MenuDebugShortcuts extends StatelessWidget {
  const _MenuDebugShortcuts({
    required this.testPanelOpen,
    required this.onToggleTestPanel,
    required this.onOpenMapEditor,
  });

  final bool testPanelOpen;
  final VoidCallback onToggleTestPanel;
  final VoidCallback? onOpenMapEditor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DebugShortcutButton(
          tooltip: '메뉴 테스트 패널',
          icon: Icons.tune,
          selected: testPanelOpen,
          onPressed: onToggleTestPanel,
        ),
        const SizedBox(width: 6),
        _DebugShortcutButton(
          tooltip: '맵 에디터',
          icon: Icons.map_outlined,
          selected: false,
          onPressed: onOpenMapEditor,
        ),
      ],
    );
  }
}

class _DebugShortcutButton extends StatelessWidget {
  const _DebugShortcutButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: selected
              ? const Color(0xFF07111D)
              : const Color(0xFFE8FBFF),
          backgroundColor: selected
              ? const Color(0xFF8EE6FF)
              : const Color(0xE607111D),
          side: BorderSide(
            color: selected ? const Color(0xFF8EE6FF) : const Color(0x6650E6FF),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _MainMenuDebugPanel extends StatelessWidget {
  const _MainMenuDebugPanel({
    required this.game,
    required this.snapshot,
    required this.onClose,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      padding: const EdgeInsets.all(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 430),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune, color: Color(0xFF8EE6FF), size: 18),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      '메뉴 테스트 패널',
                      style: TextStyle(
                        color: Color(0xFFE8FBFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: IconButton(
                      tooltip: '닫기',
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  _DebugStatusChip(
                    icon: Icons.diamond_outlined,
                    label: '룬',
                    value: '${snapshot.runes}',
                  ),
                  _DebugStatusChip(
                    icon: Icons.flag_outlined,
                    label: '해금',
                    value: '${snapshot.unlockedStageCount}',
                  ),
                  _DebugStatusChip(
                    icon: Icons.check_circle_outline,
                    label: '클리어',
                    value: '${snapshot.clearedStageNumbers.length}',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _DebugControlSection(
                title: '룬',
                children: [
                  _DebugActionButton(
                    label: '+100',
                    onPressed: () => game.debugAddRunes(100),
                  ),
                  _DebugActionButton(
                    label: '+1,000',
                    onPressed: () => game.debugAddRunes(1000),
                  ),
                  _DebugActionButton(
                    label: '+10,000',
                    onPressed: () => game.debugAddRunes(10000),
                  ),
                  _DebugActionButton(
                    label: '0으로',
                    onPressed: () => game.debugSetRunes(0),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DebugControlSection(
                title: '클리어 스테이지',
                children: [
                  for (final count in const [0, 1, 2, 5, 10])
                    _DebugActionButton(
                      label: count == 0 ? '초기' : '$count까지',
                      selected: snapshot.clearedStageNumbers.length == count,
                      onPressed: () => game.debugSetClearedStageCount(count),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _DebugControlSection(
                title: '강화',
                children: [
                  _DebugActionButton(
                    label: '강화 초기화',
                    danger: true,
                    onPressed: game.debugResetUpgradeProgress,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DebugControlSection(
                title: '코어',
                children: [
                  _DebugActionButton(
                    label: '패시브 초기화',
                    danger: true,
                    onPressed: game.debugResetCorePassiveProgress,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DebugControlSection(
                title: '연구',
                children: [
                  _DebugActionButton(
                    label: game.debugInstantResearchCompletion
                        ? '즉시 완료 ON'
                        : '즉시 완료 OFF',
                    selected: game.debugInstantResearchCompletion,
                    onPressed: () => game.debugSetInstantResearchCompletion(
                      !game.debugInstantResearchCompletion,
                    ),
                  ),
                  _DebugActionButton(
                    label: '연구 초기화',
                    danger: true,
                    onPressed: game.debugResetResearchProgress,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebugStatusChip extends StatelessWidget {
  const _DebugStatusChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x3315283A),
        border: Border.all(color: const Color(0x5533D8FF)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF8EE6FF), size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9EB3BF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE8FBFF),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugControlSection extends StatelessWidget {
  const _DebugControlSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x4415283A),
        border: Border.all(color: const Color(0x33485B68)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFE8FBFF),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 5, runSpacing: 5, children: children),
        ],
      ),
    );
  }
}

class _DebugActionButton extends StatelessWidget {
  const _DebugActionButton({
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger
        ? const Color(0xFFFF9A7A)
        : selected
        ? const Color(0xFFE7C66A)
        : const Color(0xFF8EE6FF);
    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? const Color(0xFF07111D) : Colors.white,
          backgroundColor: selected ? accent : null,
          side: BorderSide(color: accent.withValues(alpha: 0.74)),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
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

class _MenuLogo extends StatelessWidget {
  const _MenuLogo();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactLogo = constraints.maxWidth < 430;
        return IgnorePointer(
          child: Center(
            child: Opacity(
              opacity: 0.92,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!compactLogo) ...[
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
                  ],
                  Text(
                    l10n.appTitle,
                    style: TextStyle(
                      fontSize: compactLogo ? 20 : 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuQuickGlyphs extends StatelessWidget {
  const _MenuQuickGlyphs();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xAA06101A),
          border: Border.all(color: const Color(0x5533D8FF)),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenuQuickGlyph(icon: Icons.menu),
              _MenuQuickGlyph(icon: Icons.map_outlined),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuQuickGlyph extends StatelessWidget {
  const _MenuQuickGlyph({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF607486);
    return Container(
      width: 23,
      height: 23,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: ShapeDecoration(
        color: const Color(0x55101C28),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
      ),
      child: Icon(icon, color: color, size: 14),
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 18,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Container(
        height: 56,
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2433), Color(0xFF06101A)],
          ),
          border: Border(
            top: BorderSide(color: Color(0xAA5CF9E9)),
            bottom: BorderSide(color: Color(0x6607111D)),
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x6607111D),
            border: Border.all(color: const Color(0x4433D8FF)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: _TabButton(
                  key: const ValueKey('main-menu-tab-stage'),
                  icon: Icons.flag_outlined,
                  label: l10n.stageTab,
                  selected: selectedTab == MainMenuTab.stage,
                  onPressed: () => onSelectTab(MainMenuTab.stage),
                ),
              ),
              const _MenuTabGroove(),
              Expanded(
                child: _TabButton(
                  key: const ValueKey('main-menu-tab-core'),
                  icon: Icons.diamond_outlined,
                  label: l10n.coreTab,
                  selected: selectedTab == MainMenuTab.core,
                  onPressed: () => onSelectTab(MainMenuTab.core),
                ),
              ),
              const _MenuTabGroove(),
              Expanded(
                child: _TabButton(
                  key: const ValueKey('main-menu-tab-upgrades'),
                  icon: Icons.auto_awesome,
                  label: l10n.permanentUpgradeTab,
                  selected: selectedTab == MainMenuTab.permanentUpgrades,
                  onPressed: () => onSelectTab(MainMenuTab.permanentUpgrades),
                ),
              ),
              const _MenuTabGroove(),
              Expanded(
                child: _TabButton(
                  key: const ValueKey('main-menu-tab-research'),
                  icon: Icons.science_outlined,
                  label: l10n.researchTab,
                  selected: selectedTab == MainMenuTab.research,
                  onPressed: () => onSelectTab(MainMenuTab.research),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTabGroove extends StatelessWidget {
  const _MenuTabGroove();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2,
      height: 34,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFF33D8FF).withValues(alpha: 0.34),
              Colors.transparent,
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 4,
              offset: Offset(-1, 0),
            ),
          ],
        ),
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
    super.key,
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
        : const Color(0xFF88A4B3);
    final textColor = selected ? GamePalette.textPrimary : foregroundColor;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = constraints.maxWidth < 88;
        final horizontalPadding = dense ? 4.0 : 8.0;
        final indicatorInset = dense ? 11.0 : 18.0;
        final iconSize = selected
            ? (dense ? 16.0 : 18.0)
            : (dense ? 15.0 : 17.0);
        final labelGap = dense ? 4.0 : 7.0;
        final fontSize = dense ? 12.0 : 13.0;

        return Semantics(
          button: true,
          selected: selected,
          label: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(4),
              splashColor: const Color(0x1A8EE6FF),
              highlightColor: const Color(0x1022C7E8),
              child: SizedBox.expand(
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    if (selected) ...[
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.bottomCenter,
                              radius: 1.28,
                              colors: [
                                const Color(0xFF22C7E8).withValues(alpha: 0.28),
                                const Color(0xFF22C7E8).withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                              stops: const [0, 0.42, 1],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: indicatorInset,
                        right: indicatorInset,
                        bottom: 0,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0x008EE6FF),
                                Color(0xFF8EE6FF),
                                Color(0x008EE6FF),
                              ],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xAA22C7E8),
                                blurRadius: 7,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: iconSize,
                            color: foregroundColor,
                            shadows: selected
                                ? const [
                                    Shadow(
                                      color: Color(0xAA22C7E8),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          SizedBox(width: labelGap),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: fontSize,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StageMenu extends StatefulWidget {
  const _StageMenu({required this.snapshot, required this.onStartStage});

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
          unlockedStageCount: stageCount,
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
        if (activeRunInProgress) ...[
          _ActiveRunSummary(
            snapshot: snapshot,
            onPressed: () => widget.onStartStage(snapshot.currentStageNumber),
          ),
          const SizedBox(height: 10),
        ],
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
                    child: _StageSelectionRow(
                      stageNumber: stage,
                      unlocked: stage <= stageCount,
                      active:
                          activeRunInProgress &&
                          stage == snapshot.currentStageNumber,
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
                      onPressed: stage <= stageCount
                          ? () => widget.onStartStage(stage)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
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
    if (chapter == 2) {
      return const _StageChapterTheme(
        accent: Color(0xFF5CF9E9),
        secondary: Color(0xFFB68BFF),
        bannerAsset: _stageChapterTwoBannerAsset,
      );
    }
    return const _StageChapterTheme(
      accent: Color(0xFF8EE6FF),
      secondary: Color(0xFFE7C66A),
      bannerAsset: _stageChapterOneBannerAsset,
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
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.stageChapterRange(startStage, endStage),
                          style: GameTextStyles.withColor(
                            GameTextStyles.caption,
                            GamePalette.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
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
    required this.unlockedStageCount,
    required this.selectedTheme,
    required this.onSelected,
  });

  final int selectedChapter;
  final int unlockedStageCount;
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
    return chapterStart <= RunProgression.maxStageCount &&
        chapterStart <= unlockedStageCount;
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
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
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
    return GamePanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      selected: true,
      accentColor: GamePalette.metalDim,
      child: Row(
        children: [
          const _StageIcon(unlocked: true, active: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.inProgress,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5CF9E9),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l10n.stageName(snapshot.currentStageNumber),
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE8F8FF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l10n.stageProgressDetail(
                        round: snapshot.round,
                        maxRound: snapshot.maxRound,
                        turretCount: snapshot.placedTurretCount,
                        gold: snapshot.gold,
                      ),
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB9D6E4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GameButton(
            onPressed: onPressed,
            label: l10n.continueRun,
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            compact: true,
            variant: GameButtonVariant.secondary,
            accentColor: GamePalette.cyan,
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
                    theme: theme,
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
    final l10n = context.l10n;
    if (stageNumber == 1) {
      return _StageRewardInfo(
        label: sniperRewardUnlocked
            ? l10n.unlockedRewardLabel
            : l10n.clearRewardLabel,
        value: l10n.sniperTurret,
        icon: const _SniperRewardIcon(),
        highlighted: sniperRewardUnlocked,
      );
    }
    if (stageNumber == 2) {
      return _StageRewardInfo(
        label: stageCleared ? l10n.unlockedRewardLabel : l10n.clearRewardLabel,
        value: l10n.economicUpgrade,
        icon: const Icon(Icons.paid_outlined, size: 16),
        highlighted: stageCleared,
      );
    }
    if (stageNumber == 4) {
      return _StageRewardInfo(
        label: stageCleared ? l10n.unlockedRewardLabel : l10n.clearRewardLabel,
        value: l10n.combatUpgrade,
        icon: const Icon(Icons.bolt_outlined, size: 16),
        highlighted: stageCleared,
      );
    }
    if (stageNumber == 3 || stageNumber == 5) {
      return _StageRewardInfo(
        label: stageCleared ? l10n.unlockedRewardLabel : l10n.clearRewardLabel,
        value: l10n.researchTab,
        icon: const Icon(Icons.science_outlined, size: 16),
        highlighted: stageCleared,
      );
    }
    return null;
  }
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
    required this.value,
    required this.icon,
    required this.highlighted,
  });

  final String? label;
  final String value;
  final Widget icon;
  final bool highlighted;
}

class _StageRewardSummary extends StatelessWidget {
  const _StageRewardSummary({
    required this.rewardInfo,
    required this.unlocked,
    required this.theme,
    required this.dense,
  });

  final _StageRewardInfo? rewardInfo;
  final bool unlocked;
  final _StageChapterTheme theme;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final rewardInfo = this.rewardInfo;
    if (rewardInfo == null) {
      return const SizedBox.shrink();
    }
    final color = unlocked
        ? rewardInfo.highlighted
              ? theme.secondary
              : GamePalette.textSecondary
        : const Color(0xFF667987);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconTheme(
          data: IconThemeData(color: color, size: dense ? 14 : 16),
          child: rewardInfo.icon,
        ),
        SizedBox(width: dense ? 5 : 7),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rewardInfo.label != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      rewardInfo.label!,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.78),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    rewardInfo.value,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

enum _CoreAbilityTab { combatSkill, passive }

enum _CoreMenuSelection { combatSkillSlot, passiveSlotOne, passiveSlotTwo }

abstract final class _CoreUiStyle {
  static const Color panelTop = Color(0xF20C1D2C);
  static const Color panelBottom = Color(0xF006101A);
  static const Color panelLine = Color(0x885D7182);
  static const Color panelGlow = Color(0x4422C7E8);
  static const Color itemBase = Color(0xE60A1724);
  static const Color badgeBase = Color(0xAA111E2D);
  static const Color lockedLine = Color(0x55485B68);
  static const double panelRadius = 7;
}

class _CoreMenu extends StatefulWidget {
  const _CoreMenu({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  State<_CoreMenu> createState() => _CoreMenuState();
}

class _CoreMenuState extends State<_CoreMenu> {
  _CoreAbilityTab _selectedTab = _CoreAbilityTab.combatSkill;
  _CoreMenuSelection _selected = _CoreMenuSelection.combatSkillSlot;
  String _selectedAbilityName = '수호 광선';

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final compact = mediaSize.height < 760 || mediaSize.width < 480;
    final selectedPassiveSlotIndex = switch (_selected) {
      _CoreMenuSelection.passiveSlotOne => 0,
      _CoreMenuSelection.passiveSlotTwo => 1,
      _CoreMenuSelection.combatSkillSlot => 0,
    };
    final selectedAbility = _selectedCoreAbilityData(
      snapshot: widget.snapshot,
      tab: _selectedTab,
      selectedPassiveSlotIndex: selectedPassiveSlotIndex,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CoreSummaryHeader(compact: compact),
        SizedBox(height: compact ? 7 : 9),
        _CoreSocketStage(
          snapshot: widget.snapshot,
          compact: compact,
          selected: _selected,
          onUnlockPassiveSlot: () => _confirmUnlockCorePassiveSlot(
            context,
            game: widget.game,
            snapshot: widget.snapshot,
          ),
          onSelect: (selection) {
            setState(() {
              _selected = selection;
              _selectedTab = switch (selection) {
                _CoreMenuSelection.combatSkillSlot =>
                  _CoreAbilityTab.combatSkill,
                _CoreMenuSelection.passiveSlotOne ||
                _CoreMenuSelection.passiveSlotTwo => _CoreAbilityTab.passive,
              };
              final nextPassiveSlotIndex = switch (_selected) {
                _CoreMenuSelection.passiveSlotOne => 0,
                _CoreMenuSelection.passiveSlotTwo => 1,
                _CoreMenuSelection.combatSkillSlot => 0,
              };
              _selectedAbilityName = _defaultSelectedAbilityName(
                snapshot: widget.snapshot,
                tab: _selectedTab,
                selectedPassiveSlotIndex: nextPassiveSlotIndex,
              );
            });
          },
        ),
        SizedBox(height: compact ? 7 : 9),
        _CoreSelectedAbilityPanel(
          data: selectedAbility,
          selectedTab: _selectedTab,
          compact: compact,
          onAction: () => _performSelectedAbilityAction(selectedAbility),
        ),
        SizedBox(height: compact ? 7 : 9),
        _CoreAbilityLibrary(
          snapshot: widget.snapshot,
          selectedTab: _selectedTab,
          selectedPassiveSlotIndex: selectedPassiveSlotIndex,
          compact: compact,
          onSelectTab: (tab) {
            setState(() {
              _selectedTab = tab;
              _selected = tab == _CoreAbilityTab.combatSkill
                  ? _CoreMenuSelection.combatSkillSlot
                  : _selected == _CoreMenuSelection.passiveSlotTwo
                  ? _CoreMenuSelection.passiveSlotTwo
                  : _CoreMenuSelection.passiveSlotOne;
              final nextPassiveSlotIndex = switch (_selected) {
                _CoreMenuSelection.passiveSlotOne => 0,
                _CoreMenuSelection.passiveSlotTwo => 1,
                _CoreMenuSelection.combatSkillSlot => 0,
              };
              _selectedAbilityName = _defaultSelectedAbilityName(
                snapshot: widget.snapshot,
                tab: _selectedTab,
                selectedPassiveSlotIndex: nextPassiveSlotIndex,
              );
            });
          },
          selectedAbilityName: selectedAbility.name,
          onSelectAbility: (ability) {
            setState(() => _selectedAbilityName = ability.name);
          },
        ),
      ],
    );
  }

  _CoreAbilityData _selectedCoreAbilityData({
    required GameSnapshot snapshot,
    required _CoreAbilityTab tab,
    required int selectedPassiveSlotIndex,
  }) {
    final abilities = _CoreAbilityData.forTab(
      snapshot: snapshot,
      tab: tab,
      selectedPassiveSlotIndex: selectedPassiveSlotIndex,
    );
    for (final ability in abilities) {
      if (ability.name == _selectedAbilityName) {
        return ability;
      }
    }
    return abilities.firstWhere(
      (ability) =>
          ability.name ==
          _defaultSelectedAbilityName(
            snapshot: snapshot,
            tab: tab,
            selectedPassiveSlotIndex: selectedPassiveSlotIndex,
          ),
      orElse: () => abilities.first,
    );
  }

  String _defaultSelectedAbilityName({
    required GameSnapshot snapshot,
    required _CoreAbilityTab tab,
    required int selectedPassiveSlotIndex,
  }) {
    final abilities = _CoreAbilityData.forTab(
      snapshot: snapshot,
      tab: tab,
      selectedPassiveSlotIndex: selectedPassiveSlotIndex,
    );
    if (tab == _CoreAbilityTab.passive) {
      final slotted = _corePassiveAt(snapshot, selectedPassiveSlotIndex);
      if (slotted != null) {
        return abilities
            .firstWhere(
              (ability) => ability.passiveAbility == slotted,
              orElse: () => abilities.first,
            )
            .name;
      }
      return abilities
          .firstWhere(
            (ability) =>
                ability.enabled && !ability.equipped && !ability.locked,
            orElse: () => abilities.first,
          )
          .name;
    }
    return abilities.first.name;
  }

  void _performSelectedAbilityAction(_CoreAbilityData ability) {
    final combatSkill = ability.combatSkill;
    if (combatSkill != null) {
      if (ability.locked || !ability.enabled) {
        return;
      }
      if (ability.equipped) {
        widget.game.unequipCoreCombatSkill();
        return;
      }
      widget.game.equipCoreCombatSkill(combatSkill);
      return;
    }

    final passive = ability.passiveAbility;
    if (passive == null || ability.locked || !ability.enabled) {
      return;
    }
    if (ability.equipped) {
      final slotIndex = widget.snapshot.corePassiveSlots.indexOf(passive);
      if (slotIndex >= 0) {
        widget.game.unequipCorePassiveAbility(slotIndex);
      }
      return;
    }
    final selectedPassiveSlotIndex = switch (_selected) {
      _CoreMenuSelection.passiveSlotOne => 0,
      _CoreMenuSelection.passiveSlotTwo => 1,
      _CoreMenuSelection.combatSkillSlot => 0,
    };
    widget.game.equipCorePassiveAbility(passive, selectedPassiveSlotIndex);
  }
}

class _CoreSummaryHeader extends StatelessWidget {
  const _CoreSummaryHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_CoreUiStyle.panelTop, _CoreUiStyle.panelBottom],
        ),
        border: Border.all(color: _CoreUiStyle.panelLine),
        borderRadius: BorderRadius.circular(_CoreUiStyle.panelRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 12,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 11,
          vertical: compact ? 8 : 10,
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 40 : 46,
              height: compact ? 40 : 46,
              decoration: const ShapeDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFFE8FBFF),
                    Color(0xFF8EE6FF),
                    Color(0xFF155876),
                    Color(0xFF06101A),
                  ],
                  stops: [0, 0.32, 0.66, 1],
                ),
                shape: StarBorder.polygon(sides: 6, pointRounding: 0.12),
                shadows: [
                  BoxShadow(
                    color: Color(0x7722C7E8),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.diamond_outlined,
                color: Color(0xFFFFFFFF),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '넥서스 코어',
                    style: TextStyle(
                      color: Color(0xFFE8FBFF),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '전투 스킬 1칸 / 패시브 2칸',
                    style: TextStyle(
                      color: Color(0xFF8FA8BA),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: ShapeDecoration(
                color: const Color(0x22E7C66A),
                shape: BeveledRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                  side: const BorderSide(color: Color(0x99E7C66A)),
                ),
              ),
              child: const Text(
                'Lv.1',
                style: TextStyle(
                  color: Color(0xFFE7C66A),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoreSocketStage extends StatelessWidget {
  const _CoreSocketStage({
    required this.snapshot,
    required this.compact,
    required this.selected,
    required this.onUnlockPassiveSlot,
    required this.onSelect,
  });

  final GameSnapshot snapshot;
  final bool compact;
  final _CoreMenuSelection selected;
  final Future<bool> Function() onUnlockPassiveSlot;
  final ValueChanged<_CoreMenuSelection> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = constraints.maxWidth < 370;
        final stageHeight = compact ? 178.0 : 224.0;
        final skillWidth = dense ? 108.0 : 122.0;
        final passiveGap = dense ? 8.0 : 10.0;
        final passiveWidth = dense ? 112.0 : 126.0;
        final combatSkill = snapshot.coreCombatSkill;
        final hasCombatSkill = combatSkill != null;
        return Container(
          key: const ValueKey('core-socket-board'),
          padding: EdgeInsets.all(dense ? 8 : 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xD00B1B2B), Color(0xE806101A)],
            ),
            border: Border.all(color: const Color(0x775D7182), width: 1.2),
            borderRadius: BorderRadius.circular(_CoreUiStyle.panelRadius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x77000000),
                blurRadius: 16,
                offset: Offset(0, 9),
              ),
              BoxShadow(color: _CoreUiStyle.panelGlow, blurRadius: 18),
            ],
          ),
          child: SizedBox(
            height: stageHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CoreSocketStagePainter(
                      compact: compact,
                      dense: dense,
                      passiveSlotCount: snapshot.corePassiveSlotCount,
                      passiveSlotOne: _corePassiveAt(snapshot, 0),
                      passiveSlotTwo: _corePassiveAt(snapshot, 1),
                    ),
                    child: Center(
                      child: _CoreBodyGlyph(size: compact ? 84 : 96),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: skillWidth,
                      child: _CoreSocketButton(
                        kind: '전투 스킬',
                        icon: hasCombatSkill ? Icons.auto_awesome : Icons.add,
                        label: combatSkill?.label ?? '빈 슬롯',
                        state: hasCombatSkill ? '5초마다 자동 발동' : '스킬을 장착하세요',
                        accent: hasCombatSkill
                            ? const Color(0xFF8EE6FF)
                            : const Color(0xFF8FA8BA),
                        prominent: true,
                        compact: compact,
                        empty: !hasCombatSkill,
                        muted: !hasCombatSkill,
                        selected:
                            selected == _CoreMenuSelection.combatSkillSlot,
                        onTap: () =>
                            onSelect(_CoreMenuSelection.combatSkillSlot),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: passiveWidth,
                        child: _CorePassiveSlotButton(
                          index: 0,
                          ability: _corePassiveAt(snapshot, 0),
                          locked: snapshot.corePassiveSlotCount <= 0,
                          unlockCost: snapshot.corePassiveSlotUnlockCost,
                          unlockable: false,
                          compact: compact,
                          selected:
                              selected == _CoreMenuSelection.passiveSlotOne,
                          onTap: () =>
                              onSelect(_CoreMenuSelection.passiveSlotOne),
                        ),
                      ),
                      SizedBox(width: passiveGap),
                      SizedBox(
                        width: passiveWidth,
                        child: _CorePassiveSlotButton(
                          index: 1,
                          ability: _corePassiveAt(snapshot, 1),
                          locked: snapshot.corePassiveSlotCount <= 1,
                          unlockCost: snapshot.corePassiveSlotUnlockCost,
                          unlockable: snapshot.canUnlockCorePassiveSlot,
                          compact: compact,
                          selected:
                              selected == _CoreMenuSelection.passiveSlotTwo,
                          onTap: () async {
                            if (snapshot.corePassiveSlotCount <= 1 &&
                                snapshot.canUnlockCorePassiveSlot) {
                              final unlocked = await onUnlockPassiveSlot();
                              if (unlocked) {
                                onSelect(_CoreMenuSelection.passiveSlotTwo);
                              }
                              return;
                            }
                            onSelect(_CoreMenuSelection.passiveSlotTwo);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CoreSocketStagePainter extends CustomPainter {
  const _CoreSocketStagePainter({
    required this.compact,
    required this.dense,
    required this.passiveSlotCount,
    required this.passiveSlotOne,
    required this.passiveSlotTwo,
  });

  final bool compact;
  final bool dense;
  final int passiveSlotCount;
  final CorePassiveAbility? passiveSlotOne;
  final CorePassiveAbility? passiveSlotTwo;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final gap = dense ? 8.0 : 10.0;
    final topWidth = dense ? 108.0 : 122.0;
    final topHeight = compact ? 46.0 : 56.0;
    final passiveHeight = compact ? 44.0 : 54.0;
    final passiveWidth = dense ? 112.0 : 126.0;
    final passiveLeft = (size.width - passiveWidth * 2 - gap) / 2;
    final topSocket = Offset(center.dx, size.height * 0.28);
    final bottomHub = Offset(center.dx, size.height * 0.65);
    final leftSocket = Offset(
      passiveLeft + passiveWidth / 2,
      size.height * 0.83,
    );
    final rightSocket = Offset(
      passiveLeft + passiveWidth + gap + passiveWidth / 2,
      size.height * 0.83,
    );
    final passiveOneAccent = _passiveSlotAccent(passiveSlotOne);
    final passiveTwoAccent = _passiveSlotAccent(passiveSlotTwo);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = const Color(0x5533D8FF);
    canvas.drawCircle(
      center,
      math.min(size.shortestSide * 0.42, 52),
      ringPaint,
    );
    canvas.drawCircle(center, 43, ringPaint..color = const Color(0x2AE7C66A));
    final mainLinkPaint = Paint()
      ..color = const Color(0xAA72E0A2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(topSocket, center, mainLinkPaint);
    canvas.drawLine(center, bottomHub, mainLinkPaint);
    canvas.drawLine(
      bottomHub,
      leftSocket,
      mainLinkPaint..color = passiveOneAccent.withValues(alpha: 0.66),
    );
    canvas.drawLine(
      bottomHub,
      rightSocket,
      mainLinkPaint..color = passiveTwoAccent.withValues(alpha: 0.66),
    );

    _drawSocketFrame(
      canvas,
      Rect.fromLTWH((size.width - topWidth) / 2, 0, topWidth, topHeight),
      accent: const Color(0xFF8EE6FF),
    );
    _drawSocketFrame(
      canvas,
      Rect.fromLTWH(
        passiveLeft,
        size.height - passiveHeight,
        passiveWidth,
        passiveHeight,
      ),
      accent: passiveOneAccent,
      muted: passiveSlotCount <= 0 || passiveSlotOne == null,
    );
    _drawSocketFrame(
      canvas,
      Rect.fromLTWH(
        passiveLeft + passiveWidth + gap,
        size.height - passiveHeight,
        passiveWidth,
        passiveHeight,
      ),
      accent: passiveTwoAccent,
      muted: passiveSlotCount <= 1 || passiveSlotTwo == null,
    );
  }

  Color _passiveSlotAccent(CorePassiveAbility? ability) {
    return switch (ability) {
      CorePassiveAbility.selfRepair => const Color(0xFF72E0A2),
      CorePassiveAbility.costSavingDesign => const Color(0xFFFFC66A),
      null => const Color(0xFF8FA8BA),
    };
  }

  void _drawSocketFrame(
    Canvas canvas,
    Rect rect, {
    required Color accent,
    bool muted = false,
  }) {
    const bevel = 10.0;
    final frame = Path()
      ..moveTo(rect.left + bevel, rect.top)
      ..lineTo(rect.right - bevel, rect.top)
      ..lineTo(rect.right, rect.top + bevel)
      ..lineTo(rect.right, rect.bottom - bevel)
      ..lineTo(rect.right - bevel, rect.bottom)
      ..lineTo(rect.left + bevel, rect.bottom)
      ..lineTo(rect.left, rect.bottom - bevel)
      ..lineTo(rect.left, rect.top + bevel)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: muted ? 0.02 : 0.05),
          const Color(0x00000000),
        ],
      ).createShader(rect);
    canvas.drawPath(frame, fillPaint);

    final borderPaint = Paint()
      ..color = accent.withValues(alpha: muted ? 0.34 : 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(frame, borderPaint);

    final insetPaint = Paint()
      ..color = accent.withValues(alpha: muted ? 0.16 : 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final inset = rect.deflate(6);
    final insetFrame = Path()
      ..moveTo(inset.left + bevel * 0.62, inset.top)
      ..lineTo(inset.right - bevel * 0.62, inset.top)
      ..lineTo(inset.right, inset.top + bevel * 0.62)
      ..lineTo(inset.right, inset.bottom - bevel * 0.62)
      ..lineTo(inset.right - bevel * 0.62, inset.bottom)
      ..lineTo(inset.left + bevel * 0.62, inset.bottom)
      ..lineTo(inset.left, inset.bottom - bevel * 0.62)
      ..lineTo(inset.left, inset.top + bevel * 0.62)
      ..close();
    canvas.drawPath(insetFrame, insetPaint);
  }

  @override
  bool shouldRepaint(covariant _CoreSocketStagePainter oldDelegate) {
    return oldDelegate.compact != compact ||
        oldDelegate.dense != dense ||
        oldDelegate.passiveSlotCount != passiveSlotCount ||
        oldDelegate.passiveSlotOne != passiveSlotOne ||
        oldDelegate.passiveSlotTwo != passiveSlotTwo;
  }
}

class _CoreBodyGlyph extends StatelessWidget {
  const _CoreBodyGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _NexusCoreGlyphPainter()),
      ),
    );
  }
}

class _NexusCoreGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final shadowPaint = Paint()
      ..color = const Color(0xAA000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final basePaint = Paint()..color = const Color(0xFF172535);
    const gemColor = Color(0xFF8EE6FF);
    const strokeColor = Color(0xFFD6F6FF);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + unit * 0.35),
        width: unit * 0.72,
        height: unit * 0.18,
      ),
      shadowPaint,
    );

    final pedestal = Rect.fromCenter(
      center: Offset(center.dx, center.dy + unit * 0.26),
      width: unit * 0.66,
      height: unit * 0.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pedestal, Radius.circular(unit * 0.04)),
      Paint()..color = const Color(0xFF0A111A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        pedestal.deflate(unit * 0.035),
        Radius.circular(unit * 0.03),
      ),
      basePaint,
    );

    final leftBrace = Path()
      ..moveTo(center.dx - unit * 0.27, center.dy + unit * 0.03)
      ..lineTo(center.dx - unit * 0.36, center.dy - unit * 0.15)
      ..lineTo(center.dx - unit * 0.18, center.dy - unit * 0.27)
      ..lineTo(center.dx - unit * 0.08, center.dy + unit * 0.02)
      ..close();
    final rightBrace = Path()
      ..moveTo(center.dx + unit * 0.27, center.dy + unit * 0.03)
      ..lineTo(center.dx + unit * 0.36, center.dy - unit * 0.15)
      ..lineTo(center.dx + unit * 0.18, center.dy - unit * 0.27)
      ..lineTo(center.dx + unit * 0.08, center.dy + unit * 0.02)
      ..close();
    final bracePaint = Paint()..color = const Color(0xCC203B4B);
    canvas.drawPath(leftBrace, bracePaint);
    canvas.drawPath(rightBrace, bracePaint);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - unit * 0.13),
        width: unit * 0.64,
        height: unit * 0.44,
      ),
      Paint()..color = gemColor.withValues(alpha: 0.1),
    );

    final gem = Path()
      ..moveTo(center.dx, center.dy - unit * 0.42)
      ..lineTo(center.dx + unit * 0.22, center.dy - unit * 0.08)
      ..lineTo(center.dx, center.dy + unit * 0.22)
      ..lineTo(center.dx - unit * 0.22, center.dy - unit * 0.08)
      ..close();
    final leftFace = Path()
      ..moveTo(center.dx, center.dy - unit * 0.42)
      ..lineTo(center.dx, center.dy + unit * 0.22)
      ..lineTo(center.dx - unit * 0.22, center.dy - unit * 0.08)
      ..close();
    final topFace = Path()
      ..moveTo(center.dx, center.dy - unit * 0.42)
      ..lineTo(center.dx + unit * 0.22, center.dy - unit * 0.08)
      ..lineTo(center.dx, center.dy - unit * 0.16)
      ..close();
    final rightFace = Path()
      ..moveTo(center.dx, center.dy - unit * 0.16)
      ..lineTo(center.dx + unit * 0.22, center.dy - unit * 0.08)
      ..lineTo(center.dx, center.dy + unit * 0.22)
      ..close();
    final innerFace = Path()
      ..moveTo(center.dx, center.dy - unit * 0.42)
      ..lineTo(center.dx - unit * 0.08, center.dy - unit * 0.07)
      ..lineTo(center.dx, center.dy + unit * 0.22)
      ..lineTo(center.dx + unit * 0.08, center.dy - unit * 0.07)
      ..close();

    canvas.drawPath(gem, Paint()..color = gemColor);
    canvas.drawPath(leftFace, Paint()..color = const Color(0xFF39A9CF));
    canvas.drawPath(topFace, Paint()..color = const Color(0xFFE8FBFF));
    canvas.drawPath(rightFace, Paint()..color = const Color(0xFF147AA0));
    canvas.drawPath(innerFace, Paint()..color = const Color(0x55FFFFFF));
    canvas.drawPath(
      gem,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.03
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - unit * 0.11, center.dy - unit * 0.05)
        ..lineTo(center.dx, center.dy - unit * 0.18)
        ..lineTo(center.dx + unit * 0.11, center.dy - unit * 0.05),
      Paint()
        ..color = const Color(0xAAE7C66A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.024
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CorePassiveSlotButton extends StatelessWidget {
  const _CorePassiveSlotButton({
    required this.index,
    required this.ability,
    required this.locked,
    required this.unlockCost,
    required this.unlockable,
    required this.compact,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final CorePassiveAbility? ability;
  final bool locked;
  final int unlockCost;
  final bool unlockable;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return _CorePassiveSlotUnlockButton(
        index: index,
        unlockCost: unlockCost,
        unlockable: unlockable,
        compact: compact,
        selected: selected,
        onTap: onTap,
      );
    }
    final equipped = ability != null;
    final passiveIcon = switch (ability) {
      CorePassiveAbility.selfRepair => Icons.healing_outlined,
      CorePassiveAbility.costSavingDesign => Icons.construction_outlined,
      null => Icons.add,
    };
    final passiveAccent = switch (ability) {
      CorePassiveAbility.selfRepair => const Color(0xFF72E0A2),
      CorePassiveAbility.costSavingDesign => const Color(0xFFFFC66A),
      null => const Color(0xFF8FA8BA),
    };
    return _CoreSocketButton(
      kind: '패시브 ${index + 1}',
      icon: passiveIcon,
      label: ability?.label ?? '빈 슬롯',
      state: equipped
          ? (switch (ability) {
              CorePassiveAbility.selfRepair => '5라운드마다 체력 회복',
              CorePassiveAbility.costSavingDesign => '건설 비용 15% 감소',
              null => '패시브를 장착하세요',
            })
          : '패시브를 장착하세요',
      accent: passiveAccent,
      compact: true,
      empty: !equipped,
      muted: !equipped,
      selected: selected,
      onTap: onTap,
    );
  }
}

class _CorePassiveSlotUnlockButton extends StatelessWidget {
  const _CorePassiveSlotUnlockButton({
    required this.index,
    required this.unlockCost,
    required this.unlockable,
    required this.compact,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final int unlockCost;
  final bool unlockable;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = unlockable
        ? const Color(0xFFE7C66A)
        : const Color(0xFF8FA8BA);
    final label = unlockable ? '해금 가능' : '잠김';
    final state = unlockable ? '$unlockCost 룬 소모' : '$unlockCost 룬 필요';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: compact ? 44 : 54,
        padding: EdgeInsets.fromLTRB(
          compact ? 6 : 8,
          compact ? 5 : 6,
          compact ? 6 : 8,
          compact ? 5 : 6,
        ),
        decoration: ShapeDecoration(
          color: unlockable ? const Color(0x22E7C66A) : const Color(0x1A8FA8BA),
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected
                  ? accent.withValues(alpha: 0.95)
                  : accent.withValues(alpha: unlockable ? 0.72 : 0.42),
              width: selected ? 1.4 : 1.0,
            ),
          ),
          shadows: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 11,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CoreSlotKindLabel(
              label: '패시브 ${index + 1}',
              compact: compact,
              selected: selected,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  unlockable ? Icons.lock_open_outlined : Icons.lock_outline,
                  color: accent,
                  size: compact ? 10 : 13,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unlockable
                          ? const Color(0xFFE8FBFF)
                          : const Color(0xFFB4C7D2),
                      fontSize: compact ? 8 : 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              state,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: compact ? 7 : 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoreSocketButton extends StatelessWidget {
  const _CoreSocketButton({
    required this.kind,
    required this.icon,
    required this.label,
    required this.state,
    required this.onTap,
    this.accent = const Color(0xFF8EE6FF),
    this.prominent = false,
    this.compact = false,
    this.empty = false,
    this.muted = false,
    this.selected = false,
  });

  final String kind;
  final IconData icon;
  final String label;
  final String state;
  final VoidCallback onTap;
  final Color accent;
  final bool prominent;
  final bool compact;
  final bool empty;
  final bool muted;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = muted ? const Color(0xFF8FA8BA) : accent;
    final selectedAccent = muted ? const Color(0xFFB4C7D2) : accent;
    final foreground = empty
        ? const Color(0xFFBFD0D8)
        : GamePalette.textPrimary;
    final iconSize = compact
        ? prominent
              ? 10.0
              : 9.0
        : prominent
        ? 14.0
        : 12.0;
    final slotHeight = prominent
        ? (compact ? 46.0 : 56.0)
        : (compact ? 44.0 : 54.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: slotHeight,
        decoration: selected
            ? ShapeDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    selectedAccent.withValues(alpha: 0.18),
                    selectedAccent.withValues(alpha: 0.06),
                  ],
                ),
                shape: BeveledRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: selectedAccent.withValues(alpha: 0.95),
                    width: 1.4,
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: selectedAccent.withValues(alpha: 0.18),
                    blurRadius: 11,
                    spreadRadius: 0.5,
                  ),
                ],
              )
            : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 6 : 8,
            compact ? 5 : 6,
            compact ? 6 : 8,
            compact ? 5 : 6,
          ),
          child: compact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CoreSlotKindLabel(
                      label: kind,
                      compact: true,
                      selected: selected,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: effectiveAccent, size: iconSize),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground,
                              fontSize: prominent ? 8 : 7,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CoreSlotKindLabel(
                      label: kind,
                      compact: false,
                      selected: selected,
                    ),
                    const Spacer(),
                    Container(
                      width: prominent ? 20 : 18,
                      height: prominent ? 20 : 18,
                      decoration: ShapeDecoration(
                        color: effectiveAccent.withValues(
                          alpha: empty ? 0.04 : 0.1,
                        ),
                        shape: StarBorder.polygon(
                          sides: prominent ? 6 : 8,
                          pointRounding: 0.08,
                          side: BorderSide(
                            color: effectiveAccent.withValues(alpha: 0.72),
                            width: 1.1,
                          ),
                        ),
                      ),
                      child: Icon(icon, color: effectiveAccent, size: iconSize),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: foreground,
                          fontSize: prominent ? 10 : 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CoreSlotKindLabel extends StatelessWidget {
  const _CoreSlotKindLabel({
    required this.label,
    required this.compact,
    required this.selected,
  });

  final String label;
  final bool compact;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: selected ? const Color(0xFFE8FBFF) : const Color(0xFFD2E3EA),
        fontSize: compact ? 8 : 10,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _CoreStatusBadge extends StatelessWidget {
  const _CoreStatusBadge({
    required this.label,
    required this.color,
    this.disabled = false,
  });

  final String label;
  final Color color;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: disabled ? const Color(0x66101922) : _CoreUiStyle.badgeBase,
        shape: StadiumBorder(
          side: BorderSide(
            color: color.withValues(alpha: disabled ? 0.38 : 0.7),
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: disabled ? const Color(0xFF7A8D9A) : color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CoreActionCta extends StatelessWidget {
  const _CoreActionCta({
    required this.label,
    required this.color,
    required this.secondary,
  });

  final String label;
  final Color color;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final foreground = secondary ? const Color(0xFFB4C7D2) : color;
    return Container(
      height: 26,
      constraints: const BoxConstraints(minWidth: 54),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: foreground.withValues(alpha: secondary ? 0.06 : 0.1),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: BorderSide(color: foreground.withValues(alpha: 0.72)),
        ),
        shadows: [
          BoxShadow(
            color: foreground.withValues(alpha: secondary ? 0.04 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            secondary ? Icons.remove : Icons.add,
            color: foreground,
            size: 13,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoreSelectedAbilityPanel extends StatelessWidget {
  const _CoreSelectedAbilityPanel({
    required this.data,
    required this.selectedTab,
    required this.compact,
    required this.onAction,
  });

  final _CoreAbilityData data;
  final _CoreAbilityTab selectedTab;
  final bool compact;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final actionEnabled =
        (data.combatSkill != null || data.passiveAbility != null) &&
        data.enabled &&
        !data.locked;
    final detailText = data.state;
    final actionLabel = data.passiveAbility == null
        ? data.equipped
              ? '해제'
              : data.actionLabel
        : data.equipped
        ? '해제'
        : data.actionLabel;
    return Container(
      key: const ValueKey('core-selected-ability-panel'),
      height: compact ? 74 : 84,
      padding: EdgeInsets.fromLTRB(
        compact ? 9 : 11,
        compact ? 8 : 10,
        compact ? 9 : 11,
        compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF20B1B2B), Color(0xE606101A)],
        ),
        border: Border.all(color: _CoreUiStyle.panelLine),
        borderRadius: BorderRadius.circular(_CoreUiStyle.panelRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 12,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 44 : 50,
            height: compact ? 44 : 50,
            decoration: ShapeDecoration(
              color: data.accent.withValues(alpha: data.locked ? 0.06 : 0.16),
              shape: StarBorder.polygon(
                sides: 6,
                pointRounding: 0.08,
                side: BorderSide(
                  color: data.accent.withValues(
                    alpha: data.locked ? 0.26 : 0.7,
                  ),
                ),
              ),
            ),
            child: Icon(data.icon, color: data.accent, size: compact ? 22 : 25),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE8FBFF),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  detailText,
                  maxLines: selectedTab == _CoreAbilityTab.combatSkill ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB4C7D2),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          actionEnabled
              ? GestureDetector(
                  key: const ValueKey('core-selected-ability-action'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onAction,
                  child: _CoreActionCta(
                    label: actionLabel,
                    color: data.accent,
                    secondary: data.equipped,
                  ),
                )
              : _CoreStatusBadge(
                  label: data.locked ? data.actionLabel : actionLabel,
                  color: data.locked ? const Color(0xFF8FA8BA) : data.accent,
                  disabled: data.locked,
                ),
        ],
      ),
    );
  }
}

class _CoreAbilityLibrary extends StatelessWidget {
  const _CoreAbilityLibrary({
    required this.snapshot,
    required this.selectedTab,
    required this.selectedPassiveSlotIndex,
    required this.compact,
    required this.onSelectTab,
    required this.selectedAbilityName,
    required this.onSelectAbility,
  });

  final GameSnapshot snapshot;
  final _CoreAbilityTab selectedTab;
  final int selectedPassiveSlotIndex;
  final bool compact;
  final ValueChanged<_CoreAbilityTab> onSelectTab;
  final String selectedAbilityName;
  final ValueChanged<_CoreAbilityData> onSelectAbility;

  @override
  Widget build(BuildContext context) {
    final abilities = _CoreAbilityData.forTab(
      snapshot: snapshot,
      tab: selectedTab,
      selectedPassiveSlotIndex: selectedPassiveSlotIndex,
    );
    final libraryHeight = compact ? 158.0 : 188.0;
    return Container(
      height: libraryHeight,
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF20B1B2B), Color(0xF006101A)],
        ),
        border: Border.all(color: _CoreUiStyle.panelLine),
        borderRadius: BorderRadius.circular(_CoreUiStyle.panelRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _CoreAbilityTabButton(
                  label: '전투 스킬',
                  selected: selectedTab == _CoreAbilityTab.combatSkill,
                  onTap: () => onSelectTab(_CoreAbilityTab.combatSkill),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _CoreAbilityTabButton(
                  label: '패시브',
                  selected: selectedTab == _CoreAbilityTab.passive,
                  onTap: () => onSelectTab(_CoreAbilityTab.passive),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
                childAspectRatio: 0.95,
              ),
              itemCount: abilities.length,
              itemBuilder: (context, index) {
                return _CoreAbilityCard(
                  data: abilities[index],
                  selected: abilities[index].name == selectedAbilityName,
                  onTap: () => onSelectAbility(abilities[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CoreAbilityTabButton extends StatelessWidget {
  const _CoreAbilityTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 30,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? const [Color(0xFF123C4E), Color(0xFF071B29)]
                  : const [Color(0xAA15283A), Color(0xAA081421)],
            ),
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(
                color: selected
                    ? const Color(0xCC8EE6FF)
                    : const Color(0x5533D8FF),
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? GamePalette.textPrimary
                  : const Color(0xFF8FA8BA),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoreAbilityCard extends StatelessWidget {
  const _CoreAbilityCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _CoreAbilityData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = data.locked || (!data.enabled && !data.equipped);
    final borderColor = data.equipped
        ? data.accent.withValues(alpha: 0.82)
        : selected
        ? const Color(0xCC8EE6FF)
        : data.locked
        ? _CoreUiStyle.lockedLine
        : const Color(0x6633D8FF);
    final textColor = data.locked
        ? const Color(0xFF7A8D9A)
        : GamePalette.textPrimary;
    return Opacity(
      opacity: disabled ? 0.68 : 1,
      child: Material(
        key: ValueKey('core-ability-${data.name}'),
        color: Colors.transparent,
        child: InkWell(
          customBorder: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.fromLTRB(5, 7, 5, 6),
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: data.equipped
                    ? [
                        data.accent.withValues(alpha: 0.22),
                        const Color(0xE606101A),
                      ]
                    : const [_CoreUiStyle.itemBase, Color(0xDD06101A)],
              ),
              shape: BeveledRectangleBorder(
                borderRadius: BorderRadius.circular(7),
                side: BorderSide(color: borderColor, width: 1.1),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: ShapeDecoration(
                    color: data.accent.withValues(
                      alpha: data.locked ? 0.06 : 0.18,
                    ),
                    shape: StarBorder.polygon(
                      sides: 6,
                      pointRounding: 0.08,
                      side: BorderSide(
                        color: data.accent.withValues(
                          alpha: data.locked ? 0.24 : 0.68,
                        ),
                      ),
                    ),
                  ),
                  child: Icon(data.icon, color: data.accent, size: 18),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Center(
                    child: Text(
                      data.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoreAbilityData {
  const _CoreAbilityData({
    required this.icon,
    required this.name,
    required this.state,
    required this.actionLabel,
    required this.accent,
    this.combatSkill,
    this.passiveAbility,
    this.equipped = false,
    this.locked = false,
    this.enabled = false,
  });

  final IconData icon;
  final String name;
  final String state;
  final String actionLabel;
  final Color accent;
  final CoreCombatSkill? combatSkill;
  final CorePassiveAbility? passiveAbility;
  final bool equipped;
  final bool locked;
  final bool enabled;

  static List<_CoreAbilityData> forTab({
    required GameSnapshot snapshot,
    required _CoreAbilityTab tab,
    required int selectedPassiveSlotIndex,
  }) {
    return switch (tab) {
      _CoreAbilityTab.combatSkill => [
        _CoreAbilityData(
          icon: Icons.auto_awesome,
          name: '수호 광선',
          state: '5초마다 자동 발동',
          actionLabel: snapshot.coreCombatSkill == CoreCombatSkill.guardianBeam
              ? '장착중'
              : '장착',
          accent: const Color(0xFF8EE6FF),
          combatSkill: CoreCombatSkill.guardianBeam,
          equipped: snapshot.coreCombatSkill == CoreCombatSkill.guardianBeam,
          enabled: true,
        ),
        const _CoreAbilityData(
          icon: Icons.waves,
          name: '룬 파동',
          state: '후속 공격 스킬 준비중',
          actionLabel: '준비중',
          accent: Color(0xFFE7C66A),
          locked: true,
        ),
        const _CoreAbilityData(
          icon: Icons.hub_outlined,
          name: '연쇄 광휘',
          state: '챕터 2 이후 후보',
          actionLabel: '준비중',
          accent: Color(0xFF8FA8BA),
          locked: true,
        ),
      ],
      _CoreAbilityTab.passive => [
        _passiveData(
          snapshot: snapshot,
          selectedPassiveSlotIndex: selectedPassiveSlotIndex,
          ability: CorePassiveAbility.selfRepair,
          icon: Icons.healing_outlined,
          unlockText: '기본 해금',
          accent: const Color(0xFF72E0A2),
        ),
        _passiveData(
          snapshot: snapshot,
          selectedPassiveSlotIndex: selectedPassiveSlotIndex,
          ability: CorePassiveAbility.costSavingDesign,
          icon: Icons.construction_outlined,
          unlockText: '스테이지 1 클리어',
          accent: const Color(0xFFFFC66A),
        ),
        const _CoreAbilityData(
          icon: Icons.add_circle_outline,
          name: '공명 축전',
          state: '스테이지 2 클리어',
          actionLabel: '잠김',
          accent: Color(0xFF8FA8BA),
          locked: true,
        ),
      ],
    };
  }

  static _CoreAbilityData _passiveData({
    required GameSnapshot snapshot,
    required int selectedPassiveSlotIndex,
    required CorePassiveAbility ability,
    required IconData icon,
    required String unlockText,
    required Color accent,
  }) {
    final equipped = snapshot.corePassiveSlots.contains(ability);
    final unlocked = snapshot.unlockedCorePassiveAbilities.contains(ability);
    final slotUnlocked =
        selectedPassiveSlotIndex < snapshot.corePassiveSlotCount;
    final effectText = switch (ability) {
      CorePassiveAbility.selfRepair => '5라운드마다 넥서스 체력 1 회복',
      CorePassiveAbility.costSavingDesign => '포탑 건설 비용 15% 감소',
    };
    return _CoreAbilityData(
      icon: icon,
      name: ability.label,
      state: unlocked ? effectText : unlockText,
      actionLabel: equipped
          ? '장착중'
          : !unlocked
          ? '잠김'
          : !slotUnlocked
          ? '슬롯 잠김'
          : '장착',
      accent: accent,
      passiveAbility: ability,
      equipped: equipped,
      locked: !unlocked || !slotUnlocked,
      enabled: unlocked && slotUnlocked,
    );
  }
}

CorePassiveAbility? _corePassiveAt(GameSnapshot snapshot, int index) {
  return index < snapshot.corePassiveSlots.length
      ? snapshot.corePassiveSlots[index]
      : null;
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
                  gameResearchDefinitions[type]!.maxLevel,
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
  final leftStage = gameResearchDefinitions[left]!.requiredClearedStage;
  final rightStage = gameResearchDefinitions[right]!.requiredClearedStage;
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
                        : '${_researchTitle(l10n, active.type)} ${l10n.researchLevel(active.targetLevel - 1, gameResearchDefinitions[active.type]!.maxLevel)}',
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
        SizedBox(
          width: 86,
          child: GameButton(
            onPressed: () => Navigator.of(context).pop(false),
            label: l10n.cancel,
            compact: true,
            variant: GameButtonVariant.ghost,
            accentColor: GamePalette.metal,
          ),
        ),
        SizedBox(
          width: 94,
          child: GameButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: l10n.cancelResearchConfirm,
            compact: true,
            variant: GameButtonVariant.primary,
            accentColor: GamePalette.cyan,
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return;
  }
  game.cancelResearch(research.type);
}

Future<bool> _confirmUnlockCorePassiveSlot(
  BuildContext context, {
  required RuneNexusGame game,
  required GameSnapshot snapshot,
}) async {
  if (!snapshot.canUnlockCorePassiveSlot) {
    return false;
  }
  final slotNumber = snapshot.corePassiveSlotCount + 1;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF0B1725),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xAAE7C66A)),
      ),
      title: const Text(
        '패시브 슬롯을 해금할까요?',
        style: TextStyle(
          color: Color(0xFFE8FBFF),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Text(
        '$slotNumber번 코어 패시브 슬롯을 ${snapshot.corePassiveSlotUnlockCost} 룬으로 해금합니다.',
        style: const TextStyle(
          color: Color(0xFFB9D6E4),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        SizedBox(
          width: 76,
          child: GameButton(
            onPressed: () => Navigator.of(context).pop(false),
            label: '취소',
            compact: true,
            variant: GameButtonVariant.ghost,
            accentColor: GamePalette.metal,
          ),
        ),
        SizedBox(
          width: 82,
          child: GameButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: '해금',
            compact: true,
            variant: GameButtonVariant.primary,
            accentColor: GamePalette.gold,
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return false;
  }
  return game.unlockCorePassiveSlot();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth <= 330 ? 8.0 : 10.0;
        return Container(
          padding: EdgeInsets.all(padding),
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
      },
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
        final spacing = constraints.maxWidth <= 300 ? 6.0 : 8.0;
        final useTwoColumns = constraints.maxWidth >= 260;
        final tileWidth = useTwoColumns
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: spacing,
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
    final definition = gameResearchDefinitions[type]!;
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
                padding: const EdgeInsets.all(8),
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
                    const SizedBox(height: 6),
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
                    const SizedBox(height: 6),
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
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1.16,
        ),
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
      maxLines: 2,
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
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        border: Border.all(color: const Color(0x33485B68)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            levelText,
            style: const TextStyle(
              color: Color(0xFFB9D6E4),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (cost != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
            ),
          if (durationText != null)
            Text(
              durationText!,
              style: const TextStyle(
                color: Color(0xFFB9D6E4),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
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
    final definition = gameResearchDefinitions[type]!;
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
                    GameButton(
                      onPressed: canStart
                          ? () {
                              game.startResearch(type);
                              Navigator.of(context).pop();
                            }
                          : null,
                      label: l10n.startResearch,
                      compact: true,
                      height: 34,
                      variant: GameButtonVariant.primary,
                      accentColor: GamePalette.cyan,
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
  final definition = gameResearchDefinitions[type]!;
  final baseCost = definition.costForCurrentLevel(
    _researchLevel(snapshot, type),
  );
  final efficiencyRate =
      _researchLevel(snapshot, ResearchType.researchCostEfficiency) *
      RunProgression.researchCostEfficiencyPerLevel;
  return RunProgression.applyResearchCostEfficiency(baseCost, efficiencyRate);
}

int _researchDuration(GameSnapshot snapshot, ResearchType type) {
  final definition = gameResearchDefinitions[type]!;
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
    ResearchType.turretTargetPriority => l10n.tacticalCommand,
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
  final definition = gameResearchDefinitions[type]!;
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
    ResearchType.turretTargetPriority => _ResearchEffectText(
      l10n.researchTargetPriorityEffect,
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
    ResearchType.turretTargetPriority => Icons.ads_click,
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
            final spacing = constraints.maxWidth <= 320 ? 6.0 : 8.0;
            final useTwoColumns = constraints.maxWidth >= 280;
            final tileWidth = useTwoColumns
                ? (constraints.maxWidth - spacing) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: spacing,
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
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(8),
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
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CompactUpgradeValueSummary(
                currentValueText: valueText,
                nextValueText: nextValueText,
                enabled: enabled,
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 30,
                child: GameButton(
                  onPressed: enabled ? onPressed : null,
                  compact: true,
                  variant: GameButtonVariant.secondary,
                  accentColor: enabled
                      ? GamePalette.gold
                      : GamePalette.metalDim,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            l10n.levelUp,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
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
    return Wrap(
      spacing: 5,
      runSpacing: 2,
      children: [
        Text(
          '현재 $currentValueText',
          style: const TextStyle(
            color: Color(0xFFE8FBFF),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '다음 $nextValueText',
          style: TextStyle(
            color: enabled ? const Color(0xFFE7C66A) : const Color(0xFF6D7F8F),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 5),
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
          Icon(Icons.diamond_outlined, size: 12, color: foreground),
          const SizedBox(width: 2),
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
