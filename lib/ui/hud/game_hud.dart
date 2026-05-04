import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../data/definitions/demo_enemy_data.dart';
import '../../data/definitions/demo_gem_data.dart';
import '../../data/definitions/demo_turret_data.dart';
import '../../domain/combat/game_phase.dart';
import '../../domain/enemy/enemy_definition.dart';
import '../../domain/enemy/enemy_scaling.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/gem/gem_definition.dart';
import '../../domain/gem/gem_equip_rules.dart';
import '../../domain/gem/gem_type.dart';
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

class GameHud extends StatefulWidget {
  const GameHud({required this.game, super.key});

  final RuneNexusGame game;

  @override
  State<GameHud> createState() => _GameHudState();
}

class _GameHudState extends State<GameHud> {
  bool _showGemDebugPanel = false;
  EnemyType? _selectedPreviewEnemyType;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: widget.game.handleBoardPointerDown,
          onPointerMove: widget.game.handleBoardPointerMove,
          onPointerUp: widget.game.handleBoardPointerUp,
          onPointerCancel: widget.game.handleBoardPointerCancel,
          onPointerPanZoomStart: widget.game.handleTrackpadZoomStart,
          onPointerPanZoomUpdate: widget.game.handleTrackpadZoomUpdate,
          child: GameWidget(game: widget.game),
        ),
        SafeArea(
          child: ValueListenableBuilder<GameSnapshot>(
            valueListenable: widget.game.snapshotNotifier,
            builder: (context, snapshot, _) {
              final selectedPreviewEnemyType =
                  snapshot.phase == GamePhase.preparation &&
                      snapshot.nextWaveEnemyTypes.contains(
                        _selectedPreviewEnemyType,
                      )
                  ? _selectedPreviewEnemyType
                  : null;
              return Stack(
                children: [
                  if (selectedPreviewEnemyType != null)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          setState(() {
                            _selectedPreviewEnemyType = null;
                          });
                        },
                      ),
                    ),
                  _TopBar(
                    game: widget.game,
                    snapshot: snapshot,
                    showGemDebugPanel: _showGemDebugPanel,
                    onToggleGemDebugPanel: () {
                      setState(() {
                        _showGemDebugPanel = !_showGemDebugPanel;
                      });
                    },
                  ),
                  if (_showGemDebugPanel)
                    Positioned(
                      top: 78,
                      right: 12,
                      child: _GemDebugPanel(
                        game: widget.game,
                        snapshot: snapshot,
                      ),
                    ),
                  _BottomBar(
                    game: widget.game,
                    snapshot: snapshot,
                    selectedPreviewEnemyType: selectedPreviewEnemyType,
                    onSelectPreviewEnemy: (type) {
                      setState(() {
                        _selectedPreviewEnemyType =
                            selectedPreviewEnemyType == type ? null : type;
                      });
                    },
                  ),
                  if (snapshot.phase == GamePhase.reward)
                    Positioned.fill(
                      child: _RewardOverlay(
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
