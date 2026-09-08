import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:rune_nexus/ui/hud/gem_reward_target_overlay.dart';

import '../test/helpers/widget_test_helpers.dart';

// 오프라인 UI 영역 검증. 전장·카메라 통합은 실제 GameHud 캡처에서 검증.
void main() {
  for (final viewport in [const Size(320, 800), const Size(640, 360)]) {
    for (final replacement in [false, true]) {
      testWidgets('젬 대상 선택 실제 위젯 $viewport 교체=$replacement', (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          for (final family in ['NotoSansKR', 'Ahem', 'Roboto', 'sans-serif']) {
            await (FontLoader(family)
                  ..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf')))
                .load();
          }
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
        final boundaryKey = GlobalKey();
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
                backgroundColor: const Color(0xFF07111D),
                body: HudGemRewardTargetOverlay(
                  game: RuneNexusGame(saveRepository: MemorySaveRepository()),
                  snapshot: resultSnapshot(
                    phase: GamePhase.reward,
                    currentStageNumber: 1,
                    pendingRewardGem: GemType.chain,
                    clearedStageNumbers: const {3, 6},
                    rewardReplacementPoint: replacement
                        ? const GridPoint(2, 0)
                        : null,
                    selectedTurretName: replacement ? '대포' : null,
                    selectedTurretLevel: 2,
                    selectedTurretSlotLimit: 2,
                    selectedTurretGems: replacement
                        ? const [GemType.attackSpeed, GemType.explosion]
                        : const [],
                  ),
                  topInset: 80,
                  onBoardViewportChanged: (_) {},
                ),
              ),
            ),
          ),
        );
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
        final prefix =
            'target_${viewport.width.toInt()}x${viewport.height.toInt()}_${replacement ? 'replacement' : 'select'}';
        Future<void> capture(String suffix) async {
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
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'design/ux-previews/gem-equip-themed/implemented/$prefix$suffix.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('');
        if (replacement && viewport.width > viewport.height) {
          await tester.ensureVisible(find.text('타워 다시 선택'));
          await tester.pumpAndSettle();
          await capture('_scrolled');
        }
      });
    }
  }
}
