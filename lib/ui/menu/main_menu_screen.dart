import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/definitions/game_daily_quest_data.dart';
import '../../data/definitions/game_core_passive_tree_data.dart';
import '../../data/definitions/game_research_data.dart';
import '../../data/definitions/game_stage_data.dart';
import '../../data/definitions/game_turret_data.dart';
import '../../data/definitions/game_turret_module_data.dart';
import '../../data/definitions/game_weekly_quest_data.dart';
import '../../domain/account/account_session.dart';
import '../../domain/combat/game_phase.dart';
import '../../domain/core/core_ability.dart';
import '../../domain/core/core_passive_tree.dart';
import '../../domain/daily_quest/daily_quest_type.dart';
import '../../domain/economy/weekly_reward_claim.dart';
import '../../domain/gem/gem_type.dart';
import '../../domain/research/research_definition.dart';
import '../../domain/research/research_progress.dart';
import '../../domain/research/research_type.dart';
import '../../domain/turret/turret_type.dart';
import '../../domain/turret_module/turret_module_type.dart';
import '../../game/game_snapshot.dart';
import '../../game/rendering/turret_shape_renderer.dart';
import '../../game/rune_nexus_game.dart';
import '../../game/systems/run_progression.dart';
import '../../l10n/rune_nexus_localizations.dart';
import '../game/game_ui.dart';
import '../widgets/rune_balance_card.dart';

part 'main_menu_core.dart';
part 'main_menu_account.dart';
part 'main_menu_core_tree.dart';
part 'main_menu_core_tree_summary.dart';
part 'main_menu_core_tree_world.dart';
part 'main_menu_core_tree_connections.dart';
part 'main_menu_core_tree_details.dart';
part 'main_menu_daily_quest.dart';
part 'main_menu_debug_panel.dart';
part 'main_menu_frame.dart';
part 'main_menu_permanent_upgrades.dart';
part 'main_menu_research.dart';
part 'main_menu_research_slots.dart';
part 'main_menu_research_catalog.dart';
part 'main_menu_research_details.dart';
part 'main_menu_stage.dart';
part 'main_menu_stage_list.dart';
part 'main_menu_stage_details.dart';
part 'main_menu_stage_rewards.dart';
part 'main_menu_turret_modules.dart';
part 'main_menu_turret_modules_disassemble.dart';
part 'main_menu_turret_modules_draw.dart';
part 'main_menu_turret_modules_equipment.dart';
part 'main_menu_turret_modules_inventory.dart';
part 'main_menu_weekly_quest.dart';

const _showMapEditor = bool.fromEnvironment(
  'RUNE_NEXUS_DEBUG_PANEL',
  defaultValue: false,
);

enum MainMenuTab { stage, core, permanentUpgrades, research, turretModules }

enum _PermanentUpgradeGroup { combat, economy }

const int _stageChapterSize = 5;
const int _visibleStageChapterCount =
    (RunProgression.maxStageCount + _stageChapterSize - 1) ~/ _stageChapterSize;
