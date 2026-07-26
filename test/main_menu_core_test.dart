import 'dart:math' as math;

import 'helpers/widget_test_helpers.dart';

void main() {
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
            snapshot: resultSnapshot(
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
      await pumpGameFrames(tester);

      expect(find.text('전투 스킬'), findsWidgets);
      expect(find.text('패시브 트리'), findsOneWidget);
      expect(find.text('수호 광선'), findsOneWidget);
      expect(find.textContaining('패시브 슬롯'), findsNothing);

      await tester.tap(find.text('패시브 트리'));
      await pumpGameFrames(tester);

      for (final id in CorePassiveNodeId.values) {
        expect(
          find.byKey(ValueKey('core-passive-node-${id.name}')),
          findsOneWidget,
        );
      }
      final nodeInkResponse = tester.widget<InkResponse>(
        find.byKey(const ValueKey('core-passive-node-attackHaste')),
      );
      expect(nodeInkResponse.containedInkWell, isTrue);
      expect(nodeInkResponse.customBorder, isA<CircleBorder>());
      final nodeContainer = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('core-passive-node-attackHaste')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final nodeDecoration = nodeContainer.decoration! as BoxDecoration;
      expect(nodeDecoration.color, Colors.transparent);
      expect(nodeInkResponse.splashColor, const Color(0x37FFB84D));
      expect(find.text('코어 포인트 20'), findsOneWidget);
      expect(find.text('노드를 선택해 효과와 랭크를 확인하세요'), findsNothing);
      expect(
        find.byKey(const ValueKey('core-passive-node-details-empty')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('core-passive-node-details')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'core passive details overlay opens on a node and closes on empty canvas',
    (tester) async {
      final snapshots = ValueNotifier(
        resultSnapshot(
          phase: GamePhase.preparation,
          currentStageNumber: 1,
          totalCorePoints: 20,
        ),
      );
      addTearDown(snapshots.dispose);
      final game = CoreTreeGame(snapshots);

      await tester.pumpWidget(coreTreeTestApp(game, snapshots));
      await pumpGameFrames(tester);
      await tester.tap(find.text('패시브 트리'));
      await pumpGameFrames(tester);

      final canvas = find.byKey(const ValueKey('core-passive-tree-canvas'));
      final viewer = find.byKey(const ValueKey('core-passive-tree-viewer'));
      final emptySpace = find.byKey(
        const ValueKey('core-passive-tree-empty-space'),
      );
      final details = find.byKey(const ValueKey('core-passive-node-details'));
      expect(details, findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('core-passive-node-attackHaste')),
      );
      await pumpGameFrames(tester);
      await tester.pump(const Duration(milliseconds: 200));

      expect(details, findsOneWidget);
      expect(find.ancestor(of: details, matching: canvas), findsOneWidget);
      expect(find.ancestor(of: details, matching: viewer), findsNothing);
      expect(
        tester.getRect(details).bottom,
        closeTo(tester.getRect(canvas).bottom, 1.1),
      );

      final emptyCanvasPoint =
          tester.getRect(emptySpace).topLeft + const Offset(10, 10);
      await tester.dragFrom(emptyCanvasPoint, const Offset(24, 24));
      await pumpGameFrames(tester);
      expect(details, findsOneWidget);

      final closePoint =
          tester.getRect(emptySpace).topLeft + const Offset(10, 10);
      await tester.tapAt(closePoint);
      await pumpGameFrames(tester);
      await tester.pump(const Duration(milliseconds: 200));

      expect(details, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('core passive target rank is assigned atomically', (
    tester,
  ) async {
    final game = CoreEquipGame();
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
            totalCorePoints: 20,
          ),
          selectedTab: MainMenuTab.core,
          onSelectTab: (_) {},
          onStartStage: (_) {},
        ),
      ),
    );
    await pumpGameFrames(tester);
    await tester.tap(find.text('패시브 트리'));
    await pumpGameFrames(tester);

    await tester.tap(
      find.byKey(const ValueKey('core-passive-node-attackHaste')),
    );
    await pumpGameFrames(tester);
    final increase = find.byKey(const ValueKey('core-passive-rank-increase'));
    await tester.ensureVisible(increase);
    await pumpGameFrames(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(increase);
      await pumpGameFrames(tester);
    }
    await tester.tap(find.byKey(const ValueKey('core-passive-assign')));
    await pumpGameFrames(tester);

    expect(game.corePassiveBatchAssignmentCount, 1);
    expect(game.assignedCorePassiveRanks, {CorePassiveNodeId.attackHaste: 3});
  });

  testWidgets(
    'node taps only select and plus accumulates a draft for one batch',
    (tester) async {
      final snapshots = ValueNotifier(
        resultSnapshot(
          phase: GamePhase.preparation,
          currentStageNumber: 1,
          totalCorePoints: 20,
        ),
      );
      addTearDown(snapshots.dispose);
      final game = CoreTreeGame(snapshots);
      await tester.pumpWidget(coreTreeTestApp(game, snapshots));
      await pumpGameFrames(tester);
      await tester.tap(find.text('패시브 트리'));
      await pumpGameFrames(tester);

      await tester.tap(
        find.byKey(const ValueKey('core-passive-node-attackHaste')),
      );
      await pumpGameFrames(tester);
      expect(snapshots.value.corePassiveNodeRanks, isEmpty);
      expect(find.text('0→1/5'), findsNothing);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('core-passive-planned-points')),
            )
            .data,
        '예정 0',
      );

      final increase = find.byKey(const ValueKey('core-passive-rank-increase'));
      await tester.ensureVisible(increase);
      for (var i = 0; i < 3; i++) {
        await tester.tap(increase);
        await pumpGameFrames(tester);
      }

      final connectedNode = find.byKey(
        const ValueKey('core-passive-node-attackPrecompute'),
      );
      await tester.ensureVisible(connectedNode);
      await pumpGameFrames(tester);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 80),
      );
      await pumpGameFrames(tester);
      await tester.tap(connectedNode);
      await pumpGameFrames(tester);

      expect(snapshots.value.corePassiveNodeRanks, isEmpty);
      expect(game.corePassiveBatchAssignmentCount, 0);
      expect(find.text('0→3/5'), findsOneWidget);
      expect(find.text('0→1/5'), findsNothing);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('core-passive-planned-points')),
            )
            .data,
        '예정 4',
      );

      await tester.ensureVisible(increase);
      await tester.tap(increase);
      await pumpGameFrames(tester);
      expect(find.text('0→1/5'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('core-passive-planned-points')),
            )
            .data,
        '예정 5',
      );

      final assign = find.byKey(const ValueKey('core-passive-assign'));
      await tester.ensureVisible(assign);
      await tester.tap(assign);
      await tester.pump(const Duration(milliseconds: 16));

      expect(game.corePassiveBatchAssignmentCount, 1);
      expect(game.lastAssignedCorePassiveRanks, {
        CorePassiveNodeId.attackHaste: 3,
        CorePassiveNodeId.attackPrecompute: 1,
      });
      expect(snapshots.value.corePassiveNodeRanks, {
        CorePassiveNodeId.attackHaste: 3,
        CorePassiveNodeId.attackPrecompute: 1,
      });
    },
  );

  testWidgets('core passive draft lines animate while rank buttons change', (
    tester,
  ) async {
    final snapshots = ValueNotifier(
      resultSnapshot(
        phase: GamePhase.preparation,
        currentStageNumber: 1,
        totalCorePoints: 20,
      ),
    );
    addTearDown(snapshots.dispose);
    final game = CoreTreeGame(snapshots);
    await tester.pumpWidget(coreTreeTestApp(game, snapshots));
    await pumpGameFrames(tester);
    await tester.tap(find.text('패시브 트리'));
    await pumpGameFrames(tester);
    await tester.tap(
      find.byKey(const ValueKey('core-passive-node-attackHaste')),
    );
    await pumpGameFrames(tester);

    double animatedRank() {
      final layer = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('core-passive-connection-layer')),
      );
      final painter = layer.painter as dynamic;
      return (painter.draftLineRanks
              as Map<CorePassiveNodeId, double>)[CorePassiveNodeId
              .attackHaste] ??
          0;
    }

    final increase = find.byKey(const ValueKey('core-passive-rank-increase'));
    final decrease = find.byKey(const ValueKey('core-passive-rank-decrease'));
    await tester.ensureVisible(increase);
    await tester.pumpAndSettle();
    await tester.tap(increase);
    await tester.pump();
    expect(animatedRank(), 0);
    await tester.pump(const Duration(milliseconds: 130));
    expect(animatedRank(), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 150));
    expect(animatedRank(), 1);

    await tester.ensureVisible(decrease);
    await tester.pumpAndSettle();
    await tester.tap(decrease);
    await tester.pump();
    expect(animatedRank(), 1);
    await tester.pump(const Duration(milliseconds: 130));
    expect(animatedRank(), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 150));
    expect(animatedRank(), 0);
    expect(snapshots.value.corePassiveNodeRanks, isEmpty);
  });

  testWidgets('core passive draft can be cancelled without changing snapshot', (
    tester,
  ) async {
    final snapshots = ValueNotifier(
      resultSnapshot(
        phase: GamePhase.preparation,
        currentStageNumber: 1,
        totalCorePoints: 20,
      ),
    );
    addTearDown(snapshots.dispose);
    final game = CoreTreeGame(snapshots);
    await tester.pumpWidget(coreTreeTestApp(game, snapshots));
    await pumpGameFrames(tester);
    await tester.tap(find.text('패시브 트리'));
    await pumpGameFrames(tester);

    await tester.tap(
      find.byKey(const ValueKey('core-passive-node-attackHaste')),
    );
    await pumpGameFrames(tester);
    final increase = find.byKey(const ValueKey('core-passive-rank-increase'));
    await tester.ensureVisible(increase);
    await tester.tap(increase);
    await pumpGameFrames(tester);
    final cancel = find.byKey(const ValueKey('core-passive-cancel-plan'));
    expect(tester.widget<TextButton>(cancel).onPressed, isNotNull);
    await tester.ensureVisible(cancel);
    await pumpGameFrames(tester);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 80),
    );
    await pumpGameFrames(tester);
    await tester.tap(cancel);
    await pumpGameFrames(tester);

    expect(snapshots.value.corePassiveNodeRanks, isEmpty);
    expect(game.corePassiveBatchAssignmentCount, 0);
    expect(find.text('0→1/5'), findsNothing);
    expect(tester.widget<TextButton>(cancel).onPressed, isNull);
  });

  testWidgets(
    'core passive allocation lights equal-distance branches by wave',
    (tester) async {
      final snapshots = ValueNotifier(
        resultSnapshot(
          phase: GamePhase.preparation,
          currentStageNumber: 1,
          totalCorePoints: 30,
        ),
      );
      addTearDown(snapshots.dispose);
      final game = CoreTreeGame(snapshots);
      await tester.pumpWidget(coreTreeTestApp(game, snapshots));
      await pumpGameFrames(tester);
      await tester.tap(find.text('패시브 트리'));
      await pumpGameFrames(tester);
      final increase = find.byKey(const ValueKey('core-passive-rank-increase'));
      Future<void> planRanks(CorePassiveNodeId id, int rank) async {
        if (find
            .byKey(const ValueKey('core-passive-node-details'))
            .evaluate()
            .isNotEmpty) {
          await tester.tap(
            find.byKey(const ValueKey('core-passive-tree-empty-space')),
          );
          await pumpGameFrames(tester);
          await tester.pump(const Duration(milliseconds: 200));
        }
        final node = find.byKey(ValueKey('core-passive-node-${id.name}'));
        await tester.ensureVisible(node);
        await pumpGameFrames(tester);
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, 80),
        );
        await pumpGameFrames(tester);
        await tester.tap(node);
        await pumpGameFrames(tester);
        await tester.ensureVisible(increase);
        for (var value = 0; value < rank; value++) {
          await tester.tap(increase);
          await pumpGameFrames(tester);
        }
      }

      await planRanks(CorePassiveNodeId.attackHaste, 3);
      await planRanks(CorePassiveNodeId.efficiencySaving, 3);
      await planRanks(CorePassiveNodeId.attackPrecompute, 1);
      await planRanks(CorePassiveNodeId.efficiencySupplyRecovery, 1);
      final assign = find.byKey(const ValueKey('core-passive-assign'));
      await tester.ensureVisible(assign);
      await tester.tap(assign);

      await tester.pump(const Duration(milliseconds: 20));
      expect(snapshots.value.corePassiveNodeRanks, {
        CorePassiveNodeId.attackHaste: 3,
        CorePassiveNodeId.efficiencySaving: 3,
        CorePassiveNodeId.attackPrecompute: 1,
        CorePassiveNodeId.efficiencySupplyRecovery: 1,
      });
      expect(find.text('0→3/5'), findsNothing);
      expect(find.text('3/5'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('core-passive-activation-attackHaste')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 290));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('core-passive-activation-attackHaste')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('core-passive-activation-efficiencySaving')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('core-passive-activation-attackPrecompute')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('core-passive-activation-efficiencySupplyRecovery'),
        ),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 210));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('core-passive-activation-attackHaste')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('core-passive-activation-efficiencySaving')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('core-passive-activation-attackPrecompute')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('core-passive-activation-efficiencySupplyRecovery'),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('core-passive-activation-attackHaste')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('core-passive-activation-efficiencySaving')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('core-passive-activation-attackPrecompute')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('core-passive-activation-efficiencySupplyRecovery'),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('core-passive-activation-attackPrecompute')),
        findsNothing,
      );
    },
  );

  testWidgets('locked core passive node keeps assign action disabled', (
    tester,
  ) async {
    final snapshots = ValueNotifier(
      resultSnapshot(
        phase: GamePhase.preparation,
        currentStageNumber: 1,
        totalCorePoints: 20,
      ),
    );
    addTearDown(snapshots.dispose);
    final game = CoreTreeGame(snapshots);
    await tester.pumpWidget(coreTreeTestApp(game, snapshots));
    await pumpGameFrames(tester);
    await tester.tap(find.text('패시브 트리'));
    await pumpGameFrames(tester);

    final lockedNode = find.byKey(
      const ValueKey('core-passive-node-attackPrecompute'),
    );
    await tester.tap(lockedNode);
    await pumpGameFrames(tester);
    final details = find.byKey(const ValueKey('core-passive-node-details'));
    final increase = find.byKey(const ValueKey('core-passive-rank-increase'));
    final assign = find.byKey(const ValueKey('core-passive-assign'));
    await tester.ensureVisible(assign);
    await pumpGameFrames(tester);

    expect(details, findsOneWidget);
    expect(find.text('가속 동기화'), findsOneWidget);
    expect(find.text('효과'), findsOneWidget);
    expect(find.text('현재 효과'), findsNothing);
    expect(find.text('다음 효과'), findsNothing);
    expect(
      find.text('코어 스킬 발동 후 2초간 모든 포탑 공격 속도 3% 증폭', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('필요 포인트'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    TextSpan selectedEffectSpan() =>
        tester
                .widget<RichText>(
                  find.byKey(const ValueKey('core-passive-selected-effect')),
                )
                .text
            as TextSpan;

    final previewEffect = selectedEffectSpan();
    final previewNumber = previewEffect.children!
        .whereType<TextSpan>()
        .singleWhere((span) => span.text == '3%');
    expect(previewEffect.style!.color, const Color(0xFF778995));
    expect(previewNumber.style!.color, isNot(previewEffect.style!.color));
    expect(
      tester
          .widget<IconButton>(
            find.descendant(of: increase, matching: find.byType(IconButton)),
          )
          .onPressed,
      isNull,
    );
    expect(tester.widget<FilledButton>(assign).onPressed, isNull);
    expect(find.text('연결된 노드를 강화하면 개방됩니다'), findsOneWidget);
    expect(snapshots.value.corePassiveNodeRanks, isEmpty);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('core-passive-planned-points')),
          )
          .data,
      '예정 0',
    );

    final selectedNodeContainer = tester.widget<AnimatedContainer>(
      find.descendant(of: lockedNode, matching: find.byType(AnimatedContainer)),
    );
    final selectedDecoration =
        selectedNodeContainer.decoration! as BoxDecoration;
    final selectedBorder = selectedDecoration.border! as Border;
    expect(selectedBorder.top.color, const Color(0xFFE8FBFF));

    final startingNode = find.byKey(
      const ValueKey('core-passive-node-attackHaste'),
    );
    await tester.ensureVisible(startingNode);
    await pumpGameFrames(tester);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 80),
    );
    await pumpGameFrames(tester);
    await tester.tap(startingNode);
    await pumpGameFrames(tester);
    await tester.ensureVisible(increase);
    await tester.tap(increase);
    await pumpGameFrames(tester);

    final activeEffect = selectedEffectSpan();
    final activeNumber = activeEffect.children!
        .whereType<TextSpan>()
        .singleWhere((span) => span.text == '2%');
    expect(activeEffect.toPlainText(), '코어 스킬 재사용 대기시간 회복 속도 2% 증가');
    expect(activeEffect.style!.color, const Color(0xFFC8D9E2));
    expect(activeNumber.style!.color, isNot(activeEffect.style!.color));
    expect(activeNumber.style!.color, isNot(previewNumber.style!.color));
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('core-passive-selected-rank')),
          )
          .data,
      '예정 랭크 0 → 1 / 5',
    );
  });

  testWidgets('rank three start node opens its connected node in the UI', (
    tester,
  ) async {
    final snapshots = ValueNotifier(
      resultSnapshot(
        phase: GamePhase.preparation,
        currentStageNumber: 1,
        totalCorePoints: 20,
      ),
    );
    addTearDown(snapshots.dispose);
    final game = CoreTreeGame(snapshots);
    await tester.pumpWidget(coreTreeTestApp(game, snapshots));
    await pumpGameFrames(tester);
    await tester.tap(find.text('패시브 트리'));
    await pumpGameFrames(tester);

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
    await pumpGameFrames(tester);
    final increase = find.byKey(const ValueKey('core-passive-rank-increase'));
    await tester.ensureVisible(increase);
    await pumpGameFrames(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(increase);
      await pumpGameFrames(tester);
    }
    await tester.tap(find.byKey(const ValueKey('core-passive-assign')));
    await pumpGameFrames(tester);

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
      resultSnapshot(
        phase: GamePhase.preparation,
        currentStageNumber: 1,
        totalCorePoints: 20,
        spentCorePoints: 5,
        availableCorePoints: 15,
        corePassiveNodeRanks: ranks,
      ),
    );
    addTearDown(snapshots.dispose);
    final game = CoreTreeGame(snapshots);
    await tester.pumpWidget(coreTreeTestApp(game, snapshots));
    await pumpGameFrames(tester);
    await tester.tap(find.text('패시브 트리'));
    await pumpGameFrames(tester);

    await tester.tap(
      find.byKey(const ValueKey('core-passive-node-attackHaste')),
    );
    await pumpGameFrames(tester);
    final decrease = find.byKey(const ValueKey('core-passive-rank-decrease'));
    await tester.ensureVisible(decrease);
    await pumpGameFrames(tester);
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
      resultSnapshot(
        phase: GamePhase.preparation,
        currentStageNumber: 1,
        totalCorePoints: 20,
        spentCorePoints: 4,
        availableCorePoints: 16,
        corePassiveNodeRanks: ranks,
      ),
    );
    addTearDown(snapshots.dispose);
    final game = CoreTreeGame(snapshots);
    await tester.pumpWidget(coreTreeTestApp(game, snapshots));
    await pumpGameFrames(tester);
    await tester.tap(find.text('패시브 트리'));
    await pumpGameFrames(tester);

    final reset = find.byKey(const ValueKey('core-passive-reset-all'));
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('패시브 트리를 초기화할까요?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('core-passive-reset-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('core-passive-reset-panel')),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('반환 포인트'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
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
          snapshot: resultSnapshot(
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
    await pumpGameFrames(tester);
    await tester.tap(find.text('패시브 트리'));
    await pumpGameFrames(tester);

    final viewerFinder = find.byKey(const ValueKey('core-passive-tree-viewer'));
    final backgroundFinder = find.byKey(
      const ValueKey('core-passive-tree-background'),
    );
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final controller = viewer.transformationController!;
    final viewport = tester.getSize(viewerFinder);
    final initialBackgroundRect = tester.getRect(backgroundFinder);
    const worldSize = 720.0;
    final expectedMinScale =
        math.min(viewport.width / worldSize, viewport.height / worldSize) *
        0.92;

    void expectWorldTransformClamped() {
      final matrix = controller.value;
      final scale = matrix.getMaxScaleOnAxis();
      final dx = matrix.storage[12];
      final dy = matrix.storage[13];

      void expectAxisClamped(double translation, double viewportExtent) {
        final scaledWorld = worldSize * scale;
        if (scaledWorld <= viewportExtent + 0.01) {
          expect(
            translation,
            closeTo((viewportExtent - scaledWorld) / 2, 0.01),
          );
          return;
        }
        expect(
          translation,
          greaterThanOrEqualTo(viewportExtent - scaledWorld - 0.01),
        );
        expect(translation, lessThanOrEqualTo(0.01));
      }

      expectAxisClamped(dx, viewport.width);
      expectAxisClamped(dy, viewport.height);
    }

    void expectBackgroundCoversViewport() {
      final backgroundRect = tester.getRect(backgroundFinder);
      final viewportRect = tester.getRect(viewerFinder);
      expect(backgroundRect.left, lessThanOrEqualTo(viewportRect.left + 0.01));
      expect(backgroundRect.top, lessThanOrEqualTo(viewportRect.top + 0.01));
      expect(
        backgroundRect.right,
        greaterThanOrEqualTo(viewportRect.right - 0.01),
      );
      expect(
        backgroundRect.bottom,
        greaterThanOrEqualTo(viewportRect.bottom - 0.01),
      );
    }

    expect(viewer.minScale, closeTo(expectedMinScale, 0.0001));
    expect(backgroundFinder, findsOneWidget);
    expect(
      find.ancestor(of: backgroundFinder, matching: viewerFinder),
      findsOneWidget,
    );
    expectBackgroundCoversViewport();
    expect(
      controller.value.getMaxScaleOnAxis(),
      closeTo(expectedMinScale, 0.0001),
    );
    expectWorldTransformClamped();

    final viewportCenter = tester.getCenter(viewerFinder);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: viewportCenter,
        scrollDelta: const Offset(0, -600),
      ),
    );
    await pumpGameFrames(tester);
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(expectedMinScale));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: viewportCenter,
        scrollDelta: const Offset(0, 1200),
      ),
    );
    await pumpGameFrames(tester);
    expect(
      controller.value.getMaxScaleOnAxis(),
      closeTo(expectedMinScale, 0.0001),
    );
    expectWorldTransformClamped();

    await tester.drag(viewerFinder, const Offset(1200, 1200));
    await pumpGameFrames(tester);
    expectWorldTransformClamped();

    final zoomScale = viewer.minScale * 1.8;
    final zoomDx = (viewport.width - worldSize * zoomScale) / 2;
    final zoomDy = (viewport.height - worldSize * zoomScale) / 2;
    controller.value = Matrix4.identity()
      ..translateByDouble(zoomDx, zoomDy, 0, 1)
      ..scaleByDouble(zoomScale, zoomScale, zoomScale, 1);
    await pumpGameFrames(tester);
    await tester.drag(viewerFinder, const Offset(-1600, -1600));
    await pumpGameFrames(tester);
    expectWorldTransformClamped();
    expectBackgroundCoversViewport();
    await tester.drag(viewerFinder, const Offset(1600, 1600));
    await pumpGameFrames(tester);
    expectWorldTransformClamped();
    expectBackgroundCoversViewport();
    expect(
      tester.getRect(backgroundFinder).width,
      greaterThan(initialBackgroundRect.width),
    );

    final minDx = (viewport.width - worldSize * viewer.minScale) / 2;
    final minDy = (viewport.height - worldSize * viewer.minScale) / 2;
    controller.value = Matrix4.identity()
      ..translateByDouble(minDx, minDy, 0, 1)
      ..scaleByDouble(viewer.minScale, viewer.minScale, viewer.minScale, 1);
    await pumpGameFrames(tester);

    await tester.tap(
      find.byKey(const ValueKey('core-passive-node-attackHaste')),
    );
    await pumpGameFrames(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('core-passive-node-details')),
    );
    await pumpGameFrames(tester);

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
            snapshot: resultSnapshot(
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
            snapshot: resultSnapshot(
              phase: GamePhase.preparation,
              currentStageNumber: 1,
              coreCombatSkill: CoreCombatSkill.riftMark,
              coreCombatSkillBonusDamageDealt: 7.25,
            ),
          ),
        ),
      ),
    );

    expect(find.text('다음 효과 +25%'), findsOneWidget);
    expect(find.text('총 추가 피해 7.25'), findsOneWidget);
  });
}
