import 'package:flutter/material.dart';

import '../../data/definitions/game_turret_data.dart';
import '../../domain/turret/attack_tag.dart';
import '../../domain/turret/turret_definition.dart';
import '../../game/game_snapshot.dart';
import '../../game/rune_nexus_game.dart';
import '../game/game_ui.dart';
import 'hud_common.dart';

class HudTurretBuildPicker extends StatelessWidget {
  const HudTurretBuildPicker({
    required this.game,
    required this.snapshot,
    required this.enabled,
    super.key,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: snapshot.availableTurretTypes.map((type) {
        final definition = gameTurrets[type]!;
        final buildCost = game.turretBuildCost(type);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: HudTurretButton(
              type: type,
              label: definition.name,
              cost: buildCost,
              color: definition.color,
              selected: snapshot.selectedBuildTurretType == type,
              enabled: enabled,
              onPressed: () => game.previewOrBuildSelectedTile(type),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class HudBuildSelectionPanel extends StatelessWidget {
  const HudBuildSelectionPanel({
    required this.game,
    required this.snapshot,
    super.key,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final type = snapshot.selectedBuildTurretType;
    final definition = type == null ? null : gameTurrets[type]!;
    final buildCost = type == null ? 0 : game.turretBuildCost(type);
    final canInstall = snapshot.selectedBuildPoint != null;

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
                        overflow: TextOverflow.clip,
                      ),
                    ),
                    if (canInstall)
                      _InstallTurretButton(
                        definition: definition,
                        cost: buildCost,
                        enabled: snapshot.gold >= buildCost,
                        onPressed: game.confirmBuildSelectedTile,
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
                  overflow: TextOverflow.clip,
                ),
                const SizedBox(height: 6),
                HudTurretAttributeChips(definition: definition),
                const SizedBox(height: 6),
                _BuildTurretStats(definition: definition),
              ],
            ),
    );
  }
}

class _InstallTurretButton extends StatelessWidget {
  const _InstallTurretButton({
    required this.definition,
    required this.cost,
    required this.enabled,
    required this.onPressed,
  });

  final TurretDefinition definition;
  final int cost;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = definition.color;
    return GameButton(
      onPressed: enabled ? onPressed : null,
      variant: GameButtonVariant.confirm,
      accentColor: accent,
      height: 34,
      padding: const EdgeInsets.only(left: 10, right: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 16,
            color: enabled ? accent : GamePalette.textDisabled,
          ),
          const SizedBox(width: 5),
          Text(
            '설치',
            style: GameTextStyles.withColor(
              GameTextStyles.button,
              enabled ? GamePalette.textPrimary : GamePalette.textDisabled,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: enabled
                  ? GamePalette.backdrop.withValues(alpha: 0.72)
                  : GamePalette.stoneDark.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(GamePalette.radiusSmall),
            ),
            child: Text(
              '${cost}G',
              style: GameTextStyles.withColor(
                GameTextStyles.caption,
                enabled ? accent : GamePalette.textDisabled,
              ),
            ),
          ),
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
    final burnDps = definition.attackTags.contains(AttackTag.damageOverTime)
        ? definition.damage * RuneNexusGame.burnDamagePerSecondScale
        : 0.0;
    return Row(
      children: [
        HudStatPill(label: '피해', value: definition.damage.toStringAsFixed(1)),
        const SizedBox(width: 5),
        HudStatPill(
          label: 'DPS',
          value: dps.toStringAsFixed(1),
          valueChild: burnDps > 0
              ? RichText(
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE8F8FF),
                    ),
                    children: [
                      TextSpan(text: dps.toStringAsFixed(1)),
                      TextSpan(
                        text: ' +${burnDps.toStringAsFixed(1)}',
                        style: const TextStyle(color: Color(0xFFFFA24A)),
                      ),
                    ],
                  ),
                )
              : null,
        ),
        if (burnDps > 0) ...[
          const SizedBox(width: 5),
          HudStatPill(
            label: '화상',
            value: '${RuneNexusGame.burnDurationSeconds.toStringAsFixed(1)}초',
          ),
        ],
        if (definition.slowDuration > 0) ...[
          const SizedBox(width: 5),
          HudStatPill(
            label: '감속',
            value:
                '${((1 - definition.slowMultiplier) * 100).round()}%/${definition.slowDuration.toStringAsFixed(1)}초',
          ),
        ],
        const SizedBox(width: 5),
        HudStatPill(label: '사거리', value: definition.range.round().toString()),
        const SizedBox(width: 5),
        HudStatPill(
          label: '초당',
          value: '${definition.attackRate.toStringAsFixed(2)}회',
        ),
      ],
    );
  }
}
