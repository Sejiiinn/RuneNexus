import 'package:flutter/material.dart';

import '../../data/definitions/game_enemy_data.dart';
import '../../domain/combat/game_phase.dart';
import '../../domain/enemy/enemy_definition.dart';
import '../../domain/enemy/enemy_scaling.dart';
import '../../domain/turret/attack_tag.dart';
import '../../domain/turret/damage_family.dart';
import '../../game/game_snapshot.dart';
import '../game/game_icons.dart';
import '../game/game_modal.dart';
import 'hud_common.dart';

class HudPortalSummaryCard extends StatelessWidget {
  const HudPortalSummaryCard({
    required this.snapshot,
    required this.statusText,
    super.key,
  });

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
            ? () => showGameBottomSheet<void>(
                context: context,
                builder: (context) =>
                    HudPortalWaveDetailSheet(snapshot: snapshot),
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
                      overflow: TextOverflow.clip,
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
                      overflow: TextOverflow.clip,
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
              child: HudEnemyIcon(type: type, selected: false, size: 25),
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

class HudPortalWaveDetailSheet extends StatelessWidget {
  const HudPortalWaveDetailSheet({required this.snapshot, super.key});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return GameBottomSheetFrame(
      accentColor: const Color(0xFFB16DFF),
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
              GameModalCloseButton(
                tooltip: '닫기',
                onPressed: () => Navigator.of(context).pop(),
                accentColor: const Color(0xFFB16DFF),
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
          HudEnemyIcon(type: enemy.type, selected: false, size: 18),
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
              HudEnemyIcon(type: enemy.type, selected: false),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${enemy.name} x$count',
                  overflow: TextOverflow.clip,
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
              HudStatPill(
                label: '체력',
                value: maxHp.round().toString(),
                expand: false,
              ),
              if (maxArmor > 0)
                HudStatPill(
                  label: '방어구',
                  value: maxArmor.round().toString(),
                  expand: false,
                ),
              if (maxShield > 0)
                HudStatPill(
                  label: '보호막',
                  value: maxShield.round().toString(),
                  expand: false,
                ),
              HudStatPill(
                label: '속도',
                value: enemy.speed.round().toString(),
                expand: false,
              ),
              HudStatPill(
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
              HudStatPill(
                label: '보상',
                value: '+${enemy.rewardGold}',
                expand: false,
                valueChild: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GoldCurrencyIcon(size: 12),
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
