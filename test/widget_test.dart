import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/app/rune_nexus_app.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/combat/auto_start_mode.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
import 'package:rune_nexus/domain/combat/run_panel_tab.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/game/game_snapshot.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/l10n/rune_nexus_localizations.dart';
import 'package:rune_nexus/ui/menu/main_menu_screen.dart';
import 'package:rune_nexus/ui/menu/result_overlay.dart';

void main() {
  testWidgets('Rune Nexus app renders main menu', (tester) async {
    await _pumpLoadedApp(tester);

    expect(find.text('Rune Nexus'), findsOneWidget);
    expect(find.text('스테이지'), findsOneWidget);
    expect(find.text('스테이지 1'), findsOneWidget);
    expect(find.text('스테이지 5'), findsOneWidget);
    expect(find.text('잠김'), findsNWidgets(4));
    expect(find.text('강화'), findsOneWidget);
    expect(find.text('연구'), findsOneWidget);
  });

  testWidgets('main menu keeps tabs on bottom and hides logo on upgrades', (
    tester,
  ) async {
    await _pumpLoadedApp(tester);

    expect(find.text('Rune Nexus'), findsOneWidget);

    await tester.tap(find.text('강화'));
    await _pumpGameFrames(tester);

    expect(find.text('Rune Nexus'), findsNothing);
    expect(find.text('업그레이드 보드'), findsOneWidget);
    expect(find.text('넥서스 체력'), findsOneWidget);
    expect(find.text('기초 화력 훈련'), findsOneWidget);
    expect(find.text('레벨업'), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.paid_outlined));
    await _pumpGameFrames(tester);

    expect(find.text('시작 골드'), findsOneWidget);
    expect(find.text('정비 보급'), findsOneWidget);
    expect(find.text('처치 보상'), findsOneWidget);
    expect(find.text('긴급 매각'), findsOneWidget);
    expect(find.text('미해금 업그레이드'), findsNWidgets(2));
    expect(find.text('아직 사용할 수 없음'), findsNWidgets(2));
    expect(find.text('새 런을 시작할 때 보유하는 골드가 영구적으로 증가합니다.'), findsOneWidget);
    expect(find.text('웨이브를 클리어할 때마다 추가 골드를 받습니다.'), findsOneWidget);
    expect(find.text('적을 처치할 때 획득하는 골드가 증가합니다.'), findsOneWidget);
    expect(find.text('포탑을 환불할 때 돌려받는 골드 비율이 증가합니다.'), findsOneWidget);
    expect(find.text('스테이지'), findsOneWidget);
    expect(find.text('강화'), findsOneWidget);
    expect(find.text('연구'), findsOneWidget);

    await tester.tap(find.text('연구'));
    await _pumpGameFrames(tester);

    expect(find.text('연구 보드'), findsOneWidget);
    expect(find.text('링크 확장 I'), findsOneWidget);
    expect(find.text('젬 감응'), findsOneWidget);
    expect(find.text('계열 연구'), findsWidgets);

    await tester.tap(find.text('스테이지'));
    await _pumpGameFrames(tester);

    expect(find.text('Rune Nexus'), findsOneWidget);
  });

  testWidgets('stage cards fit on narrow menu width', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLoadedApp(tester);

    expect(find.text('스테이지 1 클리어 필요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permanent upgrade rows fit on narrow menu width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLoadedApp(tester);

    await tester.tap(find.text('강화'));
    await _pumpGameFrames(tester);

    expect(find.text('업그레이드 보드'), findsOneWidget);
    expect(find.text('레벨업'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked kill reward stays locked even with saved levels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: const [
          RuneNexusLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: RuneNexusLocalizations.supportedLocales,
        home: MainMenuScreen(
          game: RuneNexusGame(),
          snapshot: _resultSnapshot(
            phase: GamePhase.preparation,
            currentStageNumber: 1,
            runes: 181,
            killGoldUpgradeLevel: 3,
            killGoldProgressionBonusRate: 0,
          ),
          selectedTab: MainMenuTab.permanentUpgrades,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    await tester.tap(find.byIcon(Icons.paid_outlined));
    await _pumpGameFrames(tester);

    expect(find.text('처치 보상'), findsOneWidget);
    expect(find.text('미해금 업그레이드'), findsWidgets);
    expect(find.text('아직 사용할 수 없음'), findsWidgets);
    expect(find.text('Lv.3/10'), findsNothing);
  });

  testWidgets('locked emergency sale stays locked even with saved levels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: const [
          RuneNexusLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: RuneNexusLocalizations.supportedLocales,
        home: MainMenuScreen(
          game: RuneNexusGame(),
          snapshot: _resultSnapshot(
            phase: GamePhase.preparation,
            currentStageNumber: 1,
            runes: 181,
            emergencySaleUpgradeLevel: 3,
            turretRefundPercent: 75,
          ),
          selectedTab: MainMenuTab.permanentUpgrades,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    await tester.tap(find.byIcon(Icons.paid_outlined));
    await _pumpGameFrames(tester);

    expect(find.text('긴급 매각'), findsOneWidget);
    expect(find.text('미해금 업그레이드'), findsWidgets);
    expect(find.text('아직 사용할 수 없음'), findsWidgets);
    expect(find.text('Lv.3/5'), findsNothing);
  });

  testWidgets('emergency sale shows refund percent after stage two clear', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: const [
          RuneNexusLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: RuneNexusLocalizations.supportedLocales,
        home: MainMenuScreen(
          game: RuneNexusGame(),
          snapshot: _resultSnapshot(
            phase: GamePhase.preparation,
            currentStageNumber: 1,
            runes: 181,
            clearedStageNumbers: const {2},
            emergencySaleUpgradeLevel: 0,
            emergencySaleUpgradeCost: 60,
            canUpgradeEmergencySale: true,
            turretRefundPercent: 75,
          ),
          selectedTab: MainMenuTab.permanentUpgrades,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    await tester.tap(find.byIcon(Icons.paid_outlined));
    await _pumpGameFrames(tester);

    expect(find.text('긴급 매각'), findsOneWidget);
    expect(find.text('현재 75%'), findsOneWidget);
    expect(find.text('다음 76%'), findsOneWidget);
  });

  testWidgets('result overlay exposes next stage and growth actions', (
    tester,
  ) async {
    int? startedStage;

    await tester.pumpWidget(
      MaterialApp(
        home: ResultOverlay(
          game: RuneNexusGame(),
          snapshot: _resultSnapshot(
            phase: GamePhase.success,
            currentStageNumber: 1,
            unlockedStageCount: 2,
            completedRounds: 50,
            runes: 140,
            lastRunRuneReward: 140,
            lastRunPreviousBestRound: 20,
            lastRunWasNewBestRound: true,
            lastRunUnlockedStageNumber: 2,
            lastRunUnlockedSniperTurret: true,
            bestRoundsByStage: const {1: 50},
            clearedStageNumbers: const {1},
          ),
          onOpenStageSelect: () {},
          onOpenPermanentUpgrades: () {},
          onStartStage: (stageNumber) {
            startedStage = stageNumber;
          },
        ),
      ),
    );

    expect(find.text('스테이지 2 신규 해금'), findsOneWidget);
    expect(find.text('신기록'), findsOneWidget);
    expect(find.text('20R → 50R'), findsOneWidget);
    expect(find.text('포탑 해금'), findsOneWidget);
    expect(find.text('저격'), findsOneWidget);
    expect(find.text('신규 해금'), findsOneWidget);
    expect(find.text('스테이지 2 시작'), findsOneWidget);
    expect(find.text('업그레이드'), findsOneWidget);
    expect(find.text('현재 스테이지 재도전'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -160),
    );
    await tester.pump();
    await tester.tap(find.text('스테이지 2 시작'));

    expect(startedStage, 2);
  });

  testWidgets('failed result keeps stage selection and retry actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultOverlay(
          game: RuneNexusGame(),
          snapshot: _resultSnapshot(
            phase: GamePhase.failure,
            currentStageNumber: 1,
            completedRounds: 12,
            runes: 24,
            lastRunRuneReward: 24,
            bestRoundsByStage: const {1: 12},
          ),
          onOpenStageSelect: () {},
          onOpenPermanentUpgrades: () {},
          onStartStage: (_) {},
        ),
      ),
    );

    expect(find.text('기록 최고 12R'), findsOneWidget);
    expect(find.text('스테이지 2 시작'), findsNothing);
    expect(find.text('스테이지'), findsWidgets);
    expect(find.text('현재 스테이지 재도전'), findsOneWidget);
  });

  testWidgets('home button opens stage menu with end confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLoadedApp(tester);

    await _tapStageCard(tester, '스테이지 1');
    await _pumpUntilFound(tester, find.text('시작'));
    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await _pumpGameFrames(tester);

    expect(find.text('스테이지 메뉴'), findsOneWidget);
    expect(find.text('메인화면으로 이동'), findsOneWidget);
    expect(find.text('종료 시 보상'), findsOneWidget);
    expect(find.text('+1 룬'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('스테이지 종료'));
    await _pumpGameFrames(tester);

    expect(find.text('정말 종료할까요?'), findsOneWidget);
    expect(find.textContaining('+1 룬'), findsWidgets);
  });

  testWidgets('main menu return preserves active run as restore flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLoadedApp(tester);

    await _tapStageCard(tester, '스테이지 1');
    await _pumpUntilFound(tester, find.text('시작'));
    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await _pumpGameFrames(tester);
    await tester.tap(find.text('메인화면으로 이동'));
    await _pumpGameFrames(tester);

    expect(find.text('진행 중 · 스테이지 1'), findsOneWidget);
    expect(find.text('저장된 전투'), findsOneWidget);
    expect(find.text('이어서 진행'), findsOneWidget);

    await tester.tap(find.text('이어서 진행'));
    await _pumpGameFrames(tester);

    expect(find.text('저장된 진행 발견'), findsOneWidget);
    expect(find.text('계속 진행하시겠습니까?'), findsOneWidget);
  });

  testWidgets('debug panel button is hidden by default', (tester) async {
    await _pumpLoadedApp(tester);

    await _tapStageCard(tester, '스테이지 1');
    await _pumpGameFrames(tester);

    expect(find.text('테스트 라운드'), findsNothing);
  });
}

