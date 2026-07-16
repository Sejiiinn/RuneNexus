import 'package:flutter/material.dart';

import '../../data/definitions/game_run_upgrade_data.dart';
import '../../domain/run_upgrade/run_upgrade_definition.dart';
import '../../domain/run_upgrade/run_upgrade_type.dart';
import '../../game/game_snapshot.dart';
import '../../game/rune_nexus_game.dart';
import '../game/game_ui.dart';

class HudRunUpgradePanel extends StatelessWidget {
  const HudRunUpgradePanel({
    required this.game,
    required this.snapshot,
    super.key,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 198),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: RunUpgradeType.values.map((type) {
            final definition = gameRunUpgrades[type]!;
            final level = snapshot.runUpgradeLevels[type] ?? 0;
            final maxLevel = game.runUpgradeMaxLevelFor(type);
            final cost = game.runUpgradeCostFor(type, level);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _RunUpgradeRow(
                definition: definition,
                level: level,
                maxLevel: maxLevel,
                cost: cost,
                gold: snapshot.gold,
                onPressed: () => game.buyRunUpgrade(type),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _RunUpgradeRow extends StatelessWidget {
  const _RunUpgradeRow({
    required this.definition,
    required this.level,
    required this.maxLevel,
    required this.cost,
    required this.gold,
    required this.onPressed,
  });

  final RunUpgradeDefinition definition;
  final int level;
  final int maxLevel;
  final int cost;
  final int gold;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isMax = level >= maxLevel;
    final enabled = !isMax && gold >= cost;
    return GamePanel(
      padding: const EdgeInsets.all(8),
      variant: GamePanelVariant.inset,
      accentColor: enabled ? GamePalette.cyan : GamePalette.metalDim,
      child: Row(
        children: [
          UpgradeIcon(
            _runUpgradeIconType(definition.type),
            size: 22,
            color: enabled ? null : const Color(0xFF607486),
            semanticLabel: definition.name,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        definition.name,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFE8F8FF),
                        ),
                      ),
                    ),
                    Text(
                      'Lv $level/$maxLevel',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8FA8BA),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  definition.description,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8FA8BA),
                  ),
                ),
                const SizedBox(height: 5),
                _RunUpgradeEffectPreview(
                  definition: definition,
                  level: level,
                  maxLevel: maxLevel,
                  isMax: isMax,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: GameButton(
              onPressed: enabled ? onPressed : null,
              label: isMax ? 'MAX' : '${cost}G',
              compact: true,
              variant: GameButtonVariant.primary,
              accentColor: GamePalette.cyan,
            ),
          ),
        ],
      ),
    );
  }
}

class _RunUpgradeEffectPreview extends StatelessWidget {
  const _RunUpgradeEffectPreview({
    required this.definition,
    required this.level,
    required this.maxLevel,
    required this.isMax,
  });

  final RunUpgradeDefinition definition;
  final int level;
  final int maxLevel;
  final bool isMax;

  @override
  Widget build(BuildContext context) {
    final subject = _runUpgradeEffectSubject(definition.type);
    final currentText = _runUpgradeEffectText(definition, level, maxLevel);
    final nextText = isMax
        ? 'MAX'
        : _runUpgradeEffectText(definition, level + 1, maxLevel);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 5,
      runSpacing: 4,
      children: [
        _RunUpgradeEffectChip(
          label: subject,
          value: currentText,
          color: const Color(0xFFB9D6E4),
        ),
        const Text(
          '>',
          style: TextStyle(
            color: Color(0xFF8FA8BA),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        _RunUpgradeEffectChip(
          label: '강화',
          value: nextText,
          color: isMax ? const Color(0xFF8FA8BA) : const Color(0xFF8EE6FF),
        ),
      ],
    );
  }
}

class _RunUpgradeEffectChip extends StatelessWidget {
  const _RunUpgradeEffectChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF8FA8BA),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

String _runUpgradeEffectSubject(RunUpgradeType type) {
  return switch (type) {
    RunUpgradeType.towerDamage => '피해',
    RunUpgradeType.killGold => '처치 골드',
    RunUpgradeType.waveGold => '웨이브 보상',
  };
}

String _runUpgradeEffectText(
  RunUpgradeDefinition definition,
  int level,
  int maxLevel,
) {
  final effect = definition.effectForLevel(level, maxLevel: maxLevel);
  return switch (definition.type) {
    RunUpgradeType.towerDamage => '+${(effect * 100).round()}%',
    RunUpgradeType.killGold => '+${(effect * 100).round()}%',
    RunUpgradeType.waveGold => '+${effect.round()}G',
  };
}

GameUpgradeIconType _runUpgradeIconType(RunUpgradeType type) {
  return switch (type) {
    RunUpgradeType.towerDamage => GameUpgradeIconType.towerDamage,
    RunUpgradeType.killGold => GameUpgradeIconType.killGold,
    RunUpgradeType.waveGold => GameUpgradeIconType.waveGold,
  };
}
