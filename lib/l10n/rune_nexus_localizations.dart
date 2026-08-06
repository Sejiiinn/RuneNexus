import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/definitions/game_core_passive_tree_data.dart';
import '../domain/core/core_passive_tree.dart';

class RuneNexusLocalizations {
  const RuneNexusLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('ko'), Locale('en')];
  static const delegate = _RuneNexusLocalizationsDelegate();

  static RuneNexusLocalizations of(BuildContext context) {
    return Localizations.of<RuneNexusLocalizations>(
          context,
          RuneNexusLocalizations,
        ) ??
        const RuneNexusLocalizations(Locale('ko'));
  }

  bool get _isEnglish => locale.languageCode == 'en';

  String get appTitle => 'Rune Nexus';
  String get stageTab => _isEnglish ? 'Stage' : '스테이지';
  String get coreTab => _isEnglish ? 'Core' : '코어';
  String get coreCombatSkills => _isEnglish ? 'Combat Skills' : '전투 스킬';
  String get corePassiveTree => _isEnglish ? 'Passive Tree' : '패시브 트리';
  String get corePoints => _isEnglish ? 'Core Points' : '코어 포인트';
  String get corePointsSpent => _isEnglish ? 'Spent' : '사용';
  String get corePointsAvailable => _isEnglish ? 'Available' : '남음';
  String get corePassiveResetAll => _isEnglish ? 'Reset All' : '전체 초기화';
  String get corePassiveResetTitle =>
      _isEnglish ? 'Reset the passive tree?' : '패시브 트리를 초기화할까요?';
  String get corePassiveResetMessage => _isEnglish
      ? 'All assigned ranks will be returned for free. Your total Core Points will not change.'
      : '할당한 모든 랭크를 무료로 회수합니다. 총 코어 포인트는 줄어들지 않습니다.';
  String get corePassiveAssign => _isEnglish ? 'Assign' : '할당';
  String get corePassivePlanned => _isEnglish ? 'Planned' : '예정';
  String get corePassiveRemainingAfterPlan =>
      _isEnglish ? 'After plan' : '확정 후';
  String get corePassiveCancelPlan => _isEnglish ? 'Cancel changes' : '변경 취소';
  String get corePassivePlannedRank => _isEnglish ? 'Planned rank' : '예정 랭크';
  String get corePassiveAllocationInProgress =>
      _isEnglish ? 'Allocating...' : '할당 중...';
  String get corePassiveReturnedPoints =>
      _isEnglish ? 'Returned points' : '반환 포인트';
  String get corePassiveUnlockHint => _isEnglish
      ? 'Strengthen a connected node to unlock it.'
      : '연결된 노드를 강화하면 개방됩니다';
  String get corePassiveSelectionHint => _isEnglish
      ? 'Select a node to view its effects and ranks.'
      : '노드를 선택해 효과와 랭크를 확인하세요';
  String get corePassiveGestureHint =>
      _isEnglish ? 'Drag to move · Pinch to zoom' : '드래그로 이동 · 두 손가락으로 확대/축소';
  String get corePassiveCurrentEffect =>
      _isEnglish ? 'Current effect' : '현재 효과';
  String get corePassiveNextEffect => _isEnglish ? 'Next effect' : '다음 효과';
  String get corePassiveEffect => _isEnglish ? 'Effect' : '효과';
  String get corePassiveRequiredPoints =>
      _isEnglish ? 'Required points' : '필요 포인트';
  String get corePassiveMaxRank => _isEnglish ? 'Maximum rank' : '최대 랭크';
  String get corePassiveAttack => _isEnglish ? 'Attack' : '공격';
  String get corePassiveControl => _isEnglish ? 'Defense' : '방위';
  String get corePassiveEfficiency => _isEnglish ? 'Efficiency' : '효율';
  String get corePointEarned => _isEnglish ? 'Core Points earned' : '코어 포인트 획득';

  String corePointReward(int amount) =>
      _isEnglish ? '+$amount Core Points' : '+$amount 코어 포인트';

  String corePassiveNodeName(CorePassiveNodeId id) {
    return switch (id) {
      CorePassiveNodeId.attackHaste => _isEnglish ? 'Haste Circuit' : '가속 회로',
      CorePassiveNodeId.attackOutput =>
        _isEnglish ? 'Output Amplifier' : '출력 증폭',
      CorePassiveNodeId.attackPrecompute =>
        _isEnglish ? 'Acceleration Sync' : '가속 동기화',
      CorePassiveNodeId.attackFocus => _isEnglish ? 'Firepower Sync' : '화력 동기화',
      CorePassiveNodeId.attackGuardianBeam =>
        _isEnglish ? 'Continuous Computation' : '연속 연산',
      CorePassiveNodeId.attackRiftMark =>
        _isEnglish ? 'Critical Output' : '임계 출력',
      CorePassiveNodeId.attackOverclock =>
        _isEnglish ? 'Transcendent Output' : '초월 출력',
      CorePassiveNodeId.controlThreatSense =>
        _isEnglish ? 'Impact Dispersion' : '충격 분산',
      CorePassiveNodeId.controlSelfRepair =>
        _isEnglish ? 'Reinforced Shell' : '강화 외피',
      CorePassiveNodeId.controlRetarget => _isEnglish ? 'Self Repair' : '자가 수복',
      CorePassiveNodeId.controlRearLock =>
        _isEnglish ? 'Threat Weakening' : '위협 약화',
      CorePassiveNodeId.controlEmergencyCharge =>
        _isEnglish ? 'Emergency Charge' : '비상 충전',
      CorePassiveNodeId.controlBufferShell =>
        _isEnglish ? 'Damage Restoration' : '손상 복원',
      CorePassiveNodeId.controlFinalLine =>
        _isEnglish ? 'Final Defense Line' : '최종 방위선',
      CorePassiveNodeId.efficiencySaving =>
        _isEnglish ? 'Efficient Design' : '절약 설계',
      CorePassiveNodeId.efficiencyDiversity =>
        _isEnglish ? 'Diversity Resonance' : '다양성 감응',
      CorePassiveNodeId.efficiencyFirstDeploy =>
        _isEnglish ? 'Trait Engineering' : '특성 공학',
      CorePassiveNodeId.efficiencyFirstLink =>
        _isEnglish ? 'Link Optimization' : '연결 최적화',
      CorePassiveNodeId.efficiencyGemSpectrum =>
        _isEnglish ? 'Gem Spectrum' : '젬 스펙트럼',
      CorePassiveNodeId.efficiencySupplyRecovery =>
        _isEnglish ? 'Supply Recovery' : '보급 회수',
      CorePassiveNodeId.efficiencyCombinedFront =>
        _isEnglish ? 'Combined Front' : '통합 전선',
    };
  }

  String corePassiveNodeEffect(CorePassiveNodeId id, int rank) {
    final definition = corePassiveNodeById(id);
    final safeRank = rank.clamp(1, definition.maxRank);
    final value = definition.displayValues[safeRank - 1];
    return switch (id) {
      CorePassiveNodeId.attackHaste =>
        _isEnglish
            ? 'Core skill cooldown recovery speed increased by $value.'
            : '코어 스킬 재사용 대기시간 회복 속도 $value 증가',
      CorePassiveNodeId.attackOutput =>
        _isEnglish
            ? 'Core skill power amplified by $value.'
            : '코어 스킬 위력 $value 증폭',
      CorePassiveNodeId.attackPrecompute =>
        _isEnglish
            ? 'After a Core skill activates, all turret attack speed is amplified by $value for 2 seconds.'
            : '코어 스킬 발동 후 2초간 모든 포탑 공격 속도 $value 증폭',
      CorePassiveNodeId.attackFocus =>
        _isEnglish
            ? 'After a Core skill activates, all turret damage is amplified by $value for 2 seconds.'
            : '코어 스킬 발동 후 2초간 모든 포탑 화력 $value 증폭',
      CorePassiveNodeId.attackGuardianBeam =>
        _isEnglish
            ? 'Core skill cooldown recovery speed increased by $value.'
            : '코어 스킬 재사용 대기시간 회복 속도 $value 증가',
      CorePassiveNodeId.attackRiftMark =>
        _isEnglish
            ? 'Every third Core skill activation is amplified by $value.'
            : '코어 스킬을 3회 발동할 때마다 해당 스킬 위력 $value 증폭',
      CorePassiveNodeId.attackOverclock =>
        _isEnglish
            ? 'After all other Core skill power amplifications, final power is amplified by 25%.'
            : '다른 모든 코어 스킬 위력 증폭 계산 후 최종 위력 25% 증폭',
      CorePassiveNodeId.controlThreatSense =>
        _isEnglish
            ? 'All damage taken by the Nexus is attenuated by $value.'
            : '넥서스가 받는 모든 피해 $value 감폭',
      CorePassiveNodeId.controlSelfRepair =>
        _isEnglish
            ? 'Maximum Nexus HP increased by $value.'
            : '넥서스 최대 체력 $value 증가',
      CorePassiveNodeId.controlRetarget =>
        _isEnglish
            ? 'At the end of each round, restore $value of maximum Nexus HP.'
            : '라운드 종료 시 넥서스 최대 체력의 $value 회복',
      CorePassiveNodeId.controlRearLock =>
        _isEnglish
            ? "Attenuate an enemy's Nexus damage by up to $value based on its lost total durability."
            : '도달한 적이 잃은 총 내구도 비율에 따라 해당 적의 넥서스 피해 최대 $value 감폭',
      CorePassiveNodeId.controlEmergencyCharge =>
        _isEnglish
            ? 'After taking Nexus damage, instantly recover $value of the current Core skill cooldown, once per round.'
            : '넥서스 피해 시 현재 코어 스킬 재사용 대기시간 $value 즉시 회복, 라운드당 1회',
      CorePassiveNodeId.controlBufferShell =>
        _isEnglish
            ? 'At round end, restore $value of the Nexus HP actually lost during that round.'
            : '라운드 종료 시 해당 라운드에서 실제로 잃은 넥서스 체력의 $value 회복',
      CorePassiveNodeId.controlFinalLine =>
        _isEnglish
            ? 'Each round, negate damage from the first non-boss enemy to reach the Nexus. Bosses do not consume this effect.'
            : '매 라운드 처음 넥서스에 도달한 비보스 적 1기의 피해 무효화, 보스는 효과를 소모하지 않음',
      CorePassiveNodeId.efficiencySaving =>
        _isEnglish
            ? 'Turret build cost attenuated by $value.'
            : '포탑 건설 비용 $value 감폭',
      CorePassiveNodeId.efficiencyDiversity =>
        _isEnglish
            ? 'Turret level-up costs are attenuated by $value per distinct placed turret type after the first, up to 4 stacks.'
            : '첫 종류 이후 배치된 서로 다른 포탑 종류당 모든 포탑 레벨업 비용 $value 감폭, 최대 4중첩',
      CorePassiveNodeId.efficiencyFirstDeploy =>
        _isEnglish
            ? 'Gem Shard costs for selecting turret traits are attenuated by $value.'
            : '포탑 특성 선택에 필요한 젬 파편 $value 감폭',
      CorePassiveNodeId.efficiencyFirstLink =>
        _isEnglish
            ? 'All turret link expansion costs are attenuated by $value.'
            : '모든 포탑의 모든 링크 확장 비용 $value 감폭',
      CorePassiveNodeId.efficiencyGemSpectrum =>
        _isEnglish
            ? 'With at least 3 distinct equipped gem types, numeric gem effects are amplified by gem type count × $value, counting up to 6 types.'
            : '장착 중인 서로 다른 젬이 3종 이상이면 젬 종류 수 × $value만큼 수치형 젬 효과 증폭, 최대 6종 적용',
      CorePassiveNodeId.efficiencySupplyRecovery =>
        _isEnglish
            ? 'Round clear Gold is amplified by $value.'
            : '라운드 클리어 골드 $value 증폭',
      CorePassiveNodeId.efficiencyCombinedFront =>
        _isEnglish
            ? 'While 4+ distinct turret types are placed, final build, level-up, and link expansion costs are attenuated by $value.'
            : '서로 다른 포탑 4종 이상 배치 중 포탑 건설·레벨업·링크 확장 최종 비용 $value 감폭',
    };
  }

  String get permanentUpgradeTab => _isEnglish ? 'Upgrade' : '강화';
  String get researchTab => _isEnglish ? 'Research' : '연구';
  String get turretModuleTab => _isEnglish ? 'Turret' : '포탑';
  String get turretSection => _isEnglish ? 'Turret' : '포탑';
  String get moduleTicketSection => _isEnglish ? 'Module ticket' : '모듈권';
  String get gemSection => _isEnglish ? 'Gem' : '젬';
  String get runes => _isEnglish ? 'Runes' : '룬';
  String get diamonds => _isEnglish ? 'Diamonds' : '다이아';
  String get ownedRunes => _isEnglish ? 'Owned Runes' : '보유 룬';
  String get startGold => _isEnglish ? 'Starting Gold' : '시작 골드';
  String get nexusHp => _isEnglish ? 'Nexus HP' : '넥서스 체력';
  String get maintenanceSupply => _isEnglish ? 'Maintenance Supply' : '정비 보급';
  String get towerDamageRunUpgrade => _isEnglish ? 'Tower Damage' : '포탑 화력';
  String get killGoldRunUpgrade => _isEnglish ? 'Kill Bonus' : '처치 보너스';
  String get waveGoldRunUpgrade => _isEnglish ? 'Supply' : '정비 보급';
  String get killRewardBonus => _isEnglish ? 'Kill Reward' : '처치 보상';
  String get emergencySale => _isEnglish ? 'Emergency Sale' : '긴급 매각';
  String get basicFireTraining =>
      _isEnglish ? 'Basic Fire Training' : '기초 화력 훈련';
  String get physicalDamageTraining =>
      _isEnglish ? 'Physical Damage Training' : '물리 화력 훈련';
  String get elementalDamageTraining =>
      _isEnglish ? 'Elemental Damage Training' : '원소 화력 훈련';
  String get criticalChanceTraining => _isEnglish ? 'Critical Focus' : '치명 집중';
  String get criticalDamageTraining => _isEnglish ? 'Critical Impact' : '치명 충격';
  String get growthHubTitle => _isEnglish ? 'Growth Hub' : '성장 허브';
  String get commonGrowth => _isEnglish ? 'Common Growth' : '공통 성장';
  String get stageUnlockPreview => _isEnglish ? 'Stage Unlocks' : '스테이지 해금';
  String get towerResearch => _isEnglish ? 'Tower Research' : '계열 연구';
  String get designLocked => _isEnglish ? 'Design locked' : '설계 잠금';
  String get upgradeBoard => _isEnglish ? 'Upgrade' : '업그레이드';
  String get researchBoard => _isEnglish ? 'Research' : '연구';
  String get systemResearch => _isEnglish ? 'System Research' : '시스템 연구';
  String get researchSlot => _isEnglish ? 'Research Slot' : '연구 슬롯';
  String get researchSlotTwo => _isEnglish ? 'Research Slot II' : '연구 슬롯 II';
  String get researchSlotTwoPurchaseAccess =>
      _isEnglish ? 'Research Slot II purchase access' : '연구 슬롯 II 구매 권한';
  String get researchSlotTwoPurchaseRequirement =>
      _isEnglish ? 'Available after clearing Stage 10' : '스테이지 10 클리어 후 구매 가능';
  String get researchSlotTwoBenefit => _isEnglish
      ? 'Run two research projects at the same time.'
      : '두 연구를 동시에 진행할 수 있습니다.';
  String get researchSlotTwoUnlockTitle =>
      _isEnglish ? 'Unlock Research Slot II' : '연구 슬롯 II 해금';
  String get researchSlotTwoUnlockAction =>
      _isEnglish ? 'Unlock permanently' : '영구 해금';
  String get ownedDiamonds => _isEnglish ? 'Owned diamonds' : '보유 다이아';
  String get spendDiamondsLabel => _isEnglish ? 'Cost' : '소모 다이아';
  String get remainingDiamonds =>
      _isEnglish ? 'Balance after purchase' : '구매 후 잔액';
  String get availableResearch =>
      _isEnglish ? 'Available Research' : '시작 가능 연구';
  String get lockedResearchSection =>
      _isEnglish ? 'Locked Research' : '아직 해금되지 않음';
  String get completedResearch => _isEnglish ? 'Completed Research' : '완료된 연구';
  String get emptyResearchSlot =>
      _isEnglish ? 'Empty research slot' : '빈 연구 슬롯';
  String get startResearch => _isEnglish ? 'Start' : '연구 시작';
  String get completeResearchInstantly => _isEnglish ? 'Complete now' : '즉시 완료';
  String get researchInProgress => _isEnglish ? 'Researching' : '연구 중';
  String get researchComplete => _isEnglish ? 'Completed' : '완료';
  String get researchSlotBusy => _isEnglish ? 'Slot in use' : '슬롯 사용 중';
  String get researchAvailable => _isEnglish ? 'Ready' : '시작 가능';
  String get cancelResearchTitle =>
      _isEnglish ? 'Cancel research?' : '연구를 취소할까요?';
  String get cancelResearchConfirm => _isEnglish ? 'Cancel research' : '연구 취소';
  String get completeResearchInstantlyTitle =>
      _isEnglish ? 'Complete research now?' : '연구를 즉시 완료할까요?';
  String get researchLevelLabel => _isEnglish ? 'Level' : '레벨';
  String get researchRequirementLabel => _isEnglish ? 'Requirement' : '조건';
  String get researchCostLabel => _isEnglish ? 'Cost' : '비용';
  String get researchTimeLabel => _isEnglish ? 'Time' : '시간';
  String get researchStatusLabel => _isEnglish ? 'Status' : '상태';
  String get selectedUpgrade => _isEnglish ? 'Selected Upgrade' : '선택한 성장';
  String get maxLevelReached => _isEnglish ? 'Max level' : '최대 레벨';
  String get notEnoughRunes => _isEnglish ? 'Need more runes' : '룬 부족';
  String get notEnoughDiamonds => _isEnglish ? 'Need more diamonds' : '다이아 부족';
  String get upgradeAvailable => _isEnglish ? 'Ready' : '구매 가능';
  String get plannedUpgrade => _isEnglish ? 'Planned' : '준비 중';
  String get researchPending => _isEnglish ? 'Future update' : '이후 개발';
  String get lockedUpgrade => _isEnglish ? 'Locked Upgrade' : '미해금 업그레이드';
  String get lockedResearch => _isEnglish ? 'Locked Research' : '미해금 연구';
  String get unavailableUpgrade =>
      _isEnglish ? 'Not available yet' : '아직 사용할 수 없음';

  String researchSlotTwoUnlockMessage(int cost) {
    return _isEnglish
        ? 'Permanently unlock a second research slot for $cost diamonds. You can run two research projects at the same time.'
        : '다이아 $cost개로 두 번째 연구 슬롯을 영구 개방합니다. 개방 후 두 연구를 동시에 진행할 수 있습니다.';
  }

  String get combatUpgradeGroup => _isEnglish ? 'Combat' : '전투';
  String get economyUpgradeGroup => _isEnglish ? 'Economy' : '경제';
  String get researchLockedReason => _isEnglish
      ? 'Opens after the tower research direction is fixed.'
      : '포탑 연구 방향이 확정된 뒤 개방됩니다.';
  String get linkMaintenance =>
      _isEnglish ? 'Basic Link Engineering' : '기초 연결 공학';
  String get linkExpansionOne => _isEnglish ? 'Link Expansion I' : '링크 확장 I';
  String get linkExpansionTwo => _isEnglish ? 'Link Expansion II' : '링크 확장 II';
  String get gemAttunement => _isEnglish ? 'Gem Attunement' : '젬 감응';
  String get tacticalCommand => _isEnglish ? 'Tactical Command' : '전술 명령';
  String get researchEfficiency => _isEnglish ? 'Research Efficiency' : '연구 효율';
  String get researchCostEfficiency =>
      _isEnglish ? 'Research Cost Efficiency' : '연구 비용 효율';
  String get bossBounty => _isEnglish ? 'Boss Reward' : '토벌 보상';
  String get crystalRecovery => _isEnglish ? 'Crystal Recovery' : '결정 회수';
  String get runeResonance => _isEnglish ? 'Rune Resonance' : '룬 공명';
  String get runUpgradeCostOptimization =>
      _isEnglish ? 'Combat Investment Optimization' : '전투 투자 최적화';
  String get towerDamageLimitExpansion =>
      _isEnglish ? 'Tower Damage Expansion' : '포탑 화력 확장';
  String get killGoldLimitExpansion =>
      _isEnglish ? 'Kill Bonus Expansion' : '처치 보너스 확장';
  String get waveGoldLimitExpansion =>
      _isEnglish ? 'Supply Expansion' : '정비 보급 확장';
  String get levelUp => _isEnglish ? 'Level Up' : '레벨업';
  String get cleared => _isEnglish ? 'Cleared' : '클리어';
  String get settled => _isEnglish ? 'Settled' : '정산 완료';
  String get combatInProgress => _isEnglish ? 'Combat in progress' : '전투 진행 중';
  String get rewardPending => _isEnglish ? 'Reward pending' : '보상 선택 대기';
  String get savedCombat => _isEnglish ? 'Saved combat' : '저장된 전투';
  String get inProgress => _isEnglish ? 'In progress' : '진행 중';
  String get newRun => _isEnglish ? 'New run' : '새 진행';
  String get restartRun => _isEnglish ? 'Start new run' : '새 런 시작';
  String get continueRun => _isEnglish ? 'Continue' : '이어서 진행';
  String get startStage => _isEnglish ? 'Start stage' : '스테이지 시작';
  String get startStageAction => _isEnglish ? 'Start' : '시작하기';
  String get stageUnavailableAction => _isEnglish ? 'Unavailable' : '시작 불가';
  String get startAfterSettling =>
      _isEnglish ? 'Start after settling' : '종료 후 시작';
  String get unlocked => _isEnglish ? 'Unlocked' : '해금됨';
  String get locked => _isEnglish ? 'Locked' : '잠김';
  String get recordNone => _isEnglish ? 'No record' : '기록 없음';
  String get recordCleared => _isEnglish ? 'Cleared' : '클리어';
  String get stageBestRecordLabel => _isEnglish ? 'Best record' : '최고 기록';
  String get stageTotalRoundsLabel => _isEnglish ? 'Rounds' : '총 라운드';
  String get stageRuneRewardLabel => _isEnglish ? 'Rune reward' : '룬 보상';
  String get clearRewardLabel => _isEnglish ? 'Clear reward' : '클리어 보상';
  String get firstClearRewardLabel =>
      _isEnglish ? 'First clear reward' : '최초 클리어 보상';
  String get unlockedRewardLabel => _isEnglish ? 'Unlocked' : '해금됨';
  String get claimedRewardLabel => _isEnglish ? 'Claimed' : '수령 완료';
  String get stageSniperRewardLocked => clearReward(sniperTurret);
  String get stageSniperRewardUnlocked => unlockedReward(sniperTurret);
  String get sniperTurret => _isEnglish ? 'Sniper turret' : '저격 포탑';
  String get lightningTurret => _isEnglish ? 'Lightning turret' : '라이트닝 포탑';
  String get aimSpeedGem => _isEnglish ? 'Scope gem' : '조준경 젬';
  String get armorPiercingGem => _isEnglish ? 'Armor Pierce gem' : '장갑 관통 젬';
  String get riftMarkSkill => _isEnglish ? 'Rift Mark' : '균열 낙인';
  String get precisionReward => _isEnglish ? 'Sniper + Scope' : '저격+조준경';
  String get economicUpgrade => _isEnglish ? 'Economy upgrade' : '경제 강화';
  String get combatUpgrade => _isEnglish ? 'Combat upgrade' : '전투 강화';
  String get upgradeUnlock => _isEnglish ? 'Upgrade unlock' : '강화 해금';
  String get combatUpgradeUnlock =>
      _isEnglish ? 'Combat upgrade unlock' : '전투 강화 해금';
  String get researchUnlock => _isEnglish ? 'Research unlock' : '연구 해금';
  String get cancel => _isEnglish ? 'Cancel' : '취소';
  String get settleAndStart => _isEnglish ? 'Settle and start' : '정산 후 시작';
  String get endActiveStageTitle =>
      _isEnglish ? 'End active stage' : '진행 중인 스테이지 종료';

  String activeRunTitle(int stageNumber) {
    return _isEnglish
        ? 'Active run · Stage $stageNumber'
        : '진행 중 · 스테이지 $stageNumber';
  }

  String clearReward(String reward) {
    return _isEnglish ? 'Clear reward: $reward' : '클리어 보상: $reward';
  }

  String unlockedReward(String reward) {
    return _isEnglish ? 'Unlocked: $reward' : '해금됨: $reward';
  }

  String turretModuleTicketReward(int amount) {
    return _isEnglish ? 'Module tickets +$amount' : '모듈권 +$amount';
  }

  String cancelResearchMessage(String title) {
    return _isEnglish
        ? '$title cost is refunded, and saved progress remains.'
        : '$title 비용은 환불되고, 진행한 시간은 유지됩니다.';
  }

  String stageName(int stageNumber) {
    return _isEnglish ? 'Stage $stageNumber' : '스테이지 $stageNumber';
  }

  String stageChapterName(int chapterNumber) {
    return _isEnglish ? 'Chapter $chapterNumber' : '챕터 $chapterNumber';
  }

  String stageChapterThemeName(int chapterNumber) {
    if (chapterNumber == 1) {
      return _isEnglish ? 'Grassland Entry' : '초원 초입';
    }
    if (chapterNumber == 2) {
      return _isEnglish ? 'Rift Veil' : '균열 장막';
    }
    if (chapterNumber == 3) {
      return _isEnglish ? 'Resonant Forge' : '공명 용광로';
    }
    return _isEnglish ? 'Planned Area' : '준비 중인 지역';
  }

  String stageChapterThemeTag(int chapterNumber) {
    if (chapterNumber == 1) {
      return _isEnglish ? 'First Nexus Route' : '첫 넥서스 길목';
    }
    if (chapterNumber == 2) {
      return _isEnglish ? 'Rift Portal Zone' : '균열 포탈 지대';
    }
    if (chapterNumber == 3) {
      return _isEnglish ? 'Overheated Forge Zone' : '과열 제련 구역';
    }
    return plannedUpgrade;
  }

  String stageChapterRange(int startStage, int endStage) {
    return _isEnglish
        ? 'Stages $startStage-$endStage'
        : '스테이지 $startStage-$endStage';
  }

  String stageRuneBonus(double bonusRate) {
    final bonusPercent = (bonusRate * 100).round();
    return _isEnglish ? 'Runes +$bonusPercent%' : '룬 +$bonusPercent%';
  }

  String stageBestRound(int round) {
    return _isEnglish ? 'Best ${round}R' : '최고 ${round}R';
  }

  String stageTotalRounds(int maxRound) {
    return _isEnglish ? '$maxRound rounds' : '$maxRound라운드';
  }

  String stageFullClearRuneReward(int runes) {
    return _isEnglish ? '$runes runes on clear' : '완주 시 $runes룬';
  }

  String stageLockedRequirement(int stageNumber) {
    final requiredStage = stageNumber - 1;
    return _isEnglish
        ? 'Clear Stage $requiredStage to start this stage.'
        : '스테이지 $requiredStage 클리어 후 시작할 수 있습니다.';
  }

  String stageProgressDetail({
    required int round,
    required int maxRound,
    required int turretCount,
    required int gold,
  }) {
    return _isEnglish
        ? 'Round $round/$maxRound · Turrets $turretCount · Gold $gold'
        : '라운드 $round/$maxRound · 포탑 $turretCount · 골드 $gold';
  }

  String stageFreshDetail({
    required int round,
    required int maxRound,
    required int nexusHp,
    required int maxNexusHp,
  }) {
    return _isEnglish
        ? 'Round $round/$maxRound · Nexus $nexusHp/$maxNexusHp'
        : '라운드 $round/$maxRound · Nexus $nexusHp/$maxNexusHp';
  }

  String stageUnlockRequirement(int previousStageNumber) {
    return _isEnglish
        ? 'Clear Stage $previousStageNumber'
        : '스테이지 $previousStageNumber 클리어 필요';
  }

  String upgradeLevel(String title, int level, {int? maxLevel}) {
    final levelText = maxLevel == null ? 'Lv.$level' : 'Lv.$level/$maxLevel';
    return _isEnglish ? '$title $levelText' : '$title $levelText';
  }

  String runeCost(int cost) {
    return _isEnglish ? 'Runes $cost' : '룬 $cost';
  }

  String researchLevel(int level, int maxLevel) {
    return _isEnglish ? 'Lv.$level/$maxLevel' : 'Lv.$level/$maxLevel';
  }

  String researchDuration(int durationMillis) {
    final minutes = durationMillis ~/ 60000;
    if (minutes >= 60 && minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return _isEnglish ? '${hours}h' : '$hours시간';
    }
    return _isEnglish ? '${minutes}m' : '$minutes분';
  }

  String researchGemShardEffect(int amount) {
    return _isEnglish ? 'Gem Shards +$amount' : '젬 파편 +$amount';
  }

  String researchEfficiencyEffect(int percent) {
    return _isEnglish ? 'Research efficiency +$percent%' : '연구 효율 +$percent%';
  }

  String researchCostEfficiencyEffect(int percent) {
    return _isEnglish ? 'Cost efficiency +$percent%' : '비용 효율 +$percent%';
  }

  String get researchLinkSlotEffect {
    return _isEnglish ? 'Max links increase' : '최대 링크 증가';
  }

  String researchLinkMaintenanceEffect(int percent) {
    return _isEnglish ? 'First link cost -$percent%' : '첫 링크 비용 -$percent%';
  }

  String get researchTargetPriorityEffect {
    return _isEnglish ? 'Tower targeting commands' : '포탑 공격 명령 해금';
  }

  String researchBossBountyEffect(String percent) {
    return _isEnglish ? 'Boss kill gold +$percent%' : '보스 처치 골드 +$percent%';
  }

  String researchCrystalRecoveryEffect(int amount) {
    return _isEnglish
        ? 'Boss kill gem shards +$amount'
        : '보스 처치 시 젬 파편 +$amount';
  }

  String researchRuneResonanceEffect(int percent) {
    return _isEnglish ? 'Rune reward boost +$percent%' : '룬 보상 증폭 +$percent%';
  }

  String researchRunUpgradeCostOptimizationEffect(int percent) {
    return _isEnglish ? 'Run upgrade cost -$percent%' : '런 업그레이드 비용 -$percent%';
  }

  String researchRunUpgradeLimitExpansionEffect(String subject, int amount) {
    return _isEnglish
        ? '$subject max level +$amount'
        : '$subject 최대 레벨 +$amount';
  }

  String researchRemaining(int remainingMillis) {
    final seconds = (remainingMillis / 1000).ceil();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final restSeconds = seconds % 60;
    return _isEnglish
        ? '${hours}h ${minutes}m ${restSeconds}s'
        : '$hours시간 $minutes분 $restSeconds초';
  }

  String researchInstantCompleteCost(int cost) {
    return _isEnglish ? '$cost diamonds' : '다이아 $cost';
  }

  String completeResearchInstantlyMessage(String title, int cost) {
    return _isEnglish
        ? 'Spend $cost diamonds to complete $title now.'
        : '$title 연구를 다이아 $cost로 즉시 완료합니다.';
  }

  String stageReachRequirement(int stageNumber) {
    return _isEnglish ? 'Reach Stage $stageNumber' : '스테이지 $stageNumber 도달';
  }

  String stageClearRequirement(int stageNumber) {
    if (stageNumber <= 0) {
      return _isEnglish ? 'Unlocked by default' : '기본 해금';
    }
    return _isEnglish ? 'Clear Stage $stageNumber' : '스테이지 $stageNumber 클리어';
  }

  String unlocksAfter(String requirement) {
    return _isEnglish
        ? 'Available after: $requirement'
        : '$requirement 후 사용 가능';
  }

  String futureUpgradeEffect(String title) {
    if (title == linkMaintenance) {
      return _isEnglish
          ? 'Reduces the first link expansion cost.'
          : '첫 링크 확장 비용을 낮춥니다.';
    }
    if (title == gemAttunement) {
      return _isEnglish
          ? 'Improves the first gem reward timing.'
          : '첫 젬 보상 흐름을 개선합니다.';
    }
    if (title == runeResonance) {
      return _isEnglish
          ? 'Increases runes gained after a run.'
          : '런 종료 후 획득 룬을 늘립니다.';
    }
    return '';
  }

  String researchDescription(String title) {
    if (title == linkExpansionOne) {
      return _isEnglish
          ? 'Unlocks the first extra link socket for turrets.'
          : '포탑의 추가 링크 홈을 열 수 있게 합니다.';
    }
    if (title == linkExpansionTwo) {
      return _isEnglish
          ? 'Raises the maximum links per turret to 5.'
          : '포탑 하나가 연결할 수 있는 최대 링크를 5개로 늘립니다.';
    }
    if (title == gemAttunement) {
      return _isEnglish
          ? 'Adds +2 starting gem shards per level.'
          : '스테이지 시작 젬 파편을 +2 늘립니다.';
    }
    if (title == researchEfficiency) {
      return _isEnglish
          ? 'Increases research efficiency by 5% per level. 100% efficiency makes future research twice as fast.'
          : '레벨마다 연구 효율이 5% 증가합니다. 효율 100%는 이후 연구를 2배 빠르게 만듭니다.';
    }
    if (title == researchCostEfficiency) {
      return _isEnglish
          ? 'Increases research cost efficiency by 5% per level. 100% efficiency halves future research rune costs.'
          : '레벨마다 연구 비용 효율이 5% 증가합니다. 효율 100%는 이후 연구 룬 비용을 절반으로 줄입니다.';
    }
    if (title == tacticalCommand) {
      return _isEnglish
          ? 'Allows each turret to set its preferred attack target.'
          : '포탑별로 우선 공격 대상을 지정할 수 있도록 합니다.';
    }
    if (title == bossBounty) {
      return _isEnglish
          ? 'Increases gold gained from defeating boss enemies by 2.5% per level.'
          : '레벨마다 보스 처치 골드를 2.5% 늘립니다.';
    }
    if (title == crystalRecovery) {
      return _isEnglish
          ? 'Adds +1 gem shard per level when defeating boss enemies.'
          : '레벨마다 보스 처치 시 획득하는 젬 파편이 1 증가합니다.';
    }
    if (title == runeResonance) {
      return _isEnglish
          ? 'Increases runes gained after a run by 2% per level.'
          : '레벨마다 런 종료 후 획득하는 룬이 2% 증가합니다.';
    }
    if (title == runUpgradeCostOptimization) {
      return _isEnglish
          ? 'Reduces the cost of all run upgrades by 2% per level.'
          : '레벨마다 모든 런 업그레이드 비용이 2% 감소합니다.';
    }
    if (title == towerDamageLimitExpansion) {
      return _isEnglish
          ? 'Raises the maximum level of Tower Damage by 1 per level.'
          : '레벨마다 포탑 화력의 최대 레벨이 1 증가합니다.';
    }
    if (title == killGoldLimitExpansion) {
      return _isEnglish
          ? 'Raises the maximum level of Kill Bonus by 1 per level.'
          : '레벨마다 처치 보너스의 최대 레벨이 1 증가합니다.';
    }
    if (title == waveGoldLimitExpansion) {
      return _isEnglish
          ? 'Raises the maximum level of Supply by 1 per level.'
          : '레벨마다 정비 보급의 최대 레벨이 1 증가합니다.';
    }
    if (title == towerResearch) {
      return _isEnglish
          ? 'Reserved for turret family research after its direction is fixed.'
          : '포탑 계열 연구 방향이 확정된 뒤 사용할 영역입니다.';
    }
    return '';
  }

  String permanentUpgradeDescription(String title) {
    if (title == startGold) {
      return _isEnglish
          ? 'Increases the gold available at the start of every run.'
          : '새 런을 시작할 때 보유하는 골드가 영구적으로 증가합니다.';
    }
    if (title == nexusHp) {
      return _isEnglish
          ? 'Increases max Nexus HP for every run.'
          : '모든 런의 넥서스 최대 체력이 영구적으로 증가합니다.';
    }
    if (title == maintenanceSupply) {
      return _isEnglish
          ? 'Adds bonus gold whenever a wave is cleared.'
          : '웨이브를 클리어할 때마다 추가 골드를 받습니다.';
    }
    if (title == killRewardBonus) {
      return _isEnglish
          ? 'Increases gold gained from defeating enemies.'
          : '적을 처치할 때 획득하는 골드가 증가합니다.';
    }
    if (title == emergencySale) {
      return _isEnglish
          ? 'Increases the gold refunded when selling turrets.'
          : '포탑을 환불할 때 돌려받는 골드 비율이 증가합니다.';
    }
    if (title == basicFireTraining) {
      return _isEnglish
          ? 'Increases the damage of all turrets in every run.'
          : '모든 런에서 모든 포탑의 피해량이 증가합니다.';
    }
    if (title == physicalDamageTraining) {
      return _isEnglish
          ? 'Increases the damage of physical turrets.'
          : '물리 포탑의 피해량이 증가합니다.';
    }
    if (title == elementalDamageTraining) {
      return _isEnglish
          ? 'Increases the damage of elemental turrets.'
          : '원소 포탑의 피해량이 증가합니다.';
    }
    if (title == criticalChanceTraining) {
      return _isEnglish
          ? 'Increases critical chance for all turrets.'
          : '모든 포탑의 치명타 확률이 증가합니다.';
    }
    if (title == criticalDamageTraining) {
      return _isEnglish
          ? 'Adds to critical bonus damage for all turrets.'
          : '모든 포탑의 치명타 추가 피해율이 증가합니다.';
    }
    return '';
  }

  String endActiveStageBody({
    required int currentStageNumber,
    required int nextStageNumber,
    required int runeReward,
  }) {
    if (_isEnglish) {
      return 'Settle $runeReward runes, then start Stage $nextStageNumber.';
    }
    return '현재 보상 $runeReward룬 정산 후 스테이지 $nextStageNumber 시작';
  }
}

class _RuneNexusLocalizationsDelegate
    extends LocalizationsDelegate<RuneNexusLocalizations> {
  const _RuneNexusLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return RuneNexusLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<RuneNexusLocalizations> load(Locale locale) {
    final supportedLocale = RuneNexusLocalizations.supportedLocales.firstWhere(
      (supported) => supported.languageCode == locale.languageCode,
      orElse: () => const Locale('ko'),
    );
    return SynchronousFuture(RuneNexusLocalizations(supportedLocale));
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<RuneNexusLocalizations> old,
  ) {
    return false;
  }
}

extension RuneNexusLocalizationsX on BuildContext {
  RuneNexusLocalizations get l10n => RuneNexusLocalizations.of(this);
}
