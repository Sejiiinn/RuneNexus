import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
  String get permanentUpgradeTab => _isEnglish ? 'Upgrade' : '강화';
  String get researchTab => _isEnglish ? 'Research' : '연구';
  String get runes => _isEnglish ? 'Runes' : '룬';
  String get ownedRunes => _isEnglish ? 'Owned Runes' : '보유 룬';
  String get startGold => _isEnglish ? 'Starting Gold' : '시작 골드';
  String get nexusHp => _isEnglish ? 'Nexus HP' : '넥서스 체력';
  String get maintenanceSupply => _isEnglish ? 'Maintenance Supply' : '정비 보급';
  String get killRewardBonus => _isEnglish ? 'Kill Reward' : '처치 보상';
  String get emergencySale => _isEnglish ? 'Emergency Sale' : '긴급 매각';
  String get basicFireTraining =>
      _isEnglish ? 'Basic Fire Training' : '기초 화력 훈련';
  String get criticalChanceTraining => _isEnglish ? 'Critical Focus' : '치명 집중';
  String get criticalDamageTraining => _isEnglish ? 'Critical Impact' : '치명 충격';
  String get growthHubTitle => _isEnglish ? 'Growth Hub' : '성장 허브';
  String get commonGrowth => _isEnglish ? 'Common Growth' : '공통 성장';
  String get stageUnlockPreview => _isEnglish ? 'Stage Unlocks' : '스테이지 해금';
  String get towerResearch => _isEnglish ? 'Tower Research' : '계열 연구';
  String get designLocked => _isEnglish ? 'Design locked' : '설계 잠금';
  String get upgradeBoard => _isEnglish ? 'Upgrade Board' : '업그레이드 보드';
  String get researchBoard => _isEnglish ? 'Research Board' : '연구 보드';
  String get systemResearch => _isEnglish ? 'System Research' : '시스템 연구';
  String get researchSlot => _isEnglish ? 'Research Slot' : '연구 슬롯';
  String get availableResearch =>
      _isEnglish ? 'Available Research' : '시작 가능 연구';
  String get completedResearch => _isEnglish ? 'Completed Research' : '완료된 연구';
  String get emptyResearchSlot =>
      _isEnglish ? 'Empty research slot' : '빈 연구 슬롯';
  String get startResearch => _isEnglish ? 'Start' : '연구 시작';
  String get researchInProgress => _isEnglish ? 'Researching' : '연구 중';
  String get researchComplete => _isEnglish ? 'Completed' : '완료';
  String get researchSlotBusy => _isEnglish ? 'Slot in use' : '슬롯 사용 중';
  String get researchAvailable => _isEnglish ? 'Ready' : '시작 가능';
  String get cancelResearchTitle =>
      _isEnglish ? 'Cancel research?' : '연구를 취소할까요?';
  String get cancelResearchConfirm => _isEnglish ? 'Cancel research' : '연구 취소';
  String get researchLevelLabel => _isEnglish ? 'Level' : '레벨';
  String get researchRequirementLabel => _isEnglish ? 'Requirement' : '조건';
  String get researchCostLabel => _isEnglish ? 'Cost' : '비용';
  String get researchTimeLabel => _isEnglish ? 'Time' : '시간';
  String get researchStatusLabel => _isEnglish ? 'Status' : '상태';
  String get selectedUpgrade => _isEnglish ? 'Selected Upgrade' : '선택한 성장';
  String get maxLevelReached => _isEnglish ? 'Max level' : '최대 레벨';
  String get notEnoughRunes => _isEnglish ? 'Need more runes' : '룬 부족';
  String get upgradeAvailable => _isEnglish ? 'Ready' : '구매 가능';
  String get plannedUpgrade => _isEnglish ? 'Planned' : '준비 중';
  String get researchPending => _isEnglish ? 'Future update' : '이후 개발';
  String get lockedUpgrade => _isEnglish ? 'Locked Upgrade' : '미해금 업그레이드';
  String get lockedResearch => _isEnglish ? 'Locked Research' : '미해금 연구';
  String get unavailableUpgrade =>
      _isEnglish ? 'Not available yet' : '아직 사용할 수 없음';
  String get combatUpgradeGroup => _isEnglish ? 'Combat' : '전투';
  String get economyUpgradeGroup => _isEnglish ? 'Economy' : '경제';
  String get researchLockedReason => _isEnglish
      ? 'Opens after the tower research direction is fixed.'
      : '포탑 연구 방향이 확정된 뒤 개방됩니다.';
  String get linkMaintenance => _isEnglish ? 'Link Maintenance' : '링크 정비';
  String get linkExpansionOne => _isEnglish ? 'Link Expansion I' : '링크 확장 I';
  String get linkExpansionTwo => _isEnglish ? 'Link Expansion II' : '링크 확장 II';
  String get gemAttunement => _isEnglish ? 'Gem Attunement' : '젬 감응';
  String get researchEfficiency => _isEnglish ? 'Research Efficiency' : '연구 효율';
  String get researchCostEfficiency =>
      _isEnglish ? 'Research Cost Efficiency' : '연구 비용 효율';
  String get runeResonance => _isEnglish ? 'Rune Resonance' : '룬 공명';
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
  String get startAfterSettling =>
      _isEnglish ? 'Start after settling' : '종료 후 시작';
  String get unlocked => _isEnglish ? 'Unlocked' : '해금됨';
  String get locked => _isEnglish ? 'Locked' : '잠김';
  String get recordNone => _isEnglish ? 'No record' : '기록 없음';
  String get recordCleared => _isEnglish ? 'Cleared' : '클리어';
  String get stageSniperRewardLocked =>
      _isEnglish ? 'Clear reward: Sniper turret' : '클리어 보상: 저격 포탑';
  String get stageSniperRewardUnlocked =>
      _isEnglish ? 'Unlocked: Sniper turret' : '해금됨: 저격 포탑';
  String get sniperTurret => _isEnglish ? 'Sniper turret' : '저격 포탑';
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

  String cancelResearchMessage(String title) {
    return _isEnglish
        ? '$title cost is refunded, and saved progress remains.'
        : '$title 비용은 환불되고, 진행한 시간은 유지됩니다.';
  }

  String stageName(int stageNumber) {
    return _isEnglish ? 'Stage $stageNumber' : '스테이지 $stageNumber';
  }

  String stageChapterName(int chapterNumber) {
    if (chapterNumber == 1) {
      return _isEnglish ? 'Rift Entry' : '균열 초입';
    }
    return _isEnglish ? 'Chapter $chapterNumber' : '챕터 $chapterNumber';
  }

  String stageRuneBonus(double bonusRate) {
    final bonusPercent = (bonusRate * 100).round();
    return _isEnglish ? 'Runes +$bonusPercent%' : '룬 +$bonusPercent%';
  }

  String stageBestRound(int round) {
    return _isEnglish ? 'Best ${round}R' : '최고 ${round}R';
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

  String researchRemaining(int remainingMillis) {
    final seconds = (remainingMillis / 1000).ceil();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final restSeconds = seconds % 60;
    return _isEnglish
        ? '${hours}h ${minutes}m ${restSeconds}s'
        : '$hours시간 $minutes분 $restSeconds초';
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
    if (title == runeResonance) {
      return _isEnglish
          ? 'Opens research for improving rune rewards after a run.'
          : '런 종료 후 룬 보상을 개선하는 연구를 개방합니다.';
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
  }) {
    if (_isEnglish) {
      return 'End Stage $currentStageNumber, settle runes based on cleared '
          'rounds, then start Stage $nextStageNumber.';
    }
    return '스테이지 $currentStageNumber 진행 상황을 종료하고 현재 클리어 라운드 '
        '기준으로 룬을 정산한 뒤 스테이지 $nextStageNumber를 시작합니다.';
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
