part of 'main_menu_screen.dart';

enum _StageDetailsAction { start, continueRun }

class _StageDetailsDialog extends StatelessWidget {
  const _StageDetailsDialog({
    required this.snapshot,
    required this.stageNumber,
    required this.unlocked,
    required this.active,
    required this.theme,
    required this.statusText,
    required this.rewardInfo,
  });

  final GameSnapshot snapshot;
  final int stageNumber;
  final bool unlocked;
  final bool active;
  final _StageChapterTheme theme;
  final String statusText;
  final _StageRewardInfo? rewardInfo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fullClearRuneReward = _fullClearRuneReward(snapshot, stageNumber);
    final unlockItems = rewardInfo?.items ?? const <_StageUnlockItem>[];
    return Dialog(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _StageDetailsAssetSurface(
          asset: stageDetailsDialogFrameAsset,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _StageIcon(unlocked: unlocked, active: active),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.stageName(stageNumber),
                          style: GameTextStyles.withColor(
                            GameTextStyles.title,
                            unlocked
                                ? GamePalette.textPrimary
                                : GamePalette.textDisabled,
                          ),
                          overflow: TextOverflow.clip,
                        ),
                        const SizedBox(height: 4),
                        _StageInfoChip(
                          text: statusText,
                          unlocked: unlocked,
                          highlighted:
                              active ||
                              snapshot.clearedStageNumbers.contains(
                                stageNumber,
                              ),
                          overrideColor: active
                              ? const Color(0xFFE7C66A)
                              : unlocked
                              ? theme.accent
                              : const Color(0xFF667987),
                          accentColor: theme.accent,
                        ),
                      ],
                    ),
                  ),
                  _StageDetailsCloseButton(
                    tooltip: l10n.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                    enabled: unlocked,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _StageQuickStats(
                theme: theme,
                stats: [
                  _StageQuickStatData(
                    label: l10n.stageBestRecordLabel,
                    value: _recordTextForStage(l10n, snapshot, stageNumber),
                    icon: Icons.workspace_premium_outlined,
                  ),
                  _StageQuickStatData(
                    label: l10n.stageTotalRoundsLabel,
                    value: l10n.stageTotalRounds(snapshot.maxRound),
                    icon: Icons.flag_outlined,
                  ),
                  _StageQuickStatData(
                    label: l10n.stageRuneRewardLabel,
                    value: l10n.stageFullClearRuneReward(fullClearRuneReward),
                    icon: Icons.hexagon_outlined,
                  ),
                ],
              ),
              if (!unlocked) ...[
                const SizedBox(height: 10),
                _StageLockedNotice(
                  text: l10n.stageLockedRequirement(stageNumber),
                  theme: theme,
                ),
              ],
              if (unlockItems.isNotEmpty) ...[
                const SizedBox(height: 10),
                _StageUnlockPanel(
                  title: rewardInfo!.label ?? l10n.clearRewardLabel,
                  items: unlockItems,
                  theme: theme,
                ),
              ],
              const SizedBox(height: 16),
              _StageDetailsActions(unlocked: unlocked, active: active),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageDetailsAssetSurface extends StatelessWidget {
  const _StageDetailsAssetSurface({
    required this.asset,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.constraints,
  });

  final String asset;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              asset,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
    final resolvedConstraints = constraints;
    if (resolvedConstraints == null) {
      return content;
    }
    return ConstrainedBox(constraints: resolvedConstraints, child: content);
  }
}

