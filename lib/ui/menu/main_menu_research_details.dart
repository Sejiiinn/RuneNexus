part of 'main_menu_screen.dart';

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

    return GameModalFrame(
      maxWidth: 380,
      accentColor: GamePalette.cyan,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      padding: EdgeInsets.zero,
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
                  child: ResearchIcon(type, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AdaptiveResearchTitle(
                    text: _researchTitle(l10n, type),
                    style: const TextStyle(
                      color: Color(0xFFE8FBFF),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                    minSingleLineScale: 0.82,
                  ),
                ),
                GameModalCloseButton(
                  onPressed: () => Navigator.of(context).pop(),
                  accentColor: GamePalette.cyan,
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
                              iconWidget: const RuneCurrencyIcon(size: 14),
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
    );
  }
}

class _ResearchDialogMetric extends StatelessWidget {
  const _ResearchDialogMetric({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.value,
    required this.accent,
  }) : assert((icon == null) != (iconWidget == null));

  final IconData? icon;
  final Widget? iconWidget;
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
          iconWidget ?? Icon(icon, color: accent, size: 14),
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
                  overflow: TextOverflow.clip,
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
                  overflow: TextOverflow.clip,
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
    ResearchType.bossBounty => l10n.bossBounty,
    ResearchType.linkMaintenance => l10n.linkMaintenance,
    ResearchType.crystalRecovery => l10n.crystalRecovery,
    ResearchType.runeResonance => l10n.runeResonance,
    ResearchType.runUpgradeCostOptimization => l10n.runUpgradeCostOptimization,
    ResearchType.towerDamageLimitExpansion => l10n.towerDamageLimitExpansion,
    ResearchType.killGoldLimitExpansion => l10n.killGoldLimitExpansion,
    ResearchType.waveGoldLimitExpansion => l10n.waveGoldLimitExpansion,
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
    ResearchType.bossBounty => _ResearchEffectText(
      l10n.researchBossBountyEffect(_bossBountyPercentText(level)),
      hasNext ? '+${_bossBountyPercentText(clampedNextLevel)}%' : null,
    ),
    ResearchType.linkMaintenance => _ResearchEffectText(
      l10n.researchLinkMaintenanceEffect(_linkMaintenancePercent(level)),
      hasNext ? '-${_linkMaintenancePercent(clampedNextLevel)}%' : null,
    ),
    ResearchType.crystalRecovery => _ResearchEffectText(
      l10n.researchCrystalRecoveryEffect(
        level * RunProgression.bossGemShardsPerCrystalRecoveryLevel,
      ),
      hasNext
          ? '+${clampedNextLevel * RunProgression.bossGemShardsPerCrystalRecoveryLevel}'
          : null,
    ),
    ResearchType.runeResonance => _ResearchEffectText(
      l10n.researchRuneResonanceEffect(_runeResonancePercent(level)),
      hasNext ? _signedPercent(_runeResonancePercent(clampedNextLevel)) : null,
    ),
    ResearchType.runUpgradeCostOptimization => _ResearchEffectText(
      l10n.researchRunUpgradeCostOptimizationEffect(
        _runUpgradeCostOptimizationPercent(level),
      ),
      hasNext
          ? '-${_runUpgradeCostOptimizationPercent(clampedNextLevel)}%'
          : null,
    ),
    ResearchType.towerDamageLimitExpansion => _ResearchEffectText(
      l10n.researchRunUpgradeLimitExpansionEffect(
        l10n.towerDamageRunUpgrade,
        _runUpgradeLimitExpansionLevelBonus(level),
      ),
      hasNext
          ? '+${_runUpgradeLimitExpansionLevelBonus(clampedNextLevel)}'
          : null,
    ),
    ResearchType.killGoldLimitExpansion => _ResearchEffectText(
      l10n.researchRunUpgradeLimitExpansionEffect(
        l10n.killGoldRunUpgrade,
        _runUpgradeLimitExpansionLevelBonus(level),
      ),
      hasNext
          ? '+${_runUpgradeLimitExpansionLevelBonus(clampedNextLevel)}'
          : null,
    ),
    ResearchType.waveGoldLimitExpansion => _ResearchEffectText(
      l10n.researchRunUpgradeLimitExpansionEffect(
        l10n.waveGoldRunUpgrade,
        _runUpgradeLimitExpansionLevelBonus(level),
      ),
      hasNext
          ? '+${_runUpgradeLimitExpansionLevelBonus(clampedNextLevel)}'
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

String _bossBountyPercentText(int level) {
  final percent = level * RunProgression.bossBountyBonusPerLevel * 100;
  return percent.toStringAsFixed(percent.truncateToDouble() == percent ? 0 : 1);
}

int _linkMaintenancePercent(int level) {
  return (level * RunProgression.linkMaintenanceDiscountPerLevel * 100).round();
}

int _runeResonancePercent(int level) {
  return (level * RunProgression.runeResonanceBonusPerLevel * 100).round();
}

int _runUpgradeCostOptimizationPercent(int level) {
  return (level * RunProgression.runUpgradeCostDiscountPerLevel * 100).round();
}

int _runUpgradeLimitExpansionLevelBonus(int level) {
  return level * RunProgression.runUpgradeLimitExpansionMaxLevelPerLevel;
}
