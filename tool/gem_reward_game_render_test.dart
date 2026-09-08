// tool/의 렌더링 테스트도 전투 좌표 불변 검증용 테스트 접근자를 사용.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:rune_nexus/domain/gem/gem_reward_target_status.dart';
import 'package:rune_nexus/ui/hud/game_hud.dart';
import 'package:rune_nexus/ui/hud/gem_reward_target_overlay.dart';

import '../test/helpers/game_balance_test_helpers.dart';

const _fullCannon = GridPoint(3, 3);
const _emptyArrow = GridPoint(5, 5);
const _duplicateArrow = GridPoint(2, 0);
const _frost = GridPoint(2, 4);

Future<MemorySaveRepository> _fixture() async {
  final repository = MemorySaveRepository()
    ..data = saveWithResearch(
      clearedStageNumbers: const {1, 2, 3, 4, 5, 6},
      researchLevels: const {},
      gold: 10000,
      gemShards: 80,
      roundIndex: 9,
      mapSignature: const GameSaveAdapter().mapSignature(gameMap),
    );
  final game = RuneNexusGame(saveRepository: repository);
  game.onGameResize(Vector2(390, 844));
  await game.onLoad();
  for (final placement in [
    (_duplicateArrow, TurretType.arrow),
    (_fullCannon, TurretType.cannon),
    (const GridPoint(5, 2), TurretType.magic),
    (_frost, TurretType.frost),
    (const GridPoint(3, 8), TurretType.sniper),
    (const GridPoint(6, 7), TurretType.lightning),
    (_emptyArrow, TurretType.arrow),
  ]) {
    game.selectTurretType(placement.$2);
    game.tryBuildTurret(placement.$1);
    if (placement.$1 == _duplicateArrow) {
      game.grantGem(GemType.chain);
      game.equipSelectedTurret(GemType.chain);
    } else if (placement.$1 == _fullCannon) {
      game.upgradeSelectedTurretLink();
      game.grantGem(GemType.attackSpeed);
      game.equipSelectedTurret(GemType.attackSpeed);
      game.selectSelectedTurretGemSlot(1);
      game.grantGem(GemType.explosion);
      game.equipSelectedTurret(GemType.explosion);
    }
  }
  await game.saveNow();
  final json = repository.data!.toJson();
  final run = json['activeRun']! as Map<String, Object?>;
  expect(run['turrets'] as List, hasLength(7));
  run['phase'] = GamePhase.reward.name;
  run['isPurchasedGemReward'] = true;
  run['rewardOptions'] = ['chain', 'range', 'attackSpeed'];
  repository.data = GameSaveData.fromJson(json)!;
  return repository;
}