class _StageDetailsCloseButton extends StatelessWidget {
  const _StageDetailsCloseButton({
    required this.onPressed,
    required this.tooltip,
    required this.enabled,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: enabled ? 1 : 0.58,
            child: Image.asset(
              stageDetailsCloseButtonFrameAsset,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
          GameButton(
            onPressed: onPressed,
            tooltip: tooltip,
            compact: true,
            variant: GameButtonVariant.ghost,
            accentColor: Colors.transparent,
            padding: EdgeInsets.zero,
            child: Center(
              child: Icon(
                Icons.close_rounded,
                size: 17,
                color: enabled
                    ? const Color(0xFFFF8A3D)
                    : GamePalette.textDisabled,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageQuickStatData {
  const _StageQuickStatData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _StageQuickStats extends StatelessWidget {
  const _StageQuickStats({required this.stats, required this.theme});

  final List<_StageQuickStatData> stats;
  final _StageChapterTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: _StageQuickStat(data: stats[index], theme: theme),
          ),
        ],
      ],
    );
  }
}

class _StageQuickStat extends StatelessWidget {
  const _StageQuickStat({required this.data, required this.theme});

  final _StageQuickStatData data;
  final _StageChapterTheme theme;

  @override
  Widget build(BuildContext context) {
    return _StageDetailsAssetSurface(
      asset: stageDetailsQuickStatFrameAsset,
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, size: 17, color: theme.accent),
          const SizedBox(height: 5),
          Text(
            data.label,
            style: GameTextStyles.withColor(
              GameTextStyles.caption,
              GamePalette.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              data.value,
              maxLines: 1,
              softWrap: false,
              style: GameTextStyles.withColor(
                GameTextStyles.body,
                GamePalette.textPrimary,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageUnlockPanel extends StatelessWidget {
  const _StageUnlockPanel({
    required this.title,
    required this.items,
    required this.theme,
  });

  final String title;
  final List<_StageUnlockItem> items;
  final _StageChapterTheme theme;

  @override
  Widget build(BuildContext context) {
    final sections = _stageUnlockSections(context, items);
    return _StageDetailsAssetSurface(
      asset: stageDetailsUnlockPanelFrameAsset,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, size: 16, color: theme.accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: GameTextStyles.withColor(
                  GameTextStyles.caption,
                  GamePalette.textSecondary,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final section in sections) ...[
            _StageUnlockSection(section: section, theme: theme),
            if (section != sections.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _StageUnlockSection extends StatelessWidget {
  const _StageUnlockSection({required this.section, required this.theme});

  final _StageUnlockSectionData section;
  final _StageChapterTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('stage-unlock-section-${section.category.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              section.label,
              style: GameTextStyles.withColor(
                GameTextStyles.caption,
                GamePalette.textSecondary,
              ).copyWith(fontSize: 10, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(height: 1, color: const Color(0x33485B68)),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final item in section.items)
              _StageUnlockChip(item: item, theme: theme),
          ],
        ),
      ],
    );
  }
}

List<_StageUnlockSectionData> _stageUnlockSections(
  BuildContext context,
  List<_StageUnlockItem> items,
) {
  final l10n = context.l10n;
  final result = <_StageUnlockSectionData>[];
  for (final category in _StageUnlockCategory.values) {
    final sectionItems = items
        .where((item) => item.category == category)
        .toList(growable: false);
    if (sectionItems.isEmpty) {
      continue;
    }
    result.add(
      _StageUnlockSectionData(
        category: category,
        label: category.label(l10n),
        items: sectionItems,
      ),
    );
  }
  return result;
}

class _StageUnlockChip extends StatelessWidget {
  const _StageUnlockChip({required this.item, required this.theme});

  final _StageUnlockItem item;
  final _StageChapterTheme theme;

  @override
  Widget build(BuildContext context) {
    final color = item.highlighted ? theme.secondary : GamePalette.textPrimary;
    return _StageDetailsAssetSurface(
      asset: stageDetailsUnlockChipFrameAsset,
      constraints: const BoxConstraints(maxWidth: 178),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.researchType case final researchType?)
            ResearchIcon(researchType, size: 15, color: color)
          else if (item.upgradeIconType case final upgradeIconType?)
            UpgradeIcon(upgradeIconType, size: 15, color: color)
          else if (item.coreCombatSkill case final coreCombatSkill?)
            CoreAbilityIcon(coreCombatSkill, size: 15, color: color)
          else if (item.gemType case final gemType?)
            GemIcon(gemType, size: 15)
          else if (item.asset case final asset?)
            Image.asset(
              asset,
              width: 17,
              height: 17,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            )
          else
            Icon(item.icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              item.label,
              style: GameTextStyles.withColor(
                GameTextStyles.buttonSmall,
                color,
              ).copyWith(fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageLockedNotice extends StatelessWidget {
  const _StageLockedNotice({required this.text, required this.theme});

  final String text;
  final _StageChapterTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x183D4D5A),
        border: Border.all(color: const Color(0x33485B68)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: theme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GameTextStyles.withColor(
                GameTextStyles.caption,
                GamePalette.textSecondary,
              ),
              overflow: TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageDetailsActions extends StatelessWidget {
  const _StageDetailsActions({required this.unlocked, required this.active});

  final bool unlocked;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!unlocked) {
      return _StageDetailsActionButton(
        onPressed: null,
        label: l10n.stageUnavailableAction,
        icon: const Icon(Icons.lock_outline, size: 16),
        enabled: false,
      );
    }
    if (active) {
      return _StageDetailsActionButton(
        onPressed: () =>
            Navigator.of(context).pop(_StageDetailsAction.continueRun),
        label: l10n.continueRun,
        icon: const Icon(Icons.play_arrow_rounded, size: 16),
        enabled: true,
      );
    }
    return _StageDetailsActionButton(
      onPressed: () => Navigator.of(context).pop(_StageDetailsAction.start),
      label: l10n.startStageAction,
      icon: const Icon(Icons.play_arrow_rounded, size: 16),
      enabled: true,
    );
  }
}

class _StageDetailsActionButton extends StatelessWidget {
  const _StageDetailsActionButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    required this.enabled,
  });

  final VoidCallback? onPressed;
  final String label;
  final Widget icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? GamePalette.textPrimary
        : GamePalette.textDisabled;
    return SizedBox(
      height: 40,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: enabled ? 1 : 0.42,
            child: Image.asset(
              stageDetailsActionButtonFrameAsset,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
          GameButton(
            onPressed: onPressed,
            label: label,
            icon: IconTheme(
              data: IconThemeData(color: foreground),
              child: icon,
            ),
            variant: GameButtonVariant.ghost,
            accentColor: Colors.transparent,
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconTheme(
                  data: IconThemeData(color: foreground),
                  child: icon,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

_StageRewardInfo? _stageRewardInfoFor({
  required RuneNexusLocalizations l10n,
  required int stageNumber,
  required bool stageCleared,
  required bool sniperRewardUnlocked,
}) {
  final visual = _stageRewardVisualFor(stageNumber);
  if (visual == null) {
    return null;
  }
  final highlighted = _stageRewardHighlightedFor(
    stageNumber: stageNumber,
    stageCleared: stageCleared,
    sniperRewardUnlocked: sniperRewardUnlocked,
  );
  final String label;
  if (stageNumber == 11) {
    label = highlighted ? l10n.claimedRewardLabel : l10n.firstClearRewardLabel;
  } else {
    label = highlighted ? l10n.unlockedRewardLabel : l10n.clearRewardLabel;
  }
  return _StageRewardInfo(
    label: label,
    icon: visual.icon,
    extraIcons: visual.extraIcons,
    highlighted: highlighted,
    items: _stageUnlockItemsFor(
      l10n: l10n,
      stageNumber: stageNumber,
      highlighted: highlighted,
    ),
  );
}

_StageRewardVisual? _stageRewardVisualFor(int stageNumber) {
  return switch (stageNumber) {
    1 || 4 || 7 || 9 => const _StageRewardVisual(
      icon: _StageRewardAssetIcon(asset: stageRewardUpgradeIconAsset),
    ),
    2 || 8 => const _StageRewardVisual(
      icon: _StageRewardAssetIcon(asset: stageRewardResearchIconAsset),
    ),
    3 => const _StageRewardVisual(
      icon: _SniperRewardIcon(),
      extraIcons: [_StageRewardAssetIcon(asset: stageRewardGemIconAsset)],
    ),
    5 => const _StageRewardVisual(
      icon: _StageRewardAssetIcon(asset: stageRewardResearchIconAsset),
      extraIcons: [_StageRewardAssetIcon(asset: stageRewardCoreIconAsset)],
    ),
    6 => const _StageRewardVisual(icon: _LightningRewardIcon()),
    10 => const _StageRewardVisual(
      icon: _StageRewardAssetIcon(asset: stageRewardGemIconAsset),
      extraIcons: [_StageRewardAssetIcon(asset: stageRewardResearchIconAsset)],
    ),
    11 => const _StageRewardVisual(
      icon: _StageRewardAssetIcon(asset: turretModuleTicketIconAsset),
    ),
    15 => const _StageRewardVisual(
      icon: _StageRewardAssetIcon(asset: stageRewardResearchIconAsset),
    ),
    _ => null,
  };
}

bool _stageRewardHighlightedFor({
  required int stageNumber,
  required bool stageCleared,
  required bool sniperRewardUnlocked,
}) {
  if (stageNumber == 3) {
    return sniperRewardUnlocked;
  }
  return stageCleared;
}

List<_StageUnlockItem> _stageUnlockItemsFor({
  required RuneNexusLocalizations l10n,
  required int stageNumber,
  required bool highlighted,
}) {
  return switch (stageNumber) {
    1 => [
      _StageUnlockItem(
        label: l10n.killRewardBonus,
        upgradeIconType: GameUpgradeIconType.killGold,
        category: _StageUnlockCategory.upgrade,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.emergencySale,
        upgradeIconType: GameUpgradeIconType.turretRefund,
        category: _StageUnlockCategory.upgrade,
        highlighted: highlighted,
      ),
    ],
    2 => [
      _StageUnlockItem(
        label: l10n.tacticalCommand,
        researchType: ResearchType.turretTargetPriority,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.gemAttunement,
        researchType: ResearchType.gemAttunement,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
    ],
    3 => [
      _StageUnlockItem(
        label: l10n.sniperTurret,
        icon: Icons.center_focus_strong_outlined,
        category: _StageUnlockCategory.turret,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.aimSpeedGem,
        gemType: GemType.aimSpeed,
        category: _StageUnlockCategory.gem,
        highlighted: highlighted,
      ),
    ],
    4 => [
      _StageUnlockItem(
        label: l10n.criticalChanceTraining,
        upgradeIconType: GameUpgradeIconType.criticalChance,
        category: _StageUnlockCategory.upgrade,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.criticalDamageTraining,
        upgradeIconType: GameUpgradeIconType.criticalDamage,
        category: _StageUnlockCategory.upgrade,
        highlighted: highlighted,
      ),
    ],
    5 => [
      _StageUnlockItem(
        label: l10n.linkExpansionOne,
        researchType: ResearchType.linkExpansionOne,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.crystalRecovery,
        researchType: ResearchType.crystalRecovery,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.riftMarkSkill,
        coreCombatSkill: CoreCombatSkill.riftMark,
        category: _StageUnlockCategory.core,
        highlighted: highlighted,
      ),
    ],
    6 => [
      _StageUnlockItem(
        label: l10n.lightningTurret,
        icon: Icons.bolt_outlined,
        category: _StageUnlockCategory.turret,
        highlighted: highlighted,
      ),
    ],
    7 => [
      _StageUnlockItem(
        label: l10n.physicalDamageTraining,
        upgradeIconType: GameUpgradeIconType.physicalDamage,
        category: _StageUnlockCategory.upgrade,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.elementalDamageTraining,
        upgradeIconType: GameUpgradeIconType.elementalDamage,
        category: _StageUnlockCategory.upgrade,
        highlighted: highlighted,
      ),
    ],
    8 => [
      _StageUnlockItem(
        label: l10n.runeResonance,
        researchType: ResearchType.runeResonance,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.runUpgradeCostOptimization,
        researchType: ResearchType.runUpgradeCostOptimization,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
    ],
    9 => [
      _StageUnlockItem(
        label: l10n.linkCostOptimization,
        upgradeIconType: GameUpgradeIconType.linkCost,
        category: _StageUnlockCategory.upgrade,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.turretLevelUpOptimization,
        upgradeIconType: GameUpgradeIconType.turretLevelUpCost,
        category: _StageUnlockCategory.upgrade,
        highlighted: highlighted,
      ),
    ],
    10 => [
      _StageUnlockItem(
        label: l10n.armorPiercingGem,
        gemType: GemType.armorPiercing,
        category: _StageUnlockCategory.gem,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.researchSlotTwoPurchaseAccess,
        icon: Icons.view_module_outlined,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
    ],
    11 => [
      _StageUnlockItem(
        label: l10n.turretModuleTicketReward(
          stageElevenFirstClearTurretModuleTicketReward,
        ),
        asset: turretModuleTicketIconAsset,
        category: _StageUnlockCategory.moduleTicket,
        highlighted: highlighted,
      ),
    ],
    15 => [
      _StageUnlockItem(
        label: l10n.towerDamageLimitExpansion,
        researchType: ResearchType.towerDamageLimitExpansion,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.killGoldLimitExpansion,
        researchType: ResearchType.killGoldLimitExpansion,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
      _StageUnlockItem(
        label: l10n.waveGoldLimitExpansion,
        researchType: ResearchType.waveGoldLimitExpansion,
        category: _StageUnlockCategory.research,
        highlighted: highlighted,
      ),
    ],
    _ => const [],
  };
}

int _fullClearRuneReward(GameSnapshot snapshot, int stageNumber) {
  final resonanceLevel =
      snapshot.researchLevels[ResearchType.runeResonance] ?? 0;
  return RunProgression.calculateRuneReward(
    completedRounds: snapshot.maxRound,
    stageNumber: stageNumber,
    resonanceBonusRate:
        resonanceLevel * RunProgression.runeResonanceBonusPerLevel,
  );
}

class _StageRewardInfo {
  const _StageRewardInfo({
    this.label,
    required this.icon,
    this.extraIcons = const [],
    required this.highlighted,
    this.items = const [],
  });

  final String? label;
  final Widget icon;
  final List<Widget> extraIcons;
  final bool highlighted;
  final List<_StageUnlockItem> items;
}

class _StageRewardVisual {
  const _StageRewardVisual({required this.icon, this.extraIcons = const []});

  final Widget icon;
  final List<Widget> extraIcons;
}

class _StageUnlockItem {
  const _StageUnlockItem({
    required this.label,
    this.icon,
    this.asset,
    this.researchType,
    this.upgradeIconType,
    this.coreCombatSkill,
    this.gemType,
    required this.category,
    this.highlighted = false,
  }) : assert(
         (icon != null ? 1 : 0) +
                 (asset != null ? 1 : 0) +
                 (researchType != null ? 1 : 0) +
                 (upgradeIconType != null ? 1 : 0) +
                 (coreCombatSkill != null ? 1 : 0) +
                 (gemType != null ? 1 : 0) ==
             1,
       );

  final String label;
  final IconData? icon;
  final String? asset;
  final ResearchType? researchType;
  final GameUpgradeIconType? upgradeIconType;
  final CoreCombatSkill? coreCombatSkill;
  final GemType? gemType;
  final _StageUnlockCategory category;
  final bool highlighted;
}

class _StageUnlockSectionData {
  const _StageUnlockSectionData({
    required this.category,
    required this.label,
    required this.items,
  });

  final _StageUnlockCategory category;
  final String label;
  final List<_StageUnlockItem> items;
}

enum _StageUnlockCategory {
  upgrade,
  research,
  turret,
  gem,
  core,
  moduleTicket;

  String label(RuneNexusLocalizations l10n) {
    return switch (this) {
      _StageUnlockCategory.upgrade => l10n.permanentUpgradeTab,
      _StageUnlockCategory.research => l10n.researchTab,
      _StageUnlockCategory.turret => l10n.turretSection,
      _StageUnlockCategory.gem => l10n.gemSection,
      _StageUnlockCategory.core => l10n.coreTab,
      _StageUnlockCategory.moduleTicket => l10n.moduleTicketSection,
    };
  }
}
