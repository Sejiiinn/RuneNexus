enum TurretTraitType {
  overheatMagazine,
  lightweightBarrel,
  shrapnelShell,
  compressedCharge,
  highHeatBurn,
  lingeringEmbers,
  ignitionBurst,
  chainIgnition,
  rapidCooling,
  spreadingChill,
  frostCrack,
  coolingCycle,
  suppressiveFire,
  chainCleanup,
}

extension TurretTraitTypeText on TurretTraitType {
  String get nameText {
    return switch (this) {
      TurretTraitType.overheatMagazine => '과열 탄창',
      TurretTraitType.lightweightBarrel => '경량 총열',
      TurretTraitType.shrapnelShell => '파편 장전',
      TurretTraitType.compressedCharge => '압축 장약',
      TurretTraitType.highHeatBurn => '고열 연소',
      TurretTraitType.lingeringEmbers => '잔불 지속',
      TurretTraitType.ignitionBurst => '점화 폭발',
      TurretTraitType.chainIgnition => '연쇄 발화',
      TurretTraitType.rapidCooling => '급속 냉각',
      TurretTraitType.spreadingChill => '확산 냉기',
      TurretTraitType.frostCrack => '동상 균열',
      TurretTraitType.coolingCycle => '빙결 순환',
      TurretTraitType.suppressiveFire => '제압 사격',
      TurretTraitType.chainCleanup => '연쇄 소탕',
    };
  }

  String get shortText {
    return switch (this) {
      TurretTraitType.overheatMagazine => '같은 대상 명중마다 피해 +2%, 최대 15중첩',
      TurretTraitType.lightweightBarrel => '공격 속도 10% 증폭, 투사체 속도 30% 증폭',
      TurretTraitType.shrapnelShell => '폭발 반경 20% 증폭, 주변 피해 +10%p',
      TurretTraitType.compressedCharge => '직격 피해 +35%, 공격 속도 -10%',
      TurretTraitType.highHeatBurn => '화상 피해 +25%',
      TurretTraitType.lingeringEmbers => '화상 지속시간 +40%',
      TurretTraitType.ignitionBurst => '화상 중인 대상 명중 시 최종 화상 지속시간 30%분 직접 피해',
      TurretTraitType.chainIgnition => '화상 처치 시 주변 1명에게 남은 화상 60% 전이',
      TurretTraitType.rapidCooling => '둔화율 강화',
      TurretTraitType.spreadingChill => '사거리 15% 증폭, 피해 -10%',
      TurretTraitType.frostCrack => '둔화 대상에게 마법 취약 +15%p',
      TurretTraitType.coolingCycle => '공격 속도 20% 증폭, 둔화 지속시간 -15%',
      TurretTraitType.suppressiveFire => '같은 대상 5회 명중 시 2초간 물리 취약 +20%p',
      TurretTraitType.chainCleanup => '최근 명중 관여 처치 시 3초간 공격 속도 40% 증폭',
    };
  }
}
