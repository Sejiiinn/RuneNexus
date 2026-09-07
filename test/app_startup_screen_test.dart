import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/app/app_startup_screen.dart';
import 'package:rune_nexus/app/app_update_gate.dart';
import 'package:rune_nexus/platform/update/app_update_service.dart';
import 'package:rune_nexus/ui/game/game_image_assets.dart';

void main() {
  if (const bool.fromEnvironment('CAPTURE_STARTUP')) {
    for (final update in [false, true]) {
      testWidgets('시작 화면 렌더 캡처 ${update ? "update" : "loading"}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        await tester.runAsync(() async {
          final loader = FontLoader('NotoSansKR')
            ..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'));
          await loader.load();
        });
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2ED3FF),
                brightness: Brightness.dark,
              ),
              fontFamily: 'NotoSansKR',
              useMaterial3: true,
            ),
            home: RepaintBoundary(
              key: boundaryKey,
              child: update
                  ? AppUpdateGate(
                      service: _CaptureUpdateService(),
                      child: const SizedBox.shrink(),
                    )
                  : const AppStartupScreen(status: '업데이트 확인 중'),
            ),
          ),
        );
        await tester.runAsync(() async {
          for (final asset in [
            mainMenuBackgroundAsset,
            gameLogoAsset,
            corePassiveTreeCoreAsset,
            gameButtonFrameAsset,
          ]) {
            await precacheImage(
              gameUiAssetImageProvider(asset),
              boundaryKey.currentContext!,
            );
          }
        });
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'design/screenshots/startup_${update ? "update" : "loading"}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }

  for (final size in [const Size(320, 568), const Size(740, 320)]) {
    for (final textScale in [1.0, 1.6]) {
      testWidgets('시작 화면 $size 글자 $textScale 배에서 긴 안내와 액션 접근', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var continued = false;
        final notes = List.filled(
          8,
          '룬의 힘을 강화하고 넥서스를 지키는 새로운 업데이트입니다. 다운로드와 설치 안내를 확인해 주세요.',
        ).join('\n');
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: AppStartupScreen(
              status: '새로운 업데이트를 사용할 수 있습니다',
              busy: false,
              details: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(notes),
                  FilledButton(
                    onPressed: () => continued = true,
                    child: const Text('현재 버전으로 계속'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text(notes), findsOneWidget);
        await tester.ensureVisible(find.text('현재 버전으로 계속'));
        await tester.pump();
        await tester.tap(find.text('현재 버전으로 계속'));
        expect(continued, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _CaptureUpdateService extends AppUpdateService {
  @override
  Future<AppUpdateRelease?> check() async => AppUpdateRelease(
    versionCode: 2,
    versionName: '0.2.0',
    packageName: 'com.example.rune_nexus',
    apkUrl: Uri.parse('https://example.com/update.apk'),
    sha256: 'a' * 64,
    sizeBytes: (12.4 * 1024 * 1024).round(),
    notes: '룬 각인과 넥서스의 시각 효과를 개선했습니다.\n더 안정적인 전투를 위해 게임 환경을 정비했습니다.',
  );
}
