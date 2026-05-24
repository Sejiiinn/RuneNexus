enum CoreCombatSkill { guardianBeam }

extension CoreCombatSkillLabel on CoreCombatSkill {
  String get label {
    return switch (this) {
      CoreCombatSkill.guardianBeam => '수호 광선',
    };
  }
}

enum CorePassiveAbility { stabilityCircuit, precisionCircuit }

extension CorePassiveAbilityLabel on CorePassiveAbility {
  String get label {
    return switch (this) {
      CorePassiveAbility.stabilityCircuit => '안정 회로',
      CorePassiveAbility.precisionCircuit => '정밀 회로',
    };
  }
}
