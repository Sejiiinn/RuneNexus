import 'package:flutter/material.dart';

import '../../domain/combat/game_phase.dart';
import '../../game/game_snapshot.dart';
import '../../game/rune_nexus_game.dart';
import '../../l10n/rune_nexus_localizations.dart';
import '../game/game_ui.dart';

class ResultOverlay extends StatelessWidget {
  const ResultOverlay({
    required this.game,
    required this.snapshot,
    this.onOpenStageSelect,
    this.onOpenPermanentUpgrades,
    this.onStartStage,
    super.key,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final VoidCallback? onOpenStageSelect;
  final VoidCallback? onOpenPermanentUpgrades;
  final ValueChanged<int>? onStartStage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final success = snapshot.phase == GamePhase.success;
    final unlockGroups = _unlockGroupsFor(l10n, snapshot);
    final bestRound =
        snapshot.bestRoundsByStage[snapshot.currentStageNumber] ??
        snapshot.completedRounds;
    final recordText = _recordText(snapshot, bestRound);
    final topDamageText = snapshot.topDamageTurretName == null
        ? '없음'
        : '${snapshot.topDamageTurretName} ${_formatDamageValue(snapshot.topDamageTurretDamageDealt)}';
    final turretModuleTicketReward = snapshot.lastRunTurretModuleTicketReward;
    final rewardSubText = _rewardSubText(
      success,
      unlockGroups,
      turretModuleTicketReward,
    );
    final disableMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: disableMotion
          ? Duration.zero
          : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) {
        final panelOffset = Offset(0, (success ? 18 : 26) * (1 - progress));
        return Container(
          color: const Color(0xFF02070D).withValues(alpha: 0.67 * progress),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Transform.translate(
                  offset: panelOffset,
                  child: Transform.scale(
                    scale: 0.96 + progress * 0.04,
                    child: Opacity(
                      opacity: progress,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 390),
                        child: GamePanel(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          selected: true,
                          variant: success
                              ? GamePanelVariant.stone
                              : GamePanelVariant.danger,
                          accentColor: success
                              ? GamePalette.cyan
                              : GamePalette.danger,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ResultHeader(
                                success: success,
                                snapshot: snapshot,
                              ),
                              const SizedBox(height: 12),
                              _RewardSummary(
                                runeReward: snapshot.lastRunRuneReward,
                                corePointReward:
                                    snapshot.lastRunCorePointReward,
                                turretModuleTicketReward:
                                    turretModuleTicketReward,
                                subText: rewardSubText,
                                success: success,
                              ),
                              const SizedBox(height: 12),
                              _ResultSection(
                                title: '전투 기록',
                                child: _CompactStatList(
                                  rows: [
                                    _CompactStatRow(
                                      label: '도달 라운드',
                                      value: '${snapshot.completedRounds}R',
                                    ),
                                    _CompactStatRow(
                                      label: '기록',
                                      value: recordText,
                                      highlight:
                                          snapshot.lastRunWasNewBestRound,
                                    ),
                                    _CompactStatRow(
                                      label: '최고 피해',
                                      value: topDamageText,
                                    ),
                                    _CompactStatRow(
                                      label: '현재 룬',
                                      value: _formatInteger(snapshot.runes),
                                    ),
                                  ],
                                ),
                              ),
                              if (unlockGroups.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _UnlockSection(groups: unlockGroups),
                              ],
                              const SizedBox(height: 16),
                              _ResultActions(
                                success: success,
                                onConfirm: onOpenStageSelect,
                                onRestart: game.restartRun,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

bool _isFirstStageClear(GameSnapshot snapshot) {
  return snapshot.phase == GamePhase.success &&
      snapshot.completedRounds >= snapshot.maxRound &&
      snapshot.lastRunPreviousBestRound < snapshot.maxRound;
}

String _recordText(GameSnapshot snapshot, int bestRound) {
  if (snapshot.lastRunWasNewBestRound) {
    return snapshot.lastRunPreviousBestRound > 0
        ? '${snapshot.lastRunPreviousBestRound}R → ${snapshot.completedRounds}R'
        : '${snapshot.completedRounds}R 첫 기록';
  }
  if (snapshot.clearedStageNumbers.contains(snapshot.currentStageNumber)) {
    return '클리어';
  }
  return '최고 ${bestRound}R';
}

String _rewardSubText(
  bool success,
  List<_UnlockGroup> unlockGroups,
  int turretModuleTicketReward,
) {
  if (!success) {
    return '도달 기록 기준 정산';
  }
  if (turretModuleTicketReward > 0) {
    return '룬과 최초 클리어 보상이 정산되었습니다';
  }
  if (unlockGroups.isEmpty) {
    return '룬 보상이 정산되었습니다';
  }
  final unlockSummary = unlockGroups
      .map((group) => '${group.label} ${group.items.length}개')
      .join(' · ');
  return '$unlockSummary 해금';
}

List<_UnlockGroup> _unlockGroupsFor(
  RuneNexusLocalizations l10n,
  GameSnapshot snapshot,
) {
  if (!_isFirstStageClear(snapshot)) {
    return const [];
  }
  return switch (snapshot.currentStageNumber) {
    1 => [
      _UnlockGroup('강화', [l10n.killRewardBonus, l10n.emergencySale]),
    ],
    2 => [
      _UnlockGroup('연구', [l10n.tacticalCommand, l10n.gemAttunement]),
    ],
    3 => [
      _UnlockGroup('포탑', [l10n.sniperTurret]),
      _UnlockGroup('젬', [l10n.aimSpeedGem]),
    ],
    4 => [
      _UnlockGroup('강화', [
        l10n.criticalChanceTraining,
        l10n.criticalDamageTraining,
      ]),
    ],
    5 => [
      _UnlockGroup('연구', [l10n.linkExpansionOne, l10n.crystalRecovery]),
      _UnlockGroup('코어', [l10n.riftMarkSkill]),
    ],
    6 => [
      _UnlockGroup('포탑', [l10n.lightningTurret]),
    ],
    7 => [
      _UnlockGroup('강화', [
        l10n.physicalDamageTraining,
        l10n.elementalDamageTraining,
      ]),
    ],
    8 => [
      _UnlockGroup('연구', [l10n.runeResonance, l10n.runUpgradeCostOptimization]),
    ],
    9 => [
      _UnlockGroup('강화', [
        l10n.linkCostOptimization,
        l10n.turretLevelUpOptimization,
      ]),
    ],
    10 => [
      _UnlockGroup('젬', [l10n.armorPiercingGem]),
      _UnlockGroup('연구', [l10n.researchSlotTwoPurchaseAccess]),
    ],
    15 => [
      _UnlockGroup('연구', [
        l10n.towerDamageLimitExpansion,
        l10n.killGoldLimitExpansion,
        l10n.waveGoldLimitExpansion,
      ]),
    ],
    _ => const [],
  };
}

String _formatDamageValue(double value) {
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  if (value >= 100) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

String _formatInteger(int value) {
  final raw = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(raw[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.success, required this.snapshot});

  final bool success;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final accent = success ? GamePalette.cyan : GamePalette.danger;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          success ? resultSuccessEmblemAsset : resultFailureEmblemAsset,
          key: const ValueKey('result-status-emblem'),
          width: 72,
          height: 72,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          semanticLabel: success ? 'Nexus 방어 성공' : 'Nexus 붕괴',
        ),
        const SizedBox(height: 8),
        Text(
          success ? 'Nexus 방어 성공' : 'Nexus 붕괴',
          textAlign: TextAlign.center,
          style: GameTextStyles.title,
        ),
        const SizedBox(height: 7),
        Text(
          success
              ? '스테이지 ${snapshot.currentStageNumber} 클리어'
              : '스테이지 ${snapshot.currentStageNumber} 종료',
          textAlign: TextAlign.center,
          style: GameTextStyles.withColor(GameTextStyles.body, accent),
        ),
      ],
    );
  }
}

class _RewardSummary extends StatelessWidget {
  const _RewardSummary({
    required this.runeReward,
    required this.corePointReward,
    required this.turretModuleTicketReward,
    required this.subText,
    required this.success,
  });

  final int runeReward;
  final int corePointReward;
  final int turretModuleTicketReward;
  final String subText;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final borderColor = success ? GamePalette.gold : GamePalette.warning;
    final amountColor = success ? GamePalette.goldBright : GamePalette.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: GamePalette.backdrop.withValues(alpha: 0.62),
        border: Border.all(color: borderColor.withValues(alpha: 0.52)),
        borderRadius: BorderRadius.circular(GamePalette.radius),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: success ? 0.14 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '보상 획득',
            style: GameTextStyles.withColor(
              GameTextStyles.caption,
              borderColor,
            ),
          ),
          const SizedBox(height: 4),
          ScaleDownText(
            '+${_formatInteger(runeReward)} 룬',
            style: TextStyle(
              color: amountColor,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1,
              shadows: GameTextStyles.textShadow,
            ),
          ),
          if (corePointReward > 0) ...[
            const SizedBox(height: 7),
            ScaleDownText(
              RuneNexusLocalizations.of(
                context,
              ).corePointReward(corePointReward),
              key: const ValueKey('result-core-point-reward'),
              style: const TextStyle(
                color: Color(0xFF8EE6FF),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1,
                shadows: GameTextStyles.textShadow,
              ),
            ),
          ],
          if (turretModuleTicketReward > 0) ...[
            const SizedBox(height: 7),
            FittedBox(
              key: const ValueKey('result-turret-module-ticket-reward'),
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    turretModuleTicketIconAsset,
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    RuneNexusLocalizations.of(
                      context,
                    ).turretModuleTicketReward(turretModuleTicketReward),
                    style: const TextStyle(
                      color: Color(0xFFE7C66A),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      shadows: GameTextStyles.textShadow,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 7),
          ScaleDownText(
            subText,
            style: GameTextStyles.withColor(
              GameTextStyles.body,
              GamePalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.success,
    required this.onConfirm,
    required this.onRestart,
  });

  final bool success;
  final VoidCallback? onConfirm;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final accent = success ? GamePalette.cyan : GamePalette.danger;
    final restartAccent = success ? GamePalette.cyan : GamePalette.warning;
    const buttonWidth = 208.0;
    const buttonHeight = 34.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameButton(
          onPressed: onConfirm,
          label: '확인',
          variant: GameButtonVariant.primary,
          accentColor: accent,
          width: buttonWidth,
          height: buttonHeight,
        ),
        const SizedBox(height: 6),
        GameButton(
          onPressed: onRestart,
          icon: const Icon(Icons.replay, size: 13),
          label: '다시 시작',
          variant: GameButtonVariant.ghost,
          compact: true,
          width: buttonWidth,
          height: buttonHeight,
          accentColor: restartAccent,
        ),
      ],
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.78,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: GameTextStyles.withColor(
                GameTextStyles.sectionTitle,
                GamePalette.cyanBright,
              ),
            ),
            const SizedBox(height: 7),
            child,
          ],
        ),
      ),
    );
  }
}

