import 'helpers/widget_test_helpers.dart';

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

  testWidgets('research cards keep two columns on narrow menu width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpLoadedApp(tester);

    await tester.tap(find.text('연구').last);
    await pumpGameFrames(tester);

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
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

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

  testWidgets('menu clock refreshes active research completion', (
    tester,
  ) async {
    final game = ResearchRefreshGame();
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
          snapshot: resultSnapshot(
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
    final game = ResearchInstantCompleteGame();
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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

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
    await pumpGameFrames(tester);

    expect(game.completedResearchType, isNull);
    expect(find.text('연구를 즉시 완료할까요?'), findsOneWidget);
    expect(find.text('젬 감응 연구를 다이아 2로 즉시 완료합니다.'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(GameButton, '즉시 완료'),
      ),
    );
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

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
    final game = ResearchSlotUnlockGame();
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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

    expect(find.text('두 연구를 동시에 진행할 수 있습니다.'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('research-slot-two-unlock-button')),
    );
    await pumpGameFrames(tester);

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
    await pumpGameFrames(tester);

    expect(game.unlockedResearchSlotTwo, isTrue);
  });
}
