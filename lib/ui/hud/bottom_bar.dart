part of 'game_hud.dart';

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final canPrepare = snapshot.phase == GamePhase.preparation;
    final canEditBoard =
        snapshot.phase == GamePhase.preparation ||
        snapshot.phase == GamePhase.wave;
    final statusText = switch (snapshot.phase) {
      GamePhase.preparation => '다음 웨이브',
      GamePhase.wave => '전투 진행 중',
      GamePhase.reward => '젬 보상 선택 대기',
      GamePhase.success => '방어 성공',
      GamePhase.failure => '방어 실패',
      GamePhase.restored => '저장된 진행 대기',
    };

    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 12, right: 12),
            child: GamePanel(
              padding: const EdgeInsets.all(10),
              accentColor: GamePalette.cyan,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _BottomSpeedControl(snapshot: snapshot, game: game),
                      const Spacer(),
                      _AutoStartModeButton(game: game, snapshot: snapshot),
                      const SizedBox(width: 6),
                      _StartWaveButton(
                        enabled: canPrepare,
                        onPressed: game.startNextWave,
                      ),
                    ],
                  ),
                  if (snapshot.selectedRunPanelTab != RunPanelTab.closed) ...[
                    const SizedBox(height: 8),
                    if (snapshot.selectedPortalPoint != null) ...[
                      _PortalSummaryCard(
                        snapshot: snapshot,
                        statusText: statusText,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (snapshot.selectedRunPanelTab ==
                        RunPanelTab.upgrades) ...[
                      _RunUpgradePanel(game: game, snapshot: snapshot),
                    ] else if (snapshot.selectedRunPanelTab ==
                        RunPanelTab.gems) ...[
                      _GemInventoryPanel(game: game, snapshot: snapshot),
                    ] else if (snapshot.selectedRunPanelTab ==
                        RunPanelTab.turrets) ...[
                      if (snapshot.selectedTurretPoint != null &&
                          canEditBoard) ...[
                        _GemEquipPanel(game: game, snapshot: snapshot),
                      ] else if ((snapshot.selectedBuildPoint != null ||
                              snapshot.selectedBuildTurretType != null) &&
                          canEditBoard) ...[
                        _BuildSelectionPanel(game: game, snapshot: snapshot),
                      ],
                      if (snapshot.selectedTurretPoint == null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: snapshot.availableTurretTypes.map((type) {
                            final definition = gameTurrets[type]!;
                            final buildCost = game.turretBuildCost(type);
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: _TurretButton(
                                  type: type,
                                  label: definition.name,
                                  cost: buildCost,
                                  color: definition.color,
                                  selected:
                                      snapshot.selectedBuildTurretType == type,
                                  enabled: canEditBoard,
                                  onPressed: () =>
                                      game.previewOrBuildSelectedTile(type),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          _RunPanelTabs(game: game, snapshot: snapshot),
        ],
      ),
    );
  }
}

class _RunPanelTabs extends StatelessWidget {
  const _RunPanelTabs({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      height: 50,
      padding: const EdgeInsets.all(4),
      variant: GamePanelVariant.inset,
      accentColor: GamePalette.metalDim,
      child: Row(
        children: [
          _RunPanelTabButton(
            icon: Icons.account_tree_outlined,
            label: '포탑',
            selected: snapshot.selectedRunPanelTab == RunPanelTab.turrets,
            onPressed: () => game.selectRunPanelTab(RunPanelTab.turrets),
          ),
          const SizedBox(width: 5),
          _RunPanelTabButton(
            icon: Icons.trending_up_rounded,
            label: '업그레이드',
            selected: snapshot.selectedRunPanelTab == RunPanelTab.upgrades,
            onPressed: () => game.selectRunPanelTab(RunPanelTab.upgrades),
          ),
          const SizedBox(width: 5),
          _RunPanelTabButton(
            icon: Icons.diamond_outlined,
            label: '젬',
            selected: snapshot.selectedRunPanelTab == RunPanelTab.gems,
            onPressed: () => game.selectRunPanelTab(RunPanelTab.gems),
          ),
        ],
      ),
    );
  }
}

class _GemInventoryPanel extends StatelessWidget {
  const _GemInventoryPanel({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ownedGems = GemType.values
        .where((type) => (snapshot.gemInventory[type] ?? 0) > 0)
        .toList();
    final canPurchase =
        snapshot.phase == GamePhase.preparation &&
        snapshot.gemShards >= RuneNexusGame.gemChoicePurchaseCost;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xAA0B1B2B),
        border: Border.all(color: const Color(0x5533D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _GemShardIcon(),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '젬 파편 ${snapshot.gemShards}',
                  style: const TextStyle(
                    color: Color(0xFFE8F8FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(
                height: 32,
                child: GameButton(
                  onPressed: canPurchase ? game.purchaseGemChoice : null,
                  compact: true,
                  variant: GameButtonVariant.confirm,
                  accentColor: GamePalette.green,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '젬 구매',
                        style: GameTextStyles.withColor(
                          GameTextStyles.buttonSmall,
                          canPurchase
                              ? GamePalette.textPrimary
                              : GamePalette.textDisabled,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: _GemShardIcon(),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${RuneNexusGame.gemChoicePurchaseCost}',
                        style: GameTextStyles.withColor(
                          GameTextStyles.buttonSmall,
                          canPurchase
                              ? GamePalette.green
                              : GamePalette.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ownedGems.isEmpty)
            const Text(
              '보유한 젬이 없습니다. 5라운드 보상 또는 파편 구매로 젬을 획득하세요.',
              style: TextStyle(fontSize: 11, color: Color(0xFF8FA8BA)),
            )
          else ...[
            const _GemInventorySectionHeader(),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ownedGems.map((type) {
                return _GemInventoryChip(
                  type: type,
                  count: snapshot.gemInventory[type] ?? 0,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _GemInventorySectionHeader extends StatelessWidget {
  const _GemInventorySectionHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Divider(height: 1, thickness: 1, color: Color(0x334D6577)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '보유 젬',
            style: TextStyle(
              color: Color(0xFF5F788A),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              height: 1,
            ),
          ),
        ),
        Expanded(
          child: Divider(height: 1, thickness: 1, color: Color(0x334D6577)),
        ),
      ],
    );
  }
}

class _GemInventoryChip extends StatelessWidget {
  const _GemInventoryChip({required this.type, required this.count});

  final GemType type;
  final int count;

  @override
  Widget build(BuildContext context) {
    final gem = gameGems[type]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: gem.color.withValues(alpha: 0.12),
        border: Border.all(color: gem.color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(gem.icon, color: gem.color, size: 14),
              const SizedBox(width: 4),
              Text(
                '${gem.name} x$count',
                style: const TextStyle(
                  color: Color(0xFFE8F8FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _gemInventoryEffectText(type),
            style: const TextStyle(fontSize: 10, color: Color(0xFF9FB7C8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

String _gemInventoryEffectText(GemType type) {
  return switch (type) {
    GemType.attackSpeed => '초당 발사 +40%',
    GemType.range => '사거리 +20%',
    GemType.physicalDamage => '물리 피해 +40%',
    GemType.magicalDamage => '마법 피해 +40%',
    GemType.lightWeapon => '경량화기 강화',
    GemType.heavyWeapon => '중화기 강화',
    GemType.damageOverTime => '지속피해 강화',
    GemType.explosion => '폭발 피해 추가',
    GemType.chain => '연쇄 투사체 추가',
    GemType.criticalChance => '치명 확률 +20%p',
    GemType.aimSpeed => '조준 속도 +75%',
    GemType.damageAmplifier => '타격 피해 +25%',
    GemType.armorPiercing => '방어구 감쇄 무시',
  };
}

class _RunPanelTabButton extends StatelessWidget {
  const _RunPanelTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? GamePalette.textPrimary
        : GamePalette.textSecondary;
    final accentColor = selected ? GamePalette.cyan : GamePalette.metalDim;
    return Expanded(
      child: GameButton(
        onPressed: onPressed,
        selected: selected,
        compact: true,
        variant: GameButtonVariant.secondary,
        accentColor: accentColor,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GameTextStyles.withColor(
                  GameTextStyles.button,
                  foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunUpgradePanel extends StatelessWidget {
  const _RunUpgradePanel({required this.game, required this.snapshot});

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
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _RunUpgradeRow(
                definition: definition,
                level: level,
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
    required this.gold,
    required this.onPressed,
  });

  final RunUpgradeDefinition definition;
  final int level;
  final int gold;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isMax = level >= definition.maxLevel;
    final cost = definition.costForLevel(level);
    final enabled = !isMax && gold >= cost;
    return GamePanel(
      padding: const EdgeInsets.all(8),
      variant: GamePanelVariant.inset,
      accentColor: enabled ? GamePalette.cyan : GamePalette.metalDim,
      child: Row(
        children: [
          Icon(
            _runUpgradeIcon(definition.type),
            size: 22,
            color: enabled ? const Color(0xFF8EE6FF) : const Color(0xFF607486),
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
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFE8F8FF),
                        ),
                      ),
                    ),
                    Text(
                      'Lv $level/${definition.maxLevel}',
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
                  overflow: TextOverflow.ellipsis,
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
    required this.isMax,
  });

  final RunUpgradeDefinition definition;
  final int level;
  final bool isMax;

  @override
  Widget build(BuildContext context) {
    final subject = _runUpgradeEffectSubject(definition.type);
    final currentText = _runUpgradeEffectText(definition, level);
    final nextText = isMax
        ? 'MAX'
        : _runUpgradeEffectText(definition, level + 1);
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

String _runUpgradeEffectText(RunUpgradeDefinition definition, int level) {
  final effect = definition.effectPerLevel * level;
  return switch (definition.type) {
    RunUpgradeType.towerDamage => '+${(effect * 100).round()}%',
    RunUpgradeType.killGold => '+${(effect * 100).round()}%',
    RunUpgradeType.waveGold => '+${effect.round()}G',
  };
}

IconData _runUpgradeIcon(RunUpgradeType type) {
  return switch (type) {
    RunUpgradeType.towerDamage => Icons.local_fire_department_outlined,
    RunUpgradeType.killGold => Icons.toll_outlined,
    RunUpgradeType.waveGold => Icons.inventory_2_outlined,
  };
}

class _PortalSummaryCard extends StatelessWidget {
  const _PortalSummaryCard({required this.snapshot, required this.statusText});

  final GameSnapshot snapshot;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final showWave = snapshot.phase == GamePhase.preparation;
    final title = showWave ? '포탈 1' : statusText;
    final subtitle = showWave
        ? '${snapshot.previewText} · ${snapshot.round}/${snapshot.maxRound}'
        : '진행 상태 확인';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: showWave
            ? () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) =>
                    _PortalWaveDetailSheet(snapshot: snapshot),
              )
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xAA0B1B2B),
            border: Border.all(color: const Color(0x7733D8FF)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF4B245F),
                  border: Border.all(
                    color: const Color(0xFFB16DFF),
                    width: 1.4,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.filter_tilt_shift,
                  size: 18,
                  color: Color(0xFFE3B7FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE8F8FF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8FA8BA),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (showWave) _NextWaveEnemySummary(snapshot: snapshot),
              const SizedBox(width: 5),
              Icon(
                Icons.expand_less,
                size: 18,
                color: showWave
                    ? const Color(0xFF8EE6FF)
                    : const Color(0xFF627384),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextWaveEnemySummary extends StatelessWidget {
  const _NextWaveEnemySummary({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final types = snapshot.nextWaveEnemyTypes.take(3).toList();
    final hiddenCount = snapshot.nextWaveEnemyTypes.length - types.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...types.map(
          (type) => Padding(
            padding: const EdgeInsets.only(left: 3),
            child: SizedBox(
              width: 25,
              height: 25,
              child: _EnemyIcon(type: type, selected: false, size: 25),
            ),
          ),
        ),
        if (hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '+$hiddenCount',
              style: const TextStyle(
                color: Color(0xFF8EE6FF),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _PortalWaveDetailSheet extends StatelessWidget {
  const _PortalWaveDetailSheet({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xF70B1827),
          border: Border.all(color: const Color(0x8833D8FF)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.filter_tilt_shift,
                  color: Color(0xFFE3B7FF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '포탈 1 · ${snapshot.round}/${snapshot.maxRound} 웨이브',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE8F8FF),
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: const Color(0xFFC6D6E4),
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: Color(0x664A6172)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 17),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              snapshot.previewText,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8FA8BA),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: snapshot.nextWaveEnemyTypes.map((type) {
                final enemy = gameEnemies[type]!;
                final count = snapshot.nextWaveEnemyCounts[type] ?? 0;
                return _EnemyCountChip(enemy: enemy, count: count);
              }).toList(),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: snapshot.nextWaveEnemyTypes.map((type) {
                    final enemy = gameEnemies[type]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: _EnemyDetailRow(
                        enemy: enemy,
                        count: snapshot.nextWaveEnemyCounts[type] ?? 0,
                        round: snapshot.round,
                        stageNumber: snapshot.currentStageNumber,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnemyCountChip extends StatelessWidget {
  const _EnemyCountChip({required this.enemy, required this.count});

  final EnemyDefinition enemy;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: enemy.color.withValues(alpha: 0.12),
        border: Border.all(color: enemy.color.withValues(alpha: 0.75)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EnemyIcon(type: enemy.type, selected: false, size: 18),
          const SizedBox(width: 5),
          Text(
            '${enemy.name} x$count',
            style: TextStyle(
              color: enemy.color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnemyDetailRow extends StatelessWidget {
  const _EnemyDetailRow({
    required this.enemy,
    required this.count,
    required this.round,
    required this.stageNumber,
  });

  final EnemyDefinition enemy;
  final int count;
  final int round;
  final int stageNumber;

  @override
  Widget build(BuildContext context) {
    final maxHp = scaledEnemyMaxHp(enemy, round, stageNumber: stageNumber);
    final maxShield = scaledEnemyMaxShield(
      enemy,
      round,
      stageNumber: stageNumber,
    );
    final maxArmor = scaledEnemyMaxArmor(
      enemy,
      round,
      stageNumber: stageNumber,
    );
    final resistanceRows = [
      ...DamageFamily.values
          .map(
            (family) => (
              label: family.label,
              color: family.color,
              value: enemy.resistanceProfile.familyResistance(family),
            ),
          )
          .where((row) => row.value != 0),
      ...AttackTag.values
          .map(
            (tag) => (
              label: tag.label,
              color: tag.color,
              value: enemy.resistanceProfile.tagResistance(tag),
            ),
          )
          .where((row) => row.value != 0),
    ];

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xAA07111D),
        border: Border.all(color: enemy.color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _EnemyIcon(type: enemy.type, selected: false),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${enemy.name} x$count',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enemy.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _StatPill(
                label: '체력',
                value: maxHp.round().toString(),
                expand: false,
              ),
              if (maxArmor > 0)
                _StatPill(
                  label: '방어구',
                  value: maxArmor.round().toString(),
                  expand: false,
                ),
              if (maxShield > 0)
                _StatPill(
                  label: '보호막',
                  value: maxShield.round().toString(),
                  expand: false,
                ),
              _StatPill(
                label: '속도',
                value: enemy.speed.round().toString(),
                expand: false,
              ),
              _StatPill(
                label: '넥서스 피해',
                value: '-${enemy.coreDamage}',
                expand: false,
                valueChild: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_outline,
                      size: 12,
                      color: Color(0xFFFF7043),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '-${enemy.coreDamage}',
                      style: const TextStyle(
                        color: Color(0xFFFF9B72),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _StatPill(
                label: '보상',
                value: '+${enemy.rewardGold}',
                expand: false,
                valueChild: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.paid_outlined,
                      size: 12,
                      color: Color(0xFFFFD166),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '+${enemy.rewardGold}',
                      style: const TextStyle(
                        color: Color(0xFFFFD166),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (resistanceRows.isNotEmpty) ...[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: resistanceRows.map((row) {
                  return _ResistanceChip(
                    label: row.label,
                    value: row.value,
                    color: row.color,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomSpeedControl extends StatelessWidget {
  const _BottomSpeedControl({required this.snapshot, required this.game});

  final GameSnapshot snapshot;
  final RuneNexusGame game;

  @override
  Widget build(BuildContext context) {
    const speeds = [1.0, 2.0, 4.0];
    return GamePanel(
      height: 40,
      padding: const EdgeInsets.all(3),
      variant: GamePanelVariant.inset,
      accentColor: GamePalette.cyan,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: speeds.map((speed) {
          final selected = snapshot.speedMultiplier == speed;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: SizedBox(
              width: 30,
              height: 32,
              child: GameButton(
                onPressed: () => game.setSpeedMultiplier(speed),
                selected: selected,
                compact: true,
                variant: selected
                    ? GameButtonVariant.primary
                    : GameButtonVariant.ghost,
                accentColor: GamePalette.cyan,
                padding: EdgeInsets.zero,
                child: Center(
                  child: Text(
                    '${speed.toInt()}x',
                    style: GameTextStyles.withColor(
                      GameTextStyles.buttonSmall,
                      selected
                          ? GamePalette.voidBlack
                          : GamePalette.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AutoStartModeButton extends StatelessWidget {
  const _AutoStartModeButton({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AutoStartMode>(
      tooltip: _autoStartModeLabel(snapshot.autoStartMode),
      color: const Color(0xFF0B1827),
      offset: const Offset(0, -142),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0x8833D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      onSelected: game.setAutoStartMode,
      itemBuilder: (context) {
        return AutoStartMode.values.map((mode) {
          final selected = snapshot.autoStartMode == mode;
          return PopupMenuItem(
            value: mode,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _autoStartModeIcon(mode),
                  size: 18,
                  color: selected
                      ? const Color(0xFF8EE6FF)
                      : const Color(0xFFB7C8D8),
                ),
                const SizedBox(width: 8),
                Text(
                  _autoStartModeLabel(mode),
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF8EE6FF)
                        : const Color(0xFFE8F8FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0x2207111D),
          border: Border.all(color: const Color(0x8833D8FF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _autoStartModeIcon(snapshot.autoStartMode),
          size: 22,
          color: const Color(0xFF8EE6FF),
        ),
      ),
    );
  }
}

IconData _autoStartModeIcon(AutoStartMode mode) {
  return switch (mode) {
    AutoStartMode.pauseEachRound => Icons.pause_rounded,
    AutoStartMode.skipBossRounds => Icons.auto_mode_rounded,
    AutoStartMode.fullAuto => Icons.all_inclusive,
  };
}

String _autoStartModeLabel(AutoStartMode mode) {
  return switch (mode) {
    AutoStartMode.pauseEachRound => '웨이브마다 정지',
    AutoStartMode.skipBossRounds => '보스 제외 자동',
    AutoStartMode.fullAuto => '전부 자동',
  };
}

class _EnemyIcon extends StatelessWidget {
  const _EnemyIcon({
    required this.type,
    required this.selected,
    this.size = 30,
  });

  final EnemyType type;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enemy = gameEnemies[type]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      width: size,
      height: size,
      padding: EdgeInsets.all(math.max(2, size * 0.1)),
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
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    drawEnemyShape(
      canvas,
      size: size,
      type: type,
      color: color,
      strokeWidth: 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EnemyIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.type != type;
  }
}

class _ResistanceChip extends StatelessWidget {
  const _ResistanceChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textColor = value <= 0 ? color : const Color(0xFFFF8A8A);
    final percent = (value * 100).round();
    final sign = percent > 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.12),
        border: Border.all(color: textColor.withValues(alpha: 0.75)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label 저항 $sign$percent%',
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
                        overflow: TextOverflow.ellipsis,
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

class _StartWaveButton extends StatelessWidget {
  const _StartWaveButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      onPressed: enabled ? onPressed : null,
      variant: GameButtonVariant.primary,
      accentColor: GamePalette.cyan,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow_rounded,
            size: 20,
            color: enabled ? GamePalette.voidBlack : GamePalette.textDisabled,
          ),
          const SizedBox(width: 4),
          Text(
            '시작',
            style: GameTextStyles.withColor(
              GameTextStyles.button,
              enabled ? GamePalette.voidBlack : GamePalette.textDisabled,
            ),
          ),
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
        _StatPill(label: '피해', value: definition.damage.toStringAsFixed(1)),
        const SizedBox(width: 5),
        _StatPill(
          label: 'DPS',
          value: dps.toStringAsFixed(1),
          valueChild: burnDps > 0
              ? RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          _StatPill(
            label: '화상',
            value: '${RuneNexusGame.burnDurationSeconds.toStringAsFixed(1)}초',
          ),
        ],
        if (definition.slowDuration > 0) ...[
          const SizedBox(width: 5),
          _StatPill(
            label: '감속',
            value:
                '${((1 - definition.slowMultiplier) * 100).round()}%/${definition.slowDuration.toStringAsFixed(1)}초',
          ),
        ],
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
