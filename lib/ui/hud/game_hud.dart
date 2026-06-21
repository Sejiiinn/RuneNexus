import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../domain/combat/game_phase.dart';
import '../../game/game_snapshot.dart';
import '../../game/rune_nexus_game.dart';
import '../game/game_ui.dart';
import '../menu/result_overlay.dart';
import 'bottom_bar.dart';
import 'hud_common.dart';
import 'reward_overlay.dart';
import 'top_bar.dart';

const _showDebugPanel = bool.fromEnvironment(
  'RUNE_NEXUS_DEBUG_PANEL',
  defaultValue: false,
);
const _hudDebugBarHeight = 44.0;

class GameHud extends StatefulWidget {
  const GameHud({
    required this.game,
    this.showControls = true,
    this.onOpenStageSelect,
    this.onOpenPermanentUpgrades,
    this.onStartStage,
    super.key,
  });

  final RuneNexusGame game;
  final bool showControls;
  final VoidCallback? onOpenStageSelect;
  final VoidCallback? onOpenPermanentUpgrades;
  final ValueChanged<int>? onStartStage;

  @override
  State<GameHud> createState() => _GameHudState();
}

class _GameHudState extends State<GameHud> {
  bool _showGemDebugPanel = false;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onInactive: widget.game.saveNow,
      onPause: widget.game.saveNow,
      onDetach: widget.game.saveNow,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _handleOpenMainMenu(GameSnapshot snapshot) async {
    if (widget.onOpenStageSelect == null) {
      return;
    }

    var shouldResumeCombat = snapshot.phase == GamePhase.wave;
    if (shouldResumeCombat) {
      widget.game.pauseEngine();
    }
    try {
      final action = await showDialog<HudStageMenuAction>(
        context: context,
        builder: (context) => HudStageMenuDialog(snapshot: snapshot),
      );
      if (!mounted || action == null) {
        return;
      }

      if (action == HudStageMenuAction.openMainMenu) {
        shouldResumeCombat = !await _confirmReturnToMenu();
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => HudStageEndConfirmDialog(snapshot: snapshot),
      );
      if (!mounted || confirmed != true) {
        return;
      }

      shouldResumeCombat = !await _confirmEndStage();
    } finally {
      if (shouldResumeCombat) {
        widget.game.resumeEngine();
      }
    }
  }

  Future<bool> _confirmReturnToMenu() async {
    widget.game.suspendCurrentRunForMenu();
    await widget.game.saveNow();
    if (!mounted) {
      return false;
    }
    widget.onOpenStageSelect?.call();
    return true;
  }

