import 'package:flutter/material.dart';

import '../../domain/combat/game_phase.dart';
import '../../game/game_snapshot.dart';
import '../../game/rune_nexus_game.dart';

class ResultOverlay extends StatelessWidget {
  const ResultOverlay({required this.game, required this.snapshot, super.key});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final success = snapshot.phase == GamePhase.success;

    return Container(
      color: const Color(0xAA02070D),
      child: Center(
        child: Container(
          width: 280,
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
                success ? Icons.diamond_outlined : Icons.warning_amber_rounded,
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
                success ? '기본 전투 루프 검증 완료' : '배치와 포탑 조합을 다시 조정하세요',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFC5DCE8)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ResultMetric(
                      label: '도달',
                      value: '${snapshot.completedRounds}R',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ResultMetric(
                      label: '획득 룬',
                      value: '+${snapshot.lastRunRuneReward}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ResultMetric(
                      label: '보유 룬',
                      value: '${snapshot.runes}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ProgressionUpgradeButton(
                title: '시작 골드',
                level: snapshot.startingGoldUpgradeLevel,
                valueText: '+${snapshot.startingGoldUpgradeLevel * 10}G',
                cost: snapshot.startingGoldUpgradeCost,
                enabled: snapshot.canUpgradeStartingGold,
                onPressed: game.upgradeStartingGoldProgression,
              ),
              const SizedBox(height: 6),
              _ProgressionUpgradeButton(
                title: '넥서스 체력',
                level: snapshot.nexusHpUpgradeLevel,
                valueText: '+${snapshot.nexusHpUpgradeLevel}',
                cost: snapshot.nexusHpUpgradeCost,
                enabled: snapshot.canUpgradeNexusHp,
                onPressed: game.upgradeNexusHpProgression,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: game.restartDemo,
                child: const Text('다시 시작'),
              ),
            ],
          ),
        ),
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

class _ProgressionUpgradeButton extends StatelessWidget {
  const _ProgressionUpgradeButton({
    required this.title,
    required this.level,
    required this.valueText,
    required this.cost,
    required this.enabled,
    required this.onPressed,
  });

  final String title;
  final int level;
  final String valueText;
  final int cost;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 38,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFF6D7F8F),
          side: BorderSide(
            color: enabled ? const Color(0xFFE7C66A) : const Color(0x55485B68),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$title Lv.$level',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              valueText,
              style: const TextStyle(fontSize: 11, color: Color(0xFFB9D6E4)),
            ),
            const SizedBox(width: 10),
            Text('룬 $cost', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
