import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../test/helpers/widget_test_helpers.dart';

// flutter test tool/gem_reward_render_test.dart
void main() {
  for (final size in [const Size(320, 800), const Size(640, 360)]) {
    testWidgets('오프라인 실제 젬 보상 UI 캡처 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await (FontLoader(
          'NotoSansKR',
        )..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'))).load();
        // 독립 DefaultTextStyle도 테스트 기본 글꼴 대신 한글 글꼴 사용.
        for (final family in ['Ahem', 'Roboto', 'sans-serif']) {
          await (FontLoader(
            family,
          )..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'))).load();
        }
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      final boundaryKey = GlobalKey();
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());
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
              body: HudRewardOverlay(
                game: game,
                snapshot: resultSnapshot(
                  phase: GamePhase.reward,
                  currentStageNumber: 1,
                  completedRounds: 5,
                  gemShards: 12,
                  rewardOptions: const [
                    GemType.explosion,
                    GemType.chain,
                    GemType.heavyWeapon,
                  ],
                ),
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
      final viewport = '${size.width.toInt()}x${size.height.toInt()}';
      Future<void> capture(String state) async {
        // 폰트 미지정 커스텀 버튼: 오프라인 엔진 기본 글꼴만 보정.
        // 실제 위젯의 문구·스타일 수치·레이아웃은 그대로 유지.
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
          final output = File(
            'design/ux-previews/gem-rules/reward_${viewport}_$state.png',
          );
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('choices');
      await tester.tap(find.text('연쇄'));
      await tester.pumpAndSettle();
      await capture('selected');
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('gem-reward-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      if (scrollable.position.maxScrollExtent > 0) {
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pumpAndSettle();
        await capture('scrolled');
      }
    });
  }
}