void main() {
  for (final viewport in [
    const Size(320, 800),
    const Size(390, 844),
    const Size(640, 360),
  ]) {
    testWidgets('실제 GameHud 젬 장착 통합 $viewport', (tester) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        for (final family in ['NotoSansKR', 'Ahem', 'Roboto', 'sans-serif']) {
          await (FontLoader(
            family,
          )..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'))).load();
        }
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      final repository = (await tester.runAsync(_fixture))!;
      final initialSave = repository.data!;
      var game = RuneNexusGame(saveRepository: repository);
      final boundaryKey = GlobalKey();
      Future<void> mount() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(
              textTheme: ThemeData.dark().textTheme.apply(
                fontFamily: 'NotoSansKR',
              ),
            ),
            home: RepaintBoundary(
              key: boundaryKey,
              child: Scaffold(
                body: GameHud(key: ObjectKey(game), game: game),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => game.loaded.timeout(const Duration(seconds: 20)),
        );
        await tester.runAsync(() => game.ready());
        game.pauseEngine();
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (final image in tester.widgetList<Image>(find.byType(Image))) {
            await precacheImage(
              image.image,
              tester.element(find.byType(Scaffold)),
            );
          }
        });
        await tester.pumpAndSettle();
      }

      Future<void> capture(String suffix) async {
        await tester.runAsync(() async {
          for (final image in tester.widgetList<Image>(find.byType(Image))) {
            await precacheImage(
              image.image,
              tester.element(find.byType(Scaffold)),
            );
          }
        });
        await tester.pumpAndSettle();
        // 폰트 미지정 버튼만 테스트 엔진 글꼴 보정. 제품 UI 변경 없음.
        for (final element in find.byType(RichText).evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          final span = paragraph.text as TextSpan;
          if (span.style?.fontFamily == null) {
            paragraph.text = TextSpan(
              text: span.text,
              children: span.children,
              style: (span.style ?? const TextStyle()).copyWith(
                fontFamily: 'NotoSansKR',
              ),
            );
          }
        }
        await tester.pump();
        expect(tester.takeException(), isNull);
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'design/ux-previews/gem-equip-themed/implemented/game_${viewport.width.toInt()}x${viewport.height.toInt()}_$suffix.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await mount();
      await capture('choices');
      final worldPositions = {
        for (final turret in game.children.whereType<TurretComponent>())
          turret.gridPoint: turret.position.clone(),
      };
      final originalDistanceScale = game.boardDistanceScale;
      final originalOrigin = game.debugBoardOrigin();
      final originalSize = game.debugBoardSize();
      await tester.tap(find.text('연쇄').first);
      await tester.pumpAndSettle();
      expect(game.snapshotNotifier.value.pendingRewardGem, GemType.chain);
      expect(
        game.gemRewardTargetStatus(_fullCannon),
        GemRewardTargetStatus.replacement,
      );
      expect(
        game.gemRewardTargetStatus(_emptyArrow),
        GemRewardTargetStatus.available,
      );
      expect(
        game.gemRewardTargetStatus(_duplicateArrow),
        GemRewardTargetStatus.unavailable,
      );
      expect(
        game.gemRewardTargetStatus(_frost),
        GemRewardTargetStatus.unavailable,
      );
      expect(game.boardDistanceScale, originalDistanceScale);
      expect(game.debugBoardOrigin(), originalOrigin);
      expect(game.debugBoardSize(), originalSize);
      for (final turret in game.children.whereType<TurretComponent>()) {
        expect(turret.position, worldPositions[turret.gridPoint]);
      }
      await capture('target');

      // 실제 화면 앵커를 확보한 뒤 취소하고 동일 좌표로 전장 터치.
      game.selectRewardGemTarget(_fullCannon);
      await tester.pumpAndSettle();
      final anchor = game.gemRewardReplacementAnchor!;
      game.cancelRewardGemReplacement();
      await tester.pumpAndSettle();
      final boardFinder = find.descendant(
        of: find.byType(HudGemRewardTargetOverlay),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.key is GlobalKey,
        ),
      );
      expect(boardFinder, findsOneWidget);
      final board = tester.getRect(boardFinder);
      await tester.tapAt(
        board.topLeft +
            Offset(anchor.dx * board.width, anchor.dy * board.height),
      );
      await tester.pumpAndSettle();
      expect(game.snapshotNotifier.value.rewardReplacementPoint, _fullCannon);
      expect(find.text('이 젬과 교체'), findsNWidgets(2));
      await capture('replacement');
      await tester.ensureVisible(find.text('타워 다시 선택'));
      await tester.pumpAndSettle();
      if (viewport.width > viewport.height) {
        await capture('replacement_scrolled');
      }
      await tester.tap(find.text('타워 다시 선택'));
      await tester.pumpAndSettle();
      expect(game.snapshotNotifier.value.rewardReplacementPoint, isNull);
      expect(game.selectRewardGemTarget(_emptyArrow), isTrue);
      await tester.pumpAndSettle();
      expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
      expect(game.paused, isTrue);
      await game.saveNow();
      expect(
        repository.data!.activeRun!.turrets
            .firstWhere((turret) => turret.point == _emptyArrow)
            .equippedGemSlots,
        [GemType.chain],
      );

      // 동일 실저장 보상에서 보관 종료도 UI 버튼으로 검증.
      await tester.pumpWidget(const SizedBox.shrink());
      repository.data = initialSave;
      game = RuneNexusGame(saveRepository: repository);
      await mount();
      await tester.tap(find.text('연쇄').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('보관'));
      await tester.pumpAndSettle();
      expect(game.snapshotNotifier.value.gemInventory[GemType.chain], 1);
      expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
      expect(game.paused, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
