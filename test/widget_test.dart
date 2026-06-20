import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/app/rune_nexus_app.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/combat/auto_start_mode.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
import 'package:rune_nexus/domain/combat/run_panel_tab.dart';
import 'package:rune_nexus/domain/core/core_ability.dart';
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
import 'package:rune_nexus/game/systems/run_progression.dart';
import 'package:rune_nexus/l10n/rune_nexus_localizations.dart';
import 'package:rune_nexus/ui/game/game_button.dart';
import 'package:rune_nexus/ui/hud/core_info_panel.dart';
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

    await tester.tap(find.byKey(const ValueKey('daily-quest-entry-button')));
    await _pumpGameFrames(tester);

    expect(find.text('웨이브 30회 클리어'), findsOneWidget);
    expect(find.text('보스 3회 처치'), findsOneWidget);
    expect(find.text('몹 100회 처치'), findsOneWidget);
    expect(find.text('런 강화 5회'), findsOneWidget);
    expect(find.text('+10'), findsNWidgets(4));
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

  testWidgets('main menu keeps tabs on bottom and keeps logo across tabs', (
    tester,
  ) async {
    await _pumpLoadedApp(tester);

    expect(find.text('Rune Nexus'), findsOneWidget);
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

    expect(find.text('Rune Nexus'), findsOneWidget);
    expect(find.text('넥서스 코어'), findsOneWidget);
    expect(find.text('전투 스킬 1칸 / 패시브 2칸'), findsOneWidget);
    expect(find.text('전투 스킬'), findsWidgets);
    expect(find.text('패시브 1'), findsOneWidget);
    expect(find.text('패시브 2'), findsOneWidget);
    expect(find.text('수호 광선'), findsWidgets);
    expect(find.text('균열 낙인'), findsOneWidget);
    final riftMarkCard = find.byKey(const ValueKey('core-ability-균열 낙인'));
    await tester.ensureVisible(riftMarkCard);
    await _pumpGameFrames(tester);
    await tester.tap(riftMarkCard);
    await _pumpGameFrames(tester);
    expect(
      find.textContaining('챕터 2 해금. 내구도 높은 적에게 받는 피해 증가 낙인 부여.'),
      findsOneWidget,
    );
    expect(find.text('잠김'), findsWidgets);
    expect(find.text('예상 피해'), findsNothing);
    expect(find.text('평균 DPS 8%'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('main-menu-tab-upgrades')));
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
    expect(find.text('코어'), findsOneWidget);
    expect(find.text('강화'), findsOneWidget);
    expect(find.text('연구'), findsOneWidget);

    await tester.tap(find.text('연구').last);
    await _pumpGameFrames(tester);

    expect(find.text('Rune Nexus'), findsOneWidget);
    expect(find.text('연구 보드'), findsOneWidget);
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
  });

  testWidgets('main menu tabs respond across the whole button area', (
    tester,
  ) async {
    await _pumpLoadedApp(tester);

    await tester.tapAt(_tabLeadingEdge(tester, 'main-menu-tab-research'));
    await _pumpGameFrames(tester);

    expect(find.text('연구 보드'), findsOneWidget);

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

    expect(find.text('모듈 뽑기'), findsOneWidget);
    expect(find.text('희귀 5%'), findsNothing);
    expect(find.text('희귀 보정'), findsNothing);
    expect(find.text('선택 포탑 · 모든 기관총에 적용'), findsNothing);
    expect(find.text('기'), findsNothing);
    expect(find.text('코어 장착 모듈'), findsOneWidget);
    expect(find.textContaining('아직 보유하지 않음'), findsOneWidget);
    expect(find.text('획득 필요'), findsWidgets);
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
      find.descendant(of: resultLayer, matching: find.text('화염')),
      findsWidgets,
    );
    expect(
      find.descendant(of: resultLayer, matching: find.text('프레임')),
      findsWidgets,
    );
    expect(
      find.descendant(of: resultLayer, matching: find.text('방열 프레임')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: resultLayer, matching: find.textContaining('장착 효과')),
      findsNothing,
    );
    expect(
      find.descendant(of: resultLayer, matching: find.text('장착')),
      findsNothing,
    );
    expect(
      find.descendant(of: resultLayer, matching: find.text('합성')),
      findsNothing,
    );

    await tester.tap(
      find.descendant(of: resultLayer, matching: find.text('확인')),
    );
    await _pumpGameFrames(tester);

    expect(resultLayer, findsNothing);
    expect(find.text('방열 프레임'), findsWidgets);
    expect(find.textContaining('프레임 · 화염 · 희귀 보유'), findsOneWidget);
  });

  testWidgets('core slot board remains anchored when switching ability tabs', (
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
            unlockedStageCount: 6,
            clearedStageNumbers: const {1, 2, 3, 4, 5},
          ),
          selectedTab: MainMenuTab.core,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    final combatTabBoard = _coreSocketBoardBounds(tester);
    expect(find.text('수호 광선'), findsWidgets);
    expect(find.text('패시브 1'), findsOneWidget);
    expect(find.text('패시브 2'), findsOneWidget);

    await tester.tap(find.text('패시브'));
    await _pumpGameFrames(tester);

    expect(find.text('수호 광선'), findsWidgets);
    expect(find.text('패시브 1'), findsOneWidget);
    expect(find.text('패시브 2'), findsOneWidget);
    final passiveTabBoard = _coreSocketBoardBounds(tester);
    expect(
      (passiveTabBoard.top - combatTabBoard.top).abs(),
      lessThanOrEqualTo(4),
    );
    expect(
      (passiveTabBoard.height - combatTabBoard.height).abs(),
      lessThanOrEqualTo(4),
    );
  });

  testWidgets(
    'core passive tab syncs slot selection and equips selected slot',
    (tester) async {
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
              unlockedStageCount: 6,
              clearedStageNumbers: const {1, 2, 3, 4, 5},
              corePassiveSlotTwoUnlocked: true,
            ),
            selectedTab: MainMenuTab.core,
            onSelectTab: (_) {},
            onStartStage: (_) {},
          ),
        ),
      );
      await _pumpGameFrames(tester);

      await tester.tap(find.text('패시브'));
      await _pumpGameFrames(tester);
      expect(find.textContaining('패시브 슬롯'), findsNothing);

      await tester.tap(find.text('패시브 2'));
      await _pumpGameFrames(tester);
      expect(find.textContaining('패시브 슬롯'), findsNothing);

      final costSavingDesignCard = find.byKey(
        const ValueKey('core-ability-절약 설계'),
      );
      await tester.ensureVisible(costSavingDesignCard);
      await _pumpGameFrames(tester);
      await tester.tap(costSavingDesignCard);
      await _pumpGameFrames(tester);
      await tester.tap(
        find.byKey(const ValueKey('core-selected-ability-action')),
      );
      await _pumpGameFrames(tester);
      expect(game.equippedPassive, CorePassiveAbility.costSavingDesign);
      expect(game.equippedSlotIndex, 1);
    },
  );

  testWidgets('core menu fits 320 wide viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
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
            unlockedStageCount: 6,
            clearedStageNumbers: const {1, 2, 3, 4, 5},
          ),
          selectedTab: MainMenuTab.core,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(find.byKey(const ValueKey('core-socket-board')), findsOneWidget);
    expect(find.text('보유 능력'), findsNothing);
    expect(find.text('전투 스킬'), findsWidgets);
    expect(find.text('패시브'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('패시브'));
    await _pumpGameFrames(tester);

    expect(find.textContaining('패시브 슬롯'), findsNothing);
    expect(find.text('자가 수복'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('core second passive slot can be unlocked with diamonds', (
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
            diamonds: 200,
          ),
          selectedTab: MainMenuTab.core,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(find.text('해금 가능'), findsOneWidget);
    expect(find.text('200 다이아 소모'), findsOneWidget);

    await tester.tap(find.text('해금 가능'));
    await _pumpGameFrames(tester);

    expect(find.text('패시브 슬롯을 해금할까요?'), findsOneWidget);
    expect(find.text('2번 코어 패시브 슬롯을 200 다이아로 해금합니다.'), findsOneWidget);
    expect(game.unlockedCorePassiveSlot, isFalse);

    await tester.tap(find.widgetWithText(GameButton, '취소'));
    await tester.pumpAndSettle();

    expect(find.text('패시브 슬롯을 해금할까요?'), findsNothing);
    expect(game.unlockedCorePassiveSlot, isFalse);

    await tester.tap(find.text('해금 가능'));
    await _pumpGameFrames(tester);
    await tester.tap(find.widgetWithText(GameButton, '해금'));
    await tester.pumpAndSettle();

    expect(game.unlockedCorePassiveSlot, isTrue);
  });

  testWidgets('core passive equipped item exposes unequip action', (
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
            unlockedStageCount: 6,
            clearedStageNumbers: const {1, 2, 3, 4, 5},
            corePassiveSlots: const [CorePassiveAbility.selfRepair, null],
          ),
          selectedTab: MainMenuTab.core,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    await tester.tap(find.text('패시브'));
    await _pumpGameFrames(tester);

    final selfRepairCard = find.byKey(const ValueKey('core-ability-자가 수복'));
    await tester.ensureVisible(selfRepairCard);
    await _pumpGameFrames(tester);
    await tester.tap(selfRepairCard);
    await _pumpGameFrames(tester);
    final unequipAction = find.byKey(
      const ValueKey('core-selected-ability-action'),
    );
    expect(unequipAction, findsOneWidget);

    await tester.tap(unequipAction);
    await _pumpGameFrames(tester);
    expect(game.unequippedSlotIndex, 0);
  });

  testWidgets('core combat skill can be unequipped and re-equipped', (
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
          ),
          selectedTab: MainMenuTab.core,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    final action = find.byKey(const ValueKey('core-selected-ability-action'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    await _pumpGameFrames(tester);
    expect(game.unequippedCombatSkill, isTrue);

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
            coreCombatSkill: null,
          ),
          selectedTab: MainMenuTab.core,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    expect(find.text('빈 슬롯'), findsWidgets);
    await tester.tap(action);
    await _pumpGameFrames(tester);
    expect(game.equippedCombatSkill, CoreCombatSkill.guardianBeam);
  });

  testWidgets('core locked and pending abilities stay non-actionable', (
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
            unlockedStageCount: 1,
          ),
          selectedTab: MainMenuTab.core,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    final riftMarkCard = find.byKey(const ValueKey('core-ability-균열 낙인'));
    await tester.ensureVisible(riftMarkCard);
    await _pumpGameFrames(tester);
    await tester.tap(riftMarkCard);
    await _pumpGameFrames(tester);
    expect(
      find.textContaining('챕터 2 해금. 내구도 높은 적에게 받는 피해 증가 낙인 부여.'),
      findsOneWidget,
    );
    expect(find.text('잠김'), findsWidgets);
    expect(game.equippedCombatSkill, isNull);
    expect(game.equippedPassive, isNull);
    expect(game.unequippedSlotIndex, isNull);

    expect(game.equippedPassive, isNull);
    expect(game.unequippedSlotIndex, isNull);
  });

  testWidgets('core rift mark equips after chapter two unlock', (tester) async {
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
            unlockedStageCount: 6,
          ),
          selectedTab: MainMenuTab.core,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await _pumpGameFrames(tester);

    final riftMarkCard = find.byKey(const ValueKey('core-ability-균열 낙인'));
    await tester.ensureVisible(riftMarkCard);
    await _pumpGameFrames(tester);
    await tester.tap(riftMarkCard);
    await _pumpGameFrames(tester);
    expect(find.textContaining('10초마다 내구도 높은 적 4명에게 5초 낙인'), findsOneWidget);
    expect(find.textContaining('대상이 받는 모든 피해 증가.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('core-selected-ability-action')),
    );
    await _pumpGameFrames(tester);

    expect(game.equippedCombatSkill, CoreCombatSkill.riftMark);
    expect(game.equippedPassive, isNull);
    expect(game.unequippedSlotIndex, isNull);
  });

  testWidgets('core menu keeps run-only combat data out of main menu', (
    tester,
  ) async {
    await _pumpLoadedApp(tester);

    await tester.tap(find.text('코어'));
    await _pumpGameFrames(tester);

    expect(find.text('넥서스 코어'), findsOneWidget);
    expect(find.text('전투 스킬 1칸 / 패시브 2칸'), findsOneWidget);
    expect(find.text('보유 능력'), findsNothing);
    expect(find.text('전투 스킬'), findsWidgets);
    expect(find.text('패시브'), findsWidgets);
    expect(find.text('패시브 1'), findsOneWidget);
    expect(find.text('패시브 2'), findsOneWidget);
    expect(find.text('수호 광선'), findsWidgets);
    expect(find.text('균열 낙인'), findsOneWidget);
    expect(find.textContaining('5초마다 가장 앞선 적에게 1초간 광선 피해'), findsOneWidget);
    expect(find.textContaining('포탑 화력이 높을수록 피해 증가.'), findsOneWidget);
    final riftMarkCard = find.byKey(const ValueKey('core-ability-균열 낙인'));
    await tester.ensureVisible(riftMarkCard);
    await _pumpGameFrames(tester);
    await tester.tap(riftMarkCard);
    await _pumpGameFrames(tester);
    expect(
      find.textContaining('챕터 2 해금. 내구도 높은 적에게 받는 피해 증가 낙인 부여.'),
      findsOneWidget,
    );
    expect(find.text('잠김'), findsWidgets);
    expect(find.text('예상 피해'), findsNothing);
    expect(find.text('포탑 배치 필요'), findsNothing);
    expect(find.text('평균 DPS 8%'), findsNothing);
    expect(find.text('코어 젬 슬롯'), findsNothing);
    expect(find.text('젬 공명'), findsNothing);

    await tester.ensureVisible(find.text('패시브'));
    await tester.tap(find.text('패시브'));
    await _pumpGameFrames(tester);

    expect(find.textContaining('패시브 슬롯'), findsNothing);
    expect(find.text('자가 수복'), findsWidgets);
    expect(find.text('절약 설계'), findsOneWidget);
    expect(find.text('5라운드마다 넥서스 체력 1 회복'), findsOneWidget);
    expect(find.byKey(const ValueKey('core-ability-절약 설계')), findsOneWidget);
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

    await tester.tap(find.byKey(const ValueKey('stage-selection-row-1')));
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

    expect(find.text('업그레이드 보드'), findsOneWidget);
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

    await tester.tap(find.byIcon(Icons.paid_outlined));
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

    await tester.tap(find.byIcon(Icons.paid_outlined));
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
    expect(find.text('강화 2개 해금'), findsOneWidget);
    expect(find.text('전투 기록'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
    expect(find.text('20R → 50R'), findsOneWidget);
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
            completedRounds: 50,
            runes: 220,
            lastRunRuneReward: 220,
            lastRunPreviousBestRound: 18,
            lastRunWasNewBestRound: true,
            lastRunUnlockedStageNumber: 4,
            lastRunUnlockedSniperTurret: true,
            bestRoundsByStage: const {3: 50},
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
            completedRounds: 50,
            runes: 420,
            lastRunRuneReward: 420,
            lastRunPreviousBestRound: 32,
            lastRunWasNewBestRound: true,
            lastRunUnlockedStageNumber: 6,
            bestRoundsByStage: const {5: 50},
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
            completedRounds: 50,
            runes: 590,
            lastRunRuneReward: 590,
            lastRunPreviousBestRound: 30,
            lastRunWasNewBestRound: true,
            lastRunUnlockedStageNumber: 8,
            bestRoundsByStage: const {7: 50},
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
            completedRounds: 50,
            runes: 690,
            lastRunRuneReward: 690,
            lastRunPreviousBestRound: 30,
            lastRunWasNewBestRound: true,
            lastRunUnlockedStageNumber: 9,
            bestRoundsByStage: const {8: 50},
            clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8},
          ),
          onOpenStageSelect: () {},
          onOpenPermanentUpgrades: () {},
          onStartStage: (_) {},
        ),
      ),
    );

    expect(find.text('연구 4개 해금'), findsOneWidget);
    expect(find.text('해금 항목'), findsOneWidget);
    expect(find.text('연구'), findsOneWidget);
    expect(find.text('룬 공명'), findsOneWidget);
    expect(find.text('포탑 화력 한계 확장'), findsOneWidget);
    expect(find.text('처치 보너스 한계 확장'), findsOneWidget);
    expect(find.text('정비 보급 한계 확장'), findsOneWidget);
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
    expect(find.text('패시브 없음'), findsOneWidget);
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
    while (game.snapshotNotifier.value.selectedTurretLevel < 3) {
      game.levelUpSelectedTurret();
    }
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

