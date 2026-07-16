part of 'main_menu_screen.dart';

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
    final tiles = group == _PermanentUpgradeGroup.combat
        ? _combatUpgradeTiles(l10n: l10n, game: game, snapshot: snapshot)
        : _economyUpgradeTiles(l10n: l10n, game: game, snapshot: snapshot);
    return _PermanentUpgradeBoard(tiles: tiles);
  }
}

List<_PermanentUpgradeTileData> _combatUpgradeTiles({
  required RuneNexusLocalizations l10n,
  required RuneNexusGame game,
  required GameSnapshot snapshot,
}) {
  final nextNexusHpLevel = (snapshot.nexusHpUpgradeLevel + 1)
      .clamp(0, RunProgression.maxNexusHpUpgradeLevel)
      .toInt();
  final nextFireTrainingLevel = (snapshot.fireTrainingUpgradeLevel + 1)
      .clamp(0, RunProgression.maxFireTrainingUpgradeLevel)
      .toInt();
  final nextPhysicalDamageTrainingLevel =
      (snapshot.physicalDamageTrainingUpgradeLevel + 1)
          .clamp(0, RunProgression.maxPhysicalDamageTrainingUpgradeLevel)
          .toInt();
  final nextElementalDamageTrainingLevel =
      (snapshot.elementalDamageTrainingUpgradeLevel + 1)
          .clamp(0, RunProgression.maxElementalDamageTrainingUpgradeLevel)
          .toInt();
  final nextCriticalChanceLevel = (snapshot.criticalChanceUpgradeLevel + 1)
      .clamp(0, RunProgression.maxCriticalChanceUpgradeLevel)
      .toInt();
  final nextCriticalDamageLevel = (snapshot.criticalDamageUpgradeLevel + 1)
      .clamp(0, RunProgression.maxCriticalDamageUpgradeLevel)
      .toInt();
  final stageFourCleared = snapshot.clearedStageNumbers.contains(4);
  final stageSevenCleared = snapshot.clearedStageNumbers.contains(7);
  return [
    _PermanentUpgradeTileData(
      upgradeIconType: GameUpgradeIconType.nexusHp,
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
    _PermanentUpgradeTileData(
      upgradeIconType: GameUpgradeIconType.towerDamage,
      title: l10n.basicFireTraining,
      description: l10n.permanentUpgradeDescription(l10n.basicFireTraining),
      level: snapshot.fireTrainingUpgradeLevel,
      maxLevel: RunProgression.maxFireTrainingUpgradeLevel,
      globalMaxLevel: RunProgression.maxFireTrainingUpgradeLevel,
      valueText:
          '+${(snapshot.fireTrainingDamageBonusRate * 100).toStringAsFixed(1)}%',
      nextValueText:
          '+${(nextFireTrainingLevel * RunProgression.fireTrainingDamagePerUpgradeLevel * 100).toStringAsFixed(1)}%',
      cost: snapshot.fireTrainingUpgradeCost,
      enabled: snapshot.canUpgradeFireTraining,
      lockText: l10n.maxLevelReached,
      onPressed: game.upgradeFireTrainingProgression,
    ),
    if (stageSevenCleared)
      _PermanentUpgradeTileData(
        upgradeIconType: GameUpgradeIconType.physicalDamage,
        title: l10n.physicalDamageTraining,
        description: l10n.permanentUpgradeDescription(
          l10n.physicalDamageTraining,
        ),
        level: snapshot.physicalDamageTrainingUpgradeLevel,
        maxLevel: RunProgression.maxPhysicalDamageTrainingUpgradeLevel,
        globalMaxLevel: RunProgression.maxPhysicalDamageTrainingUpgradeLevel,
        valueText:
            '+${(snapshot.physicalDamageTrainingBonusRate * 100).toStringAsFixed(1)}%',
        nextValueText:
            '+${(nextPhysicalDamageTrainingLevel * RunProgression.familyDamageTrainingBonusPerUpgradeLevel * 100).toStringAsFixed(1)}%',
        cost: snapshot.physicalDamageTrainingUpgradeCost,
        enabled: snapshot.canUpgradePhysicalDamageTraining,
        lockText: l10n.maxLevelReached,
        onPressed: game.upgradePhysicalDamageTrainingProgression,
      ),
    if (stageSevenCleared)
      _PermanentUpgradeTileData(
        upgradeIconType: GameUpgradeIconType.elementalDamage,
        title: l10n.elementalDamageTraining,
        description: l10n.permanentUpgradeDescription(
          l10n.elementalDamageTraining,
        ),
        level: snapshot.elementalDamageTrainingUpgradeLevel,
        maxLevel: RunProgression.maxElementalDamageTrainingUpgradeLevel,
        globalMaxLevel: RunProgression.maxElementalDamageTrainingUpgradeLevel,
        valueText:
            '+${(snapshot.elementalDamageTrainingBonusRate * 100).toStringAsFixed(1)}%',
        nextValueText:
            '+${(nextElementalDamageTrainingLevel * RunProgression.familyDamageTrainingBonusPerUpgradeLevel * 100).toStringAsFixed(1)}%',
        cost: snapshot.elementalDamageTrainingUpgradeCost,
        enabled: snapshot.canUpgradeElementalDamageTraining,
        lockText: l10n.maxLevelReached,
        onPressed: game.upgradeElementalDamageTrainingProgression,
      ),
    if (stageFourCleared)
      _PermanentUpgradeTileData(
        upgradeIconType: GameUpgradeIconType.criticalChance,
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
      _PermanentUpgradeTileData(
        upgradeIconType: GameUpgradeIconType.criticalDamage,
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
}

List<_PermanentUpgradeTileData> _economyUpgradeTiles({
  required RuneNexusLocalizations l10n,
  required RuneNexusGame game,
  required GameSnapshot snapshot,
}) {
  final nextStartingGoldLevel = (snapshot.startingGoldUpgradeLevel + 1)
      .clamp(0, RunProgression.maxStartingGoldUpgradeLevel)
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
  final economyUpgradeUnlocked = snapshot.clearedStageNumbers.contains(
    RuneNexusGame.economyUpgradeUnlockStage,
  );
  return [
    _PermanentUpgradeTileData(
      upgradeIconType: GameUpgradeIconType.startingGold,
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
    _PermanentUpgradeTileData(
      upgradeIconType: GameUpgradeIconType.waveGold,
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
    if (economyUpgradeUnlocked)
      _PermanentUpgradeTileData(
        upgradeIconType: GameUpgradeIconType.killGold,
        title: l10n.killRewardBonus,
        description: l10n.permanentUpgradeDescription(l10n.killRewardBonus),
        level: snapshot.killGoldUpgradeLevel,
        maxLevel: RunProgression.maxKillGoldUpgradeLevel,
        globalMaxLevel: RunProgression.maxKillGoldUpgradeLevel,
        valueText: '+${(snapshot.killGoldProgressionBonusRate * 100).round()}%',
        nextValueText:
            '+${(nextKillGoldLevel * RunProgression.killGoldBonusPerUpgradeLevel * 100).round()}%',
        cost: snapshot.killGoldUpgradeCost,
        enabled: snapshot.canUpgradeKillGold,
        lockText: l10n.maxLevelReached,
        onPressed: game.upgradeKillGoldProgression,
      ),
    if (economyUpgradeUnlocked)
      _PermanentUpgradeTileData(
        upgradeIconType: GameUpgradeIconType.turretRefund,
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
}

class _PermanentUpgradeTileData {
  const _PermanentUpgradeTileData({
    required this.upgradeIconType,
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

  final GameUpgradeIconType upgradeIconType;
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
}

class _PermanentUpgradeBoard extends StatelessWidget {
  const _PermanentUpgradeBoard({required this.tiles});

  final List<_PermanentUpgradeTileData> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
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
              SizedBox(
                width: tileWidth,
                child: _PermanentUpgradeTile(data: tile),
              ),
          ],
        );
      },
    );
  }
}

class _PermanentUpgradeTile extends StatelessWidget {
  const _PermanentUpgradeTile({required this.data});

  final _PermanentUpgradeTileData data;

  bool get _isMaxed => data.level >= data.globalMaxLevel;
  bool get _isTierLocked =>
      data.level >= data.maxLevel && data.level < data.globalMaxLevel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final borderColor = data.enabled
        ? const Color(0xFFE7C66A)
        : const Color(0x55485B68);
    final titleColor = data.enabled
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: UpgradeIcon(
                    data.upgradeIconType,
                    size: 30,
                    semanticLabel: data.title,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      maxLines: 1,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.clip,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lv.${data.level}/${data.maxLevel}',
                      style: const TextStyle(
                        color: Color(0xFFB9D6E4),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            data.description,
            style: const TextStyle(color: Color(0xFF9EB3BF), fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.clip,
          ),
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CompactUpgradeValueSummary(
                currentValueText: data.valueText,
                nextValueText: data.nextValueText,
                enabled: data.enabled,
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 30,
                child: GameButton(
                  onPressed: data.enabled ? data.onPressed : null,
                  compact: true,
                  variant: GameButtonVariant.secondary,
                  accentColor: data.enabled
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
      return Center(
        child: Text(
          l10n.maxLevelReached,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          overflow: TextOverflow.clip,
        ),
      );
    }
    if (_isTierLocked) {
      return Center(
        child: Text(
          data.lockText,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          overflow: TextOverflow.clip,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            l10n.levelUp,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            overflow: TextOverflow.clip,
          ),
        ),
        const SizedBox(width: 4),
        _RuneCostChip(cost: data.cost, enabled: data.enabled),
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
                overflow: TextOverflow.clip,
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
          const RuneCurrencyIcon(size: 12),
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