const double _stageRowHeight = 54;
const Color _diamondCurrencyColor = Color(0xFF8EE6FF);
const Color _researchInstantCompleteAccent = Color(0xFF0F5D72);

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({
    required this.game,
    required this.snapshot,
    this.snapshotListenable,
    required this.selectedTab,
    required this.onSelectTab,
    required this.onStartStage,
    this.accountSession = const AccountSession.guest(),
    this.onConnectPlayGames,
    this.onConnectGoogle,
    this.onCreateLegacyTransfer,
    this.onSyncAccount,
    this.onSignOut,
    this.onClaimWeeklyReward,
    this.onOpenMapEditor,
    super.key,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final ValueListenable<GameSnapshot>? snapshotListenable;
  final MainMenuTab selectedTab;
  final ValueChanged<MainMenuTab> onSelectTab;
  final ValueChanged<int> onStartStage;
  final AccountSession accountSession;
  final VoidCallback? onConnectPlayGames;
  final VoidCallback? onConnectGoogle;
  final VoidCallback? onCreateLegacyTransfer;
  final VoidCallback? onSyncAccount;
  final VoidCallback? onSignOut;
  final Future<void> Function(WeeklyRewardClaimTarget target)?
  onClaimWeeklyReward;
  final VoidCallback? onOpenMapEditor;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  _PermanentUpgradeGroup _selectedUpgradeGroup = _PermanentUpgradeGroup.combat;
  final _turretModuleMenuKey = GlobalKey<_TurretModuleMenuState>();
  List<TurretModuleInventoryItem> _turretModuleDrawResults = const [];
  bool _showMenuDebugPanel = false;
  Timer? _researchClockTimer;

  GameSnapshot get _currentSnapshot =>
      widget.snapshotListenable?.value ?? widget.snapshot;

  @override
  void initState() {
    super.initState();
    widget.snapshotListenable?.addListener(_handleSnapshotChanged);
    _syncResearchClockTimer();
  }

  @override
  void didUpdateWidget(covariant MainMenuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshotListenable != widget.snapshotListenable) {
      oldWidget.snapshotListenable?.removeListener(_handleSnapshotChanged);
      widget.snapshotListenable?.addListener(_handleSnapshotChanged);
    }
    _syncResearchClockTimer();
  }

  @override
  void dispose() {
    widget.snapshotListenable?.removeListener(_handleSnapshotChanged);
    _researchClockTimer?.cancel();
    super.dispose();
  }

  void _handleSnapshotChanged() {
    _syncResearchClockTimer();
  }

  void _syncResearchClockTimer() {
    final needsClock =
        widget.selectedTab != MainMenuTab.research &&
        _currentSnapshot.activeResearches.isNotEmpty;
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
      if (widget.selectedTab == MainMenuTab.research ||
          _currentSnapshot.activeResearches.isEmpty) {
        _researchClockTimer?.cancel();
        _researchClockTimer = null;
        return;
      }
      widget.game.refreshResearchProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = widget.selectedTab;
    final compactTopBar = MediaQuery.sizeOf(context).width < 430;
    const debugBarHeight = _showMapEditor ? 44.0 : 0.0;
    final menuTopPadding =
        debugBarHeight + (selectedTab == MainMenuTab.stage ? 76.0 : 54.0);
    return Container(
      color: GamePalette.backdrop,
      child: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _MainMenuBackdrop()),
            if (selectedTab == MainMenuTab.stage)
              const Positioned(
                top: 10 + debugBarHeight,
                left: 0,
                right: 0,
                child: _MenuLogo(),
              ),
            Positioned.fill(
              child: _MainMenuSnapshotLayer(
                game: widget.game,
                snapshot: widget.snapshot,
                snapshotListenable: widget.snapshotListenable,
                selectedTab: selectedTab,
                selectedUpgradeGroup: _selectedUpgradeGroup,
                showMenuDebugPanel: _showMenuDebugPanel,
                compactTopBar: compactTopBar,
                headerTopOffset: debugBarHeight,
                menuTopPadding: menuTopPadding,
                onStartStage: widget.onStartStage,
                accountSession: widget.accountSession,
                onOpenAccount: () => _openAccountDialog(context),
                onClaimWeeklyReward: widget.onClaimWeeklyReward,
                turretModuleMenuKey: _turretModuleMenuKey,
                onTurretModuleDrawResults: _showTurretModuleDrawResults,
                onCloseDebugPanel: () {
                  setState(() {
                    _showMenuDebugPanel = false;
                  });
                },
              ),
            ),
            if (_showMapEditor)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
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
            if (selectedTab == MainMenuTab.turretModules &&
                _turretModuleDrawResults.isNotEmpty)
              Positioned.fill(
                child: _TurretModuleDrawResultLayer(
                  results: _turretModuleDrawResults,
                  onClose: _closeTurretModuleDrawResults,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showTurretModuleDrawResults(List<TurretModuleInventoryItem> results) {
    if (results.isEmpty) {
      return;
    }
    setState(() {
      _turretModuleDrawResults = List.unmodifiable(results);
    });
  }

  Future<void> _openAccountDialog(BuildContext context) {
    return showGameDialog<void>(
      context: context,
      builder: (context) => _AccountDialog(
        session: widget.accountSession,
        onConnectPlayGames: widget.onConnectPlayGames,
        onConnectGoogle: widget.onConnectGoogle,
        onCreateLegacyTransfer: widget.onCreateLegacyTransfer,
        onSyncAccount: widget.onSyncAccount,
        onSignOut: widget.onSignOut,
      ),
    );
  }

  void _closeTurretModuleDrawResults() {
    final best = _bestDrawResult(_turretModuleDrawResults);
    if (best != null) {
      _turretModuleMenuKey.currentState?.focusDrawResult(best);
    }
    setState(() {
      _turretModuleDrawResults = const [];
    });
  }
}

class _MainMenuSnapshotLayer extends StatelessWidget {
  const _MainMenuSnapshotLayer({
    required this.game,
    required this.snapshot,
    required this.snapshotListenable,
    required this.selectedTab,
    required this.selectedUpgradeGroup,
    required this.showMenuDebugPanel,
    required this.compactTopBar,
    required this.headerTopOffset,
    required this.menuTopPadding,
    required this.onStartStage,
    required this.accountSession,
    required this.onOpenAccount,
    required this.onClaimWeeklyReward,
    required this.turretModuleMenuKey,
    required this.onTurretModuleDrawResults,
    required this.onCloseDebugPanel,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final ValueListenable<GameSnapshot>? snapshotListenable;
  final MainMenuTab selectedTab;
  final _PermanentUpgradeGroup selectedUpgradeGroup;
  final bool showMenuDebugPanel;
  final bool compactTopBar;
  final double headerTopOffset;
  final double menuTopPadding;
  final ValueChanged<int> onStartStage;
  final AccountSession accountSession;
  final VoidCallback onOpenAccount;
  final Future<void> Function(WeeklyRewardClaimTarget target)?
  onClaimWeeklyReward;
  final GlobalKey<_TurretModuleMenuState> turretModuleMenuKey;
  final ValueChanged<List<TurretModuleInventoryItem>> onTurretModuleDrawResults;
  final VoidCallback onCloseDebugPanel;

  @override
  Widget build(BuildContext context) {
    final listenable = snapshotListenable;
    if (listenable == null) {
      return _MainMenuSnapshotContent(
        game: game,
        snapshot: snapshot,
        selectedTab: selectedTab,
        selectedUpgradeGroup: selectedUpgradeGroup,
        showMenuDebugPanel: showMenuDebugPanel,
        compactTopBar: compactTopBar,
        headerTopOffset: headerTopOffset,
        menuTopPadding: menuTopPadding,
        onStartStage: onStartStage,
        accountSession: accountSession,
        onOpenAccount: onOpenAccount,
        onClaimWeeklyReward: onClaimWeeklyReward,
        turretModuleMenuKey: turretModuleMenuKey,
        onTurretModuleDrawResults: onTurretModuleDrawResults,
        onCloseDebugPanel: onCloseDebugPanel,
      );
    }
    return ValueListenableBuilder<GameSnapshot>(
      valueListenable: listenable,
      builder: (context, snapshot, _) {
        return _MainMenuSnapshotContent(
          game: game,
          snapshot: snapshot,
          selectedTab: selectedTab,
          selectedUpgradeGroup: selectedUpgradeGroup,
          showMenuDebugPanel: showMenuDebugPanel,
          compactTopBar: compactTopBar,
          headerTopOffset: headerTopOffset,
          menuTopPadding: menuTopPadding,
          onStartStage: onStartStage,
          accountSession: accountSession,
          onOpenAccount: onOpenAccount,
          onClaimWeeklyReward: onClaimWeeklyReward,
          turretModuleMenuKey: turretModuleMenuKey,
          onTurretModuleDrawResults: onTurretModuleDrawResults,
          onCloseDebugPanel: onCloseDebugPanel,
        );
      },
    );
  }
}

class _MainMenuSnapshotContent extends StatelessWidget {
  const _MainMenuSnapshotContent({
    required this.game,
    required this.snapshot,
    required this.selectedTab,
    required this.selectedUpgradeGroup,
    required this.showMenuDebugPanel,
    required this.compactTopBar,
    required this.headerTopOffset,
    required this.menuTopPadding,
    required this.onStartStage,
    required this.accountSession,
    required this.onOpenAccount,
    required this.onClaimWeeklyReward,
    required this.turretModuleMenuKey,
    required this.onTurretModuleDrawResults,
    required this.onCloseDebugPanel,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final MainMenuTab selectedTab;
  final _PermanentUpgradeGroup selectedUpgradeGroup;
  final bool showMenuDebugPanel;
  final bool compactTopBar;
  final double headerTopOffset;
  final double menuTopPadding;
  final ValueChanged<int> onStartStage;
  final AccountSession accountSession;
  final VoidCallback onOpenAccount;
  final Future<void> Function(WeeklyRewardClaimTarget target)?
  onClaimWeeklyReward;
  final GlobalKey<_TurretModuleMenuState> turretModuleMenuKey;
  final ValueChanged<List<TurretModuleInventoryItem>> onTurretModuleDrawResults;
  final VoidCallback onCloseDebugPanel;

  @override
  Widget build(BuildContext context) {
    final menuHorizontalPadding = selectedTab == MainMenuTab.research
        ? 10.0
        : 16.0;
    final menuBottomPadding = selectedTab == MainMenuTab.permanentUpgrades
        ? 146.0
        : selectedTab == MainMenuTab.stage
        ? 62.0
        : 92.0;
    return Stack(
      children: [
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
                        key: const ValueKey('main-menu-content-panel'),
                        child: _StageMenu(
                          game: game,
                          snapshot: snapshot,
                          onStartStage: onStartStage,
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
                menuHorizontalPadding,
                menuTopPadding,
                menuHorizontalPadding,
                menuBottomPadding,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (selectedTab == MainMenuTab.research)
                      KeyedSubtree(
                        key: const ValueKey('research-content'),
                        child: _ResearchMenu(game: game, snapshot: snapshot),
                      )
                    else if (selectedTab == MainMenuTab.core)
                      KeyedSubtree(
                        key: const ValueKey('core-content'),
                        child: _CoreMenu(game: game, snapshot: snapshot),
                      )
                    else
                      _MainMenuPanel(
                        key: const ValueKey('main-menu-content-panel'),
                        child: switch (selectedTab) {
                          MainMenuTab.permanentUpgrades =>
                            _PermanentUpgradeMenu(
                              game: game,
                              snapshot: snapshot,
                              group: selectedUpgradeGroup,
                            ),
                          MainMenuTab.turretModules => _TurretModuleMenu(
                            key: turretModuleMenuKey,
                            game: game,
                            snapshot: snapshot,
                            onDrawResults: onTurretModuleDrawResults,
                          ),
                          MainMenuTab.core ||
                          MainMenuTab.research ||
                          MainMenuTab.stage => const SizedBox.shrink(),
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (selectedTab == MainMenuTab.stage)
          Positioned(
            top: headerTopOffset + (compactTopBar ? 4 : 10),
            left: 16,
            child: Row(
              children: [
                _DailyQuestEntryButton(
                  snapshot: snapshot,
                  onPressed: () =>
                      _openDailyQuestDialog(context, game, onClaimWeeklyReward),
                ),
                const SizedBox(width: 8),
                _AccountEntryButton(
                  session: accountSession,
                  onPressed: onOpenAccount,
                ),
              ],
            ),
          ),
        if (selectedTab == MainMenuTab.stage)
          Positioned(
            top: headerTopOffset + (compactTopBar ? 4 : 10),
            right: 16,
            child: RuneBalanceCard(
              key: const ValueKey('menu-currency-balance'),
              runes: snapshot.runes,
              diamonds: snapshot.diamonds,
              compact: compactTopBar,
              frameless: true,
            ),
          )
        else
          Positioned(
            top: headerTopOffset,
            left: 0,
            right: 0,
            child: _MenuResourceBar(
              key: const ValueKey('menu-resource-bar'),
              selectedTab: selectedTab,
              runes: snapshot.runes,
              diamonds: snapshot.diamonds,
              turretModuleTickets: snapshot.turretModuleTickets,
              accountSession: accountSession,
              onOpenAccount: onOpenAccount,
            ),
          ),
        if (_showMapEditor && showMenuDebugPanel)
          Positioned(
            top: headerTopOffset + 58,
            left: 16,
            right: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: _MainMenuDebugPanel(
                  game: game,
                  snapshot: snapshot,
                  onClose: onCloseDebugPanel,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MainMenuPanel extends StatelessWidget {
  const _MainMenuPanel({required this.child, super.key});

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
