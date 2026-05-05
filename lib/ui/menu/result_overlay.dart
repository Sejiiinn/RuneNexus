import 'package:flutter/material.dart';

import '../../domain/combat/game_phase.dart';
import '../../game/game_snapshot.dart';
import '../../game/rune_nexus_game.dart';
import '../widgets/rune_balance_card.dart';

class ResultOverlay extends StatelessWidget {
  const ResultOverlay({
    required this.game,
    required this.snapshot,
    this.onOpenMainMenu,
    super.key,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final VoidCallback? onOpenMainMenu;

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
                    child: Center(
                      child: RuneBalanceCard(
                        runes: snapshot.runes,
                        compact: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onOpenMainMenu,
                      child: const Text('메인으로'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: game.restartDemo,
                      child: const Text('다시 시작'),
                    ),
                  ),
                ],
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
