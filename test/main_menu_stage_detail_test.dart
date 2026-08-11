import 'package:rune_nexus/ui/game/game_image_assets.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  testWidgets('stage cards fit on narrow menu width', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpLoadedApp(tester);

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
    await pumpLoadedApp(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

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
    await pumpLoadedApp(tester);

    expect(find.text('전술 명령'), findsNothing);
    expect(find.text('젬 감응'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('stage-selection-row-2')));
    await pumpGameFrames(tester);

    expect(find.text('클리어 보상'), findsOneWidget);
    expect(find.text('전술 명령'), findsOneWidget);
    expect(find.text('젬 감응'), findsOneWidget);
    expect(find.text('연구 해금'), findsNothing);
  });

  testWidgets('stage eleven details show its first-clear module tickets', (
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
          snapshot: resultSnapshot(
            phase: GamePhase.preparation,
            currentStageNumber: 11,
            unlockedStageCount: 11,
          ),
          selectedTab: MainMenuTab.stage,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await pumpGameFrames(tester);

    await tester.tap(find.byKey(const ValueKey('stage-selection-row-11')));
    await pumpGameFrames(tester);

    expect(find.text('최초 클리어 보상'), findsOneWidget);
    expect(find.text('모듈권 +5'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                turretModuleTicketIconAsset,
      ),
      findsWidgets,
    );
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
            snapshot: resultSnapshot(
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
      await pumpGameFrames(tester);
      final stageRow = find.byKey(ValueKey('stage-selection-row-$stageNumber'));
      await tester.ensureVisible(stageRow);
      await tester.tap(stageRow);
      await pumpGameFrames(tester);
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

  testWidgets('stage nine shows its advanced economy upgrade rewards', (
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
          snapshot: resultSnapshot(
            phase: GamePhase.preparation,
            currentStageNumber: 9,
            unlockedStageCount: 9,
            clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8},
          ),
          selectedTab: MainMenuTab.stage,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await pumpGameFrames(tester);

    final stageRow = find.byKey(const ValueKey('stage-selection-row-9'));
    expect(stageRow, findsOneWidget);
    await tester.tap(stageRow);
    await pumpGameFrames(tester);

    expect(find.text('연결 공정'), findsOneWidget);
    expect(find.text('강화 공정'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is UpgradeIcon &&
            widget.type == GameUpgradeIconType.linkCost,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is UpgradeIcon &&
            widget.type == GameUpgradeIconType.turretLevelUpCost,
      ),
      findsOneWidget,
    );
  });

  testWidgets('stage fifteen shows its research reward and unlock details', (
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
          snapshot: resultSnapshot(
            phase: GamePhase.preparation,
            currentStageNumber: 15,
            unlockedStageCount: 15,
            clearedStageNumbers: const {
              1,
              2,
              3,
              4,
              5,
              6,
              7,
              8,
              9,
              10,
              11,
              12,
              13,
              14,
            },
          ),
          selectedTab: MainMenuTab.stage,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await pumpGameFrames(tester);

    final stageRow = find.byKey(const ValueKey('stage-selection-row-15'));
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
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('stage-selection-row-5')),
    );
    await tester.tap(find.byKey(const ValueKey('stage-selection-row-5')));
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

    await tapStageCard(tester, '스테이지 1');
    await pumpGameFrames(tester);

    expect(find.text('이어서 진행'), findsWidgets);
    expect(find.text('처음부터 시작'), findsNothing);

    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('이어서 진행')),
    );
    await pumpGameFrames(tester);

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
    await pumpGameFrames(tester);

    expect(find.text('챕터 2 · 6-10'), findsOneWidget);
    expect(stageChipText('6'), findsOneWidget);
    expect(stageChipText('10'), findsOneWidget);
    expect(find.text('챕터 1 · 1-5'), findsOneWidget);
    expect(find.text('챕터 3 · 11-15'), findsOneWidget);

    await tester.ensureVisible(find.text('Export 표시'));
    await tester.tap(find.text('Export 표시'));
    await pumpGameFrames(tester);

    expect(
      find.textContaining('tileTheme: chapterTwoRiftTileTheme'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('챕터 3 · 11-15'));
    await tester.tap(find.text('챕터 3 · 11-15'));
    await pumpGameFrames(tester);

    expect(stageChipText('11'), findsOneWidget);
    expect(stageChipText('15'), findsOneWidget);

    await tester.ensureVisible(find.text('Export 표시'));
    await tester.tap(find.text('Export 표시'));
    await pumpGameFrames(tester);

    expect(
      find.textContaining('tileTheme: chapterThreeForgeTileTheme'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('챕터 1 · 1-5'));
    await tester.tap(find.text('챕터 1 · 1-5'));
    await pumpGameFrames(tester);

    expect(stageChipText('1'), findsOneWidget);
    expect(stageChipText('5'), findsOneWidget);
    expect(stageChipText('6'), findsNothing);
  });
}
