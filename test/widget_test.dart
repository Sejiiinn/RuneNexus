import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/app/rune_nexus_app.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/combat/auto_start_mode.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
import 'package:rune_nexus/domain/combat/run_panel_tab.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/research/research_progress.dart';
import 'package:rune_nexus/domain/research/research_type.dart';
import 'package:rune_nexus/domain/turret/turret_target_priority.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/game/game_snapshot.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/l10n/rune_nexus_localizations.dart';
import 'package:rune_nexus/ui/game/game_button.dart';
import 'package:rune_nexus/ui/hud/game_hud.dart';
import 'package:rune_nexus/ui/menu/main_menu_screen.dart';
import 'package:rune_nexus/ui/menu/map_editor_panel.dart';
import 'package:rune_nexus/ui/menu/result_overlay.dart';

void main() {
  test('tactical command research has popup description text', () {
    const ko = RuneNexusLocalizations(Locale('ko'));
    const en = RuneNexusLocalizations(Locale('en'));

    expect(
      ko.researchDescription(ko.tacticalCommand),
      '포탑별로 우선 공격 대상을 지정할 수 있도록 합니다.',
    );
    expect(
      en.researchDescription(en.tacticalCommand),
      'Allows each turret to set its preferred attack target.',
    );
  });

  testWidgets('Rune Nexus app renders main menu', (tester) async {
    await _pumpLoadedApp(tester);

    expect(find.text('Rune Nexus'), findsOneWidget);
    expect(find.text('스테이지'), findsOneWidget);
    expect(find.text('스테이지 1'), findsOneWidget);
    expect(find.text('스테이지 5'), findsOneWidget);
    expect(find.text('잠김'), findsNWidgets(4));
    expect(find.text('강화'), findsOneWidget);
    expect(find.text('연구'), findsWidgets);
  });

  testWidgets('stage menu opens chapter two as stages six to ten', (
    tester,
  ) async {
    int? startedStage;
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
            unlockedStageCount: 6,
            clearedStageNumbers: const {1, 2, 3, 4, 5},
          ),
          selectedTab: MainMenuTab.stage,
          onSelectTab: (_) {},
          onStartStage: (stage) {
            startedStage = stage;
          },
        ),
      ),
    );
    await _pumpGameFrames(tester);

    await tester.tap(find.text('챕터 2'));
    await _pumpGameFrames(tester);

    expect(find.text('균열 장막'), findsOneWidget);
    expect(find.text('스테이지 6'), findsOneWidget);
    expect(find.text('스테이지 10'), findsOneWidget);
    expect(find.text('스테이지 1'), findsNothing);

    await tester.tap(find.text('스테이지 6'));
    await _pumpGameFrames(tester);

    expect(startedStage, 6);
  });

  testWidgets('selected ghost game buttons stay visually restrained', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GameButton(
          onPressed: () {},
          label: '진행 중',
          selected: true,
          variant: GameButtonVariant.ghost,
        ),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.gradient, isNull);
  });

  testWidgets('main menu keeps tabs on bottom and keeps logo across tabs', (
    tester,
  ) async {
    await _pumpLoadedApp(tester);

    expect(find.text('Rune Nexus'), findsOneWidget);

    await tester.tap(find.text('강화'));
    await _pumpGameFrames(tester);

    expect(find.text('Rune Nexus'), findsOneWidget);
    expect(find.text('업그레이드 보드'), findsOneWidget);
    expect(find.text('넥서스 체력'), findsOneWidget);
    expect(find.text('기초 화력 훈련'), findsOneWidget);
    expect(find.text('레벨업'), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.paid_outlined));
    await _pumpGameFrames(tester);

    expect(find.text('시작 골드'), findsOneWidget);
    expect(find.text('정비 보급'), findsOneWidget);
    expect(find.text('처치 보상'), findsNothing);
    expect(find.text('긴급 매각'), findsNothing);
    expect(find.text('미해금 업그레이드'), findsNothing);
    expect(find.text('아직 사용할 수 없음'), findsNothing);
    expect(find.text('새 런을 시작할 때 보유하는 골드가 영구적으로 증가합니다.'), findsOneWidget);
    expect(find.text('웨이브를 클리어할 때마다 추가 골드를 받습니다.'), findsOneWidget);
    expect(find.text('적을 처치할 때 획득하는 골드가 증가합니다.'), findsNothing);
    expect(find.text('포탑을 환불할 때 돌려받는 골드 비율이 증가합니다.'), findsNothing);
    expect(find.text('스테이지'), findsOneWidget);
    expect(find.text('강화'), findsOneWidget);
    expect(find.text('연구'), findsOneWidget);

    await tester.tap(find.text('연구').last);
    await _pumpGameFrames(tester);

    expect(find.text('Rune Nexus'), findsOneWidget);
    expect(find.text('연구 보드'), findsOneWidget);
    expect(find.text('링크 확장 I'), findsOneWidget);
    expect(find.text('젬 감응'), findsOneWidget);
    expect(find.text('연구 슬롯'), findsOneWidget);
    expect(find.text('시작 가능 연구'), findsOneWidget);

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

    expect(find.text('스테이지 1 클리어 필요'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stage cards clarify clear rewards and unlocked rewards', (
    tester,
  ) async {
    await _pumpLoadedApp(tester);

    expect(find.text('클리어 보상'), findsNWidgets(5));
    expect(find.text('저격 포탑'), findsOneWidget);
    expect(find.text('경제 강화'), findsOneWidget);
    expect(find.text('연구'), findsNWidgets(3));
    expect(find.text('전투 강화'), findsOneWidget);
    expect(find.text('룬 +0%'), findsOneWidget);
    expect(find.text('룬 +20%'), findsOneWidget);
    expect(find.text('룬 +45%'), findsOneWidget);
    expect(find.text('룬 +75%'), findsOneWidget);
    expect(find.text('룬 +110%'), findsOneWidget);
    expect(find.text('강화 해금'), findsNothing);
    expect(find.text('연구 해금'), findsNothing);
    expect(find.text('전투 강화 해금'), findsNothing);

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
            unlockedStageCount: 5,
            clearedStageNumbers: const {2, 3, 4, 5},
          ),
          selectedTab: MainMenuTab.stage,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(find.text('해금됨'), findsNWidgets(4));
    expect(find.text('경제 강화'), findsOneWidget);
    expect(find.text('연구'), findsNWidgets(3));
    expect(find.text('전투 강화'), findsOneWidget);
    expect(find.text('클리어 보상: 경제 강화'), findsNothing);
    expect(find.text('클리어 보상: 연구'), findsNothing);
    expect(find.text('클리어 보상: 전투 강화'), findsNothing);
  });

  testWidgets('map editor scopes stage chips by chapter and preserves theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF07111D),
          body: SingleChildScrollView(
            child: DebugMapEditorPanel(initialStageNumber: 6),
          ),
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(find.text('챕터 2 · 6-10'), findsOneWidget);
    expect(_stageChipText('6'), findsOneWidget);
    expect(_stageChipText('10'), findsOneWidget);
    expect(find.text('챕터 1 · 1-5'), findsOneWidget);

    await tester.ensureVisible(find.text('Export 표시'));
    await tester.tap(find.text('Export 표시'));
    await _pumpGameFrames(tester);

    expect(
      find.textContaining('tileTheme: chapterTwoRiftTileTheme'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('챕터 1 · 1-5'));
    await tester.tap(find.text('챕터 1 · 1-5'));
    await _pumpGameFrames(tester);

    expect(_stageChipText('1'), findsOneWidget);
    expect(_stageChipText('5'), findsOneWidget);
    expect(_stageChipText('6'), findsNothing);
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

    final nexusHpTopLeft = tester.getTopLeft(find.text('넥서스 체력'));
    final fireTrainingTopLeft = tester.getTopLeft(find.text('기초 화력 훈련'));

    expect(find.text('업그레이드 보드'), findsOneWidget);
    expect(find.text('레벨업'), findsNWidgets(2));
    expect((nexusHpTopLeft.dy - fireTrainingTopLeft.dy).abs(), lessThan(4));
    expect(fireTrainingTopLeft.dx, greaterThan(nexusHpTopLeft.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('research cards keep two columns on narrow menu width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLoadedApp(tester);

    await tester.tap(find.text('연구').last);
    await _pumpGameFrames(tester);

    final efficiencyTopLeft = tester.getTopLeft(find.text('연구 효율'));
    final costEfficiencyTopLeft = tester.getTopLeft(find.text('연구 비용 효율'));

    expect(
      find.textContaining('연구 효율 +0% -> +5%', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('비용 효율 +0% -> +5%', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('미해금 연구'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
    expect(find.text('Lv.0/1'), findsNWidgets(2));
    expect(
      (efficiencyTopLeft.dy - costEfficiencyTopLeft.dy).abs(),
      lessThan(4),
    );
    expect(costEfficiencyTopLeft.dx, greaterThan(efficiencyTopLeft.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('kill reward is hidden before stage two clear', (tester) async {
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

    expect(find.text('처치 보상'), findsNothing);
    expect(find.text('미해금 업그레이드'), findsNothing);
    expect(find.text('아직 사용할 수 없음'), findsNothing);
    expect(find.text('Lv.3/10'), findsNothing);
  });

  testWidgets('emergency sale is hidden before stage two clear', (
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

    expect(find.text('긴급 매각'), findsNothing);
    expect(find.text('미해금 업그레이드'), findsNothing);
    expect(find.text('아직 사용할 수 없음'), findsNothing);
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
            emergencySaleUpgradeCost: 80,
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

  testWidgets('critical upgrades are hidden before stage four clear', (
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
            runes: 200,
            criticalChanceUpgradeLevel: 15,
            criticalChanceProgressionBonusRate: 0,
            criticalDamageUpgradeLevel: 15,
            criticalDamageProgressionBonusRate: 0,
          ),
          selectedTab: MainMenuTab.permanentUpgrades,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(find.text('치명 집중'), findsNothing);
    expect(find.text('치명 충격'), findsNothing);
    expect(find.text('Lv.15/20'), findsNothing);
  });

  testWidgets('critical upgrades unlock after stage four clear', (
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
            runes: 200,
            clearedStageNumbers: const {4},
            criticalChanceUpgradeLevel: 15,
            criticalChanceUpgradeCost: 1078,
            canUpgradeCriticalChance: true,
            criticalChanceProgressionBonusRate: 0.15,
            criticalDamageUpgradeLevel: 15,
            criticalDamageUpgradeCost: 251,
            canUpgradeCriticalDamage: true,
            criticalDamageProgressionBonusRate: 0.15,
          ),
          selectedTab: MainMenuTab.permanentUpgrades,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(find.text('치명 집중'), findsOneWidget);
    expect(find.text('치명 충격'), findsOneWidget);
    expect(find.text('현재 +15%p'), findsNWidgets(2));
    expect(find.text('다음 +16%p'), findsNWidgets(2));
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
    expect(find.text('+0 룬'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('스테이지 종료'));
    await _pumpGameFrames(tester);

    expect(find.text('정말 종료할까요?'), findsOneWidget);
    expect(find.textContaining('+0 룬'), findsWidgets);
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

  testWidgets(
    'selected turret panel gates target priority selector by research',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF07111D),
            body: GameHud(game: game),
          ),
        ),
      );
      await _pumpGameFrames(tester, frameCount: 10);
      game.tryBuildTurret(const GridPoint(2, 0));
      await _pumpGameFrames(tester);

      expect(find.text('공격 명령'), findsNothing);
      expect(find.text('선두 적'), findsNothing);
      expect(tester.takeException(), isNull);

      final unlockedRepository = MemorySaveRepository()
        ..data = _saveWithResearch(
          clearedStageNumbers: const {3},
          researchLevels: const {ResearchType.turretTargetPriority: 1},
        );
      final unlockedGame = RuneNexusGame(saveRepository: unlockedRepository);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF07111D),
            body: GameHud(game: unlockedGame),
          ),
        ),
      );
      await _pumpGameFrames(tester, frameCount: 10);
      unlockedGame.tryBuildTurret(const GridPoint(2, 0));
      await _pumpGameFrames(tester);

      expect(find.text('공격 명령'), findsOneWidget);
      expect(find.text('선두 적'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('trait dialog uses compact tier panel on narrow combat width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF07111D),
          body: GameHud(game: game),
        ),
      ),
    );
    await _pumpGameFrames(tester, frameCount: 10);
    game.debugAddGold(1000);
    game.tryBuildTurret(const GridPoint(2, 0));
    while (game.snapshotNotifier.value.selectedTurretLevel < 3) {
      game.levelUpSelectedTurret();
    }
    await _pumpGameFrames(tester);

    await tester.tap(find.byTooltip('특성'));
    await _pumpGameFrames(tester);

    expect(find.text('기관총 특성'), findsOneWidget);
    expect(find.text('무기 개조'), findsNWidgets(2));
    expect(find.text('전투 교리'), findsOneWidget);
    expect(find.text('과열 탄창'), findsOneWidget);
    expect(find.text('경량 총열'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('전투 교리'));
    await _pumpGameFrames(tester);

    expect(find.text('1차 특성 선택 후 후보 카드가 열립니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu clock refreshes active research completion', (
    tester,
  ) async {
    final game = _ResearchRefreshGame();
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
          game: game,
          snapshot: _resultSnapshot(
            phase: GamePhase.preparation,
            currentStageNumber: 1,
            activeResearches: const [
              ResearchProgress(
                type: ResearchType.gemAttunement,
                targetLevel: 1,
                startedAtMillis: 0,
                durationMillis: 1,
              ),
            ],
          ),
          selectedTab: MainMenuTab.stage,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));

    expect(game.researchRefreshCount, 1);
  });
}

Future<void> _pumpLoadedApp(WidgetTester tester) async {
  await tester.pumpWidget(
    RuneNexusApp(game: RuneNexusGame(saveRepository: MemorySaveRepository())),
  );
  await _pumpUntilFound(tester, find.text('Rune Nexus'));
}

Finder _stageChipText(String text) {
  return find.descendant(
    of: find.byType(ChoiceChip),
    matching: find.text(text),
  );
}

Future<void> _tapStageCard(WidgetTester tester, String stageName) async {
  final stageNumber = RegExp(r'\d+').firstMatch(stageName)?.group(0);
  expect(stageNumber, isNotNull);
  await tester.tap(find.byKey(ValueKey('stage-selection-row-$stageNumber')));
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
  int criticalChanceUpgradeLevel = 0,
  int criticalChanceUpgradeCost = 70,
  bool canUpgradeCriticalChance = false,
  double criticalChanceProgressionBonusRate = 0,
  int criticalDamageUpgradeLevel = 0,
  int criticalDamageUpgradeCost = 60,
  bool canUpgradeCriticalDamage = false,
  double criticalDamageProgressionBonusRate = 0,
  int emergencySaleUpgradeLevel = 0,
  int emergencySaleUpgradeCost = 80,
  bool canUpgradeEmergencySale = false,
  int turretRefundPercent = 75,
  List<ResearchProgress> activeResearches = const [],
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
    selectedTurretLevelUpPreviewActive: false,
    selectedTurretNextLevel: 0,
    selectedTurretNextDamage: 0,
    selectedTurretNextRange: 0,
    selectedTurretNextAttackRate: 0,
    selectedTurretNextBurnDamagePerSecond: 0,
    selectedTurretNextBurnDuration: 0,
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
    canSetTurretTargetPriority: false,
    selectedTurretTargetPriority: TurretTargetPriority.first,
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
    criticalChanceUpgradeLevel: criticalChanceUpgradeLevel,
    criticalChanceUpgradeCost: criticalChanceUpgradeCost,
    canUpgradeCriticalChance: canUpgradeCriticalChance,
    criticalChanceProgressionBonusRate: criticalChanceProgressionBonusRate,
    criticalDamageUpgradeLevel: criticalDamageUpgradeLevel,
    criticalDamageUpgradeCost: criticalDamageUpgradeCost,
    canUpgradeCriticalDamage: canUpgradeCriticalDamage,
    criticalDamageProgressionBonusRate: criticalDamageProgressionBonusRate,
    killGoldUpgradeLevel: killGoldUpgradeLevel,
    killGoldUpgradeCost: 7,
    canUpgradeKillGold: false,
    killGoldProgressionBonusRate: killGoldProgressionBonusRate,
    emergencySaleUpgradeLevel: emergencySaleUpgradeLevel,
    emergencySaleUpgradeCost: emergencySaleUpgradeCost,
    canUpgradeEmergencySale: canUpgradeEmergencySale,
    turretRefundPercent: turretRefundPercent,
    researchSlotCount: 1,
    researchLevels: const {},
    researchElapsedMillis: const {},
    activeResearches: activeResearches,
    startingGemShards: 0,
  );
}

class _ResearchRefreshGame extends RuneNexusGame {
  _ResearchRefreshGame() : super(saveRepository: MemorySaveRepository());

  int researchRefreshCount = 0;

  @override
  bool refreshResearchProgress() {
    researchRefreshCount += 1;
    return true;
  }
}

GameSaveData _saveWithResearch({
  required Set<int> clearedStageNumbers,
  required Map<ResearchType, int> researchLevels,
}) {
  return GameSaveData(
    version: GameSaveData.currentVersion,
    savedAtMillis: 0,
    gold: 150,
    gemShards: 0,
    nexusHp: 20,
    stageNumber: 1,
    mapSignature: null,
    roundIndex: 0,
    completedRounds: 0,
    phase: GamePhase.preparation,
    autoStartMode: AutoStartMode.pauseEachRound,
    progression: SavedProgression(
      runes: 0,
      lastRunRuneReward: 0,
      startingGoldUpgradeLevel: 0,
      nexusHpUpgradeLevel: 0,
      supplyUpgradeLevel: 0,
      fireTrainingUpgradeLevel: 0,
      criticalChanceUpgradeLevel: 0,
      criticalDamageUpgradeLevel: 0,
      killGoldUpgradeLevel: 0,
      emergencySaleUpgradeLevel: 0,
      unlockedStageCount: 4,
      bestRoundsByStage: const {},
      clearedStageNumbers: clearedStageNumbers,
      researchLevels: researchLevels,
      researchElapsedMillis: const {},
      activeResearches: const [],
    ),
    runUpgradeLevels: const {},
    killGoldFractionWallet: 0,
    gemInventory: const {},
    rewardOptions: const [],
    isPurchasedGemReward: false,
    turrets: const [],
    enemies: const [],
    spawnQueue: const [],
  );
}
