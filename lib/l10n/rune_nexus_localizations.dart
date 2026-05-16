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
  String get basicFireTraining =>
      _isEnglish ? 'Basic Fire Training' : '기초 화력 훈련';
  String get growthHubTitle => _isEnglish ? 'Growth Hub' : '성장 허브';
  String get commonGrowth => _isEnglish ? 'Common Growth' : '공통 성장';
  String get stageUnlockPreview => _isEnglish ? 'Stage Unlocks' : '스테이지 해금';
  String get towerResearch => _isEnglish ? 'Tower Research' : '계열 연구';
  String get designLocked => _isEnglish ? 'Design locked' : '설계 잠금';
  String get upgradeBoard => _isEnglish ? 'Upgrade Board' : '업그레이드 보드';
  String get researchBoard => _isEnglish ? 'Research Board' : '연구 보드';
  String get systemResearch => _isEnglish ? 'System Research' : '시스템 연구';
  String get selectedUpgrade => _isEnglish ? 'Selected Upgrade' : '선택한 성장';
  String get maxLevelReached => _isEnglish ? 'Max level' : '최대 레벨';
  String get notEnoughRunes => _isEnglish ? 'Need more runes' : '룬 부족';
  String get upgradeAvailable => _isEnglish ? 'Ready' : '구매 가능';
  String get plannedUpgrade => _isEnglish ? 'Planned' : '준비 중';
  String get researchPending => _isEnglish ? 'Future update' : '이후 개발';
  String get combatUpgradeGroup => _isEnglish ? 'Combat' : '전투';
  String get economyUpgradeGroup => _isEnglish ? 'Economy' : '경제';
  String get researchLockedReason => _isEnglish
      ? 'Opens after the tower research direction is fixed.'
      : '포탑 연구 방향이 확정된 뒤 개방됩니다.';
  String get linkMaintenance => _isEnglish ? 'Link Maintenance' : '링크 정비';
  String get linkExpansionOne => _isEnglish ? 'Link Expansion I' : '링크 확장 I';
  String get linkExpansionTwo => _isEnglish ? 'Link Expansion II' : '링크 확장 II';
  String get gemAttunement => _isEnglish ? 'Gem Attunement' : '젬 감응';
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
  String get cancel => _isEnglish ? 'Cancel' : '취소';
  String get settleAndStart => _isEnglish ? 'Settle and start' : '정산 후 시작';
  String get endActiveStageTitle =>
      _isEnglish ? 'End active stage' : '진행 중인 스테이지 종료';

  String activeRunTitle(int stageNumber) {
    return _isEnglish
        ? 'Active run · Stage $stageNumber'
        : '진행 중 · 스테이지 $stageNumber';
  }

  String stageName(int stageNumber) {
    return _isEnglish ? 'Stage $stageNumber' : '스테이지 $stageNumber';
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

  String stageReachRequirement(int stageNumber) {
    return _isEnglish ? 'Reach Stage $stageNumber' : '스테이지 $stageNumber 도달';
  }

  String stageClearRequirement(int stageNumber) {
    return _isEnglish ? 'Clear Stage $stageNumber' : '스테이지 $stageNumber 클리어';
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
          ? 'Raises the maximum links per turret to 4.'
          : '포탑 하나가 연결할 수 있는 최대 링크를 4개로 늘립니다.';
    }
    if (title == linkExpansionTwo) {
      return _isEnglish
          ? 'Raises the maximum links per turret to 5.'
          : '포탑 하나가 연결할 수 있는 최대 링크를 5개로 늘립니다.';
    }
    if (title == gemAttunement) {
      return _isEnglish
          ? 'Opens the first gem reward and gem interaction flow.'
          : '첫 젬 보상과 젬 상호작용 흐름을 개방합니다.';
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
    if (title == basicFireTraining) {
      return _isEnglish
          ? 'Increases the damage of all turrets in every run.'
          : '모든 런에서 모든 포탑의 피해량이 증가합니다.';
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
