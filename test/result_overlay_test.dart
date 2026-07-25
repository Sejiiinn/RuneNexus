import 'helpers/widget_test_helpers.dart';

void main() {
  testWidgets('result overlay summarizes rewards and unlocks', (tester) async {
    var openedStageSelect = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ResultOverlay(
          game: RuneNexusGame(),
          snapshot: resultSnapshot(
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
          snapshot: resultSnapshot(
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
          snapshot: resultSnapshot(
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
          snapshot: resultSnapshot(
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
          snapshot: resultSnapshot(
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
          snapshot: resultSnapshot(
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
          snapshot: resultSnapshot(
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
          snapshot: resultSnapshot(
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
}
