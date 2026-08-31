import 'package:rune_nexus/ui/game/game_image_assets.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  testWidgets('turret module menu shows equipment flow and ticket purchase', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;

    final game = TurretModuleDrawGame();
    final initialSnapshot = resultSnapshot(
      phase: GamePhase.preparation,
      currentStageNumber: 1,
      diamonds: 80,
      turretModuleTickets: 3,
      turretModuleDrawCount: 260,
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
    await pumpGameFrames(tester);

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('menu-resource-title')))
          .data,
      '포탑 모듈',
    );
    expect(
      find.byKey(const ValueKey('menu-turret-module-tickets')),
      findsNothing,
    );
    expect(find.text('모듈권 3'), findsNothing);
    final currencyBalance = find.byKey(const ValueKey('menu-currency-balance'));
    expect(
      find.descendant(of: currencyBalance, matching: find.text('3')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: currencyBalance,
        matching: find.byType(RuneCurrencyIcon),
      ),
      findsNothing,
    );
    final moduleTicketIcon = tester.widget<Image>(
      find.byKey(const ValueKey('menu-turret-module-ticket-icon')),
    );
    expect(moduleTicketIcon.image, isA<AssetImage>());
    expect(
      (moduleTicketIcon.image as AssetImage).assetName,
      turretModuleTicketIconAsset,
    );
    expect(find.text('모듈 뽑기'), findsNothing);
    expect(find.text('모듈 구축 Lv.3'), findsOneWidget);
    expect(find.textContaining('현재 누적'), findsNothing);
    expect(find.text('유니크 4%'), findsNothing);
    expect(find.text('희귀 10%'), findsNothing);
    expect(find.text('마법 30%'), findsNothing);
    expect(find.text('일반 56%'), findsNothing);
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
    final previewFrame = tester.widget<Image>(
      find.byKey(const ValueKey('turret-module-preview-frame')),
    );
    expect(previewFrame.image, isA<AssetImage>());
    expect(
      (previewFrame.image as AssetImage).assetName,
      turretModulePreviewFrameAsset,
    );
    final connectorAssembly = tester.widget<Image>(
      find.byKey(const ValueKey('turret-module-connector-assembly')),
    );
    expect(connectorAssembly.image, isA<AssetImage>());
    expect(
      (connectorAssembly.image as AssetImage).assetName,
      turretModuleConnectorAssemblyAsset,
    );
    final buildLevelButton = find.byKey(
      const ValueKey('turret-module-build-level-button'),
    );
    final buildLevelButtonRect = tester.getRect(buildLevelButton);
    expect(buildLevelButtonRect.height, lessThanOrEqualTo(36));
    final fiveDrawButton = find.byKey(
      const ValueKey('turret-module-draw-button-5'),
    );
    final fiveDrawButtonRect = tester.getRect(fiveDrawButton);
    expect(fiveDrawButtonRect.width, lessThanOrEqualTo(72));
    expect(
      (fiveDrawButtonRect.center.dy - buildLevelButtonRect.center.dy).abs(),
      lessThanOrEqualTo(1),
    );
    expect(buildLevelButtonRect.right, lessThan(fiveDrawButtonRect.left));
    expect(find.text('부족 2장 · 다이아 80'), findsNothing);
    expect(
      find.descendant(of: fiveDrawButton, matching: find.text('80')),
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

    await tester.tap(buildLevelButton);
    await pumpGameFrames(tester);

    expect(
      find.byKey(const ValueKey('turret-module-build-level-dialog')),
      findsOneWidget,
    );
    expect(find.text('현재 누적 260회 · 모듈 획득 누적으로 상위 등급 확률 증가'), findsOneWidget);
    expect(find.text('누적 250회 달성'), findsOneWidget);
    final currentLevelTab = tester.widget<GameButton>(
      find.byKey(const ValueKey('turret-module-build-level-tab-3')),
    );
    expect(currentLevelTab.selected, isTrue);
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('turret-module-build-grade-rate-3-unique'),
            ),
          )
          .data,
      '4%',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('turret-module-build-grade-rate-3-rare')),
          )
          .data,
      '10%',
    );
    expect(find.text('현재 적용 중'), findsOneWidget);
    final buildLevelDialog = find.byKey(
      const ValueKey('turret-module-build-level-dialog'),
    );
    final buildLevelDetail = find.byKey(
      const ValueKey('turret-module-build-level-detail'),
    );
    final currentDialogHeight = tester.getSize(buildLevelDialog).height;
    final currentDetailHeight = tester.getSize(buildLevelDetail).height;

    await tester.tap(
      find.byKey(const ValueKey('turret-module-build-level-tab-5')),
    );
    await pumpGameFrames(tester);

    expect(
      tester
          .widget<GameButton>(
            find.byKey(const ValueKey('turret-module-build-level-tab-5')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('turret-module-build-grade-rate-5-unique'),
            ),
          )
          .data,
      '5%',
    );
    expect(find.text('누적 800회 달성'), findsOneWidget);
    expect(find.text('현재 적용 중'), findsNothing);
    expect(tester.getSize(buildLevelDialog).height, currentDialogHeight);
    expect(tester.getSize(buildLevelDetail).height, currentDetailHeight);

    await tester.tap(
      find.byKey(const ValueKey('turret-module-build-level-tab-1')),
    );
    await pumpGameFrames(tester);

    expect(find.text('기본 단계'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await pumpGameFrames(tester);

    await tester.tap(find.text('대포'));
    await pumpGameFrames(tester);

    expect(find.text('대포 모듈 인벤토리'), findsOneWidget);

    await tester.tap(fiveDrawButton);
    await pumpGameFrames(tester);

    expect(find.text('모듈권 구매'), findsOneWidget);
    final purchaseDialog = find.byType(Dialog);
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
      find.descendant(of: purchaseDialog, matching: find.text('80')),
      findsOneWidget,
    );
    expect(find.text('80개'), findsNothing);

    await tester.tap(find.text('구매'));
    await pumpGameFrames(tester);
    await tester.pump(const Duration(milliseconds: 240));

    final resultLayer = find.byKey(
      const ValueKey('turret-module-draw-result-layer'),
    );
    expect(resultLayer, findsOneWidget);
    final drawResultFrame = tester.widget<Image>(
      find.byKey(const ValueKey('turret-module-draw-result-dialog-frame')),
    );
    expect(
      (drawResultFrame.image as AssetImage).assetName,
      gamePanelFrameAsset,
    );
    final drawResultSocket = tester.widget<Image>(
      find.byKey(
        const ValueKey('turret-module-draw-card-socket-test-module-1'),
      ),
    );
    expect(
      (drawResultSocket.image as AssetImage).assetName,
      gameCardFrameAsset,
    );
    final drawResultConfirmFrame = tester.widget<Image>(
      find.byKey(const ValueKey('turret-module-draw-result-confirm-frame')),
    );
    expect(
      (drawResultConfirmFrame.image as AssetImage).assetName,
      gameButtonFrameAsset,
    );
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
    await pumpGameFrames(tester);

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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);

    expect(find.text('선택한 모듈 없음'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('turret-module-socket-frame')));
    await pumpGameFrames(tester);

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
    final game = TurretModuleDisassembleGame();
    final snapshot = resultSnapshot(
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
    await pumpGameFrames(tester);

    final inventorySlot = find.byKey(
      const ValueKey('turret-module-inventory-slot-spare-core-module'),
    );
    await tester.ensureVisible(inventorySlot);
    await pumpGameFrames(tester);
    await tester.tap(inventorySlot);
    await pumpGameFrames(tester);

    final disassembleButton = find.byKey(
      const ValueKey('turret-module-disassemble-button-spare-core-module'),
    );
    await tester.ensureVisible(disassembleButton);
    await pumpGameFrames(tester);
    await tester.tap(disassembleButton);
    await pumpGameFrames(tester);

    expect(game.disassembledId, isNull);
    final dialog = find.byKey(
      const ValueKey('turret-module-disassemble-dialog'),
    );
    expect(dialog, findsOneWidget);
    final disassembleFrame = tester.widget<Image>(
      find.byKey(const ValueKey('turret-module-disassemble-dialog-frame')),
    );
    expect(
      (disassembleFrame.image as AssetImage).assetName,
      gamePanelFrameAsset,
    );
    final refundFrame = tester.widget<Image>(
      find.byKey(const ValueKey('turret-module-disassemble-refund-frame')),
    );
    expect((refundFrame.image as AssetImage).assetName, gameRowFrameAsset);
    final cancelFrame = tester.widget<Image>(
      find.byKey(const ValueKey('turret-module-disassemble-cancel-frame')),
    );
    expect((cancelFrame.image as AssetImage).assetName, gameButtonFrameAsset);
    final confirmFrame = tester.widget<Image>(
      find.byKey(const ValueKey('turret-module-disassemble-confirm-frame')),
    );
    expect((confirmFrame.image as AssetImage).assetName, gameButtonFrameAsset);
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
    await pumpGameFrames(tester);
    await tester.tap(disassembleButton);
    await pumpGameFrames(tester);
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
      final game = TurretModuleDisassembleGame();

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
      await pumpGameFrames(tester);

      final coreFilter = find.byKey(
        const ValueKey('turret-module-part-filter-core'),
      );
      await tester.ensureVisible(coreFilter);
      await tester.tap(coreFilter);
      await pumpGameFrames(tester);

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
}
