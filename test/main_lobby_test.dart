import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:rune_nexus/ui/game/game_image_assets.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  if (const bool.fromEnvironment('CAPTURE_LOBBY')) {
    testWidgets('실제 로비 초기 상태와 전투 진행 상태 렌더 캡처', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundaryKey = GlobalKey();
      await tester.runAsync(() async {
        final loader = FontLoader('NotoSansKR')
          ..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'));
        await loader.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: RuneNexusApp(
            game: RuneNexusGame(saveRepository: MemorySaveRepository()),
          ),
        ),
      );
      await pumpUntilLoadedApp(tester);
      await tester.runAsync(() async {
        final context = tester.element(find.byType(MainMenuScreen));
        for (final provider in {
          ...runeNexusStartupImageProviders(),
          ...tester
              .widgetList<Image>(find.byType(Image))
              .map((image) => image.image),
        }) {
          await precacheImage(provider, context);
        }
      });
      for (final active in [false, true]) {
        if (active) {
          await tapStageCard(tester, '스테이지 1');
          await tester.tap(find.text('시작하기'));
          await pumpUntilFound(tester, find.text('시작'));
          await tester.tap(find.text('시작'));
          await tester.pump();
          await tester.tap(find.byIcon(Icons.home_outlined));
          await pumpGameFrames(tester);
          await tester.tap(find.text('메인화면으로 이동'));
          await pumpGameFrames(tester);
          await tester.tap(
            find.byKey(const ValueKey('main-menu-back-to-lobby')),
          );
        }
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'design/lobby/implemented_lobby${active ? "_active" : ""}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }

  testWidgets('첫 접속은 로비이며 각 메뉴 진입과 로비 복귀를 지원한다', (tester) async {
    await pumpLoadedApp(tester);

    expect(find.byKey(const ValueKey('main-lobby-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-currency-balance')), findsNothing);
    expect(find.byKey(const ValueKey('stage-selection-row-1')), findsNothing);
    expect(find.byKey(const ValueKey('lobby-continue-run')), findsNothing);

    const entries = {
      'lobby-stage-select': MainMenuTab.stage,
      'lobby-tab-core': MainMenuTab.core,
      'lobby-tab-upgrades': MainMenuTab.permanentUpgrades,
      'lobby-tab-research': MainMenuTab.research,
      'lobby-tab-modules': MainMenuTab.turretModules,
    };
    for (final entry in entries.entries) {
      await tester.ensureVisible(find.byKey(ValueKey(entry.key)));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey(entry.key)));
      await pumpGameFrames(tester);
      expect(find.byKey(const ValueKey('main-lobby-screen')), findsNothing);
      expect(
        tester.widget<MainMenuScreen>(find.byType(MainMenuScreen)).selectedTab,
        entry.value,
      );
      await tester.tap(find.byKey(const ValueKey('main-menu-back-to-lobby')));
      await pumpGameFrames(tester);
      expect(find.byKey(const ValueKey('main-lobby-screen')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('로비 이벤트와 설정은 기존 임무와 계정 화면으로 연결된다', (tester) async {
    await pumpLoadedApp(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('lobby-events')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lobby-events')));
    await pumpGameFrames(tester);
    await tester.tap(find.text('출석 · 퀘스트'));
    await pumpGameFrames(tester);
    expect(
      find.byKey(const ValueKey('daily-quest-summary-card')),
      findsOneWidget,
    );
    Navigator.of(tester.element(find.byType(Dialog).first)).pop();
    await pumpGameFrames(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('lobby-settings')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lobby-settings')));
    await pumpGameFrames(tester);
    await tester.tap(find.text('계정 및 저장'));
    await pumpGameFrames(tester);
    expect(find.byKey(const ValueKey('account-summary-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('리더보드는 로비 위 모달로 열리고 계정 연결로 이어진다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpLoadedApp(tester);
    await tester.tap(find.byKey(const ValueKey('lobby-leaderboard')));
    await pumpGameFrames(tester);
    expect(find.text('계정 연결'), findsOneWidget);
    expect(find.byKey(const ValueKey('main-lobby-screen')), findsOneWidget);
    final dialog = tester.getRect(
      find.byKey(const ValueKey('leaderboard-content')),
    );
    expect(dialog.height, lessThanOrEqualTo(844 * 0.85));
    expect(dialog.top, greaterThan(0));
    await tester.tap(find.text('계정 연결'));
    await tester.pump(const Duration(milliseconds: 300));
    await pumpGameFrames(tester);
    expect(find.byKey(const ValueKey('account-summary-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('leaderboard-list')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('전투에서 스테이지로 돌아온 뒤 로비에서 저장된 전투를 재개한다', (tester) async {
    tester.view.physicalSize = const Size(411, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpLoadedApp(tester);
    await tapStageCard(tester, '스테이지 1');
    await tester.tap(find.text('시작하기'));
    await pumpUntilFound(tester, find.text('시작'));
    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await pumpGameFrames(tester);
    await tester.tap(find.text('메인화면으로 이동'));
    await pumpGameFrames(tester);
    expect(
      tester.widget<MainMenuScreen>(find.byType(MainMenuScreen)).selectedTab,
      MainMenuTab.stage,
    );
    expect(find.byKey(const ValueKey('main-lobby-screen')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('main-menu-back-to-lobby')));
    await pumpGameFrames(tester);
    expect(find.byKey(const ValueKey('lobby-continue-run')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lobby-continue-run')));
    await pumpGameFrames(tester);
    expect(find.text('저장된 진행 발견'), findsOneWidget);
    await tester.tap(find.text('재개'));
    await pumpGameFrames(tester);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('main-lobby-screen')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('연구 탭에서 로비로 돌아와도 연구 완료가 반영된다', (tester) async {
    final startedAt = DateTime.now();
    final repository = MemorySaveRepository()
      ..data = GameSaveData.fromJson({
        'version': 2,
        'savedAtMillis': startedAt.millisecondsSinceEpoch,
        'preferences': <String, Object?>{},
        'progression': <String, Object?>{
          'unlockedStageCount': 3,
          'clearedStageNumbers': [1, 2],
          'activeResearches': [
            {
              'type': ResearchType.gemAttunement.name,
              'targetLevel': 1,
              'startedAtMillis': startedAt.millisecondsSinceEpoch,
              'durationMillis': 2000,
              'initialElapsedMillis': 0,
            },
          ],
        },
        'turretModules': <String, Object?>{},
        'activeRun': null,
      });
    final game = RuneNexusGame(saveRepository: repository);
    await game.prepareSavedStateForMenu();
    var showLobby = false;
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
        home: StatefulBuilder(
          builder: (context, setState) => MainMenuScreen(
            game: game,
            snapshot: game.snapshotNotifier.value,
            snapshotListenable: game.snapshotNotifier,
            showLobby: showLobby,
            selectedTab: MainMenuTab.research,
            onSelectTab: (_) {},
            onStartStage: (_) {},
            onOpenLobby: () => setState(() => showLobby = true),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('main-menu-back-to-lobby')));
    await tester.pump();
    expect(find.byKey(const ValueKey('main-lobby-screen')), findsOneWidget);
    expect(game.snapshotNotifier.value.activeResearches, hasLength(1));

    // 연구 진행의 실제 벽시계 만료 후 로비 타이머만 실행.
    await tester.runAsync(() async {
      final remaining = startedAt
          .add(const Duration(milliseconds: 2100))
          .difference(DateTime.now());
      if (!remaining.isNegative) await Future<void>.delayed(remaining);
    });
    await tester.pump(const Duration(seconds: 1));
    expect(game.snapshotNotifier.value.activeResearches, isEmpty);
    expect(
      game.snapshotNotifier.value.researchLevels[ResearchType.gemAttunement],
      1,
    );
    expect(tester.takeException(), isNull);
  });

  for (final viewport in [const Size(320, 568), const Size(844, 390)]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        '로비 ${viewport.width}x${viewport.height} 글자 $textScale 배율에서 메뉴 접근 가능',
        (tester) async {
          tester.view.physicalSize = viewport;
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
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: MainMenuScreen(
                game: RuneNexusGame(saveRepository: MemorySaveRepository()),
                snapshot: resultSnapshot(
                  phase: GamePhase.preparation,
                  currentStageNumber: 1,
                  hasStageProgress: true,
                  completedRounds: 8,
                ),
                showLobby: true,
                selectedTab: MainMenuTab.stage,
                onSelectTab: (_) {},
                onStartStage: (_) {},
              ),
            ),
          );
          await pumpGameFrames(tester);
          for (final key in [
            'lobby-stage-select',
            'lobby-continue-run',
            'lobby-tab-core',
            'lobby-tab-upgrades',
            'lobby-tab-research',
            'lobby-tab-modules',
            'lobby-events',
            'lobby-leaderboard',
            'lobby-settings',
          ]) {
            final entry = find.byKey(ValueKey(key));
            expect(entry, findsOneWidget);
            await tester.ensureVisible(entry);
            await tester.pump();
            expect(entry.hitTestable(), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
