import 'package:rune_nexus/ui/hud/gem_reward_target_overlay.dart';

import 'helpers/widget_test_helpers.dart';

class _RewardActionGame extends RuneNexusGame {
  _RewardActionGame() : super(saveRepository: MemorySaveRepository());

  GemType? previewed;
  int? replacedSlot;
  int stored = 0;
  int cleared = 0;
  int cancelledReplacement = 0;

  @override
  bool previewRewardGem(GemType type) {
    previewed = type;
    return true;
  }

  @override
  bool replaceRewardGem(int slotIndex) {
    replacedSlot = slotIndex;
    return true;
  }

  @override
  bool storeRewardGem() {
    stored++;
    return true;
  }

  @override
  void clearRewardGemPreview() => cleared++;

  @override
  void cancelRewardGemReplacement() => cancelledReplacement++;
}

void main() {
  testWidgets('reward card begins target selection without a confirm step', (
    tester,
  ) async {
    final game = _RewardActionGame();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HudRewardOverlay(
            game: game,
            snapshot: resultSnapshot(
              phase: GamePhase.reward,
              currentStageNumber: 1,
              rewardOptions: const [GemType.chain, GemType.explosion],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('연쇄'));
    expect(game.previewed, GemType.chain);
    expect(find.text('획득 확정'), findsNothing);
    expect(find.text('젬 대신 파편 획득'), findsOneWidget);
  });

  for (final size in [const Size(320, 800), const Size(640, 360)]) {
    testWidgets('target overlay preserves board taps and actions at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = _RewardActionGame();
      Rect? board;
      var boardTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => boardTaps++,
                  ),
                ),
                Positioned.fill(
                  child: HudGemRewardTargetOverlay(
                    game: game,
                    snapshot: resultSnapshot(
                      phase: GamePhase.reward,
                      currentStageNumber: 1,
                      pendingRewardGem: GemType.chain,
                      clearedStageNumbers: const {3, 6},
                    ),
                    topInset: 80,
                    onBoardViewportChanged: (value) => board = value,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(board, isNotNull);
      expect(board!.width, greaterThan(200));
      expect(board!.height, greaterThan(100));
      await tester.tapAt(board!.center);
      expect(boardTaps, 1);
      for (final name in ['기관총', '대포', '화염', '냉각', '저격', '라이트닝']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.byIcon(Icons.block), findsNWidgets(2));
      expect(find.text('즉시 장착'), findsNothing);
      expect(find.text('교체 후 장착'), findsNothing);
      await tester.tap(find.text('젬 다시 선택'));
      await tester.tap(find.text('보관'));
      expect(game.cleared, 1);
      expect(game.stored, 1);
      expect(boardTaps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'replacement slots stay accessible and block board taps at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final game = _RewardActionGame();
        Rect? board;
        var boardTaps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => boardTaps++,
                    ),
                  ),
                  Positioned.fill(
                    child: HudGemRewardTargetOverlay(
                      game: game,
                      snapshot: resultSnapshot(
                        phase: GamePhase.reward,
                        currentStageNumber: 1,
                        pendingRewardGem: GemType.chain,
                        rewardReplacementPoint: const GridPoint(2, 0),
                        selectedTurretName: '대포',
                        selectedTurretLevel: 2,
                        selectedTurretSlotLimit: 2,
                        selectedTurretGems: const [
                          GemType.attackSpeed,
                          GemType.explosion,
                        ],
                        clearedStageNumbers: const {3, 6},
                      ),
                      topInset: 80,
                      onBoardViewportChanged: (value) => board = value,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('대포 Lv.2 · 홈 2/2'), findsOneWidget);
        final replacement = find.text('이 젬과 교체').last;
        await tester.ensureVisible(replacement);
        await tester.pumpAndSettle();
        await tester.tap(replacement);
        expect(game.replacedSlot, 1);
        final back = find.text('타워 다시 선택');
        await tester.ensureVisible(back);
        await tester.pumpAndSettle();
        await tester.tap(back);
        expect(game.cancelledReplacement, 1);
        await tester.tapAt(board!.topLeft + const Offset(1, 1));
        expect(boardTaps, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
