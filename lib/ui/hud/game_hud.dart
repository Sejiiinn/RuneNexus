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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.game,
    required this.snapshot,
    required this.showGemDebugPanel,
    required this.onToggleGemDebugPanel,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final bool showGemDebugPanel;
  final VoidCallback onToggleGemDebugPanel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xDD091624),
          border: Border.all(color: const Color(0x8833D8FF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Metric(label: '골드', value: '${snapshot.gold}'),
            const SizedBox(width: 14),
            _Metric(
              label: 'Nexus',
              value: '${snapshot.nexusHp}/${snapshot.maxNexusHp}',
            ),
            const SizedBox(width: 14),
            _Metric(
              label: '라운드',
              value: '${snapshot.round}/${snapshot.maxRound}',
            ),
            const SizedBox(width: 14),
            _SpeedControl(snapshot: snapshot, game: game),
            const SizedBox(width: 6),
            SizedBox(
              width: 30,
              height: 28,
              child: IconButton(
                onPressed: onToggleGemDebugPanel,
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: showGemDebugPanel
                      ? const Color(0xFF8EE6FF)
                      : Colors.transparent,
                  side: BorderSide(
                    color: showGemDebugPanel
                        ? const Color(0xFF8EE6FF)
                        : const Color(0x5533D8FF),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: Icon(
                  Icons.diamond_outlined,
                  size: 17,
                  color: showGemDebugPanel
                      ? const Color(0xFF07111D)
                      : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GemDebugPanel extends StatelessWidget {
  const _GemDebugPanel({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xF0091624),
        border: Border.all(color: const Color(0xAA33D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '테스트 라운드',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _DebugRoundButton(
                label: '-1',
                enabled: snapshot.round > 1,
                onPressed: () => game.debugSetRound(snapshot.round - 1),
              ),
              const SizedBox(width: 5),
              _DebugRoundButton(
                label: '+1',
                enabled: snapshot.round < snapshot.maxRound,
                onPressed: () => game.debugSetRound(snapshot.round + 1),
              ),
              const SizedBox(width: 5),
              _DebugRoundButton(
                label: '+5',
                enabled: snapshot.round < snapshot.maxRound,
                onPressed: () => game.debugSetRound(snapshot.round + 5),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              _DebugRoundButton(
                label: '10R',
                enabled: snapshot.round != 10,
                onPressed: () => game.debugSetRound(10),
              ),
              const SizedBox(width: 5),
              _DebugRoundButton(
                label: '25R',
                enabled: snapshot.round != 25,
                onPressed: () => game.debugSetRound(25),
              ),
              const SizedBox(width: 5),
              _DebugRoundButton(
                label: '50R',
                enabled: snapshot.round != snapshot.maxRound,
                onPressed: () => game.debugSetRound(snapshot.maxRound),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              _DebugRoundButton(
                label: '스테이지 초기화',
                enabled: true,
                onPressed: game.restartDemo,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '테스트 골드',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _DebugRoundButton(
                label: '+100',
                enabled: true,
                onPressed: () => game.debugAddGold(100),
              ),
              const SizedBox(width: 5),
              _DebugRoundButton(
                label: '+500',
                enabled: true,
                onPressed: () => game.debugAddGold(500),
              ),
              const SizedBox(width: 5),
              _DebugRoundButton(
                label: '+1000',
                enabled: true,
                onPressed: () => game.debugAddGold(1000),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '테스트 젬',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: GemType.values.map((type) {
              final gem = demoGems[type]!;
              return SizedBox(
                width: 70,
                height: 34,
                child: OutlinedButton.icon(
                  onPressed: () => game.grantGem(type),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: gem.color),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  icon: Icon(gem.icon, color: gem.color, size: 14),
                  label: Text(
                    gem.name,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DebugRoundButton extends StatelessWidget {
  const _DebugRoundButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 28,
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0x7733D8FF)),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          child: Text(label, style: const TextStyle(fontSize: 11)),
        ),
      ),
    );
  }
}

class _SpeedControl extends StatelessWidget {
  const _SpeedControl({required this.snapshot, required this.game});

  final GameSnapshot snapshot;
  final RuneNexusGame game;

  @override
  Widget build(BuildContext context) {
    const speeds = [1.0, 2.0, 4.0];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: speeds.map((speed) {
        final selected = snapshot.speedMultiplier == speed;
        return Padding(
          padding: const EdgeInsets.only(left: 3),
          child: SizedBox(
            width: 30,
            height: 28,
            child: OutlinedButton(
              onPressed: () => game.setSpeedMultiplier(speed),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: selected
                    ? const Color(0xFF07111D)
                    : Colors.white,
                backgroundColor: selected
                    ? const Color(0xFF8EE6FF)
                    : Colors.transparent,
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF8EE6FF)
                      : const Color(0x5533D8FF),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                '${speed.toInt()}x',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.game,
    required this.snapshot,
    required this.selectedPreviewEnemyType,
    required this.onSelectPreviewEnemy,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final EnemyType? selectedPreviewEnemyType;
  final ValueChanged<EnemyType> onSelectPreviewEnemy;

  @override
  Widget build(BuildContext context) {
    final canPrepare = snapshot.phase == GamePhase.preparation;
    final statusText = switch (snapshot.phase) {
      GamePhase.preparation => '다음 라운드',
      GamePhase.wave => '전투 진행 중',
      GamePhase.reward => '젬 보상 선택 대기',
      GamePhase.success => '방어 성공',
      GamePhase.failure => '방어 실패',
    };

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xE607111D),
          border: Border.all(color: const Color(0x8833D8FF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: snapshot.phase == GamePhase.preparation
                      ? _WavePreview(
                          snapshot: snapshot,
                          selectedType: selectedPreviewEnemyType,
                          onSelectType: onSelectPreviewEnemy,
                        )
                      : Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFE8F8FF),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: canPrepare ? game.startNextWave : null,
                  child: const Text('시작'),
                ),
              ],
            ),
            if (snapshot.selectedTurretPoint != null && canPrepare) ...[
              const SizedBox(height: 8),
              _GemEquipPanel(game: game, snapshot: snapshot),
            ] else if (snapshot.selectedBuildPoint != null && canPrepare) ...[
              const SizedBox(height: 8),
              _BuildSelectionPanel(game: game, snapshot: snapshot),
            ],
            const SizedBox(height: 8),
            Row(
              children: TurretType.values.map((type) {
                final definition = demoTurrets[type]!;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _TurretButton(
                      type: type,
                      label: definition.name,
                      cost: definition.cost,
                      color: definition.color,
                      selected: snapshot.selectedBuildTurretType == type,
                      enabled:
                          canPrepare && snapshot.selectedBuildPoint != null,
                      onPressed: () => game.previewOrBuildSelectedTile(type),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WavePreview extends StatelessWidget {
  const _WavePreview({
    required this.snapshot,
    required this.selectedType,
    required this.onSelectType,
  });

  final GameSnapshot snapshot;
  final EnemyType? selectedType;
  final ValueChanged<EnemyType> onSelectType;

  @override
  Widget build(BuildContext context) {
    final selectedEnemy = selectedType == null
        ? null
        : demoEnemies[selectedType]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '다음 라운드',
              style: TextStyle(fontSize: 13, color: Color(0xFFE8F8FF)),
            ),
            const SizedBox(width: 8),
            ...snapshot.nextWaveEnemyTypes.map((type) {
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: GestureDetector(
                  onTap: () => onSelectType(type),
                  child: _EnemyIcon(type: type, selected: selectedType == type),
                ),
              );
            }),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          reverseDuration: const Duration(milliseconds: 90),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: selectedEnemy == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey(selectedType),
                  padding: const EdgeInsets.only(top: 8),
                  child: _EnemyPreviewPanel(
                    enemy: selectedEnemy,
                    round: snapshot.round,
                  ),
                ),
        ),
      ],
    );
  }
}

class _EnemyIcon extends StatelessWidget {
  const _EnemyIcon({required this.type, required this.selected});

  final EnemyType type;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final enemy = demoEnemies[type]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      width: 30,
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: selected
            ? enemy.color.withValues(alpha: 0.16)
            : Colors.transparent,
        border: Border.all(
          color: selected ? enemy.color : Colors.transparent,
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: CustomPaint(
        painter: _EnemyIconPainter(color: enemy.color, type: type),
      ),
    );
  }
}

class _EnemyIconPainter extends CustomPainter {
  const _EnemyIconPainter({required this.color, required this.type});

  final Color color;
  final EnemyType type;

  @override
  void paint(Canvas canvas, Size size) {
    drawEnemyShape(
      canvas,
      size: size,
      type: type,
      color: color,
      strokeWidth: 2,
    );
  }

  @override
  bool shouldRepaint(covariant _EnemyIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.type != type;
  }
}

class _EnemyPreviewPanel extends StatelessWidget {
  const _EnemyPreviewPanel({required this.enemy, required this.round});

  final EnemyDefinition enemy;
  final int round;

  @override
  Widget build(BuildContext context) {
    final maxHp = scaledEnemyMaxHp(enemy, round);
    final multiplierRows = [
      ...DamageFamily.values
          .map(
            (family) => (
              label: family.label,
              color: family.color,
              value: enemy.resistanceProfile.familyMultiplier(family),
            ),
          )
          .where((row) => row.value != 1),
      ...AttackTag.values
          .map(
            (tag) => (
              label: tag.label,
              color: tag.color,
              value: enemy.resistanceProfile.tagMultiplier(tag),
            ),
          )
          .where((row) => row.value != 1),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xF00B1B2B),
        border: Border.all(color: enemy.color.withValues(alpha: 0.65)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _EnemyIcon(type: enemy.type, selected: false),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  enemy.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: enemy.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatPill(label: '체력', value: maxHp.round().toString()),
              const SizedBox(width: 5),
              _StatPill(label: '속도', value: enemy.speed.round().toString()),
            ],
          ),
          const SizedBox(height: 7),
          if (multiplierRows.isEmpty)
            const Text(
              '피해 배율 변화 없음',
              style: TextStyle(fontSize: 11, color: Color(0xFFB9D6E4)),
            )
          else
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: multiplierRows.map((row) {
                return _MultiplierChip(
                  label: row.label,
                  value: row.value,
                  color: row.color,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _MultiplierChip extends StatelessWidget {
  const _MultiplierChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textColor = value >= 1 ? color : const Color(0xFFFF8A8A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.12),
        border: Border.all(color: textColor.withValues(alpha: 0.75)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label x${value.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class _BuildSelectionPanel extends StatelessWidget {
  const _BuildSelectionPanel({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final type = snapshot.selectedBuildTurretType;
    final definition = type == null ? null : demoTurrets[type]!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xAA0B1B2B),
        border: Border.all(color: const Color(0x5533D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: definition == null
          ? const Text(
              '설치할 포탑을 선택하세요',
              style: TextStyle(fontSize: 12, color: Color(0xFFE8F8FF)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${definition.name} 포탑',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: definition.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      height: 30,
                      child: FilledButton(
                        onPressed: snapshot.gold >= definition.cost
                            ? game.confirmBuildSelectedTile
                            : null,
                        child: Text(
                          '설치 ${definition.cost}G',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  definition.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB9D6E4),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                _TurretAttributeChips(definition: definition),
                const SizedBox(height: 6),
                _BuildTurretStats(definition: definition),
              ],
            ),
    );
  }
}

class _BuildTurretStats extends StatelessWidget {
  const _BuildTurretStats({required this.definition});

  final TurretDefinition definition;

  @override
  Widget build(BuildContext context) {
    final dps = definition.damage * definition.attackRate;
    return Row(
      children: [
        _StatPill(label: '피해', value: definition.damage.toStringAsFixed(1)),
        const SizedBox(width: 5),
        _StatPill(label: 'DPS', value: dps.toStringAsFixed(1)),
        const SizedBox(width: 5),
        _StatPill(label: '사거리', value: definition.range.round().toString()),
        const SizedBox(width: 5),
        _StatPill(
          label: '초당',
          value: '${definition.attackRate.toStringAsFixed(2)}회',
        ),
      ],
    );
  }
}

class _TurretAttributeChips extends StatelessWidget {
  const _TurretAttributeChips({required this.definition});

  final TurretDefinition definition;

  @override
  Widget build(BuildContext context) {
    final labels = [
      (
        label: definition.damageFamily.label,
        color: definition.damageFamily.color,
      ),
      ...definition.attackTags.map(
        (tag) => (label: tag.label, color: tag.color),
      ),
    ];

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: labels.map((label) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: label.color.withValues(alpha: 0.12),
            border: Border.all(color: label.color.withValues(alpha: 0.75)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: label.color,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GemEquipPanel extends StatefulWidget {
  const _GemEquipPanel({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  State<_GemEquipPanel> createState() => _GemEquipPanelState();
}

class _GemEquipPanelState extends State<_GemEquipPanel> {
  GemType? _selectedInventoryGem;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final slotText =
        '${snapshot.selectedTurretGems.length}/${snapshot.selectedTurretSlotLimit}';
    final definition = demoTurrets[snapshot.selectedTurretType]!;
    final inventory = GemType.values
        .where((type) => (snapshot.gemInventory[type] ?? 0) > 0)
        .toList();
    final selectedSlotIndex = snapshot.selectedTurretGemSlotIndex;
    final selectedSlotGem =
        selectedSlotIndex != null &&
            selectedSlotIndex < snapshot.selectedTurretGems.length
        ? snapshot.selectedTurretGems[selectedSlotIndex]
        : null;
    final selectedInventoryGem =
        _selectedInventoryGem != null &&
            inventory.contains(_selectedInventoryGem)
        ? _selectedInventoryGem
        : null;
    final selectedInventoryGemDefinition = selectedInventoryGem == null
        ? null
        : demoGems[selectedInventoryGem]!;
    final selectedInventoryBlockReason = selectedInventoryGem == null
        ? null
        : gemEquipBlockReason(selectedInventoryGem, definition);
    final selectedInventoryEquipped =
        selectedInventoryGem != null &&
        snapshot.selectedTurretGems.contains(selectedInventoryGem);
    final selectedInventoryCanInstall =
        selectedInventoryGem != null &&
        !selectedInventoryEquipped &&
        selectedInventoryBlockReason == null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xAA0B1B2B),
        border: Border.all(color: const Color(0x5533D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${snapshot.selectedTurretName} 포탑  Lv.${snapshot.selectedTurretLevel}/${snapshot.selectedTurretMaxLevel}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFE8F8FF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                height: 30,
                child: OutlinedButton(
                  onPressed:
                      snapshot.selectedTurretCanLevelUp &&
                          snapshot.gold >= snapshot.selectedTurretLevelUpCost
                      ? widget.game.levelUpSelectedTurret
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE7C66A)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: Text(
                    snapshot.selectedTurretCanLevelUp
                        ? '레벨업 ${snapshot.selectedTurretLevelUpCost}G'
                        : '최대 레벨',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              if (snapshot.selectedTurretHasLinkUpgrade) ...[
                const SizedBox(width: 6),
                SizedBox(
                  height: 30,
                  child: OutlinedButton(
                    onPressed:
                        snapshot.selectedTurretCanUpgradeLink &&
                            snapshot.gold >=
                                snapshot.selectedTurretLinkUpgradeCost
                        ? widget.game.upgradeSelectedTurretLink
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF8EE6FF)),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    child: Text(
                      snapshot.selectedTurretCanUpgradeLink
                          ? '${snapshot.selectedTurretNextSlotLimit}링크 ${snapshot.selectedTurretLinkUpgradeCost}G'
                          : '${snapshot.selectedTurretNextSlotLimit}링크 Lv.${snapshot.selectedTurretLinkUpgradeRequiredLevel}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          _TurretAttributeChips(definition: definition),
          const SizedBox(height: 6),
          _TurretStats(snapshot: snapshot),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '링크 $slotText',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8AA6B8)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(snapshot.selectedTurretSlotLimit, (
                      index,
                    ) {
                      final type = index < snapshot.selectedTurretGems.length
                          ? snapshot.selectedTurretGems[index]
                          : null;
                      final selected = selectedSlotIndex == index;
                      final color = type == null
                          ? const Color(0xFF8AA6B8)
                          : demoGems[type]!.color;
                      final label = type == null
                          ? '${index + 1}: 빈 슬롯'
                          : '${index + 1}';

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: OutlinedButton(
                          onPressed: () =>
                              widget.game.selectSelectedTurretGemSlot(index),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: selected
                                  ? color
                                  : color.withValues(alpha: 0.55),
                              width: selected ? 2 : 1,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (type != null) ...[
                                Icon(demoGems[type]!.icon, size: 13),
                                const SizedBox(width: 4),
                              ],
                              Text(label, style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
          if (selectedSlotGem != null) ...[
            const SizedBox(height: 6),
            _SelectedSlotGemActions(
              type: selectedSlotGem,
              turret: definition,
              onRemove: widget.game.removeSelectedTurretGemSlot,
            ),
          ],
          const SizedBox(height: 6),
          if (inventory.isEmpty)
            const Text(
              '보유 젬 없음',
              style: TextStyle(fontSize: 12, color: Color(0xFF8AA6B8)),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '보유 젬',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8AA6B8)),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: inventory.map((type) {
                    final gem = demoGems[type]!;
                    final count = snapshot.gemInventory[type]!;
                    final equipped = snapshot.selectedTurretGems.contains(type);
                    final selected = selectedInventoryGem == type;
                    final blockReason = gemEquipBlockReason(type, definition);
                    final canInstall = !equipped && blockReason == null;
                    return _InventoryGemChip(
                      gem: gem,
                      count: count,
                      selected: selected,
                      equipped: equipped,
                      blocked: blockReason != null,
                      onTap: () {
                        if (selected && canInstall) {
                          widget.game.equipSelectedTurret(type);
                          setState(() {
                            _selectedInventoryGem = null;
                          });
                          return;
                        }
                        setState(() {
                          _selectedInventoryGem = type;
                        });
                      },
                    );
                  }).toList(),
                ),
                if (selectedInventoryGem != null &&
                    selectedInventoryGemDefinition != null) ...[
                  const SizedBox(height: 6),
                  _SelectedInventoryGemActions(
                    type: selectedInventoryGem,
                    turret: definition,
                    gem: selectedInventoryGemDefinition,
                    blockReason: selectedInventoryEquipped
                        ? '이미 이 포탑에 장착됨'
                        : selectedInventoryBlockReason,
                    canInstall: selectedInventoryCanInstall,
                    onInstall: () {
                      widget.game.equipSelectedTurret(selectedInventoryGem);
                      setState(() {
                        _selectedInventoryGem = null;
                      });
                    },
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _InventoryGemChip extends StatelessWidget {
  const _InventoryGemChip({
    required this.gem,
    required this.count,
    required this.selected,
    required this.equipped,
    required this.blocked,
    required this.onTap,
  });

  final GemDefinition gem;
  final int count;
  final bool selected;
  final bool equipped;
  final bool blocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dimmed = equipped || blocked;
    return Opacity(
      opacity: dimmed && !selected ? 0.48 : 1,
      child: SizedBox(
        width: 106,
        height: 34,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(
              color: selected ? gem.color : gem.color.withValues(alpha: 0.58),
              width: selected ? 2 : 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Icon(gem.icon, color: gem.color, size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  gem.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'x$count',
                style: const TextStyle(fontSize: 10, color: Color(0xFFB9D6E4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedInventoryGemActions extends StatelessWidget {
  const _SelectedInventoryGemActions({
    required this.type,
    required this.turret,
    required this.gem,
    required this.blockReason,
    required this.canInstall,
    required this.onInstall,
  });

  final GemType type;
  final TurretDefinition turret;
  final GemDefinition gem;
  final String? blockReason;
  final bool canInstall;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x9907111D),
        border: Border.all(color: gem.color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(gem.icon, color: gem.color, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gem.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE8F8FF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  blockReason ?? _gemEffectText(type, turret),
                  style: TextStyle(
                    fontSize: 10,
                    color: blockReason == null
                        ? const Color(0xFFC9DCE8)
                        : const Color(0xFFFFA68A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: OutlinedButton(
              onPressed: canInstall ? onInstall : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF6D7F8F),
                side: BorderSide(
                  color: canInstall ? gem.color : const Color(0x55485B68),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: const Text('장착', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedSlotGemActions extends StatelessWidget {
  const _SelectedSlotGemActions({
    required this.type,
    required this.turret,
    required this.onRemove,
  });

  final GemType type;
  final TurretDefinition turret;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final gem = demoGems[type]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x9907111D),
        border: Border.all(color: gem.color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(gem.icon, color: gem.color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gem.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE8F8FF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _gemEffectText(type, turret),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFD6ECF6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: OutlinedButton(
              onPressed: onRemove,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF8AA6B8)),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: const Text('해제', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurretStats extends StatelessWidget {
  const _TurretStats({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final dps = snapshot.selectedTurretAttackRate <= 0
        ? 0
        : snapshot.selectedTurretDamage * snapshot.selectedTurretAttackRate;

    return Row(
      children: [
        _StatPill(
          label: '피해',
          value: snapshot.selectedTurretDamage.toStringAsFixed(1),
        ),
        const SizedBox(width: 5),
        _StatPill(label: 'DPS', value: dps.toStringAsFixed(1)),
        const SizedBox(width: 5),
        _StatPill(
          label: '사거리',
          value: snapshot.selectedTurretRange.round().toString(),
        ),
        const SizedBox(width: 5),
        _StatPill(
          label: '초당',
          value: '${snapshot.selectedTurretAttackRate.toStringAsFixed(2)}회',
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xAA07111D),
          border: Border.all(color: const Color(0x3333D8FF)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF8AA6B8)),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

String _gemEffectText(GemType type, TurretDefinition turret) {
  return switch (type) {
    GemType.attackSpeed => '초당 발사 40% 증가',
    GemType.range => '사거리 +32',
    GemType.physicalDamage =>
      turret.damageFamily == DamageFamily.physical
          ? '물리 피해 40% 증폭'
          : '현재 적용되는 물리 피해 없음',
    GemType.magicalDamage =>
      turret.damageFamily == DamageFamily.magical
          ? '마법 피해 40% 증폭'
          : '현재 적용되는 마법 피해 없음',
    GemType.lightWeapon =>
      turret.attackTags.contains(AttackTag.light)
          ? '경량화기 피해 20% 증폭, 초당 발사 20% 증가'
          : '현재 적용되는 경량화기 피해 없음',
    GemType.heavyWeapon =>
      turret.attackTags.contains(AttackTag.heavy)
          ? '중화기 피해 30% 증폭, 효과 범위 20% 증가'
          : '현재 적용되는 중화기 피해 없음',
    GemType.damageOverTime =>
      turret.attackTags.contains(AttackTag.damageOverTime)
          ? '지속피해 30% 증폭, 지속시간 30% 증가'
          : '현재 적용되는 지속피해 없음',
    GemType.explosion =>
      turret.splashRadius > 0 ? '폭발 반경 +8, 주변 피해 65%' : '반경 34 폭발, 주변 피해 35%',
    GemType.chain =>
      turret.splashRadius > 0 ? '폭발 미적중 최대 2명에게 35% 연쇄' : '주변 최대 2명에게 35% 연쇄',
  };
}

class _RewardOverlay extends StatefulWidget {
  const _RewardOverlay({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  State<_RewardOverlay> createState() => _RewardOverlayState();
}

class _RewardOverlayState extends State<_RewardOverlay> {
  GemType? _selectedGem;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final selectedGem =
        _selectedGem != null && snapshot.rewardOptions.contains(_selectedGem)
        ? _selectedGem
        : null;
    final selectedGemDefinition = selectedGem == null
        ? null
        : demoGems[selectedGem]!;

    return Container(
      color: const Color(0x9902070D),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xF0091624),
            border: Border.all(color: const Color(0xAA33D8FF)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '젬 보상 선택',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${snapshot.completedRounds}라운드 클리어 보상',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB9D6E4)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: snapshot.rewardOptions.map((type) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _RewardCard(
                      type: type,
                      ownedCount: snapshot.gemInventory[type] ?? 0,
                      selected: selectedGem == type,
                      onPressed: () {
                        setState(() {
                          _selectedGem = type;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
              if (selectedGem != null && selectedGemDefinition != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xAA07111D),
                    border: Border.all(
                      color: selectedGemDefinition.color.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedGemDefinition.icon,
                        color: selectedGemDefinition.color,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selectedGemDefinition.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _rewardGemEffectText(selectedGem),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFC9DCE8),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 30,
                        child: FilledButton(
                          onPressed: () =>
                              widget.game.selectRewardGem(selectedGem),
                          child: const Text(
                            '선택',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.type,
    required this.ownedCount,
    required this.selected,
    required this.onPressed,
  });

  final GemType type;
  final int ownedCount;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final gem = demoGems[type]!;
    return SizedBox(
      width: 96,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
            color: selected ? gem.color : gem.color.withValues(alpha: 0.62),
            width: selected ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(gem.icon, color: gem.color, size: 28),
            const SizedBox(height: 8),
            Text(gem.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              gem.shortText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFFC9DCE8)),
            ),
            const SizedBox(height: 6),
            Text(
              '보유 x$ownedCount',
              style: const TextStyle(fontSize: 10, color: Color(0xFF8AA6B8)),
            ),
          ],
        ),
      ),
    );
  }
}

String _rewardGemEffectText(GemType type) {
  return switch (type) {
    GemType.attackSpeed => '장착 포탑의 초당 발사 수를 40% 증가',
    GemType.range => '장착 포탑의 사거리 +32',
    GemType.physicalDamage => '물리 피해 40% 증폭',
    GemType.magicalDamage => '마법 피해 40% 증폭',
    GemType.lightWeapon => '경량화기 피해와 연사 강화',
    GemType.heavyWeapon => '중화기 피해와 효과 범위 강화',
    GemType.damageOverTime => '지속피해와 지속시간 강화',
    GemType.explosion => '타격 지점 주변에 폭발 피해 추가',
    GemType.chain => '주변 최대 2명에게 추가 투사체 발사',
  };
}

class _TurretButton extends StatelessWidget {
  const _TurretButton({
    required this.type,
    required this.label,
    required this.cost,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final TurretType type;
  final String label;
  final int cost;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(
          color: selected ? color : const Color(0x5533D8FF),
          width: selected ? 2 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TurretShapeIcon(type: type, color: color),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('$cost G', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _TurretShapeIcon extends StatelessWidget {
  const _TurretShapeIcon({required this.type, required this.color});

  final TurretType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 20,
      child: CustomPaint(
        painter: _TurretShapePainter(type: type, color: color),
      ),
    );
  }
}

class _TurretShapePainter extends CustomPainter {
  const _TurretShapePainter({required this.type, required this.color});

  final TurretType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    drawTurretShape(
      canvas,
      size: size,
      type: type,
      color: color,
      strokeWidth: 1.4,
    );
  }

  @override
  bool shouldRepaint(_TurretShapePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.type != type;
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF8CC8D8)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
