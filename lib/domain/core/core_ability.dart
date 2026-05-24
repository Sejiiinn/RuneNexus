enum CoreCombatSkill { guardianBeam }

extension CoreCombatSkillLabel on CoreCombatSkill {
  String get label {
    return switch (this) {
      CoreCombatSkill.guardianBeam => '수호 광선',
    };
  }
}

enum CorePassiveAbility { selfRepair, costSavingDesign }

extension CorePassiveAbilityLabel on CorePassiveAbility {
  String get label {
    return switch (this) {
      CorePassiveAbility.selfRepair => '자가 수복',
      CorePassiveAbility.costSavingDesign => '절약 설계',
    };
  }
}
