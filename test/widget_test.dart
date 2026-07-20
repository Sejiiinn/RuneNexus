import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/app/rune_nexus_app.dart';
import 'package:rune_nexus/data/definitions/game_core_passive_tree_data.dart';
import 'package:rune_nexus/data/definitions/game_stage_maps.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/combat/auto_start_mode.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
import 'package:rune_nexus/domain/combat/run_panel_tab.dart';
import 'package:rune_nexus/domain/core/core_ability.dart';
import 'package:rune_nexus/domain/core/core_passive_tree.dart';
import 'package:rune_nexus/domain/gem/gem_type.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/research/research_progress.dart';
import 'package:rune_nexus/domain/research/research_type.dart';
import 'package:rune_nexus/domain/turret/turret_target_priority.dart';
import 'package:rune_nexus/domain/turret/turret_trait_type.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/turret_module/turret_module_type.dart';
import 'package:rune_nexus/data/definitions/game_turret_module_data.dart';
import 'package:rune_nexus/game/game_snapshot.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/game/systems/game_save_adapter.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';
import 'package:rune_nexus/l10n/rune_nexus_localizations.dart';
import 'package:rune_nexus/ui/game/game_button.dart';
import 'package:rune_nexus/ui/game/core_ability_icon.dart';
import 'package:rune_nexus/ui/game/game_icons.dart';
import 'package:rune_nexus/ui/game/research_icon.dart';
import 'package:rune_nexus/ui/game/upgrade_icon.dart';
import 'package:rune_nexus/ui/hud/core_info_panel.dart';
import 'package:rune_nexus/ui/hud/game_hud.dart';
import 'package:rune_nexus/ui/hud/reward_overlay.dart';
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
    expect(find.text('다이아'), findsNothing);

    final logoRect = tester.getRect(find.text('Rune Nexus'));
    final currencyRect = tester.getRect(
      find.byKey(const ValueKey('menu-currency-balance')),
    );
    expect(currencyRect.overlaps(logoRect), isFalse);
  });

  testWidgets('main menu currency does not overlap logo on narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLoadedApp(tester);

    final logoRect = tester.getRect(find.text('Rune Nexus'));
    final currencyRect = tester.getRect(
      find.byKey(const ValueKey('menu-currency-balance')),
    );
    final viewportCenterX =
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2;
    expect((logoRect.center.dx - viewportCenterX).abs(), lessThanOrEqualTo(1));
    expect(currencyRect.top, lessThan(logoRect.top));
    expect(currencyRect.overlaps(logoRect), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stage menu opens daily quest dialog', (tester) async {
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
          ),
          selectedTab: MainMenuTab.stage,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(
      find.byKey(const ValueKey('daily-quest-entry-button')),
      findsOneWidget,
    );
    expect(find.byTooltip('일일 임무'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('daily-quest-entry-button')));
    await _pumpGameFrames(tester);

    expect(find.text('웨이브 30회 클리어'), findsOneWidget);
    expect(find.text('보스 3회 처치'), findsOneWidget);
    expect(find.text('몹 100회 처치'), findsOneWidget);
    expect(find.text('런 강화 5회'), findsOneWidget);
    expect(find.text('+10'), findsNWidgets(5));
    expect(find.text('오늘 출석'), findsOneWidget);
    final dailySummary = find.byKey(const ValueKey('daily-quest-summary-card'));
    final todayProgress = find.descendant(
      of: dailySummary,
      matching: find.textContaining('0/4 완료'),
    );
    final dailyReset = find.descendant(
      of: dailySummary,
      matching: find.text('매일 05:00 갱신'),
    );
    expect(todayProgress, findsOneWidget);
    expect(
      find.descendant(of: dailySummary, matching: find.text('전체 완료')),
      findsNothing,
    );
    expect(
      (tester.getTopLeft(find.text('오늘 진행')).dy -
              tester.getTopLeft(dailyReset).dy)
          .abs(),
      lessThan(4),
    );
    expect(
      tester.getTopLeft(find.text('오늘 출석')).dy,
      lessThan(tester.getTopLeft(find.text('웨이브 30회 클리어')).dy),
    );
    expect(find.byTooltip('닫기'), findsOneWidget);
    expect(find.widgetWithText(GameButton, '닫기'), findsNothing);
    final dailyDialogWidth = tester.getSize(find.byType(AlertDialog)).width;

    await tester.tap(find.byKey(const ValueKey('quest-period-weekly')));
    await _pumpGameFrames(tester);

    expect(find.text('웨이브 150회 클리어'), findsOneWidget);
    expect(find.text('보스 15회 처치'), findsOneWidget);
    expect(find.text('몹 500회 처치'), findsOneWidget);
    expect(find.text('런 강화 25회'), findsOneWidget);
    expect(find.text('이번 주 출석'), findsOneWidget);
    expect(find.text('모듈권 +1'), findsOneWidget);
    final weeklySummary = find.byKey(
      const ValueKey('weekly-quest-summary-card'),
    );
    final weeklyProgress = find.descendant(
      of: weeklySummary,
      matching: find.textContaining('0/4 완료'),
    );
    final weeklyReset = find.descendant(
      of: weeklySummary,
      matching: find.text('월요일 05:00 갱신'),
    );
    expect(weeklyProgress, findsOneWidget);
    expect(
      find.descendant(of: weeklySummary, matching: find.text('전체 완료')),
      findsNothing,
    );
    expect(
      (tester.getTopLeft(find.text('이번 주 진행')).dy -
              tester.getTopLeft(weeklyReset).dy)
          .abs(),
      lessThan(4),
    );
    expect(
      tester.getTopLeft(find.text('이번 주 출석')).dy,
      lessThan(tester.getTopLeft(find.text('웨이브 150회 클리어')).dy),
    );
    expect(tester.getSize(find.byType(AlertDialog)).width, dailyDialogWidth);
    expect(tester.takeException(), isNull);
  });

  testWidgets('daily quest entry only appears on stage tab', (tester) async {
    await _pumpLoadedApp(tester);

    expect(
      find.byKey(const ValueKey('daily-quest-entry-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('main-menu-tab-research')));
    await _pumpGameFrames(tester);

    expect(
      find.byKey(const ValueKey('daily-quest-entry-button')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('main-menu-tab-core')));
    await _pumpGameFrames(tester);

    expect(
      find.byKey(const ValueKey('daily-quest-entry-button')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('main-menu-tab-upgrades')));
    await _pumpGameFrames(tester);

    expect(
      find.byKey(const ValueKey('daily-quest-entry-button')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('main-menu-tab-modules')));
    await _pumpGameFrames(tester);

    expect(
      find.byKey(const ValueKey('daily-quest-entry-button')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('main-menu-tab-stage')));
    await _pumpGameFrames(tester);

    expect(
      find.byKey(const ValueKey('daily-quest-entry-button')),
      findsOneWidget,
    );
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
    expect(find.text('라이트닝 포탑'), findsNothing);

    await tester.tap(find.text('스테이지 6'));
    await _pumpGameFrames(tester);

    expect(find.text('총 라운드'), findsOneWidget);
    expect(find.text('룬 보상'), findsOneWidget);
    expect(find.text('라이트닝 포탑'), findsWidgets);
    expect(startedStage, isNull);

    await tester.tap(find.text('시작하기'));
    await _pumpGameFrames(tester);

    expect(startedStage, 6);
  });

  testWidgets('stage menu previews chapter two before stage five clear', (
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
            unlockedStageCount: 1,
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

    expect(find.text('챕터 2'), findsOneWidget);
    expect(find.text('챕터 3'), findsOneWidget);

    await tester.tap(find.text('챕터 2'));
    await _pumpGameFrames(tester);

    expect(find.text('균열 장막'), findsOneWidget);
    expect(find.text('스테이지 6'), findsOneWidget);
    expect(find.text('스테이지 10'), findsOneWidget);
    expect(find.text('스테이지 1'), findsNothing);
    expect(find.text('잠김'), findsNWidgets(5));

    await tester.tap(find.byKey(const ValueKey('stage-selection-row-6')));
    await _pumpGameFrames(tester);

    expect(find.text('스테이지 5 클리어 후 시작할 수 있습니다.'), findsOneWidget);
    expect(find.text('시작 불가'), findsOneWidget);
    expect(startedStage, isNull);
  });

  testWidgets('stage menu opens chapter three as stages eleven to fifteen', (
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
            unlockedStageCount: 11,
            clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
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

    await tester.tap(find.text('챕터 3'));
    await _pumpGameFrames(tester);

    expect(find.text('공명 용광로'), findsOneWidget);
    expect(find.text('스테이지 11'), findsOneWidget);
    expect(find.text('스테이지 15'), findsOneWidget);
    expect(find.text('스테이지 6'), findsNothing);

    await tester.tap(find.text('스테이지 11'));
    await _pumpGameFrames(tester);

    expect(find.text('총 라운드'), findsOneWidget);
    expect(startedStage, isNull);

    await tester.tap(find.text('시작하기'));
    await _pumpGameFrames(tester);

    expect(startedStage, 11);
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

  testWidgets('main menu keeps the logo on stage and compacts other headers', (
    tester,
  ) async {
    await _pumpLoadedApp(tester);

    expect(find.text('Rune Nexus'), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-resource-bar')), findsNothing);
    final stageTabRect = tester.getRect(
      find.byKey(const ValueKey('main-menu-tab-stage')),
    );
    final turretTabRect = tester.getRect(
      find.byKey(const ValueKey('main-menu-tab-modules')),
    );
    final screenRect = tester.getRect(find.byType(MainMenuScreen));
    expect(stageTabRect.left, screenRect.left);
    expect(turretTabRect.right, screenRect.right);
    expect(turretTabRect.bottom, closeTo(screenRect.bottom, 1));
    expect(find.text('모듈'), findsNothing);
    expect(find.text('포탑'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/stage_rewards/reward_turret.png',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('코어'));
    await _pumpGameFrames(tester);

    expect(find.text('Rune Nexus'), findsNothing);
    final resourceBar = find.byKey(const ValueKey('menu-resource-bar'));
    expect(resourceBar, findsOneWidget);
    expect(
      find.descendant(
        of: resourceBar,
        matching: find.byKey(const ValueKey('menu-currency-balance')),
      ),
      findsOneWidget,
    );
    final resourceBarRect = tester.getRect(resourceBar);
    final corePanelRect = tester.getRect(
      find.byKey(const ValueKey('main-menu-content-panel')),
    );
    expect(corePanelRect.top, greaterThanOrEqualTo(resourceBarRect.bottom));
    expect(find.text('넥서스 코어'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('menu-resource-title')))
          .data,
      '넥서스 코어',
    );
    expect(find.text('전투 스킬 1칸 / 패시브 2칸'), findsNothing);
    expect(find.text('Lv.1'), findsNothing);
    expect(find.text('전투 스킬'), findsWidgets);
    expect(find.text('패시브 트리'), findsOneWidget);
    expect(find.text('수호 광선'), findsOneWidget);
    expect(find.text('균열 낙인'), findsOneWidget);
    expect(find.text('연쇄 광휘'), findsNothing);
    expect(find.text('잠김'), findsWidgets);
    expect(find.text('예상 피해'), findsNothing);
    expect(find.text('평균 DPS 8%'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('main-menu-tab-upgrades')));
    await _pumpGameFrames(tester);

    expect(find.text('Rune Nexus'), findsNothing);
    expect(find.text('업그레이드 보드'), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('menu-resource-title')))
          .data,
      '업그레이드',
    );
    expect(find.text('넥서스 체력'), findsOneWidget);
    expect(find.text('기초 화력 훈련'), findsOneWidget);
    expect(find.text('레벨업'), findsNWidgets(2));

    await tester.tap(find.byTooltip('경제'));
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
    expect(find.text('코어'), findsOneWidget);
    expect(find.text('강화'), findsOneWidget);
    expect(find.text('연구'), findsOneWidget);

    await tester.tap(find.text('연구').last);
    await _pumpGameFrames(tester);

    expect(find.text('Rune Nexus'), findsNothing);
    expect(find.text('연구 보드'), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('menu-resource-title')))
          .data,
      '연구',
    );
    expect(find.text('토벌 보상'), findsOneWidget);
    expect(find.text('기초 연결 공학'), findsOneWidget);
    expect(find.text('링크 확장 I'), findsOneWidget);
    expect(find.text('젬 감응'), findsOneWidget);
    expect(find.text('연구 슬롯'), findsOneWidget);
    expect(find.text('시작 가능 연구'), findsOneWidget);
    final bountyTopLeft = tester.getTopLeft(find.text('토벌 보상'));
    final linkMaintenanceTopLeft = tester.getTopLeft(find.text('기초 연결 공학'));
    expect(
      linkMaintenanceTopLeft.dy > bountyTopLeft.dy ||
          linkMaintenanceTopLeft.dx > bountyTopLeft.dx,
      isTrue,
    );

    await tester.tap(find.text('스테이지'));
    await _pumpGameFrames(tester);

    expect(find.text('Rune Nexus'), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-resource-bar')), findsNothing);
  });

  testWidgets('main menu tabs respond across the whole button area', (
    tester,
  ) async {
    await _pumpLoadedApp(tester);

    await tester.tapAt(_tabLeadingEdge(tester, 'main-menu-tab-research'));
    await _pumpGameFrames(tester);

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('menu-resource-title')))
          .data,
      '연구',
    );

    await tester.tapAt(_tabLeadingEdge(tester, 'main-menu-tab-core'));
    await _pumpGameFrames(tester);

    expect(find.text('넥서스 코어'), findsOneWidget);

    await tester.tapAt(_tabLeadingEdge(tester, 'main-menu-tab-stage'));
    await _pumpGameFrames(tester);

    expect(find.text('스테이지 1'), findsOneWidget);
  });

  testWidgets('turret module menu shows equipment flow and ticket purchase', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;

    final game = _TurretModuleDrawGame();
    final initialSnapshot = _resultSnapshot(
      phase: GamePhase.preparation,
      currentStageNumber: 1,
      diamonds: 160,
      turretModuleTickets: 3,
    );
    game.snapshotNotifier.value = initialSnapshot;

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
          snapshot: initialSnapshot,
          snapshotListenable: game.snapshotNotifier,
          selectedTab: MainMenuTab.turretModules,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('menu-resource-title')))
          .data,
      '포탑 모듈',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('menu-turret-module-tickets')),
        matching: find.text('모듈권 3'),
      ),
      findsOneWidget,
    );
    expect(find.text('모듈 뽑기'), findsOneWidget);
    expect(find.text('희귀 5%'), findsNothing);
    expect(find.text('희귀 보정'), findsNothing);
    expect(find.text('선택 포탑 · 모든 기관총에 적용'), findsNothing);
    expect(find.text('기'), findsNothing);
    expect(find.text('기관총 모듈 인벤토리'), findsOneWidget);
    expect(find.textContaining('보유 모듈 0개'), findsOneWidget);
    expect(find.text('획득 필요'), findsNothing);
    expect(find.text('0성'), findsNothing);
    expect(find.text('☆☆☆'), findsNothing);
    expect(find.textContaining('장착 효과:'), findsOneWidget);
    final drawTitleRect = tester.getRect(find.text('모듈 뽑기'));
    final fiveDrawButton = find.byKey(
      const ValueKey('turret-module-draw-button-5'),
    );
    final fiveDrawButtonRect = tester.getRect(fiveDrawButton);
    expect(fiveDrawButtonRect.width, lessThanOrEqualTo(72));
    expect(
      (fiveDrawButtonRect.center.dy - drawTitleRect.center.dy).abs(),
      lessThanOrEqualTo(6),
    );
    expect(find.text('부족 2장 · 다이아 160'), findsNothing);
    expect(
      find.descendant(of: fiveDrawButton, matching: find.text('160')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: fiveDrawButton,
        matching: find.byKey(
          const ValueKey('turret-module-draw-diamond-cost-5'),
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('대포'));
    await _pumpGameFrames(tester);

    expect(find.text('대포 모듈 인벤토리'), findsOneWidget);

    await tester.tap(fiveDrawButton);
    await _pumpGameFrames(tester);

    expect(find.text('모듈권 구매'), findsOneWidget);
    final purchaseDialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: purchaseDialog, matching: find.text('구매 모듈권')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: purchaseDialog, matching: find.text('부족 모듈권')),
      findsNothing,
    );
    expect(
      find.descendant(of: purchaseDialog, matching: find.text('2장')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: purchaseDialog, matching: find.text('결제')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: purchaseDialog, matching: find.text('결제 다이아')),
      findsNothing,
    );
    expect(
      find.descendant(of: purchaseDialog, matching: find.text('160')),
      findsOneWidget,
    );
    expect(find.text('160개'), findsNothing);

    await tester.tap(find.text('구매'));
    await _pumpGameFrames(tester);
    await tester.pump(const Duration(milliseconds: 240));

    final resultLayer = find.byKey(
      const ValueKey('turret-module-draw-result-layer'),
    );
    expect(resultLayer, findsOneWidget);
    final layerRect = tester.getRect(resultLayer);
    final screenRect = tester.getRect(find.byType(MainMenuScreen));
    final moduleTabRect = tester.getRect(
      find.byKey(const ValueKey('main-menu-tab-modules')),
    );
    expect((layerRect.top - screenRect.top).abs(), lessThanOrEqualTo(1));
    expect((layerRect.bottom - screenRect.bottom).abs(), lessThanOrEqualTo(1));
    expect(layerRect.overlaps(moduleTabRect), isTrue);
    expect(game.drawCount, 5);
    expect(game.requestedTurretType, TurretType.cannon);
    expect(game.boughtMissingTicketsWithDiamonds, isTrue);
    for (var i = 0; i < 5; i++) {
      expect(
        find.byKey(ValueKey('turret-module-draw-result-card-$i')),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: resultLayer, matching: find.text('희귀')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: resultLayer,
        matching: find.textContaining('화염 포탑 ·'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: resultLayer, matching: find.textContaining('· 프레임')),
      findsWidgets,
    );
    expect(
      find.descendant(of: resultLayer, matching: find.text('방열 프레임')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: resultLayer, matching: find.text('포탑 모듈 5개')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: resultLayer, matching: find.text('피해 +5%')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: resultLayer, matching: find.text('레벨업 비용 -10%')),
      findsOneWidget,
    );
    final firstCardRect = tester.getRect(
      find.byKey(const ValueKey('turret-module-draw-result-card-0')),
    );
    final secondCardRect = tester.getRect(
      find.byKey(const ValueKey('turret-module-draw-result-card-1')),
    );
    final fifthCardRect = tester.getRect(
      find.byKey(const ValueKey('turret-module-draw-result-card-4')),
    );
    final rareGradeRect = tester.getRect(
      find.byKey(const ValueKey('turret-module-draw-grade-test-module-3')),
    );
    expect(
      (firstCardRect.top - secondCardRect.top).abs(),
      lessThanOrEqualTo(1),
    );
    expect(firstCardRect.right, lessThan(secondCardRect.left));
    expect(
      (fifthCardRect.center.dx - layerRect.center.dx).abs(),
      lessThanOrEqualTo(1),
    );
    expect(rareGradeRect.width, lessThan(firstCardRect.width / 2));
    expect(
      find.descendant(of: resultLayer, matching: find.textContaining('장착 효과')),
      findsNothing,
    );
    expect(
      find.descendant(of: resultLayer, matching: find.text('장착')),
      findsNothing,
    );
    expect(
      find.descendant(of: resultLayer, matching: find.text('분해')),
      findsNothing,
    );

    await tester.tap(
      find.descendant(of: resultLayer, matching: find.text('확인')),
    );
    await _pumpGameFrames(tester);

    expect(resultLayer, findsNothing);
    expect(find.text('방열 프레임'), findsWidgets);
    expect(find.textContaining('프레임 · 화염 · 1옵션'), findsOneWidget);
    expect(find.text('일괄 분해'), findsOneWidget);
    expect(find.text('보유 1개'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('turret-module-inventory-slot-test-module-3')),
      findsOneWidget,
    );
    expect(find.textContaining('피해 +18%'), findsNothing);
  });

  testWidgets('turret module socket focuses equipped inventory item', (
    tester,
  ) async {
    final equippedFrame = TurretModuleInventoryItem(
      id: 'equipped-frame-module',
      key: TurretModuleKey(
        turretType: TurretType.arrow,
        part: TurretModulePart.frame,
        family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.frame),
        grade: TurretModuleGrade.magic,
      ),
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.levelUpCostDiscount,
          value: 10,
        ),
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.buildCostDiscount,
          value: 6,
        ),
      ],
      acquiredOrder: 1,
      equipped: true,
    );
    final spareCore = TurretModuleInventoryItem(
      id: 'spare-core-module',
      key: TurretModuleKey(
        turretType: TurretType.arrow,
        part: TurretModulePart.core,
        family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.core),
        grade: TurretModuleGrade.normal,
      ),
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.damageIncrease,
          value: 5,
        ),
      ],
      acquiredOrder: 2,
      equipped: false,
    );

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
            ownedTurretModules: [equippedFrame, spareCore],
          ),
          selectedTab: MainMenuTab.turretModules,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(find.text('선택한 모듈 없음'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('turret-module-socket-frame')));
    await _pumpGameFrames(tester);

    expect(find.textContaining('프레임 · 기관총 · 2옵션 · 장착됨'), findsOneWidget);
    expect(find.text('레벨업 비용 -10%'), findsWidgets);
    expect(find.text('설치 비용 -6%'), findsWidgets);
    expect(find.textContaining('레벨업 비용 -10% · 설치 비용 -6%'), findsNothing);
    expect(
      find.byKey(
        const ValueKey('turret-module-inventory-slot-equipped-frame-module'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('turret module disassemble asks confirmation first', (
    tester,
  ) async {
    final spareCore = TurretModuleInventoryItem(
      id: 'spare-core-module',
      key: TurretModuleKey(
        turretType: TurretType.arrow,
        part: TurretModulePart.core,
        family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.core),
        grade: TurretModuleGrade.normal,
      ),
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.damageIncrease,
          value: 5,
        ),
      ],
      acquiredOrder: 1,
      equipped: false,
    );
    final game = _TurretModuleDisassembleGame();
    final snapshot = _resultSnapshot(
      phase: GamePhase.preparation,
      currentStageNumber: 1,
      ownedTurretModules: [spareCore],
    );

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
          snapshot: snapshot,
          selectedTab: MainMenuTab.turretModules,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    final inventorySlot = find.byKey(
      const ValueKey('turret-module-inventory-slot-spare-core-module'),
    );
    await tester.ensureVisible(inventorySlot);
    await _pumpGameFrames(tester);
    await tester.tap(inventorySlot);
    await _pumpGameFrames(tester);

    final disassembleButton = find.byKey(
      const ValueKey('turret-module-disassemble-button-spare-core-module'),
    );
    await tester.ensureVisible(disassembleButton);
    await _pumpGameFrames(tester);
    await tester.tap(disassembleButton);
    await _pumpGameFrames(tester);

    expect(game.disassembledId, isNull);
    final dialog = find.byKey(
      const ValueKey('turret-module-disassemble-dialog'),
    );
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('이 모듈 분해 시 2 다이아가 반환됩니다. 진행하시겠습니까?'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('반환 다이아')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('turret-module-disassemble-cancel')),
    );
    await tester.pumpAndSettle();

    expect(dialog, findsNothing);
    expect(game.disassembledId, isNull);

    await tester.ensureVisible(disassembleButton);
    await _pumpGameFrames(tester);
    await tester.tap(disassembleButton);
    await _pumpGameFrames(tester);
    await tester.tap(
      find.byKey(const ValueKey('turret-module-disassemble-confirm')),
    );
    await tester.pumpAndSettle();

    expect(game.disassembledId, 'spare-core-module');
  });

  testWidgets(
    'turret module bulk disassembly uses the visible filter and selected items',
    (tester) async {
      TurretModuleInventoryItem item({
        required String id,
        required TurretModulePart part,
        required TurretModuleGrade grade,
        bool equipped = false,
      }) {
        return TurretModuleInventoryItem(
          id: id,
          key: TurretModuleKey(
            turretType: TurretType.arrow,
            part: part,
            family: turretModuleFamilyFor(TurretType.arrow, part),
            grade: grade,
          ),
          options: const [
            TurretModuleOptionRoll(
              type: TurretModuleOptionType.damageIncrease,
              value: 5,
            ),
          ],
          acquiredOrder: 1,
          equipped: equipped,
        );
      }

      final normalCore = item(
        id: 'bulk-normal-core',
        part: TurretModulePart.core,
        grade: TurretModuleGrade.normal,
      );
      final magicCore = item(
        id: 'bulk-magic-core',
        part: TurretModulePart.core,
        grade: TurretModuleGrade.magic,
      );
      final rareCore = item(
        id: 'bulk-rare-core',
        part: TurretModulePart.core,
        grade: TurretModuleGrade.rare,
      );
      final uniqueCore = item(
        id: 'bulk-unique-core',
        part: TurretModulePart.core,
        grade: TurretModuleGrade.unique,
      );
      final equippedCore = item(
        id: 'bulk-equipped-core',
        part: TurretModulePart.core,
        grade: TurretModuleGrade.normal,
        equipped: true,
      );
      final normalBarrel = item(
        id: 'bulk-normal-barrel',
        part: TurretModulePart.barrel,
        grade: TurretModuleGrade.normal,
      );
      final game = _TurretModuleDisassembleGame();

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
              ownedTurretModules: [
                normalCore,
                magicCore,
                rareCore,
                uniqueCore,
                equippedCore,
                normalBarrel,
              ],
            ),
            selectedTab: MainMenuTab.turretModules,
            onSelectTab: (_) {},
            onStartStage: (_) {},
          ),
        ),
      );
      await _pumpGameFrames(tester);

      final coreFilter = find.byKey(
        const ValueKey('turret-module-part-filter-core'),
      );
      await tester.ensureVisible(coreFilter);
      await tester.tap(coreFilter);
      await _pumpGameFrames(tester);

      final bulkOpen = find.byKey(
        const ValueKey('turret-module-bulk-disassemble-open'),
      );
      await tester.ensureVisible(bulkOpen);
      await tester.tap(bulkOpen);
      await tester.pumpAndSettle();

      final dialog = find.byKey(
        const ValueKey('turret-module-bulk-disassemble-dialog'),
      );
      expect(dialog, findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('turret-module-bulk-target-bulk-normal-core'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('turret-module-bulk-target-bulk-normal-barrel'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('turret-module-bulk-target-bulk-equipped-core'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('turret-module-bulk-target-bulk-unique-core'),
        ),
        findsNothing,
      );
      expect(find.text('선택 1개'), findsOneWidget);
      final normalGradeChip = find.byKey(
        const ValueKey('turret-module-bulk-grade-normal'),
      );
      expect(tester.getSize(normalGradeChip).height, 25);
      expect(tester.getSize(normalGradeChip).width, lessThan(80));
      expect(
        find.byKey(const ValueKey('turret-module-bulk-return-diamonds')),
        findsOneWidget,
      );

      await tester.tap(normalGradeChip);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey('turret-module-bulk-target-bulk-normal-core'),
        ),
        findsNothing,
      );
      expect(find.text('선택 0개'), findsOneWidget);
      expect(
        tester
            .widget<GameButton>(
              find.byKey(
                const ValueKey('turret-module-bulk-disassemble-confirm'),
              ),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(normalGradeChip);
      await tester.pumpAndSettle();
      expect(find.text('선택 1개'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('turret-module-bulk-grade-magic')),
      );
      await tester.pumpAndSettle();
      final magicTarget = find.byKey(
        const ValueKey('turret-module-bulk-target-bulk-magic-core'),
      );
      expect(magicTarget, findsOneWidget);
      expect(find.text('선택 2개'), findsOneWidget);

      await tester.tap(magicTarget);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('turret-module-bulk-grade-rare')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('turret-module-bulk-target-bulk-rare-core')),
        findsOneWidget,
      );
      expect(find.text('선택 2개'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('turret-module-bulk-return-diamonds')),
            )
            .data,
        '22',
      );

      final confirm = find.byKey(
        const ValueKey('turret-module-bulk-disassemble-confirm'),
      );
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(game.bulkDisassembledIds, {'bulk-normal-core', 'bulk-rare-core'});
    },
  );

  testWidgets(
    'core menu switches between combat skills and 27-node passive tree',
    (tester) async {
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
              totalCorePoints: 20,
            ),
            selectedTab: MainMenuTab.core,
            onSelectTab: (_) {},
            onStartStage: (_) {},
          ),
        ),
      );
      await _pumpGameFrames(tester);

      expect(find.text('전투 스킬'), findsWidgets);
      expect(find.text('패시브 트리'), findsOneWidget);
      expect(find.text('수호 광선'), findsOneWidget);
      expect(find.textContaining('패시브 슬롯'), findsNothing);

      await tester.tap(find.text('패시브 트리'));
      await _pumpGameFrames(tester);

      for (final id in CorePassiveNodeId.values) {
        expect(
          find.byKey(ValueKey('core-passive-node-${id.name}')),
          findsOneWidget,
        );
      }
      expect(find.text('코어 포인트 20'), findsOneWidget);
      expect(find.text('노드를 선택해 효과와 랭크를 확인하세요'), findsOneWidget);
    },
  );

  testWidgets('core passive target rank is assigned atomically', (
    tester,
  ) async {
    final game = _CoreEquipGame();
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
            totalCorePoints: 20,
          ),
          selectedTab: MainMenuTab.core,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);
    await tester.tap(find.text('패시브 트리'));
    await _pumpGameFrames(tester);

    await tester.tap(
      find.byKey(const ValueKey('core-passive-node-attackHaste')),
    );
    await _pumpGameFrames(tester);
    final increase = find.byKey(const ValueKey('core-passive-rank-increase'));
    await tester.ensureVisible(increase);
    await _pumpGameFrames(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(increase);
      await _pumpGameFrames(tester);
    }
    await tester.tap(find.byKey(const ValueKey('core-passive-assign')));
    await _pumpGameFrames(tester);

    expect(game.assignedCorePassiveNode, CorePassiveNodeId.attackHaste);
    expect(game.assignedCorePassiveRank, 3);
  });

  testWidgets('locked core passive node keeps assign action disabled', (
    tester,
  ) async {
    final snapshots = ValueNotifier(
      _resultSnapshot(
        phase: GamePhase.preparation,
        currentStageNumber: 1,
        totalCorePoints: 20,
      ),
    );
    addTearDown(snapshots.dispose);
    final game = _CoreTreeGame(snapshots);
    await tester.pumpWidget(_coreTreeTestApp(game, snapshots));
    await _pumpGameFrames(tester);
    await tester.tap(find.text('패시브 트리'));
    await _pumpGameFrames(tester);

    await tester.tap(
      find.byKey(const ValueKey('core-passive-node-attackPrecompute')),
    );
    await _pumpGameFrames(tester);
    final assign = find.byKey(const ValueKey('core-passive-assign'));
    await tester.ensureVisible(assign);
    await _pumpGameFrames(tester);

    expect(tester.widget<FilledButton>(assign).onPressed, isNull);
    expect(find.text('연결된 노드를 강화하면 개방됩니다'), findsOneWidget);
  });

  testWidgets('rank three start node opens its connected node in the UI', (
    tester,
  ) async {
    final snapshots = ValueNotifier(
      _resultSnapshot(
        phase: GamePhase.preparation,
        currentStageNumber: 1,
        totalCorePoints: 20,
      ),
    );
    addTearDown(snapshots.dispose);
    final game = _CoreTreeGame(snapshots);
    await tester.pumpWidget(_coreTreeTestApp(game, snapshots));
    await _pumpGameFrames(tester);
    await tester.tap(find.text('패시브 트리'));
    await _pumpGameFrames(tester);

    final connectedNode = find.byKey(
      const ValueKey('core-passive-node-attackPrecompute'),
    );
    expect(
      find.descendant(
        of: connectedNode,
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('core-passive-node-attackHaste')),
    );
    await _pumpGameFrames(tester);
    final increase = find.byKey(const ValueKey('core-passive-rank-increase'));
    await tester.ensureVisible(increase);
    await _pumpGameFrames(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(increase);
      await _pumpGameFrames(tester);
    }
    await tester.tap(find.byKey(const ValueKey('core-passive-assign')));
    await _pumpGameFrames(tester);

    expect(
      snapshots.value.corePassiveNodeRanks[CorePassiveNodeId.attackHaste],
      3,
    );
    expect(
      find.descendant(
        of: connectedNode,
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsNothing,
    );
  });

  testWidgets('path-breaking core passive refund disables decrease action', (
    tester,
  ) async {
    const ranks = {
      CorePassiveNodeId.attackHaste: 3,
      CorePassiveNodeId.attackPrecompute: 1,
    };
    final snapshots = ValueNotifier(
      _resultSnapshot(
        phase: GamePhase.preparation,
        currentStageNumber: 1,
        totalCorePoints: 20,
        spentCorePoints: 5,
        availableCorePoints: 15,
        corePassiveNodeRanks: ranks,
      ),
    );
    addTearDown(snapshots.dispose);
    final game = _CoreTreeGame(snapshots);
    await tester.pumpWidget(_coreTreeTestApp(game, snapshots));
    await _pumpGameFrames(tester);
    await tester.tap(find.text('패시브 트리'));
    await _pumpGameFrames(tester);

    await tester.tap(
      find.byKey(const ValueKey('core-passive-node-attackHaste')),
    );
    await _pumpGameFrames(tester);
    final decrease = find.byKey(const ValueKey('core-passive-rank-decrease'));
    await tester.ensureVisible(decrease);
    await _pumpGameFrames(tester);
    final iconButton = find.descendant(
      of: decrease,
      matching: find.byType(IconButton),
    );

    expect(tester.widget<IconButton>(iconButton).onPressed, isNull);
    expect(snapshots.value.corePassiveNodeRanks, ranks);
  });

  testWidgets('confirmed core passive reset clears spent points', (
    tester,
  ) async {
    const ranks = {CorePassiveNodeId.attackHaste: 3};
    final snapshots = ValueNotifier(
      _resultSnapshot(
        phase: GamePhase.preparation,
        currentStageNumber: 1,
        totalCorePoints: 20,
        spentCorePoints: 4,
        availableCorePoints: 16,
        corePassiveNodeRanks: ranks,
      ),
    );
    addTearDown(snapshots.dispose);
    final game = _CoreTreeGame(snapshots);
    await tester.pumpWidget(_coreTreeTestApp(game, snapshots));
    await _pumpGameFrames(tester);
    await tester.tap(find.text('패시브 트리'));
    await _pumpGameFrames(tester);

    final reset = find.byKey(const ValueKey('core-passive-reset-all'));
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('패시브 트리를 초기화할까요?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('core-passive-reset-confirm')));
    await tester.pumpAndSettle();

    expect(snapshots.value.spentCorePoints, 0);
    expect(snapshots.value.availableCorePoints, 20);
    expect(snapshots.value.corePassiveNodeRanks, isEmpty);
    expect(find.text('사용 0'), findsOneWidget);
  });

  testWidgets('core passive tree details fit a 320px viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
            totalCorePoints: 20,
          ),
          selectedTab: MainMenuTab.core,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);
    await tester.tap(find.text('패시브 트리'));
    await _pumpGameFrames(tester);
    await tester.tap(
      find.byKey(const ValueKey('core-passive-node-attackHaste')),
    );
    await _pumpGameFrames(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('core-passive-node-details')),
    );
    await _pumpGameFrames(tester);

    expect(find.text('가속 회로'), findsOneWidget);
    expect(find.text('할당'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guardian beam core panel shows beam and saved total damage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF07111D),
          body: HudCoreInfoPanel(
            snapshot: _resultSnapshot(
              phase: GamePhase.preparation,
              currentStageNumber: 1,
              coreCombatSkill: CoreCombatSkill.guardianBeam,
              nexusCoreBeamDamage: 6.25,
              coreCombatSkillDirectDamageDealt: 12.5,
            ),
          ),
        ),
      ),
    );

    expect(find.text('광선 피해 6.25'), findsOneWidget);
    expect(find.text('총 피해 12.5'), findsOneWidget);
    expect(find.textContaining('현재 피해'), findsNothing);
  });

  testWidgets('rift mark core panel shows effect and saved bonus damage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF07111D),
          body: HudCoreInfoPanel(
            snapshot: _resultSnapshot(
              phase: GamePhase.preparation,
              currentStageNumber: 1,
              coreCombatSkill: CoreCombatSkill.riftMark,
              coreCombatSkillBonusDamageDealt: 7.25,
            ),
          ),
        ),
      ),
    );

    expect(find.text('현재 효과 +25%'), findsOneWidget);
    expect(find.text('총 추가 피해 7.25'), findsOneWidget);
  });

  testWidgets('stage cards fit on narrow menu width', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLoadedApp(tester);

    expect(find.text('스테이지'), findsOneWidget);
    expect(find.text('코어'), findsOneWidget);
    expect(find.text('강화'), findsOneWidget);
    expect(find.text('클리어 보상'), findsNothing);
    expect(find.text('스테이지 1 클리어 필요'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stage cards keep clear rewards icon-only until details', (
    tester,
  ) async {
    await _pumpLoadedApp(tester);

    expect(find.text('클리어 보상'), findsNothing);
    expect(find.text('저격+조준경'), findsNothing);
    expect(find.text('경제 강화'), findsNothing);
    expect(find.text('연구+코어'), findsNothing);
    expect(find.text('전투 강화'), findsNothing);
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

    expect(find.text('해금됨'), findsNothing);
    expect(find.text('경제 강화'), findsNothing);
    expect(find.text('연구+코어'), findsNothing);
    expect(find.text('저격+조준경'), findsNothing);
    expect(find.text('전투 강화'), findsNothing);
    expect(find.text('클리어 보상: 경제 강화'), findsNothing);
    expect(find.text('클리어 보상: 연구'), findsNothing);
    expect(find.text('클리어 보상: 전투 강화'), findsNothing);
  });

  testWidgets('stage details show actual unlock items', (tester) async {
    await _pumpLoadedApp(tester);

    expect(find.text('전술 명령'), findsNothing);
    expect(find.text('젬 감응'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('stage-selection-row-2')));
    await _pumpGameFrames(tester);

    expect(find.text('클리어 보상'), findsOneWidget);
    expect(find.text('전술 명령'), findsOneWidget);
    expect(find.text('젬 감응'), findsOneWidget);
    expect(find.text('연구 해금'), findsNothing);
  });

  testWidgets('stage gem unlocks use their dedicated gem icons', (
    tester,
  ) async {
    Future<void> pumpStageDetails({
      required int stageNumber,
      required Set<int> clearedStages,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey('stage-app-$stageNumber'),
          locale: const Locale('ko'),
          localizationsDelegates: const [
            RuneNexusLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: RuneNexusLocalizations.supportedLocales,
          home: MainMenuScreen(
            key: ValueKey('stage-menu-$stageNumber'),
            game: RuneNexusGame(),
            snapshot: _resultSnapshot(
              phase: GamePhase.preparation,
              currentStageNumber: stageNumber,
              unlockedStageCount: stageNumber,
              clearedStageNumbers: clearedStages,
            ),
            selectedTab: MainMenuTab.stage,
            onSelectTab: (_) {},
            onStartStage: (_) {},
          ),
        ),
      );
      await _pumpGameFrames(tester);
      final stageRow = find.byKey(ValueKey('stage-selection-row-$stageNumber'));
      await tester.ensureVisible(stageRow);
      await tester.tap(stageRow);
      await _pumpGameFrames(tester);
    }

    await pumpStageDetails(stageNumber: 3, clearedStages: const {1, 2});

    final stageThreeGemSection = find.byKey(
      const ValueKey('stage-unlock-section-gem'),
    );
    expect(
      find.descendant(
        of: stageThreeGemSection,
        matching: find.byWidgetPredicate(
          (widget) => widget is GemIcon && widget.type == GemType.aimSpeed,
        ),
      ),
      findsOneWidget,
    );

    await pumpStageDetails(
      stageNumber: 10,
      clearedStages: const {1, 2, 3, 4, 5, 6, 7, 8, 9},
    );

    final stageTenGemSection = find.byKey(
      const ValueKey('stage-unlock-section-gem'),
    );
    expect(
      find.descendant(
        of: stageTenGemSection,
        matching: find.byWidgetPredicate(
          (widget) => widget is GemIcon && widget.type == GemType.armorPiercing,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('stage twelve shows its research reward and unlock details', (
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
            currentStageNumber: 12,
            unlockedStageCount: 12,
            clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11},
          ),
          selectedTab: MainMenuTab.stage,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    final stageRow = find.byKey(const ValueKey('stage-selection-row-12'));
    expect(stageRow, findsOneWidget);
    expect(
      find.descendant(
        of: stageRow,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/stage_rewards/reward_research.png',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(stageRow);
    await _pumpGameFrames(tester);

    expect(find.text('포탑 화력 확장'), findsOneWidget);
    expect(find.text('처치 보너스 확장'), findsOneWidget);
    expect(find.text('정비 보급 확장'), findsOneWidget);
  });

  testWidgets('stage details group unlock rewards by system section', (
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
            unlockedStageCount: 5,
            clearedStageNumbers: const {1, 2, 3, 4},
          ),
          selectedTab: MainMenuTab.stage,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('stage-selection-row-5')),
    );
    await tester.tap(find.byKey(const ValueKey('stage-selection-row-5')));
    await _pumpGameFrames(tester);

    final researchSection = find.byKey(
      const ValueKey('stage-unlock-section-research'),
    );
    final coreSection = find.byKey(const ValueKey('stage-unlock-section-core'));

    expect(researchSection, findsOneWidget);
    expect(coreSection, findsOneWidget);
    expect(
      find.descendant(of: researchSection, matching: find.text('연구')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: researchSection, matching: find.text('링크 확장 I')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: researchSection, matching: find.text('결정 회수')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: coreSection, matching: find.text('코어')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: coreSection, matching: find.text('균열 낙인')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: coreSection,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CoreAbilityIcon &&
              widget.skill == CoreCombatSkill.riftMark,
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(researchSection).dy,
      lessThan(tester.getTopLeft(coreSection).dy),
    );
  });

  testWidgets('active stage details only offer continue action', (
    tester,
  ) async {
    int? continuedStage;
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
            hasStageProgress: true,
            completedRounds: 8,
          ),
          selectedTab: MainMenuTab.stage,
          onSelectTab: (_) {},
          onStartStage: (stage) {
            continuedStage = stage;
          },
        ),
      ),
    );
    await _pumpGameFrames(tester);

    await _tapStageCard(tester, '스테이지 1');
    await _pumpGameFrames(tester);

    expect(find.text('이어서 진행'), findsWidgets);
    expect(find.text('처음부터 시작'), findsNothing);

    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('이어서 진행')),
    );
    await _pumpGameFrames(tester);

    expect(continuedStage, 1);
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
    expect(find.text('챕터 3 · 11-15'), findsOneWidget);

    await tester.ensureVisible(find.text('Export 표시'));
    await tester.tap(find.text('Export 표시'));
    await _pumpGameFrames(tester);

    expect(
      find.textContaining('tileTheme: chapterTwoRiftTileTheme'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('챕터 3 · 11-15'));
    await tester.tap(find.text('챕터 3 · 11-15'));
    await _pumpGameFrames(tester);

    expect(_stageChipText('11'), findsOneWidget);
    expect(_stageChipText('15'), findsOneWidget);

    await tester.ensureVisible(find.text('Export 표시'));
    await tester.tap(find.text('Export 표시'));
    await _pumpGameFrames(tester);

    expect(
      find.textContaining('tileTheme: chapterThreeForgeTileTheme'),
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

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('menu-resource-title')))
          .data,
      '업그레이드',
    );
    expect(find.text('레벨업'), findsNWidgets(2));
    expect((nexusHpTopLeft.dy - fireTrainingTopLeft.dy).abs(), lessThan(4));
    expect(fireTrainingTopLeft.dx, greaterThan(nexusHpTopLeft.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('maxed permanent upgrade labels are centered in buttons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
            nexusHpUpgradeLevel: RunProgression.maxNexusHpUpgradeLevel,
            fireTrainingUpgradeLevel:
                RunProgression.maxFireTrainingUpgradeLevel,
            fireTrainingDamageBonusRate:
                RunProgression.maxFireTrainingUpgradeLevel *
                RunProgression.fireTrainingDamagePerUpgradeLevel,
          ),
          selectedTab: MainMenuTab.permanentUpgrades,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    final maxLabels = find.text('최대 레벨');
    expect(maxLabels, findsNWidgets(2));
    final upgradeIcons = tester.widgetList<UpgradeIcon>(
      find.byType(UpgradeIcon),
    );
    expect(upgradeIcons, hasLength(2));
    expect(upgradeIcons.every((icon) => icon.color == null), isTrue);

    for (var index = 0; index < 2; index++) {
      final label = maxLabels.at(index);
      final button = find.ancestor(
        of: label,
        matching: find.byType(GameButton),
      );
      final labelRect = tester.getRect(label);
      final buttonRect = tester.getRect(button);

      expect((labelRect.center.dx - buttonRect.center.dx).abs(), lessThan(1));
      expect((labelRect.center.dy - buttonRect.center.dy).abs(), lessThan(1));
    }
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

    final researchContent = find.byKey(const ValueKey('research-content'));
    expect(researchContent, findsOneWidget);
    expect(find.byKey(const ValueKey('main-menu-content-panel')), findsNothing);
    expect(tester.getSize(researchContent).width, greaterThanOrEqualTo(338));

    final efficiencyTopLeft = tester.getTopLeft(find.text('연구 효율'));
    final costEfficiencyTopLeft = tester.getTopLeft(find.text('연구 비용 효율'));
    final efficiencyCard = find.byKey(
      const ValueKey('research-tile-researchEfficiency'),
    );
    expect(efficiencyCard, findsOneWidget);

    final efficiencyEffect = find.descendant(
      of: efficiencyCard,
      matching: find.textContaining('연구 효율 +0% -> +5%', findRichText: true),
    );
    expect(efficiencyEffect, findsOneWidget);
    expect(
      find.textContaining('비용 효율 +0% -> +5%', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('미해금 연구'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
    expect(find.text('Lv.0/1'), findsNWidgets(2));
    expect(tester.getSize(find.byType(ResearchIcon).first), const Size(32, 32));
    final efficiencyLevelText = find.descendant(
      of: efficiencyCard,
      matching: find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data?.startsWith('Lv.') ?? false),
      ),
    );
    expect(efficiencyLevelText, findsOneWidget);
    final efficiencyMetaTopLeft = tester.getTopLeft(efficiencyLevelText);
    final efficiencyEffectTopLeft = tester.getTopLeft(efficiencyEffect);
    final efficiencyDurationIcon = find.descendant(
      of: efficiencyCard,
      matching: find.byIcon(Icons.schedule),
    );
    expect(efficiencyDurationIcon, findsOneWidget);
    final efficiencyDurationTopLeft = tester.getTopLeft(efficiencyDurationIcon);
    expect(efficiencyMetaTopLeft.dy, lessThan(efficiencyEffectTopLeft.dy));
    expect(efficiencyEffectTopLeft.dy, lessThan(efficiencyDurationTopLeft.dy));
    expect(efficiencyEffectTopLeft.dx, lessThan(efficiencyTopLeft.dx));
    expect(
      find.descendant(
        of: efficiencyCard,
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: efficiencyCard,
        matching: find.byIcon(Icons.open_in_new),
      ),
      findsNothing,
    );
    expect(
      (efficiencyTopLeft.dy - costEfficiencyTopLeft.dy).abs(),
      lessThan(4),
    );
    expect(costEfficiencyTopLeft.dx, greaterThan(efficiencyTopLeft.dx));
    for (final title in ['포탑 화력 확장', '처치 보너스 확장', '정비 보급 확장']) {
      final titleFinder = find.text(title);
      expect(titleFinder, findsOneWidget);
      expect(
        tester.getSize(titleFinder).height,
        lessThan(20),
        reason: '$title should stay on one line',
      );
    }

    await tester.tap(efficiencyCard);
    await _pumpGameFrames(tester);

    final researchDialog = find.byType(Dialog);
    expect(researchDialog, findsOneWidget);
    expect(
      find.descendant(
        of: researchDialog,
        matching: find.byType(RuneCurrencyIcon),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('research tab separates unlocked locked and completed sections', (
    tester,
  ) async {
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
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
            clearedStageNumbers: const {1, 2},
            researchLevels: const {ResearchType.turretTargetPriority: 1},
            activeResearches: [
              ResearchProgress(
                type: ResearchType.gemAttunement,
                targetLevel: 1,
                startedAtMillis: nowMillis,
                durationMillis: 61000,
              ),
            ],
          ),
          selectedTab: MainMenuTab.research,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(find.text('시작 가능 연구'), findsOneWidget);
    expect(find.text('아직 해금되지 않음'), findsOneWidget);
    expect(find.text('완료된 연구'), findsOneWidget);

    final availableTop = tester.getTopLeft(find.text('시작 가능 연구'));
    final lockedTop = tester.getTopLeft(find.text('아직 해금되지 않음'));
    final completedTop = tester.getTopLeft(find.text('완료된 연구'));
    final gemAttunementTop = tester.getTopLeft(find.text('젬 감응'));
    final linkExpansionTop = tester.getTopLeft(find.text('링크 확장 I'));
    final tacticalCommandTop = tester.getTopLeft(find.text('전술 명령'));

    expect(gemAttunementTop.dy, greaterThan(availableTop.dy));
    expect(gemAttunementTop.dy, lessThan(lockedTop.dy));
    expect(linkExpansionTop.dy, greaterThan(lockedTop.dy));
    expect(linkExpansionTop.dy, lessThan(completedTop.dy));
    expect(tacticalCommandTop.dy, greaterThan(completedTop.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('kill reward is hidden before stage one clear', (tester) async {
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

    await tester.tap(find.byTooltip('경제'));
    await _pumpGameFrames(tester);

    expect(find.text('처치 보상'), findsNothing);
    expect(find.text('미해금 업그레이드'), findsNothing);
    expect(find.text('아직 사용할 수 없음'), findsNothing);
    expect(find.text('Lv.3/10'), findsNothing);
  });

  testWidgets('emergency sale is hidden before stage one clear', (
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

    await tester.tap(find.byTooltip('경제'));
    await _pumpGameFrames(tester);

    expect(find.text('긴급 매각'), findsNothing);
    expect(find.text('미해금 업그레이드'), findsNothing);
    expect(find.text('아직 사용할 수 없음'), findsNothing);
    expect(find.text('Lv.3/5'), findsNothing);
  });

  testWidgets('emergency sale shows refund percent after stage one clear', (
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
            clearedStageNumbers: const {1},
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

    await tester.tap(find.byTooltip('경제'));
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

  testWidgets('family damage upgrades are hidden before stage seven clear', (
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
            runes: 1000,
            clearedStageNumbers: const {1, 2, 3, 4, 5, 6},
            physicalDamageTrainingUpgradeLevel: 15,
            physicalDamageTrainingBonusRate: 0.30,
            elementalDamageTrainingUpgradeLevel: 15,
            elementalDamageTrainingBonusRate: 0.30,
          ),
          selectedTab: MainMenuTab.permanentUpgrades,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(find.text('물리 화력 훈련'), findsNothing);
    expect(find.text('원소 화력 훈련'), findsNothing);
  });

  testWidgets('family damage upgrades unlock after stage seven clear', (
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
            runes: 1000,
            clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7},
            physicalDamageTrainingUpgradeLevel: 15,
            physicalDamageTrainingBonusRate: 0.30,
            elementalDamageTrainingUpgradeLevel: 15,
            elementalDamageTrainingBonusRate: 0.30,
          ),
          selectedTab: MainMenuTab.permanentUpgrades,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(find.text('물리 화력 훈련'), findsOneWidget);
    expect(find.text('원소 화력 훈련'), findsOneWidget);
    expect(find.text('현재 +30.0%'), findsNWidgets(2));
    expect(find.text('다음 +32.0%'), findsNWidgets(2));
  });

  testWidgets('result overlay summarizes rewards and unlocks', (tester) async {
    var openedStageSelect = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ResultOverlay(
          game: RuneNexusGame(),
          snapshot: _resultSnapshot(
            phase: GamePhase.success,
            currentStageNumber: 1,
            unlockedStageCount: 2,
            completedRounds: 40,
            runes: 140,
            lastRunRuneReward: 140,
            lastRunCorePointReward: 1,
            lastRunPreviousBestRound: 20,
            lastRunWasNewBestRound: true,
            lastRunUnlockedStageNumber: 2,
            lastRunUnlockedSniperTurret: true,
            bestRoundsByStage: const {1: 40},
            clearedStageNumbers: const {1},
          ),
          onOpenStageSelect: () {
            openedStageSelect = true;
          },
          onOpenPermanentUpgrades: () {},
          onStartStage: (_) {},
        ),
      ),
    );

    expect(find.text('Nexus 방어 성공'), findsOneWidget);
    expect(find.text('스테이지 1 클리어'), findsOneWidget);
    expect(find.text('보상 획득'), findsOneWidget);
    expect(find.text('+140 룬'), findsOneWidget);
    expect(find.text('+1 코어 포인트'), findsOneWidget);
    expect(find.text('강화 2개 해금'), findsOneWidget);
    expect(find.text('전투 기록'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
    expect(find.text('20R → 40R'), findsOneWidget);
    expect(find.text('해금 항목'), findsOneWidget);
    expect(find.text('강화'), findsOneWidget);
    expect(find.text('처치 보상'), findsOneWidget);
    expect(find.text('긴급 매각'), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);
    expect(find.text('다시 시작'), findsOneWidget);
    expect(find.text('스테이지 2 시작'), findsNothing);
    expect(find.text('현재 스테이지 재도전'), findsNothing);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -160),
    );
    await tester.pump();
    await tester.tap(find.text('확인'));

    expect(openedStageSelect, isTrue);
  });

  testWidgets('result overlay shows stage three precision unlocks', (
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
        home: ResultOverlay(
          game: RuneNexusGame(),
          snapshot: _resultSnapshot(
            phase: GamePhase.success,
            currentStageNumber: 3,
            unlockedStageCount: 4,
            completedRounds: 40,
            runes: 220,
            lastRunRuneReward: 220,
            lastRunPreviousBestRound: 18,
            lastRunWasNewBestRound: true,
            lastRunUnlockedStageNumber: 4,
            lastRunUnlockedSniperTurret: true,
            bestRoundsByStage: const {3: 40},
            clearedStageNumbers: const {1, 2, 3},
          ),
          onOpenStageSelect: () {},
          onOpenPermanentUpgrades: () {},
          onStartStage: (_) {},
        ),
      ),
    );

    expect(find.text('포탑 1개 · 젬 1개 해금'), findsOneWidget);
    expect(find.text('해금 항목'), findsOneWidget);
    expect(find.text('포탑'), findsOneWidget);
    expect(find.text('저격 포탑'), findsOneWidget);
    expect(find.text('젬'), findsOneWidget);
    expect(find.text('조준경 젬'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('result-core-point-reward')),
      findsNothing,
    );
  });

  testWidgets('result overlay shows stage five chapter two unlocks', (
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
        home: ResultOverlay(
          game: RuneNexusGame(),
          snapshot: _resultSnapshot(
            phase: GamePhase.success,
            currentStageNumber: 5,
            unlockedStageCount: 6,
            completedRounds: 40,
            runes: 420,
            lastRunRuneReward: 420,
            lastRunPreviousBestRound: 32,
            lastRunWasNewBestRound: true,
            lastRunUnlockedStageNumber: 6,
            bestRoundsByStage: const {5: 40},
            clearedStageNumbers: const {1, 2, 3, 4, 5},
          ),
          onOpenStageSelect: () {},
          onOpenPermanentUpgrades: () {},
          onStartStage: (_) {},
        ),
      ),
    );

    expect(find.text('연구 2개 · 코어 1개 해금'), findsOneWidget);
    expect(find.text('해금 항목'), findsOneWidget);
    expect(find.text('연구'), findsOneWidget);
    expect(find.text('링크 확장 I'), findsOneWidget);
    expect(find.text('결정 회수'), findsOneWidget);
    expect(find.text('코어'), findsOneWidget);
    expect(find.text('균열 낙인'), findsOneWidget);
  });

  testWidgets('result overlay shows stage seven family damage unlocks', (
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
        home: ResultOverlay(
          game: RuneNexusGame(),
          snapshot: _resultSnapshot(
            phase: GamePhase.success,
            currentStageNumber: 7,
            unlockedStageCount: 8,
            completedRounds: 40,
            runes: 590,
            lastRunRuneReward: 590,
            lastRunPreviousBestRound: 30,
            lastRunWasNewBestRound: true,
            lastRunUnlockedStageNumber: 8,
            bestRoundsByStage: const {7: 40},
            clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7},
          ),
          onOpenStageSelect: () {},
          onOpenPermanentUpgrades: () {},
          onStartStage: (_) {},
        ),
      ),
    );

    expect(find.text('강화 2개 해금'), findsOneWidget);
    expect(find.text('해금 항목'), findsOneWidget);
    expect(find.text('강화'), findsOneWidget);
    expect(find.text('물리 화력 훈련'), findsOneWidget);
    expect(find.text('원소 화력 훈련'), findsOneWidget);
  });

  testWidgets('result overlay shows stage eight rune resonance unlock', (
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
        home: ResultOverlay(
          game: RuneNexusGame(),
          snapshot: _resultSnapshot(
            phase: GamePhase.success,
            currentStageNumber: 8,
            unlockedStageCount: 9,
            completedRounds: 40,
            runes: 690,
            lastRunRuneReward: 690,
            lastRunPreviousBestRound: 30,
            lastRunWasNewBestRound: true,
            lastRunUnlockedStageNumber: 9,
            bestRoundsByStage: const {8: 40},
            clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8},
          ),
          onOpenStageSelect: () {},
          onOpenPermanentUpgrades: () {},
          onStartStage: (_) {},
        ),
      ),
    );

    expect(find.text('연구 2개 해금'), findsOneWidget);
    expect(find.text('해금 항목'), findsOneWidget);
    expect(find.text('연구'), findsOneWidget);
    expect(find.text('룬 공명'), findsOneWidget);
    expect(find.text('전투 투자 최적화'), findsOneWidget);
  });

  testWidgets('result overlay shows stage ten research slot purchase access', (
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
        home: ResultOverlay(
          game: RuneNexusGame(),
          snapshot: _resultSnapshot(
            phase: GamePhase.success,
            currentStageNumber: 10,
            unlockedStageCount: 11,
            completedRounds: 40,
            runes: 850,
            lastRunRuneReward: 850,
            lastRunPreviousBestRound: 30,
            lastRunWasNewBestRound: true,
            lastRunUnlockedStageNumber: 11,
            bestRoundsByStage: const {10: 40},
            clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
          ),
          onOpenStageSelect: () {},
          onOpenPermanentUpgrades: () {},
          onStartStage: (_) {},
        ),
      ),
    );

    expect(find.text('젬 1개 · 연구 1개 해금'), findsOneWidget);
    expect(find.text('장갑 관통 젬'), findsOneWidget);
    expect(find.text('연구 슬롯 II 구매 권한'), findsOneWidget);
  });

  testWidgets('result overlay shows stage twelve limit research unlocks', (
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
        home: ResultOverlay(
          game: RuneNexusGame(),
          snapshot: _resultSnapshot(
            phase: GamePhase.success,
            currentStageNumber: 12,
            unlockedStageCount: 13,
            completedRounds: 40,
            runes: 1000,
            lastRunRuneReward: 1000,
            lastRunPreviousBestRound: 30,
            lastRunWasNewBestRound: true,
            lastRunUnlockedStageNumber: 13,
            bestRoundsByStage: const {12: 40},
            clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12},
          ),
          onOpenStageSelect: () {},
          onOpenPermanentUpgrades: () {},
          onStartStage: (_) {},
        ),
      ),
    );

    expect(find.text('연구 3개 해금'), findsOneWidget);
    expect(find.text('포탑 화력 확장'), findsOneWidget);
    expect(find.text('처치 보너스 확장'), findsOneWidget);
    expect(find.text('정비 보급 확장'), findsOneWidget);
  });

  testWidgets('failed result keeps reward summary and retry action', (
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

    expect(find.text('Nexus 붕괴'), findsOneWidget);
    expect(find.text('스테이지 1 종료'), findsOneWidget);
    expect(find.text('+24 룬'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('result-core-point-reward')),
      findsNothing,
    );
    expect(find.text('도달 기록 기준 정산'), findsOneWidget);
    expect(find.text('최고 12R'), findsOneWidget);
    expect(find.text('해금 항목'), findsNothing);
    expect(find.text('스테이지 2 시작'), findsNothing);
    expect(find.text('확인'), findsOneWidget);
    expect(find.text('다시 시작'), findsOneWidget);
  });

  testWidgets('home button opens stage menu with end confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 854);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLoadedApp(tester);

    await _tapStageCard(tester, '스테이지 1');
    await _pumpUntilFound(tester, find.text('시작하기'));
    await tester.tap(find.text('시작하기'));
    await _pumpUntilFound(tester, find.text('시작'));
    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await _pumpGameFrames(tester);

    expect(find.text('스테이지 메뉴'), findsOneWidget);
    expect(find.text('메인화면으로 이동'), findsOneWidget);
    expect(find.text('종료 시 보상'), findsNothing);
    expect(find.text('+0 룬'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('스테이지 종료'));
    await _pumpGameFrames(tester);

    expect(find.text('정말 종료할까요?'), findsOneWidget);
    expect(find.text('종료 시 보상'), findsOneWidget);
    expect(find.text('0웨이브 기준'), findsOneWidget);
    expect(find.textContaining('+0 룬'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(RuneCurrencyIcon),
      ),
      findsWidgets,
    );
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
    await _pumpUntilFound(tester, find.text('시작하기'));
    await tester.tap(find.text('시작하기'));
    await _pumpUntilFound(tester, find.text('시작'));
    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await _pumpGameFrames(tester);
    await tester.tap(find.text('메인화면으로 이동'));
    await _pumpGameFrames(tester);

    expect(find.text('진행 중 · 스테이지 1'), findsNothing);
    expect(find.text('진행 중'), findsWidgets);
    expect(find.text('스테이지 1'), findsWidgets);
    expect(find.text('저장된 전투'), findsNothing);
    expect(find.text('이어서 진행'), findsOneWidget);

    await tester.tap(find.text('이어서 진행'));
    await _pumpGameFrames(tester);

    expect(find.text('저장된 진행 발견'), findsOneWidget);
    expect(find.text('이전 진행을 이어갈까요?'), findsOneWidget);
    expect(find.text('새로 시작'), findsNothing);
    expect(find.text('메인 메뉴'), findsOneWidget);
    expect(find.text('재개'), findsOneWidget);

    await tester.tap(find.text('메인 메뉴'));
    await _pumpGameFrames(tester);

    expect(find.text('저장된 진행 발견'), findsNothing);
    expect(find.text('저장된 전투'), findsNothing);
    expect(find.text('이어서 진행'), findsOneWidget);
  });

  testWidgets('active run can settle and switch to another stage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    game.debugSetClearedStageCount(1);

    await tester.pumpWidget(RuneNexusApp(game: game));
    await _pumpUntilFound(tester, find.text('Rune Nexus'));

    await _tapStageCard(tester, '스테이지 1');
    await _pumpUntilFound(tester, find.text('시작하기'));
    await tester.tap(find.text('시작하기'));
    await _pumpUntilFound(tester, find.text('시작'));
    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await _pumpGameFrames(tester);
    await tester.tap(find.text('메인화면으로 이동'));
    await _pumpGameFrames(tester);

    await tester.tap(find.byKey(const ValueKey('stage-selection-row-2')));
    await _pumpGameFrames(tester);
    await tester.tap(find.text('시작하기'));
    await _pumpGameFrames(tester);

    expect(find.text('진행 중인 스테이지 종료'), findsOneWidget);
    expect(find.text('현재 보상 0룬 정산 후 스테이지 2 시작'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(RuneCurrencyIcon),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('정산 후 시작'));
    await _pumpGameFrames(tester);

    expect(game.snapshotNotifier.value.currentStageNumber, 2);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

  testWidgets(
    'main menu return before first wave does not create restore flow',
    (tester) async {
      tester.view.physicalSize = const Size(411, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());

      await tester.pumpWidget(RuneNexusApp(game: game));
      await _pumpUntilFound(tester, find.text('Rune Nexus'));

      await _tapStageCard(tester, '스테이지 1');
      await _pumpGameFrames(tester);
      await tester.tap(find.text('시작하기'));
      await _pumpGameFrames(tester);
      expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
      expect(game.snapshotNotifier.value.hasStageProgress, isFalse);

      await tester.tap(find.byIcon(Icons.home_outlined));
      await _pumpGameFrames(tester);
      await tester.tap(find.text('메인화면으로 이동'));
      await _pumpGameFrames(tester);

      expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
      expect(game.snapshotNotifier.value.hasStageProgress, isFalse);
      expect(find.text('진행 중'), findsNothing);
      expect(find.text('저장된 전투'), findsNothing);
      expect(find.text('이어서 진행'), findsNothing);
      expect(find.text('스테이지 1'), findsWidgets);
    },
  );

  testWidgets('debug panel button is hidden by default', (tester) async {
    await _pumpLoadedApp(tester);

    await _tapStageCard(tester, '스테이지 1');
    await _pumpGameFrames(tester);

    expect(find.text('테스트 라운드'), findsNothing);
  });

  testWidgets('gem reward choices stay in one row on narrow combat width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    final snapshot = _resultSnapshot(
      phase: GamePhase.reward,
      currentStageNumber: 1,
      completedRounds: 1,
      gemShards: 12,
      rewardOptions: const [
        GemType.chain,
        GemType.heavyWeapon,
        GemType.attackSpeed,
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF07111D),
          body: HudRewardOverlay(game: game, snapshot: snapshot),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chainTop = tester.getTopLeft(find.text('연쇄')).dy;
    final heavyTop = tester.getTopLeft(find.text('중화기 증폭')).dy;
    final speedTop = tester.getTopLeft(find.text('가속')).dy;
    expect(heavyTop, closeTo(chainTop, 0.1));
    expect(speedTop, closeTo(chainTop, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('combat HUD shows total turret DPS under the home button', (
    tester,
  ) async {
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

    expect(find.byTooltip('배치 포탑 전체 DPS'), findsOneWidget);
    expect(find.text('전투력'), findsOneWidget);

    game.tryBuildTurret(const GridPoint(2, 0));
    await _pumpGameFrames(tester);

    expect(game.snapshotNotifier.value.totalTurretDps, closeTo(15.89, 0.001));
    expect(find.text('15.9'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('core tile selection shows combat skill contribution in HUD', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
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
    game.debugSetClearedStageCount(5);
    expect(game.equipCoreCombatSkill(CoreCombatSkill.riftMark), isTrue);
    game.restartRun();
    await _pumpGameFrames(tester);

    await tester.tapAt(const Offset(305, 474));
    await _pumpGameFrames(tester);

    expect(
      game.snapshotNotifier.value.selectedCorePoint,
      const GridPoint(6, 9),
    );
    expect(
      game.snapshotNotifier.value.selectedRunPanelTab,
      RunPanelTab.turrets,
    );
    expect(find.text('넥서스 코어'), findsOneWidget);
    expect(find.text('내구도'), findsOneWidget);
    expect(find.text('전투 스킬'), findsOneWidget);
    expect(find.text('균열 낙인'), findsOneWidget);
    expect(find.text('내구도 높은 적 4명에게 받는 피해 25% 증가 낙인 부여'), findsOneWidget);
    expect(find.text('코어'), findsNothing);
    expect(find.text('패시브 트리'), findsOneWidget);
    expect(find.text('0 / 0pt'), findsOneWidget);
    expect(find.text('현재 효과 +25%'), findsOneWidget);
    expect(find.text('총 추가 피해 0.00'), findsOneWidget);
    expect(find.text('발동 0회'), findsNothing);
    expect(find.text('포탈 1'), findsNothing);
    expect(tester.takeException(), isNull);
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

      await tester.tap(
        find.byKey(const ValueKey('turret-target-priority-selector')),
      );
      await _pumpGameFrames(tester);

      expect(find.text('후방 적'), findsOneWidget);
      expect(find.text('강한 적'), findsOneWidget);
      expect(find.text('약한 적'), findsOneWidget);
      expect(find.text('가까운 적'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await _pumpGameFrames(tester);
      expect(
        find.byKey(const ValueKey('turret-target-priority-selector')),
        findsOneWidget,
      );
      await tester.tap(find.text('젬 · 링크'));
      await _pumpGameFrames(tester);

      expect(
        find.byKey(const ValueKey('turret-target-priority-selector')),
        findsNothing,
      );
      expect(find.text('공격 명령'), findsNothing);
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
    for (
      var level = game.snapshotNotifier.value.selectedTurretLevel;
      level < 3;
      level++
    ) {
      game.levelUpSelectedTurret();
    }
    expect(game.snapshotNotifier.value.selectedTurretLevel, 3);
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

    expect(find.text('제압 사격'), findsOneWidget);
    expect(find.text('연쇄 소탕'), findsOneWidget);
    expect(find.text('1차 특성 선택 후 후보 카드가 열립니다.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trait dialog previews first tap and confirms second tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = MemorySaveRepository()
      ..data = _saveWithResearch(
        clearedStageNumbers: const {},
        researchLevels: const {},
        gold: 1000,
        gemShards: RuneNexusGame.primaryTraitCost,
        roundIndex: 1,
        mapSignature: const GameSaveAdapter().mapSignature(gameMap),
      );
    final game = RuneNexusGame(saveRepository: repository);

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
    for (
      var level = game.snapshotNotifier.value.selectedTurretLevel;
      level < 3;
      level++
    ) {
      game.levelUpSelectedTurret();
    }
    expect(game.snapshotNotifier.value.selectedTurretLevel, 3);
    await _pumpGameFrames(tester);

    await tester.tap(find.byTooltip('특성'));
    await _pumpGameFrames(tester);
    await tester.tap(find.text('과열 탄창'));
    await _pumpGameFrames(tester);

    expect(find.text('선택'), findsOneWidget);
    expect(find.text('기관총 특성'), findsOneWidget);
    expect(game.snapshotNotifier.value.selectedTurretPrimaryTrait, isNull);
    expect(
      game.snapshotNotifier.value.gemShards,
      RuneNexusGame.primaryTraitCost,
    );

    await tester.tap(find.text('과열 탄창'));
    await _pumpGameFrames(tester);

    expect(
      game.snapshotNotifier.value.selectedTurretPrimaryTrait,
      TurretTraitType.overheatMagazine,
    );
    expect(game.snapshotNotifier.value.gemShards, 0);
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

  testWidgets('active research slot shows diamond instant completion', (
    tester,
  ) async {
    final game = _ResearchInstantCompleteGame();
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
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
            diamonds: 2,
            activeResearches: [
              ResearchProgress(
                type: ResearchType.gemAttunement,
                targetLevel: 1,
                startedAtMillis: nowMillis,
                durationMillis: 61000,
              ),
            ],
          ),
          selectedTab: MainMenuTab.research,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(find.text('즉시 완료'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('즉시 완료 · 다이아 2'), findsNothing);
    expect(find.text('다이아 2'), findsNothing);
    expect(find.text('0시간 1분 1초'), findsOneWidget);

    final remainingRect = tester.getRect(find.text('0시간 1분 1초'));
    final instantCompleteRect = tester.getRect(find.text('즉시 완료'));
    final instantCompleteButtonRect = tester.getRect(
      find.byKey(const ValueKey('research-instant-complete-button')),
    );
    final instantCompleteCostRect = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('research-instant-complete-button')),
        matching: find.text('2'),
      ),
    );
    expect(instantCompleteRect.left, greaterThan(remainingRect.right));
    expect(instantCompleteButtonRect.width, 104);
    expect(
      (instantCompleteRect.left + instantCompleteCostRect.right) / 2,
      closeTo(instantCompleteButtonRect.center.dx, 3),
    );

    await tester.tap(find.text('즉시 완료'));
    await _pumpGameFrames(tester);

    expect(game.completedResearchType, isNull);
    expect(find.text('연구를 즉시 완료할까요?'), findsOneWidget);
    expect(find.text('젬 감응 연구를 다이아 2로 즉시 완료합니다.'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(GameButton, '즉시 완료'),
      ),
    );
    await _pumpGameFrames(tester);

    expect(game.completedResearchType, ResearchType.gemAttunement);
  });

  testWidgets('empty research slot does not show instant completion', (
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
            diamonds: 10,
          ),
          selectedTab: MainMenuTab.research,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(find.text('빈 연구 슬롯'), findsOneWidget);
    expect(find.text('즉시 완료'), findsNothing);
  });

  testWidgets('second research slot previews its stage ten requirement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
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
            currentStageNumber: 8,
            diamonds: RunProgression.researchSlotTwoUnlockCost,
            clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8},
          ),
          selectedTab: MainMenuTab.research,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(
      find.byKey(const ValueKey('research-slot-two-locked-card')),
      findsOneWidget,
    );
    expect(find.text('연구 슬롯 II'), findsOneWidget);
    expect(find.text('스테이지 10 클리어 후 구매 가능'), findsOneWidget);
    final button = tester.widget<GameButton>(
      find.byKey(const ValueKey('research-slot-two-unlock-button')),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stage ten can purchase the second research slot permanently', (
    tester,
  ) async {
    final game = _ResearchSlotUnlockGame();
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
            currentStageNumber: 11,
            diamonds: RunProgression.researchSlotTwoUnlockCost,
            clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
          ),
          selectedTab: MainMenuTab.research,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(find.text('두 연구를 동시에 진행할 수 있습니다.'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('research-slot-two-unlock-button')),
    );
    await _pumpGameFrames(tester);

    expect(
      find.byKey(const ValueKey('research-slot-two-unlock-dialog')),
      findsOneWidget,
    );
    expect(find.text('연구 슬롯 II 해금'), findsOneWidget);
    expect(
      find.text('다이아 600개로 두 번째 연구 슬롯을 영구 개방합니다. 개방 후 두 연구를 동시에 진행할 수 있습니다.'),
      findsOneWidget,
    );
    expect(find.text('보유 다이아'), findsOneWidget);
    expect(find.text('소모 다이아'), findsOneWidget);
    expect(find.text('구매 후 잔액'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('research-slot-two-unlock-confirm')),
    );
    await _pumpGameFrames(tester);

    expect(game.unlockedResearchSlotTwo, isTrue);
  });
}

Widget _coreTreeTestApp(
  RuneNexusGame game,
  ValueListenable<GameSnapshot> snapshots,
) {
  return MaterialApp(
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
      snapshot: snapshots.value,
      snapshotListenable: snapshots,
      selectedTab: MainMenuTab.core,
      onSelectTab: (_) {},
      onStartStage: (_) {},
    ),
  );
}

Future<void> _pumpLoadedApp(WidgetTester tester) async {
  await tester.pumpWidget(
    RuneNexusApp(game: RuneNexusGame(saveRepository: MemorySaveRepository())),
  );
  await _pumpUntilFound(tester, find.text('Rune Nexus'));
}

Offset _tabLeadingEdge(WidgetTester tester, String key) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  return Offset(rect.left + 8, rect.center.dy);
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
  final row = find.byKey(ValueKey('stage-selection-row-$stageNumber'));
  if (row.evaluate().isNotEmpty) {
    await tester.tap(row);
  } else {
    await tester.tap(find.text(stageName).first);
  }
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
  bool hasStageProgress = false,
  int completedRounds = 0,
  int runes = 0,
  int diamonds = 0,
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
  int nexusHpUpgradeLevel = 0,
  int fireTrainingUpgradeLevel = 0,
  double fireTrainingDamageBonusRate = 0,
  int physicalDamageTrainingUpgradeLevel = 0,
  double physicalDamageTrainingBonusRate = 0,
  int elementalDamageTrainingUpgradeLevel = 0,
  double elementalDamageTrainingBonusRate = 0,
  int emergencySaleUpgradeLevel = 0,
  int emergencySaleUpgradeCost = 80,
  bool canUpgradeEmergencySale = false,
  int turretRefundPercent = 75,
  List<ResearchProgress> activeResearches = const [],
  Map<ResearchType, int> researchLevels = const {},
  bool researchSlotTwoUnlocked = false,
  CoreCombatSkill? coreCombatSkill = CoreCombatSkill.guardianBeam,
  int totalCorePoints = 0,
  int spentCorePoints = 0,
  int availableCorePoints = 0,
  int lastRunCorePointReward = 0,
  Map<CorePassiveNodeId, int> corePassiveNodeRanks = const {},
  GridPoint? selectedCorePoint,
  double nexusCoreBeamDamage = 0,
  double coreCombatSkillDirectDamageDealt = 0,
  double coreCombatSkillBonusDamageDealt = 0,
  int coreCombatSkillActivationCount = 0,
  int turretModuleTickets = 0,
  List<TurretModuleInventoryItem> ownedTurretModules = const [],
  int gemShards = 0,
  List<GemType> rewardOptions = const [],
  Map<GemType, int> gemCollection = const {},
}) {
  return GameSnapshot(
    gold: 0,
    gemShards: gemShards,
    nexusHp: 0,
    maxNexusHp: 20,
    round: completedRounds,
    maxRound: 40,
    phase: phase,
    restoredPhase: null,
    hasStageProgress: hasStageProgress,
    placedTurretCount: 0,
    currentStageNumber: currentStageNumber,
    unlockedStageCount: unlockedStageCount,
    bestRoundsByStage: bestRoundsByStage,
    clearedStageNumbers: clearedStageNumbers,
    availableTurretTypes: [
      TurretType.arrow,
      TurretType.cannon,
      TurretType.magic,
      TurretType.frost,
      if (clearedStageNumbers.contains(3)) TurretType.sniper,
      if (clearedStageNumbers.contains(6)) TurretType.lightning,
    ],
    selectedTurretType: TurretType.arrow,
    selectedRunPanelTab: RunPanelTab.turrets,
    previewText: '',
    rewardOptions: rewardOptions,
    isPurchasedGemReward: false,
    gemInventory: const {},
    gemCollection: gemCollection,
    selectedBuildPoint: null,
    selectedBuildTurretType: null,
    selectedPortalPoint: null,
    selectedCorePoint: selectedCorePoint,
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
    selectedTurretCriticalChance: 0,
    selectedTurretCriticalDamageMultiplier: 1.5,
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
    totalTurretDps: 0,
    nexusCoreBeamIntervalSeconds: 5,
    nexusCoreBeamCooldownSeconds: 5,
    nexusCoreBeamAvailable: true,
    nexusCoreBeamActive: false,
    nexusCoreBeamDamage: nexusCoreBeamDamage,
    coreCombatSkillDirectDamageDealt: coreCombatSkillDirectDamageDealt,
    coreCombatSkillBonusDamageDealt: coreCombatSkillBonusDamageDealt,
    coreCombatSkillActivationCount: coreCombatSkillActivationCount,
    coreCombatSkill: coreCombatSkill,
    totalCorePoints: totalCorePoints,
    spentCorePoints: spentCorePoints,
    availableCorePoints: availableCorePoints == 0 && totalCorePoints > 0
        ? totalCorePoints - spentCorePoints
        : availableCorePoints,
    lastRunCorePointReward: lastRunCorePointReward,
    corePassiveNodeRanks: corePassiveNodeRanks,
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
    diamonds: diamonds,
    turretModuleTickets: turretModuleTickets,
    ownedTurretModules: ownedTurretModules,
    dailyQuestDayKey: RunProgression.uninitializedDailyQuestDayKey,
    dailyQuestProgress: const {},
    claimedDailyQuestRewards: const {},
    completedDailyQuestCount: 0,
    dailyAttendanceRewardClaimed: false,
    dailyQuestAllCompleteClaimed: false,
    dailyQuestClockRollbackDetected: false,
    weeklyQuestWeekKey: RunProgression.uninitializedWeeklyQuestWeekKey,
    weeklyQuestProgress: const {},
    claimedWeeklyQuestRewards: const {},
    completedWeeklyQuestCount: 0,
    weeklyQuestAllCompleteClaimed: false,
    weeklyAttendanceDays: 0,
    weeklyAttendanceRewardClaimed: false,
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
    nexusHpUpgradeLevel: nexusHpUpgradeLevel,
    nexusHpUpgradeCost: 14,
    canUpgradeNexusHp: false,
    supplyUpgradeLevel: 0,
    supplyUpgradeCost: 7,
    canUpgradeSupply: false,
    waveClearGoldProgressionBonus: 0,
    fireTrainingUpgradeLevel: fireTrainingUpgradeLevel,
    fireTrainingUpgradeCost: 7,
    canUpgradeFireTraining: false,
    fireTrainingDamageBonusRate: fireTrainingDamageBonusRate,
    physicalDamageTrainingUpgradeLevel: physicalDamageTrainingUpgradeLevel,
    physicalDamageTrainingUpgradeCost:
        RunProgression.familyDamageTrainingUpgradeBaseCost,
    canUpgradePhysicalDamageTraining: false,
    physicalDamageTrainingBonusRate: physicalDamageTrainingBonusRate,
    elementalDamageTrainingUpgradeLevel: elementalDamageTrainingUpgradeLevel,
    elementalDamageTrainingUpgradeCost:
        RunProgression.familyDamageTrainingUpgradeBaseCost,
    canUpgradeElementalDamageTraining: false,
    elementalDamageTrainingBonusRate: elementalDamageTrainingBonusRate,
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
    researchSlotCount: researchSlotTwoUnlocked ? 2 : 1,
    researchLevels: researchLevels,
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

class _ResearchInstantCompleteGame extends RuneNexusGame {
  _ResearchInstantCompleteGame()
    : super(saveRepository: MemorySaveRepository());

  ResearchType? completedResearchType;

  @override
  void completeResearchWithDiamonds(ResearchType type) {
    completedResearchType = type;
  }
}

class _ResearchSlotUnlockGame extends RuneNexusGame {
  _ResearchSlotUnlockGame() : super(saveRepository: MemorySaveRepository());

  bool unlockedResearchSlotTwo = false;

  @override
  bool unlockResearchSlotTwo() {
    unlockedResearchSlotTwo = true;
    return true;
  }
}

class _CoreEquipGame extends RuneNexusGame {
  _CoreEquipGame() : super(saveRepository: MemorySaveRepository());

  CoreCombatSkill? equippedCombatSkill;
  bool unequippedCombatSkill = false;
  CorePassiveNodeId? assignedCorePassiveNode;
  int? assignedCorePassiveRank;

  @override
  bool equipCoreCombatSkill(CoreCombatSkill skill) {
    equippedCombatSkill = skill;
    return true;
  }

  @override
  bool unequipCoreCombatSkill() {
    unequippedCombatSkill = true;
    return true;
  }

  @override
  bool setCorePassiveNodeRank(CorePassiveNodeId id, int rank) {
    assignedCorePassiveNode = id;
    assignedCorePassiveRank = rank;
    return true;
  }
}

class _CoreTreeGame extends RuneNexusGame {
  _CoreTreeGame(this.snapshots) : super(saveRepository: MemorySaveRepository());

  final ValueNotifier<GameSnapshot> snapshots;

  @override
  bool setCorePassiveNodeRank(CorePassiveNodeId id, int rank) {
    final current = snapshots.value;
    final ranks = Map<CorePassiveNodeId, int>.of(current.corePassiveNodeRanks);
    if (rank == 0) {
      ranks.remove(id);
    } else {
      ranks[id] = rank;
    }
    _publishRanks(current.totalCorePoints, ranks);
    return true;
  }

  @override
  bool resetCorePassiveTree() {
    _publishRanks(snapshots.value.totalCorePoints, const {});
    return true;
  }

  void _publishRanks(int totalCorePoints, Map<CorePassiveNodeId, int> ranks) {
    final spentCorePoints = corePassiveSpentPoints(ranks);
    snapshots.value = _resultSnapshot(
      phase: GamePhase.preparation,
      currentStageNumber: 1,
      totalCorePoints: totalCorePoints,
      spentCorePoints: spentCorePoints,
      availableCorePoints: totalCorePoints - spentCorePoints,
      corePassiveNodeRanks: Map.unmodifiable(ranks),
    );
  }
}

class _TurretModuleDrawGame extends RuneNexusGame {
  _TurretModuleDrawGame() : super(saveRepository: MemorySaveRepository());

  int? drawCount;
  TurretType? requestedTurretType;
  bool? boughtMissingTicketsWithDiamonds;

  static final List<TurretModuleInventoryItem> results = [
    TurretModuleInventoryItem(
      id: 'test-module-1',
      key: TurretModuleKey(
        turretType: TurretType.arrow,
        part: TurretModulePart.core,
        family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.core),
        grade: TurretModuleGrade.normal,
      ),
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.damageIncrease,
          value: 5,
        ),
      ],
      acquiredOrder: 1,
      equipped: false,
    ),
    TurretModuleInventoryItem(
      id: 'test-module-2',
      key: TurretModuleKey(
        turretType: TurretType.cannon,
        part: TurretModulePart.barrel,
        family: turretModuleFamilyFor(
          TurretType.cannon,
          TurretModulePart.barrel,
        ),
        grade: TurretModuleGrade.magic,
      ),
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.attackRateIncrease,
          value: 5,
        ),
      ],
      acquiredOrder: 2,
      equipped: false,
    ),
    TurretModuleInventoryItem(
      id: 'test-module-3',
      key: TurretModuleKey(
        turretType: TurretType.magic,
        part: TurretModulePart.frame,
        family: turretModuleFamilyFor(TurretType.magic, TurretModulePart.frame),
        grade: TurretModuleGrade.rare,
      ),
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.levelUpCostDiscount,
          value: 10,
        ),
      ],
      acquiredOrder: 3,
      equipped: false,
    ),
    TurretModuleInventoryItem(
      id: 'test-module-4',
      key: TurretModuleKey(
        turretType: TurretType.frost,
        part: TurretModulePart.core,
        family: turretModuleFamilyFor(TurretType.frost, TurretModulePart.core),
        grade: TurretModuleGrade.normal,
      ),
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.slowDurationIncrease,
          value: 4,
        ),
      ],
      acquiredOrder: 4,
      equipped: false,
    ),
    TurretModuleInventoryItem(
      id: 'test-module-5',
      key: TurretModuleKey(
        turretType: TurretType.arrow,
        part: TurretModulePart.frame,
        family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.frame),
        grade: TurretModuleGrade.magic,
      ),
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.buildCostDiscount,
          value: 6,
        ),
      ],
      acquiredOrder: 5,
      equipped: false,
    ),
  ];

  @override
  List<TurretModuleInventoryItem> drawTurretModules(
    int count, {
    TurretType? turretType,
    bool buyMissingTicketsWithDiamonds = false,
  }) {
    drawCount = count;
    requestedTurretType = turretType;
    boughtMissingTicketsWithDiamonds = buyMissingTicketsWithDiamonds;
    snapshotNotifier.value = _resultSnapshot(
      phase: GamePhase.preparation,
      currentStageNumber: 1,
      diamonds: 0,
      turretModuleTickets: 0,
      ownedTurretModules: results,
    );
    return results;
  }
}

class _TurretModuleDisassembleGame extends RuneNexusGame {
  _TurretModuleDisassembleGame()
    : super(saveRepository: MemorySaveRepository());

  String? disassembledId;
  Set<String>? bulkDisassembledIds;

  @override
  bool disassembleTurretModule(String id) {
    disassembledId = id;
    return true;
  }

  @override
  int disassembleTurretModules(Iterable<String> ids) {
    bulkDisassembledIds = ids.toSet();
    return bulkDisassembledIds!.length;
  }
}

GameSaveData _saveWithResearch({
  required Set<int> clearedStageNumbers,
  required Map<ResearchType, int> researchLevels,
  int gold = 170,
  int gemShards = 0,
  int roundIndex = 0,
  GamePhase phase = GamePhase.preparation,
  String? mapSignature,
}) {
  return GameSaveData(
    version: GameSaveData.currentVersion,
    savedAtMillis: 0,
    gold: gold,
    gemShards: gemShards,
    nexusHp: 20,
    stageNumber: 1,
    mapSignature: mapSignature,
    roundIndex: roundIndex,
    completedRounds: 0,
    phase: phase,
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