class _CompactStatList extends StatelessWidget {
  const _CompactStatList({required this.rows});

  final List<_CompactStatRow> rows;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {0: FixedColumnWidth(86), 1: FlexColumnWidth()},
      children: [
        for (final row in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Text(row.label, style: GameTextStyles.caption),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ScaleDownText(
                    row.value,
                    textAlign: TextAlign.right,
                    alignment: Alignment.centerRight,
                    style: GameTextStyles.withColor(
                      GameTextStyles.body,
                      row.highlight
                          ? GamePalette.green
                          : GamePalette.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _CompactStatRow {
  const _CompactStatRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;
}

class _UnlockSection extends StatelessWidget {
  const _UnlockSection({required this.groups});

  final List<_UnlockGroup> groups;

  @override
  Widget build(BuildContext context) {
    return _ResultSection(
      title: '해금 항목',
      child: Column(
        children: [
          for (final group in groups)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(group.label, style: GameTextStyles.caption),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      children: [
                        for (final item in group.items)
                          _UnlockItem(label: item),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            '각 탭에서 상세 확인 가능',
            textAlign: TextAlign.center,
            style: GameTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _UnlockItem extends StatelessWidget {
  const _UnlockItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '◆',
          style: TextStyle(
            color: GamePalette.gold,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: GamePalette.goldBright,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _UnlockGroup {
  const _UnlockGroup(this.label, this.items);

  final String label;
  final List<String> items;
}
