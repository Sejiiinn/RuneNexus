import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../test/helpers/widget_test_helpers.dart';

// flutter test tool/core_tree_render_test.dart
// 실제 MainMenuScreen 위젯 + 고정 진행 상태의 오프라인 테스트 렌더.
void main() {
  testWidgets('코어 트리 스프라이트 적용 테스트 렌더', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      // 독립 텍스트의 테스트 기본 글꼴까지 한글 표시 지원.
      for (final family in ['NotoSansKR', 'Ahem', 'Roboto', 'sans-serif']) {
        await (FontLoader(
          family,
        )..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'NotoSansKR'),
        locale: const Locale('ko'),
        localizationsDelegates: const [
          RuneNexusLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: RuneNexusLocalizations.supportedLocales,
        home: RepaintBoundary(
          key: boundaryKey,
          child: Scaffold(
            body: MainMenuScreen(
              game: RuneNexusGame(saveRepository: MemorySaveRepository()),
              snapshot: resultSnapshot(
                phase: GamePhase.preparation,
                currentStageNumber: 6,
                unlockedStageCount: 6,
                clearedStageNumbers: const {1, 2, 3, 4, 5},
                totalCorePoints: 30,
                spentCorePoints: 23,
                availableCorePoints: 7,
                corePassiveNodeRanks: const {
                  CorePassiveNodeId.attackHaste: 3,
                  CorePassiveNodeId.attackPrecompute: 3,
                  CorePassiveNodeId.attackGuardianBeam: 3,
                  CorePassiveNodeId.attackOverclock: 1,
                },
                coreCombatSkill: CoreCombatSkill.guardianBeam,
              ),
              selectedTab: MainMenuTab.core,
              onSelectTab: (_) {},
              onStartStage: (_) {},
            ),
          ),
        ),
      ),
    );
    await pumpGameFrames(tester);

    await tester.runAsync(() async {
      final context = tester.element(find.byType(MainMenuScreen));
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(image.image, context);
      }
    });
    await tester.pump(const Duration(milliseconds: 300));
    // 폰트 미지정 버튼의 오프라인 엔진 기본 글꼴만 보정.
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
    expect(
      find.byKey(const ValueKey('core-passive-center-select')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File(
        'design/core_tree_concepts/production/core-tree-sprites-test.png',
      );
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
