enum CoreCombatSkill { guardianBeam, riftMark }

extension CoreCombatSkillLabel on CoreCombatSkill {
  String get label {
    return switch (this) {
      CoreCombatSkill.guardianBeam => '수호 광선',
      CoreCombatSkill.riftMark => '균열 낙인',
    };
  }
}
