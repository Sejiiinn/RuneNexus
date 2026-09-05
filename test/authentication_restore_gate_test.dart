import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  const configured =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID') != '' &&
      String.fromEnvironment('RUNE_NEXUS_API_BASE_URL') != '';
  const sessionChannel = MethodChannel('rune_nexus/session_storage');
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  group(
    '인증 구성 활성화 시작 경계',
    () {
      testWidgets(
        '세션 판정 전에는 게스트 저장을 읽지 않고 세션 없음 확인 뒤 진입한다',
        (tester) async {
          late Directory directory;
          await tester.runAsync(() async {
            directory = await Directory.systemTemp.createTemp(
              'rune_nexus_gate_',
            );
            final saveFile = File('${directory.path}/saves/guest/save_v2.json');
            await saveFile.parent.create(recursive: true);
            await saveFile.writeAsString(
              jsonEncode({
                'version': 2,
                'savedAtMillis': 100,
                'preferences': <String, Object?>{},
                'progression': {'runes': 2468},
                'turretModules': <String, Object?>{},
                'activeRun': null,
              }),
            );
          });
          addTearDown(() => directory.delete(recursive: true));
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          final sessionRead = Completer<String?>();
          var sessionReads = 0;
          var pathRequests = 0;
          messenger.setMockMethodCallHandler(sessionChannel, (call) async {
            expect(call.method, 'read');
            sessionReads++;
            return sessionRead.future;
          });
          messenger.setMockMethodCallHandler(pathChannel, (call) async {
            expect(call.method, 'getApplicationSupportDirectory');
            pathRequests++;
            return directory.path;
          });
          addTearDown(() {
            messenger.setMockMethodCallHandler(sessionChannel, null);
            messenger.setMockMethodCallHandler(pathChannel, null);
          });

          await tester.pumpWidget(const RuneNexusApp());
          await tester.pump(const Duration(seconds: 1));

          expect(sessionReads, 1);
          expect(pathRequests, 0);
          expect(find.byType(MainMenuScreen), findsNothing);
          expect(find.text('초기화에 실패했습니다'), findsNothing);

          sessionRead.complete(null);
          await pumpUntilLoadedApp(tester);

          expect(pathRequests, 1);
          expect(
            tester
                .widget<MainMenuScreen>(find.byType(MainMenuScreen))
                .game
                .snapshotNotifier
                .value
                .runes,
            2468,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant({TargetPlatform.android}),
      );

      testWidgets(
        '세션 저장소 일시 장애와 재시도 중에도 게스트 진입을 막는다',
        (tester) async {
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          var sessionReads = 0;
          var pathRequests = 0;
          messenger.setMockMethodCallHandler(sessionChannel, (call) async {
            expect(call.method, 'read');
            sessionReads++;
            throw PlatformException(code: 'session_storage_unavailable');
          });
          messenger.setMockMethodCallHandler(pathChannel, (call) async {
            pathRequests++;
            throw StateError('세션 장애 중 게스트 저장소를 조회하면 안 됩니다.');
          });
          addTearDown(() {
            messenger.setMockMethodCallHandler(sessionChannel, null);
            messenger.setMockMethodCallHandler(pathChannel, null);
          });

          await tester.pumpWidget(const RuneNexusApp());
          await _pumpUntilError(tester);

          expect(sessionReads, 1);
          expect(pathRequests, 0);
          expect(find.byType(MainMenuScreen), findsNothing);
          await tester.tap(find.text('다시 시도'));
          await tester.pump();
          await _pumpUntilError(tester);

          expect(sessionReads, 2);
          expect(pathRequests, 0);
          expect(find.byType(MainMenuScreen), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant({TargetPlatform.android}),
      );
    },
    skip: configured
        ? false
        : 'GOOGLE_WEB_CLIENT_ID와 RUNE_NEXUS_API_BASE_URL dart-define이 필요한 인증 시작 통합 테스트',
  );
}

Future<void> _pumpUntilError(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    if (find.text('초기화에 실패했습니다').evaluate().isNotEmpty) return;
  }
  fail('세션 저장소 오류 화면이 표시되지 않았습니다.');
}
