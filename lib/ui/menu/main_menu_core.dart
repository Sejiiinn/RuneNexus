part of 'main_menu_screen.dart';

enum _CoreMenuView { combatSkill, passiveTree }

class _CoreMenu extends StatefulWidget {
  const _CoreMenu({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  State<_CoreMenu> createState() => _CoreMenuState();
}

class _CoreMenuState extends State<_CoreMenu> {
  _CoreMenuView _view = _CoreMenuView.combatSkill;

  @override
  Widget build(BuildContext context) {
    final l10n = RuneNexusLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CoreViewTabs(
          selected: _view,
          combatSkillLabel: l10n.coreCombatSkills,
          passiveTreeLabel: l10n.corePassiveTree,
          onSelected: (view) => setState(() => _view = view),
        ),
        const SizedBox(height: 10),
        switch (_view) {
          _CoreMenuView.combatSkill => _CoreCombatSkillMenu(
            game: widget.game,
            snapshot: widget.snapshot,
          ),
          _CoreMenuView.passiveTree => _CorePassiveTreeMenu(
            game: widget.game,
            snapshot: widget.snapshot,
          ),
        },
      ],
    );
  }
}

class _CoreViewTabs extends StatelessWidget {
  const _CoreViewTabs({
    required this.selected,
    required this.combatSkillLabel,
    required this.passiveTreeLabel,
    required this.onSelected,
  });

  final _CoreMenuView selected;
  final String combatSkillLabel;
  final String passiveTreeLabel;
  final ValueChanged<_CoreMenuView> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('core-view-tabs'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xE6091724),
        border: Border.all(color: const Color(0x775D7182)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CoreViewTabButton(
              label: combatSkillLabel,
              selected: selected == _CoreMenuView.combatSkill,
              onTap: () => onSelected(_CoreMenuView.combatSkill),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _CoreViewTabButton(
              label: passiveTreeLabel,
              selected: selected == _CoreMenuView.passiveTree,
              onTap: () => onSelected(_CoreMenuView.passiveTree),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoreViewTabButton extends StatelessWidget {
  const _CoreViewTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF16465A), Color(0xFF0B2637)],
                  )
                : null,
            border: Border.all(
              color: selected ? const Color(0xCC8EE6FF) : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: selected
                  ? const Color(0xFFE8FBFF)
                  : const Color(0xFF8FA8BA),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoreCombatSkillMenu extends StatelessWidget {
  const _CoreCombatSkillMenu({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

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
                ? '내구도가 높은 적에게 낙인을 부여해 대상이 받는 모든 피해를 증가시킵니다.'
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
                  maxLines: 1,
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
                  maxLines: 3,
                  overflow: TextOverflow.fade,
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
