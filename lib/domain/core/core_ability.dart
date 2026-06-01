enum CoreCombatSkill { guardianBeam, riftMark }

extension CoreCombatSkillLabel on CoreCombatSkill {
  String get label {
    return switch (this) {
      CoreCombatSkill.guardianBeam => '수호 광선',
      CoreCombatSkill.riftMark => '균열 낙인',
    };
  }
}

enum CorePassiveAbility { selfRepair, costSavingDesign, skillAcceleration }

extension CorePassiveAbilityLabel on CorePassiveAbility {
  String get label {
    return switch (this) {
      CorePassiveAbility.selfRepair => '자가 수복',
      CorePassiveAbility.costSavingDesign => '절약 설계',
      CorePassiveAbility.skillAcceleration => '연산 가속',
    };
  }
}