Future<void> _pumpLoadedApp(WidgetTester tester) async {
  await tester.pumpWidget(
    RuneNexusApp(game: RuneNexusGame(saveRepository: MemorySaveRepository())),
  );
  await _pumpUntilFound(tester, find.text('Rune Nexus'));
}

Future<void> _tapStageCard(WidgetTester tester, String stageName) async {
  final button = tester.widget<OutlinedButton>(
    find.widgetWithText(OutlinedButton, stageName),
  );
  button.onPressed?.call();
  await tester.pump();
}

Future<void> _pumpGameFrames(WidgetTester tester, {int frameCount = 3}) async {
  for (var i = 0; i < frameCount; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxFrameCount = 60,
}) async {
  for (var i = 0; i < maxFrameCount; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('앱 초기 로딩이 완료되지 않았습니다.');
}

GameSnapshot _resultSnapshot({
  required GamePhase phase,
  required int currentStageNumber,
  int unlockedStageCount = 1,
  int completedRounds = 0,
  int runes = 0,
  int lastRunRuneReward = 0,
  int lastRunPreviousBestRound = 0,
  bool lastRunWasNewBestRound = false,
  int? lastRunUnlockedStageNumber,
  bool lastRunUnlockedSniperTurret = false,
  Map<int, int> bestRoundsByStage = const {},
  Set<int> clearedStageNumbers = const {},
  int killGoldUpgradeLevel = 0,
  double killGoldProgressionBonusRate = 0,
  int emergencySaleUpgradeLevel = 0,
  int emergencySaleUpgradeCost = 60,
  bool canUpgradeEmergencySale = false,
  int turretRefundPercent = 75,
}) {
  return GameSnapshot(
    gold: 0,
    gemShards: 0,
    nexusHp: 0,
    maxNexusHp: 20,
    round: completedRounds,
    maxRound: 50,
    phase: phase,
    restoredPhase: null,
    hasStageProgress: false,
    placedTurretCount: 0,
    currentStageNumber: currentStageNumber,
    unlockedStageCount: unlockedStageCount,
    bestRoundsByStage: bestRoundsByStage,
    clearedStageNumbers: clearedStageNumbers,
    availableTurretTypes: const [
      TurretType.arrow,
      TurretType.cannon,
      TurretType.magic,
      TurretType.frost,
    ],
    selectedTurretType: TurretType.arrow,
    selectedRunPanelTab: RunPanelTab.turrets,
    previewText: '',
    rewardOptions: const [],
    isPurchasedGemReward: false,
    gemInventory: const {},
    gemCollection: const {},
    selectedBuildPoint: null,
    selectedBuildTurretType: null,
    selectedPortalPoint: null,
    selectedTurretPoint: null,
    selectedTurretName: null,
    selectedTurretGems: const [],
    selectedTurretGemSlotIndex: null,
    selectedTurretSlotLimit: 0,
    selectedTurretHasLinkUpgrade: false,
    selectedTurretCanUpgradeLink: false,
    selectedTurretLinkUpgradeCost: 0,
    selectedTurretNextSlotLimit: 0,
    selectedTurretLinkUpgradeRequiredLevel: 0,
    selectedTurretLevel: 0,
    selectedTurretMaxLevel: 0,
    selectedTurretCanLevelUp: false,
    selectedTurretLevelUpCost: 0,
    selectedTurretRefundGold: 0,
    selectedTurretDamage: 0,
    selectedTurretRange: 0,
    selectedTurretAttackRate: 0,
    selectedTurretBurnDamagePerSecond: 0,
    selectedTurretBurnDuration: 0,
    selectedTurretDamageDealt: 0,
    selectedTurretDirectDamageDealt: 0,
    selectedTurretSplashDamageDealt: 0,
    selectedTurretChainDamageDealt: 0,
    selectedTurretBurnDamageDealt: 0,
    selectedTurretSupportsTraits: false,
    selectedTurretPrimaryTraitChoices: const [],
    selectedTurretSecondaryTraitChoices: const [],
    selectedTurretPrimaryTrait: null,
    selectedTurretSecondaryTrait: null,
    selectedTurretCanChoosePrimaryTrait: false,
    selectedTurretCanChooseSecondaryTrait: false,
    selectedTurretPrimaryTraitCost: 12,
    selectedTurretSecondaryTraitCost: 24,
    selectedTurretPrimaryTraitRequiredLevel: 3,
    selectedTurretSecondaryTraitRequiredLevel: 7,
    topDamageTurretName: null,
    topDamageTurretDamageDealt: 0,
    nextWaveEnemyTypes: const [],
    nextWaveEnemyCounts: const {},
    nextWaveClearRewardGold: 0,
    nextWaveKillRewardGold: 0,
    nextWaveClearRewardGemShards: 0,
    autoStartMode: AutoStartMode.pauseEachRound,
    speedMultiplier: 1,
    killGoldFractionWallet: 0,
    runUpgradeLevels: const {},
    towerDamageRunBonusRate: 0,
    killGoldRunBonusRate: 0,
    waveClearGoldRunBonus: 0,
    runes: runes,
    lastRunRuneReward: lastRunRuneReward,
    projectedFailureRuneReward: completedRounds * 2,
    lastRunPreviousBestRound: lastRunPreviousBestRound,
    lastRunWasNewBestRound: lastRunWasNewBestRound,
    lastRunUnlockedStageNumber: lastRunUnlockedStageNumber,
    lastRunUnlockedSniperTurret: lastRunUnlockedSniperTurret,
    completedRounds: completedRounds,
    startingGoldUpgradeLevel: 0,
    startingGoldUpgradeCost: 4,
    canUpgradeStartingGold: false,
    nexusHpUpgradeLevel: 0,
    nexusHpUpgradeCost: 14,
    canUpgradeNexusHp: false,
    supplyUpgradeLevel: 0,
    supplyUpgradeCost: 7,
    canUpgradeSupply: false,
    waveClearGoldProgressionBonus: 0,
    fireTrainingUpgradeLevel: 0,
    fireTrainingUpgradeCost: 7,
    canUpgradeFireTraining: false,
    fireTrainingDamageBonusRate: 0,
    killGoldUpgradeLevel: killGoldUpgradeLevel,
    killGoldUpgradeCost: 7,
    canUpgradeKillGold: false,
    killGoldProgressionBonusRate: killGoldProgressionBonusRate,
    emergencySaleUpgradeLevel: emergencySaleUpgradeLevel,
    emergencySaleUpgradeCost: emergencySaleUpgradeCost,
    canUpgradeEmergencySale: canUpgradeEmergencySale,
    turretRefundPercent: turretRefundPercent,
  );
}
