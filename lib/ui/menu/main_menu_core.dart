part of 'main_menu_screen.dart';

class _CoreCombatSkillMenu extends StatelessWidget {
  const _CoreCombatSkillMenu({
    required this.game,
    required this.snapshot,
    required this.onClose,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final riftMarkUnlocked = snapshot.unlockedStageCount >= 6;
    return Container(
      key: const ValueKey('core-combat-skill-menu'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF20B1B2B), Color(0xF006101A)],
        ),
        border: Border.all(color: const Color(0x885D7182)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '코어 스킬 선택',
                  style: TextStyle(
                    color: Color(0xFFE8FBFF),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              GameModalCloseButton(
                key: const ValueKey('core-combat-skill-close'),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CoreCombatSkillCard(
            skill: CoreCombatSkill.guardianBeam,
            state: '5초마다 자동 발동',
            description: '가장 앞선 적에게 광선을 발사하며 포탑 화력에 비례해 피해가 증가합니다.',
            accent: const Color(0xFF8EE6FF),
            equipped: snapshot.coreCombatSkill == CoreCombatSkill.guardianBeam,
            unlocked: true,
            onPressed: () => _toggleCombatSkill(
              game,
              snapshot,
              CoreCombatSkill.guardianBeam,
            ),
          ),
          const SizedBox(height: 9),
          _CoreCombatSkillCard(
            skill: CoreCombatSkill.riftMark,
            state: riftMarkUnlocked ? '10초마다 자동 발동' : '챕터 2 해금',
            description: riftMarkUnlocked
                ? '내구도가 높은 적 4명의 받는 모든 피해를 기본 25% 증폭합니다. 코어 스킬 위력에 비례하며 보스는 절반입니다.'
                : '스테이지 6에 도달하면 균열 낙인을 장착할 수 있습니다.',
            accent: const Color(0xFFCFA7FF),
            equipped: snapshot.coreCombatSkill == CoreCombatSkill.riftMark,
            unlocked: riftMarkUnlocked,
            onPressed: riftMarkUnlocked
                ? () => _toggleCombatSkill(
                    game,
                    snapshot,
                    CoreCombatSkill.riftMark,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  void _toggleCombatSkill(
    RuneNexusGame game,
    GameSnapshot snapshot,
    CoreCombatSkill skill,
  ) {
    if (snapshot.coreCombatSkill == skill) {
      game.unequipCoreCombatSkill();
    } else {
      game.equipCoreCombatSkill(skill);
    }
  }
}

class _CoreCombatSkillCard extends StatelessWidget {
  const _CoreCombatSkillCard({
    required this.skill,
    required this.state,
    required this.description,
    required this.accent,
    required this.equipped,
    required this.unlocked,
    required this.onPressed,
  });

  final CoreCombatSkill skill;
  final String state;
  final String description;
  final Color accent;
  final bool equipped;
  final bool unlocked;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: ValueKey('core-combat-skill-${skill.name}'),
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: equipped
            ? accent.withValues(alpha: 0.13)
            : const Color(0xB30B1824),
        border: Border.all(
          color: equipped
              ? accent.withValues(alpha: 0.9)
              : const Color(0x665D7182),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: unlocked ? 0.13 : 0.05),
              border: Border.all(color: accent.withValues(alpha: 0.55)),
              shape: BoxShape.circle,
            ),
            child: CoreAbilityIcon(
              skill,
              size: 28,
              color: unlocked ? null : const Color(0xFF71828D),
              semanticLabel: skill.label,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.label,
                  style: const TextStyle(
                    color: Color(0xFFE8FBFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state,
                  style: TextStyle(
                    color: accent.withValues(alpha: unlocked ? 0.95 : 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFFB4C7D2),
                    fontSize: 10,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(52, 38),
                backgroundColor: accent.withValues(alpha: 0.22),
                disabledBackgroundColor: const Color(0x55364650),
                foregroundColor: const Color(0xFFE8FBFF),
                textStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text(
                equipped
                    ? '해제'
                    : unlocked
                    ? '장착'
                    : '잠김',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
