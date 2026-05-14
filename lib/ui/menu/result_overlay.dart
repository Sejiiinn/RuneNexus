import 'package:flutter/material.dart';

import '../../domain/combat/game_phase.dart';
import '../../game/game_snapshot.dart';
import '../../game/rune_nexus_game.dart';
import '../widgets/rune_balance_card.dart';

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
    final success = snapshot.phase == GamePhase.success;
    final nextStageNumber = snapshot.currentStageNumber + 1;
    final canStartNextStage =
        success && nextStageNumber <= snapshot.unlockedStageCount;
    final bestRound =
        snapshot.bestRoundsByStage[snapshot.currentStageNumber] ??
        snapshot.completedRounds;
    final recordText = snapshot.lastRunWasNewBestRound
        ? '신기록 ${snapshot.completedRounds}R'
        : snapshot.clearedStageNumbers.contains(snapshot.currentStageNumber)
        ? '클리어'
        : '최고 ${bestRound}R';
    final stageStatusText = success
        ? snapshot.lastRunUnlockedStageNumber != null
              ? '스테이지 ${snapshot.lastRunUnlockedStageNumber} 신규 해금'
              : canStartNextStage
              ? '스테이지 $nextStageNumber 이용 가능'
              : '스테이지 ${snapshot.currentStageNumber} 클리어'
        : '기록 $recordText';
    final topDamageText = snapshot.topDamageTurretName == null
        ? '없음'
        : '${snapshot.topDamageTurretName} ${_formatDamageValue(snapshot.topDamageTurretDamageDealt)}';

    return Container(
      color: const Color(0xAA02070D),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xEE091624),
                  border: Border.all(
                    color: success
                        ? const Color(0xFF50E6FF)
                        : const Color(0xFFFF5A66),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      success
                          ? Icons.diamond_outlined
                          : Icons.warning_amber_rounded,
                      color: success
                          ? const Color(0xFF50E6FF)
                          : const Color(0xFFFF5A66),
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      success ? 'Nexus 방어 성공' : 'Nexus 붕괴',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stageStatusText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFC5DCE8)),
                    ),
                    if (snapshot.lastRunWasNewBestRound ||
                        snapshot.lastRunUnlockedStageNumber != null ||
                        snapshot.lastRunUnlockedSniperTurret) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (snapshot.lastRunWasNewBestRound)
                            _ResultHighlight(
                              icon: Icons.trending_up,
                              label: '신기록',
                              value: snapshot.lastRunPreviousBestRound > 0
                                  ? '${snapshot.lastRunPreviousBestRound}R → ${snapshot.completedRounds}R'
                                  : '${snapshot.completedRounds}R 첫 기록',
                            ),
                          if (snapshot.lastRunUnlockedStageNumber != null)
                            _ResultHighlight(
                              icon: Icons.lock_open,
                              label: '신규 해금',
                              value:
                                  '스테이지 ${snapshot.lastRunUnlockedStageNumber}',
                            ),
                          if (snapshot.lastRunUnlockedSniperTurret)
                            const _ResultHighlight(
                              icon: Icons.my_location,
                              label: '포탑 해금',
                              value: '저격',
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 2.55,
                      children: [
                        _ResultMetric(
                          label: '스테이지',
                          value: '${snapshot.currentStageNumber}',
                        ),
                        _ResultMetric(
                          label: '도달',
                          value: '${snapshot.completedRounds}R',
                        ),
                        _ResultMetric(label: '기록', value: recordText),
                        _ResultMetric(
                          label: '획득 룬',
                          value: '+${snapshot.lastRunRuneReward}',
                        ),
                        _ResultMetric(label: '최고 피해', value: topDamageText),
                      ],
                    ),
                    const SizedBox(height: 10),
                    RuneBalanceCard(runes: snapshot.runes, compact: true),
                    const SizedBox(height: 16),
                    if (canStartNextStage) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onStartStage == null
                              ? null
                              : () => onStartStage!(nextStageNumber),
                          icon: const Icon(Icons.flag_outlined, size: 17),
                          label: Text('스테이지 $nextStageNumber 시작'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onOpenStageSelect,
                            icon: const Icon(Icons.map_outlined, size: 16),
                            label: const Text('스테이지'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onOpenPermanentUpgrades,
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            label: const Text('업그레이드'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: game.restartDemo,
                        icon: const Icon(Icons.replay, size: 17),
                        label: const Text('현재 스테이지 재도전'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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

class _ResultHighlight extends StatelessWidget {
  const _ResultHighlight({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF102437),
        border: Border.all(color: const Color(0xFFE7C66A)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFE7C66A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE7C66A),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE8F8FF),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xAA07111D),
        border: Border.all(color: const Color(0x5533D8FF)),
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
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
