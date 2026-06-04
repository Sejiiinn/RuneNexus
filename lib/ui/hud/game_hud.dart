import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../domain/combat/game_phase.dart';
import '../../game/game_snapshot.dart';
import '../../game/rune_nexus_game.dart';
import '../menu/result_overlay.dart';
import 'bottom_bar.dart';
import 'hud_common.dart';
import 'reward_overlay.dart';
import 'top_bar.dart';

const _showDebugPanel = bool.fromEnvironment(
  'RUNE_NEXUS_DEBUG_PANEL',
  defaultValue: false,
);

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
                _HudTopBarLayer(
                  game: widget.game,
                  showDebugButton: _showDebugPanel,
                  showGemDebugPanel: _showGemDebugPanel,
                  onOpenMainMenu: _handleOpenMainMenu,
                  onToggleGemDebugPanel: () {
                    setState(() {
                      _showGemDebugPanel = !_showGemDebugPanel;
                    });
                  },
                ),
                if (_showDebugPanel && _showGemDebugPanel)
                  _HudGemDebugLayer(game: widget.game),
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
    required this.showDebugButton,
    required this.showGemDebugPanel,
    required this.onOpenMainMenu,
    required this.onToggleGemDebugPanel,
  });

  final RuneNexusGame game;
  final bool showDebugButton;
  final bool showGemDebugPanel;
  final ValueChanged<GameSnapshot> onOpenMainMenu;
  final VoidCallback onToggleGemDebugPanel;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameSnapshot>(
      valueListenable: game.snapshotNotifier,
      builder: (context, snapshot, _) {
        return HudTopBar(
          snapshot: snapshot,
          showDebugButton: showDebugButton,
          showGemDebugPanel: showGemDebugPanel,
          onOpenMainMenu: () => onOpenMainMenu(snapshot),
          onToggleGemDebugPanel: onToggleGemDebugPanel,
        );
      },
    );
  }
}

class _HudGemDebugLayer extends StatelessWidget {
  const _HudGemDebugLayer({required this.game});

  final RuneNexusGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameSnapshot>(
      valueListenable: game.snapshotNotifier,
      builder: (context, snapshot, _) {
        return Positioned(
          top: 112,
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
            child: HudRestoreRunOverlay(game: game, snapshot: snapshot),
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