  Future<bool> _confirmEndStage() async {
    await widget.game.settleCurrentRunAsFailure();
    await widget.game.saveNow();
    if (!mounted) {
      return false;
    }
    widget.onOpenStageSelect?.call();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: !widget.showControls,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: widget.game.handleBoardPointerDown,
            onPointerMove: widget.game.handleBoardPointerMove,
            onPointerUp: widget.game.handleBoardPointerUp,
            onPointerCancel: widget.game.handleBoardPointerCancel,
            onPointerPanZoomStart: widget.game.handleTrackpadZoomStart,
            onPointerPanZoomUpdate: widget.game.handleTrackpadZoomUpdate,
            child: GameWidget(
              game: widget.game,
              loadingBuilder: (_) => const _GameLoadingScreen(),
            ),
          ),
        ),
        if (widget.showControls)
          SafeArea(
            child: Stack(
              children: [
                if (_showDebugPanel)
                  _HudDebugShortcuts(
                    testPanelOpen: _showGemDebugPanel,
                    onToggleTestPanel: () {
                      setState(() {
                        _showGemDebugPanel = !_showGemDebugPanel;
                      });
                    },
                  ),
                _HudTopBarLayer(
                  game: widget.game,
                  topInset: _showDebugPanel ? _hudDebugBarHeight : 0,
                  onOpenMainMenu: _handleOpenMainMenu,
                ),
                if (_showDebugPanel && _showGemDebugPanel)
                  _HudGemDebugLayer(
                    game: widget.game,
                    topInset: _hudDebugBarHeight,
                  ),
                _HudBottomBarLayer(game: widget.game),
                _HudOverlayLayer(
                  game: widget.game,
                  onOpenStageSelect: widget.onOpenStageSelect,
                  onOpenPermanentUpgrades: widget.onOpenPermanentUpgrades,
                  onStartStage: widget.onStartStage,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HudTopBarLayer extends StatelessWidget {
  const _HudTopBarLayer({
    required this.game,
    required this.topInset,
    required this.onOpenMainMenu,
  });

  final RuneNexusGame game;
  final double topInset;
  final ValueChanged<GameSnapshot> onOpenMainMenu;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameSnapshot>(
      valueListenable: game.snapshotNotifier,
      builder: (context, snapshot, _) {
        return HudTopBar(
          snapshot: snapshot,
          topInset: topInset,
          onOpenMainMenu: () => onOpenMainMenu(snapshot),
        );
      },
    );
  }
}

class _HudDebugShortcuts extends StatelessWidget {
  const _HudDebugShortcuts({
    required this.testPanelOpen,
    required this.onToggleTestPanel,
  });

  final bool testPanelOpen;
  final VoidCallback onToggleTestPanel;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: _hudDebugBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: const BoxDecoration(
          color: Color(0xF203070E),
          border: Border(bottom: BorderSide(color: Color(0x66FFB55E))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 102,
              child: GameButton(
                onPressed: onToggleTestPanel,
                label: '테스트 패널',
                icon: const Icon(Icons.tune, size: 15),
                compact: true,
                selected: testPanelOpen,
                variant: GameButtonVariant.ghost,
                accentColor: const Color(0xFFFFB55E),
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudGemDebugLayer extends StatelessWidget {
  const _HudGemDebugLayer({required this.game, required this.topInset});

  final RuneNexusGame game;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameSnapshot>(
      valueListenable: game.snapshotNotifier,
      builder: (context, snapshot, _) {
        return Positioned(
          top: 112 + topInset,
          right: 12,
          bottom: 212,
          child: HudGemDebugPanel(game: game, snapshot: snapshot),
        );
      },
    );
  }
}

class _HudBottomBarLayer extends StatelessWidget {
  const _HudBottomBarLayer({required this.game});

  final RuneNexusGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameSnapshot>(
      valueListenable: game.snapshotNotifier,
      builder: (context, snapshot, _) {
        return HudBottomBar(game: game, snapshot: snapshot);
      },
    );
  }
}

class _HudOverlayLayer extends StatelessWidget {
  const _HudOverlayLayer({
    required this.game,
    required this.onOpenStageSelect,
    required this.onOpenPermanentUpgrades,
    required this.onStartStage,
  });

  final RuneNexusGame game;
  final VoidCallback? onOpenStageSelect;
  final VoidCallback? onOpenPermanentUpgrades;
  final ValueChanged<int>? onStartStage;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameSnapshot>(
      valueListenable: game.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.phase == GamePhase.reward) {
          return Positioned.fill(
            child: HudRewardOverlay(game: game, snapshot: snapshot),
          );
        }
        if (snapshot.phase == GamePhase.restored) {
          return Positioned.fill(
            child: HudRestoreRunOverlay(
              game: game,
              snapshot: snapshot,
              onOpenStageSelect: onOpenStageSelect,
            ),
          );
        }
        if (snapshot.phase == GamePhase.success ||
            snapshot.phase == GamePhase.failure) {
          return Positioned.fill(
            child: ResultOverlay(
              game: game,
              snapshot: snapshot,
              onOpenStageSelect: onOpenStageSelect,
              onOpenPermanentUpgrades: onOpenPermanentUpgrades,
              onStartStage: onStartStage,
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _GameLoadingScreen extends StatelessWidget {
  const _GameLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF07111D),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF8EE6FF), size: 34),
            SizedBox(height: 14),
            Text(
              '전투 준비 중',
              style: TextStyle(
                color: Color(0xFFE8FBFF),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
