import 'package:flutter/material.dart';

import '../../domain/core/core_ability.dart';
import '../../game/game_snapshot.dart';

class HudCoreInfoPanel extends StatelessWidget {
  const HudCoreInfoPanel({required this.snapshot, super.key});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final skill = snapshot.coreCombatSkill;
    final passiveAbilities = snapshot.corePassiveSlots
        .whereType<CorePassiveAbility>()
        .toList();
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
                      '전투 스킬 ${skill == null ? 0 : 1}개 · 패시브 ${passiveAbilities.length}개 장착',
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
                    '${snapshot.nexusHp.round()} / ${snapshot.maxNexusHp.round()}',
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
          _CorePassiveInfoRow(passiveAbilities: passiveAbilities),
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
          if (metric != null) ...[
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                metric,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  color: Color(0xFF8EE6FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CorePassiveInfoRow extends StatelessWidget {
  const _CorePassiveInfoRow({required this.passiveAbilities});

  final List<CorePassiveAbility> passiveAbilities;

  @override
  Widget build(BuildContext context) {
    return _CoreInfoSection(
      label: '패시브',
      child: passiveAbilities.isEmpty
          ? const _CoreInfoText(
              title: '패시브 없음',
              description: '장착된 코어 패시브가 없습니다.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < passiveAbilities.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  _CoreInfoText(
                    title: passiveAbilities[i].label,
                    description: _corePassiveDescription(passiveAbilities[i]),
                  ),
                ],
              ],
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

String? _coreCombatSkillMetric(CoreCombatSkill? skill, GameSnapshot snapshot) {
  return switch (skill) {
    CoreCombatSkill.guardianBeam =>
      '현재 피해 ${_formatCoreCombatStat(snapshot.nexusCoreBeamDamage)}',
    CoreCombatSkill.riftMark =>
      '총 추가 피해 ${_formatCoreCombatStat(snapshot.coreCombatSkillBonusDamageDealt)}',
    null => null,
  };
}

String _corePassiveDescription(CorePassiveAbility ability) {
  return switch (ability) {
    CorePassiveAbility.selfRepair => '5라운드마다 내구도 1 회복',
    CorePassiveAbility.costSavingDesign => '포탑 건설 비용 15% 감소',
    CorePassiveAbility.skillAcceleration => '전투 스킬 재사용 대기시간 10% 감소',
  };
}

String _formatCoreCombatStat(double value) {
  if (value >= 100) {
    return value.round().toString();
  }
  if (value >= 10) {
    return value.toStringAsFixed(1);
  }
  return value.toStringAsFixed(2);
}
