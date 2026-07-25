import 'package:flutter/material.dart';

import '../../data/definitions/game_core_passive_tree_data.dart';
import '../../domain/core/core_ability.dart';
import '../../game/game_snapshot.dart';
import 'hud_common.dart';

class HudCoreInfoPanel extends StatelessWidget {
  const HudCoreInfoPanel({required this.snapshot, super.key});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final skill = snapshot.coreCombatSkill;
    final allocatedNodeCount = snapshot.corePassiveNodeRanks.values
        .where((rank) => rank > 0)
        .length;
    final hpProgress = snapshot.maxNexusHp <= 0
        ? 0.0
        : (snapshot.nexusHp / snapshot.maxNexusHp).clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xAA0B1B2B),
        border: Border.all(color: const Color(0x778EE6FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const _NexusCoreIcon(),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '넥서스 코어',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE8F8FF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '전투 스킬 ${skill == null ? 0 : 1}개 · 패시브 노드 $allocatedNodeCount개 할당',
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
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${hudFormatNexusHp(snapshot.nexusHp)} / '
                    '${hudFormatNexusHp(snapshot.maxNexusHp)}',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF72E0A2),
                    ),
                  ),
                  const Text(
                    '내구도',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8FA8BA),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: hpProgress,
              backgroundColor: const Color(0x332A4A5D),
              color: const Color(0xFF72E0A2),
            ),
          ),
          const SizedBox(height: 8),
          _CoreSkillInfoRow(skill: skill, snapshot: snapshot),
          const SizedBox(height: 8),
          _CorePassiveTreeInfoRow(snapshot: snapshot),
        ],
      ),
    );
  }
}

class _CoreSkillInfoRow extends StatelessWidget {
  const _CoreSkillInfoRow({required this.skill, required this.snapshot});

  final CoreCombatSkill? skill;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final title = skill?.label ?? '전투 스킬 없음';
    final description = skill == null
        ? '코어 전투 스킬이 장착되어 있지 않습니다.'
        : _coreCombatSkillDescription(skill!);
    final metric = _coreCombatSkillMetric(skill, snapshot);

    return _CoreInfoSection(
      label: '전투 스킬',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CoreInfoText(title: title, description: description),
          if (metric != null) ...[const SizedBox(height: 5), metric],
        ],
      ),
    );
  }
}

class _CorePassiveTreeInfoRow extends StatelessWidget {
  const _CorePassiveTreeInfoRow({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _CoreInfoSection(
      label: '패시브 트리',
      child: _CoreInfoText(
        title: '${snapshot.spentCorePoints} / ${snapshot.totalCorePoints}pt',
        description: '남은 코어 포인트 ${snapshot.availableCorePoints}pt',
      ),
    );
  }
}

class _CoreInfoSection extends StatelessWidget {
  const _CoreInfoSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x66101F2C),
        border: Border.all(color: const Color(0x338EE6FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              color: Color(0xFF8FA8BA),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }
}

class _NexusCoreIcon extends StatelessWidget {
  const _NexusCoreIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 31,
      height: 31,
      decoration: BoxDecoration(
        color: const Color(0xFF103041),
        border: Border.all(color: const Color(0xFF8EE6FF), width: 1.4),
        borderRadius: BorderRadius.circular(7),
        boxShadow: const [
          BoxShadow(color: Color(0x338EE6FF), blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: Center(
        child: Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: const Color(0x338EE6FF),
              border: Border.all(color: const Color(0xFFE8FBFF), width: 1.3),
            ),
            child: Center(
              child: Container(
                width: 5,
                height: 5,
                color: const Color(0xFF8EE6FF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoreInfoText extends StatelessWidget {
  const _CoreInfoText({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFE8F8FF),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFB8D4E2),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

String _coreCombatSkillDescription(CoreCombatSkill skill) {
  return switch (skill) {
    CoreCombatSkill.guardianBeam => '코어에 가까운 적에게 집중 피해',
    CoreCombatSkill.riftMark => '내구도 높은 적 4명에게 받는 피해 25% 증가 낙인 부여',
  };
}

Widget? _coreCombatSkillMetric(CoreCombatSkill? skill, GameSnapshot snapshot) {
  return switch (skill) {
    CoreCombatSkill.guardianBeam => Row(
      children: [
        Flexible(
          child: Text(
            '광선 피해 ${_formatCoreCombatStat(snapshot.nexusCoreBeamDamage)}',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: _coreCombatMetricTextStyle,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            '총 피해 ${_formatCoreCombatStat(snapshot.coreCombatSkillDirectDamageDealt)}',
            maxLines: 1,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.right,
            style: _coreCombatMetricTextStyle,
          ),
        ),
      ],
    ),
    CoreCombatSkill.riftMark => _riftMarkMetric(snapshot),
    null => null,
  };
}

Widget _riftMarkMetric(GameSnapshot snapshot) {
  final nextActivationMultiplier = corePassiveCoreSkillPowerMultiplier(
    snapshot.corePassiveNodeRanks,
    activationNumber: snapshot.coreCombatSkillActivationCount + 1,
  );
  final nextAmplificationPercent = 25.0 * nextActivationMultiplier;
  return Row(
    children: [
      Flexible(
        child: Text(
          '다음 효과 +${_formatCoreCombatPercent(nextAmplificationPercent)}%',
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: _coreCombatMetricTextStyle,
        ),
      ),
      const Spacer(),
      Flexible(
        child: Text(
          '총 추가 피해 ${_formatCoreCombatStat(snapshot.coreCombatSkillBonusDamageDealt)}',
          maxLines: 1,
          overflow: TextOverflow.clip,
          textAlign: TextAlign.right,
          style: _coreCombatMetricTextStyle,
        ),
      ),
    ],
  );
}

const _coreCombatMetricTextStyle = TextStyle(
  color: Color(0xFF8EE6FF),
  fontSize: 10,
  fontWeight: FontWeight.w900,
);

String _formatCoreCombatStat(double value) {
  if (value >= 100) {
    return value.round().toString();
  }
  if (value >= 10) {
    return value.toStringAsFixed(1);
  }
  return value.toStringAsFixed(2);
}

String _formatCoreCombatPercent(double value) {
  if ((value - value.round()).abs() < 0.001) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