Rect _coreSocketBoardBounds(WidgetTester tester) {
  return tester.getRect(find.byKey(const ValueKey('core-socket-board')));
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
  CoreCombatSkill? coreCombatSkill = CoreCombatSkill.guardianBeam,
  List<CorePassiveAbility?> corePassiveSlots = const [null, null],
  GridPoint? selectedCorePoint,
  double nexusCoreBeamDamage = 0,
  double coreCombatSkillDirectDamageDealt = 0,
  double coreCombatSkillBonusDamageDealt = 0,
  int coreCombatSkillActivationCount = 0,
  bool corePassiveSlotTwoUnlocked = false,
  int turretModuleTickets = 0,
  List<TurretModuleInventoryItem> ownedTurretModules = const [],
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
    rewardOptions: const [],
    isPurchasedGemReward: false,
    gemInventory: const {},
    gemCollection: const {},
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
    corePassiveSlots: corePassiveSlots,
    corePassiveSlotCount: corePassiveSlotTwoUnlocked ? 2 : 1,
    corePassiveSlotUnlockCost: RunProgression.corePassiveSlotUnlockCost,
    canUnlockCorePassiveSlot:
        !corePassiveSlotTwoUnlocked &&
        diamonds >= RunProgression.corePassiveSlotUnlockCost,
    unlockedCorePassiveAbilities: {
      CorePassiveAbility.selfRepair,
      CorePassiveAbility.costSavingDesign,
      CorePassiveAbility.skillAcceleration,
    },
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
    dailyQuestAllCompleteClaimed: false,
    dailyQuestClockRollbackDetected: false,
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

class _ResearchInstantCompleteGame extends RuneNexusGame {
  _ResearchInstantCompleteGame()
    : super(saveRepository: MemorySaveRepository());

  ResearchType? completedResearchType;

  @override
  void completeResearchWithDiamonds(ResearchType type) {
    completedResearchType = type;
  }
}

class _CoreEquipGame extends RuneNexusGame {
  _CoreEquipGame() : super(saveRepository: MemorySaveRepository());

  CoreCombatSkill? equippedCombatSkill;
  bool unequippedCombatSkill = false;
  CorePassiveAbility? equippedPassive;
  int? equippedSlotIndex;
  int? unequippedSlotIndex;
  bool unlockedCorePassiveSlot = false;

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
  bool equipCorePassiveAbility(CorePassiveAbility ability, int slotIndex) {
    equippedPassive = ability;
    equippedSlotIndex = slotIndex;
    return true;
  }

  @override
  bool unequipCorePassiveAbility(int slotIndex) {
    unequippedSlotIndex = slotIndex;
    return true;
  }

  @override
  bool unlockCorePassiveSlot() {
    unlockedCorePassiveSlot = true;
    return true;
  }
}

class _TurretModuleDrawGame extends RuneNexusGame {
  _TurretModuleDrawGame() : super(saveRepository: MemorySaveRepository());

  int? drawCount;
  bool? boughtMissingTicketsWithDiamonds;

  static final List<TurretModuleInventoryItem> results = [
    TurretModuleInventoryItem(
      key: TurretModuleKey(
        turretType: TurretType.arrow,
        part: TurretModulePart.core,
        family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.core),
        grade: TurretModuleGrade.normal,
      ),
      stars: 0,
      shards: 0,
      equipped: false,
    ),
    TurretModuleInventoryItem(
      key: TurretModuleKey(
        turretType: TurretType.cannon,
        part: TurretModulePart.barrel,
        family: turretModuleFamilyFor(
          TurretType.cannon,
          TurretModulePart.barrel,
        ),
        grade: TurretModuleGrade.magic,
      ),
      stars: 0,
      shards: 5,
      equipped: false,
    ),
    TurretModuleInventoryItem(
      key: TurretModuleKey(
        turretType: TurretType.magic,
        part: TurretModulePart.frame,
        family: turretModuleFamilyFor(TurretType.magic, TurretModulePart.frame),
        grade: TurretModuleGrade.rare,
      ),
      stars: 0,
      shards: 0,
      equipped: false,
    ),
    TurretModuleInventoryItem(
      key: TurretModuleKey(
        turretType: TurretType.frost,
        part: TurretModulePart.core,
        family: turretModuleFamilyFor(TurretType.frost, TurretModulePart.core),
        grade: TurretModuleGrade.normal,
      ),
      stars: 0,
      shards: 1,
      equipped: false,
    ),
    TurretModuleInventoryItem(
      key: TurretModuleKey(
        turretType: TurretType.arrow,
        part: TurretModulePart.frame,
        family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.frame),
        grade: TurretModuleGrade.magic,
      ),
      stars: 0,
      shards: 1,
      equipped: false,
    ),
  ];

  @override
  List<TurretModuleInventoryItem> drawTurretModules(
    int count, {
    bool buyMissingTicketsWithDiamonds = false,
  }) {
    drawCount = count;
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

GameSaveData _saveWithResearch({
  required Set<int> clearedStageNumbers,
  required Map<ResearchType, int> researchLevels,
  int gold = 170,
  int gemShards = 0,
}) {
  return GameSaveData(
    version: GameSaveData.currentVersion,
    savedAtMillis: 0,
    gold: gold,
    gemShards: gemShards,
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
