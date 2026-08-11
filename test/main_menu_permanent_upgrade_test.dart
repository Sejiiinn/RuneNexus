import 'helpers/widget_test_helpers.dart';

void main() {
  testWidgets('permanent upgrade rows fit on narrow menu width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpLoadedApp(tester);

    await tester.tap(find.text('강화'));
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

    await tester.tap(find.byTooltip('경제'));
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

    await tester.tap(find.byTooltip('경제'));
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

    await tester.tap(find.byTooltip('경제'));
    await pumpGameFrames(tester);

    expect(find.text('긴급 매각'), findsOneWidget);
    expect(find.text('현재 75%'), findsOneWidget);
    expect(find.text('다음 76%'), findsOneWidget);
  });

  testWidgets('advanced economy upgrades unlock after stage nine clear', (
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
            currentStageNumber: 10,
            unlockedStageCount: 10,
            runes: 500,
            clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8, 9},
            linkCostOptimizationUpgradeLevel: 5,
            linkCostOptimizationUpgradeCost: 140,
            canUpgradeLinkCostOptimization: true,
            turretLevelUpOptimizationUpgradeLevel: 5,
            turretLevelUpOptimizationUpgradeCost: 140,
            canUpgradeTurretLevelUpOptimization: true,
          ),
          selectedTab: MainMenuTab.permanentUpgrades,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await pumpGameFrames(tester);

    await tester.tap(find.byTooltip('경제'));
    await pumpGameFrames(tester);

    expect(find.text('연결 공정'), findsOneWidget);
    expect(find.text('강화 공정'), findsOneWidget);
    expect(find.text('Lv.5/20'), findsNWidgets(2));
    expect(find.text('현재 -5%'), findsNWidgets(2));
    expect(find.text('다음 -6%'), findsNWidgets(2));
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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

    expect(find.text('물리 화력 훈련'), findsOneWidget);
    expect(find.text('원소 화력 훈련'), findsOneWidget);
    expect(find.text('현재 +30.0%'), findsNWidgets(2));
    expect(find.text('다음 +32.0%'), findsNWidgets(2));
  });
}
