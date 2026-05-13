enum TurretTraitType {
  overheatMagazine,
  lightweightBarrel,
  shrapnelShell,
  compressedCharge,
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
      TurretTraitType.suppressiveFire => '제압 사격',
      TurretTraitType.chainCleanup => '연쇄 소탕',
    };
  }

  String get shortText {
    return switch (this) {
      TurretTraitType.overheatMagazine => '같은 대상 명중마다 피해 +2%, 최대 15중첩',
      TurretTraitType.lightweightBarrel => '공격 속도 +10%, 투사체 속도 +30%',
      TurretTraitType.shrapnelShell => '폭발 반경 +20%, 주변 피해 +10%p',
      TurretTraitType.compressedCharge => '직격 피해 +35%, 공격 속도 -10%',
      TurretTraitType.suppressiveFire => '같은 대상 5회 명중 시 2초간 물리 취약 +20%p',
      TurretTraitType.chainCleanup => '최근 명중 관여 처치 시 3초간 공격 속도 +40%',
    };
  }
}
