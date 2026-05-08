import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../data/definitions/demo_enemy_data.dart';
import '../../data/definitions/demo_gem_data.dart';
import '../../data/definitions/demo_run_upgrade_data.dart';
import '../../data/definitions/demo_turret_data.dart';
import '../../domain/combat/auto_start_mode.dart';
import '../../domain/combat/game_phase.dart';
import '../../domain/combat/run_panel_tab.dart';
import '../../domain/enemy/enemy_definition.dart';
import '../../domain/enemy/enemy_scaling.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/gem/gem_definition.dart';
import '../../domain/gem/gem_equip_rules.dart';
import '../../domain/gem/gem_type.dart';
import '../../domain/run_upgrade/run_upgrade_definition.dart';
import '../../domain/run_upgrade/run_upgrade_type.dart';
import '../../domain/turret/attack_tag.dart';
import '../../domain/turret/damage_family.dart';
import '../../domain/turret/turret_definition.dart';
import '../../domain/turret/turret_type.dart';
import '../../game/game_snapshot.dart';
import '../../game/rendering/enemy_shape_renderer.dart';
import '../../game/rendering/turret_shape_renderer.dart';
import '../../game/rune_nexus_game.dart';
import '../menu/result_overlay.dart';

part 'top_bar.dart';
part 'bottom_bar.dart';
part 'gem_equip_panel.dart';
part 'reward_overlay.dart';
part 'hud_common.dart';

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
      final action = await showDialog<_StageMenuAction>(
        context: context,
        builder: (context) => _StageMenuDialog(snapshot: snapshot),
      );
      if (!mounted || action == null) {
        return;
      }

      if (action == _StageMenuAction.openMainMenu) {
        widget.game.suspendCurrentRunForMenu();
        await widget.game.saveNow();
        if (!mounted) {
          return;
        }
        shouldResumeCombat = false;
        widget.onOpenStageSelect?.call();
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _StageEndConfirmDialog(snapshot: snapshot),
      );
      if (!mounted || confirmed != true) {
        return;
      }

      await widget.game.settleCurrentRunAsFailure();
      await widget.game.saveNow();
      if (!mounted) {
        return;
      }
      shouldResumeCombat = false;
      widget.onOpenStageSelect?.call();
    } finally {
      if (shouldResumeCombat) {
        widget.game.resumeEngine();
      }
    }
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
            child: ValueListenableBuilder<GameSnapshot>(
              valueListenable: widget.game.snapshotNotifier,
              builder: (context, snapshot, _) {
                return Stack(
                  children: [
                    _TopBar(
                      snapshot: snapshot,
                      showDebugButton: _showDebugPanel,
                      showGemDebugPanel: _showGemDebugPanel,
                      onOpenMainMenu: () => _handleOpenMainMenu(snapshot),
                      onToggleGemDebugPanel: () {
                        setState(() {
                          _showGemDebugPanel = !_showGemDebugPanel;
                        });
                      },
                    ),
                    if (_showDebugPanel && _showGemDebugPanel)
                      Positioned(
                        top: 78,
                        right: 12,
                        child: _GemDebugPanel(
                          game: widget.game,
                          snapshot: snapshot,
                        ),
                      ),
                    _BottomBar(game: widget.game, snapshot: snapshot),
                    if (snapshot.phase == GamePhase.reward)
                      Positioned.fill(
                        child: _RewardOverlay(
                          game: widget.game,
                          snapshot: snapshot,
                        ),
                      ),
                    if (snapshot.phase == GamePhase.restored)
                      Positioned.fill(
                        child: _RestoreRunOverlay(
                          game: widget.game,
                          snapshot: snapshot,
                        ),
                      ),
                    if (snapshot.phase == GamePhase.success ||
                        snapshot.phase == GamePhase.failure)
                      Positioned.fill(
                        child: ResultOverlay(
                          game: widget.game,
                          snapshot: snapshot,
                          onOpenStageSelect: widget.onOpenStageSelect,
                          onOpenPermanentUpgrades:
                              widget.onOpenPermanentUpgrades,
                          onStartStage: widget.onStartStage,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
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
