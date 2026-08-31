import 'package:rune_nexus/ui/game/game_image_assets.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  testWidgets('Rune Nexus app renders main menu', (tester) async {
    await pumpLoadedApp(tester);

    expect(_gameLogoFinder(), findsOneWidget);
    expect(find.text('스테이지'), findsOneWidget);
    expect(find.text('스테이지 1'), findsOneWidget);
    expect(find.text('스테이지 5'), findsOneWidget);
    expect(find.text('잠김'), findsNWidgets(4));
    expect(find.text('강화'), findsOneWidget);
    expect(find.text('연구'), findsWidgets);
    expect(find.text('다이아'), findsNothing);

    final logoRect = tester.getRect(_gameLogoFinder());
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

    await pumpLoadedApp(tester);

    final logoRect = tester.getRect(_gameLogoFinder());
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

  testWidgets('active stage number socket preserves its source aspect ratio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
          snapshot: resultSnapshot(
            phase: GamePhase.wave,
            currentStageNumber: 1,
            hasStageProgress: true,
          ),
          selectedTab: MainMenuTab.stage,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await pumpGameFrames(tester);

    final socketImage = tester
        .widgetList<Image>(find.byType(Image))
        .firstWhere(
          (image) =>
              image.image is AssetImage &&
              (image.image as AssetImage).assetName ==
                  stageReferenceNumberSocketAsset,
        );
    expect(socketImage.fit, BoxFit.contain);
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
          snapshot: resultSnapshot(
            phase: GamePhase.preparation,
            currentStageNumber: 1,
          ),
          selectedTab: MainMenuTab.stage,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await pumpGameFrames(tester);

    expect(
      find.byKey(const ValueKey('daily-quest-entry-button')),
      findsOneWidget,
    );
    expect(find.byTooltip('일일 임무'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('daily-quest-entry-button')));
    await pumpGameFrames(tester);

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
    final dailyDialogWidth = tester.getSize(find.byType(Dialog)).width;

    await tester.tap(find.byKey(const ValueKey('quest-period-weekly')));
    await pumpGameFrames(tester);

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
    expect(tester.getSize(find.byType(Dialog)).width, dailyDialogWidth);
    expect(tester.takeException(), isNull);
  });

  testWidgets('daily quest entry only appears on stage tab', (tester) async {
    await pumpLoadedApp(tester);

    expect(
      find.byKey(const ValueKey('daily-quest-entry-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('main-menu-tab-research')));
    await pumpGameFrames(tester);

    expect(
      find.byKey(const ValueKey('daily-quest-entry-button')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('main-menu-tab-core')));
    await pumpGameFrames(tester);

    expect(
      find.byKey(const ValueKey('daily-quest-entry-button')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('main-menu-tab-upgrades')));
    await pumpGameFrames(tester);

    expect(
      find.byKey(const ValueKey('daily-quest-entry-button')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('main-menu-tab-modules')));
    await pumpGameFrames(tester);

    expect(
      find.byKey(const ValueKey('daily-quest-entry-button')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('main-menu-tab-stage')));
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

    await tester.tap(find.text('챕터 2'));
    await pumpGameFrames(tester);

    expect(find.text('균열 장막'), findsOneWidget);
    expect(find.text('스테이지 6'), findsOneWidget);
    expect(find.text('스테이지 10'), findsOneWidget);
    expect(find.text('스테이지 1'), findsNothing);
    expect(find.text('라이트닝 포탑'), findsNothing);

    await tester.tap(find.text('스테이지 6'));
    await pumpGameFrames(tester);

    expect(find.text('총 라운드'), findsOneWidget);
    expect(find.text('룬 보상'), findsOneWidget);
    expect(find.text('라이트닝 포탑'), findsWidgets);
    expect(startedStage, isNull);

    await tester.tap(find.text('시작하기'));
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

    expect(find.text('챕터 2'), findsOneWidget);
    expect(find.text('챕터 3'), findsOneWidget);

    await tester.tap(find.text('챕터 2'));
    await pumpGameFrames(tester);

    expect(find.text('균열 장막'), findsOneWidget);
    expect(find.text('스테이지 6'), findsOneWidget);
    expect(find.text('스테이지 10'), findsOneWidget);
    expect(find.text('스테이지 1'), findsNothing);
    expect(find.text('잠김'), findsNWidgets(5));

    await tester.tap(find.byKey(const ValueKey('stage-selection-row-6')));
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

    await tester.tap(find.text('챕터 3'));
    await pumpGameFrames(tester);

    expect(find.text('공명 용광로'), findsOneWidget);
    expect(find.text('스테이지 11'), findsOneWidget);
    expect(find.text('스테이지 15'), findsOneWidget);
    expect(find.text('스테이지 6'), findsNothing);

    await tester.tap(find.text('스테이지 11'));
    await pumpGameFrames(tester);

    expect(find.text('총 라운드'), findsOneWidget);
    expect(startedStage, isNull);

    await tester.tap(find.text('시작하기'));
    await pumpGameFrames(tester);

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
    await pumpLoadedApp(tester);

    expect(_gameLogoFinder(), findsOneWidget);
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
    await pumpGameFrames(tester);

    expect(_gameLogoFinder(), findsNothing);
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
    final coreContent = find.byKey(const ValueKey('core-content'));
    expect(coreContent, findsOneWidget);
    expect(find.byKey(const ValueKey('main-menu-content-panel')), findsNothing);
    expect(
      tester.getRect(coreContent).top,
      greaterThanOrEqualTo(resourceBarRect.bottom),
    );
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
    await pumpGameFrames(tester);

    expect(_gameLogoFinder(), findsNothing);
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
    await pumpGameFrames(tester);

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
    await pumpGameFrames(tester);

    expect(_gameLogoFinder(), findsNothing);
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
    await pumpGameFrames(tester);

    expect(_gameLogoFinder(), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-resource-bar')), findsNothing);
  });

  testWidgets('main menu tabs respond across the whole button area', (
    tester,
  ) async {
    await pumpLoadedApp(tester);

    await tester.tapAt(tabLeadingEdge(tester, 'main-menu-tab-research'));
    await pumpGameFrames(tester);

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('menu-resource-title')))
          .data,
      '연구',
    );

    await tester.tapAt(tabLeadingEdge(tester, 'main-menu-tab-core'));
    await pumpGameFrames(tester);

    expect(find.text('넥서스 코어'), findsOneWidget);

    await tester.tapAt(tabLeadingEdge(tester, 'main-menu-tab-stage'));
    await pumpGameFrames(tester);

    expect(find.text('스테이지 1'), findsOneWidget);
  });
}

Finder _gameLogoFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == gameLogoAsset,
  );
}
