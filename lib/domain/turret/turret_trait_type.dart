enum TurretTraitType {
  overheatMagazine,
  lightweightBarrel,
  suppressiveFire,
  chainCleanup,
}

extension TurretTraitTypeText on TurretTraitType {
  String get nameText {
    return switch (this) {
      TurretTraitType.overheatMagazine => '과열 탄창',
      TurretTraitType.lightweightBarrel => '경량 총열',
      TurretTraitType.suppressiveFire => '제압 사격',
      TurretTraitType.chainCleanup => '연쇄 소탕',
    };
  }

  String get shortText {
    return switch (this) {
      TurretTraitType.overheatMagazine => '같은 대상 명중마다 피해 +2%, 최대 15중첩',
      TurretTraitType.lightweightBarrel => '공격 속도 +10%, 투사체 속도 +30%',
      TurretTraitType.suppressiveFire => '같은 대상 5회 명중 시 2초간 물리 취약 +20%p',
      TurretTraitType.chainCleanup => '최근 명중 관여 처치 시 3초간 공격 속도 +40%',
    };
  }

  String get intentText {
    return switch (this) {
      TurretTraitType.overheatMagazine => '보스와 탱커를 오래 때리는 캐리 기관총',
      TurretTraitType.lightweightBarrel => '빠른 적 대응과 초반 안정성',
      TurretTraitType.suppressiveFire => '보스/탱커와 물리 조합 지원',
      TurretTraitType.chainCleanup => '웨이브 정리와 킬 체인',
    };
  }
}
