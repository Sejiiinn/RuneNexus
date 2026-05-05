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
  String get permanentUpgradeTab =>
      _isEnglish ? 'Permanent Upgrades' : '영구 업그레이드';
  String get runes => _isEnglish ? 'Runes' : '룬';
  String get ownedRunes => _isEnglish ? 'Owned Runes' : '보유 룬';
  String get startGold => _isEnglish ? 'Starting Gold' : '시작 골드';
  String get nexusHp => _isEnglish ? 'Nexus HP' : '넥서스 체력';
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
  String get cancel => _isEnglish ? 'Cancel' : '취소';
  String get settleAndStart => _isEnglish ? 'Settle and start' : '정산 후 시작';
  String get endActiveStageTitle =>
      _isEnglish ? 'End active stage' : '진행 중인 스테이지 종료';

  String stageName(int stageNumber) {
    return _isEnglish ? 'Stage $stageNumber' : '스테이지 $stageNumber';
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

  String upgradeLevel(String title, int level) {
    return _isEnglish ? '$title Lv.$level' : '$title Lv.$level';
  }

  String runeCost(int cost) {
    return _isEnglish ? 'Runes $cost' : '룬 $cost';
  }

  String endActiveStageBody({
    required int currentStageNumber,
    required int nextStageNumber,
  }) {
    if (_isEnglish) {
      return 'End Stage $currentStageNumber, settle runes based on cleared '
          'rounds, then start Stage $nextStageNumber. Saved placement and '
          'enemy progress will be deleted.';
    }
    return '스테이지 $currentStageNumber 진행 상황을 종료하고 현재 클리어 라운드 '
        '기준으로 룬을 정산한 뒤 스테이지 $nextStageNumber를 시작합니다. '
        '저장된 배치와 적 진행도는 삭제됩니다.';
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
