import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  testWidgets('저장 읽기 실패 후 시작 재시도는 새 게임으로 원래 진행을 다시 읽는다', (tester) async {
    late Directory directory;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('rune_nexus_startup_');
      final saveFile = File('${directory.path}/saves/guest/save_v2.json');
      await saveFile.parent.create(recursive: true);
      await saveFile.writeAsString(
        jsonEncode({
          'version': 2,
          'savedAtMillis': 100,
          'preferences': <String, Object?>{},
          'progression': {'runes': 4321},
          'turretModules': <String, Object?>{},
          'activeRun': null,
        }),
      );
    });
    addTearDown(() => directory.delete(recursive: true));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var pathRequests = 0;
    messenger.setMockMethodCallHandler(pathChannel, (call) async {
      expect(call.method, 'getApplicationSupportDirectory');
      pathRequests++;
      if (pathRequests == 1) {
        throw PlatformException(code: 'storage_temporarily_unavailable');
      }
      return directory.path;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(pathChannel, null));

    await tester.pumpWidget(const RuneNexusApp());
    await pumpUntilFound(tester, find.text('초기화에 실패했습니다'));
    expect(pathRequests, 1);
    expect(find.byType(MainMenuScreen), findsNothing);

    await tester.tap(find.text('다시 시도'));
    await pumpUntilLoadedApp(tester);

    expect(pathRequests, 2);
    final menu = tester.widget<MainMenuScreen>(find.byType(MainMenuScreen));
    expect(menu.game.snapshotNotifier.value.runes, 4321);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('저장소 장애가 계속되면 시작 재시도도 메인 진입을 차단한다', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var pathRequests = 0;
    messenger.setMockMethodCallHandler(pathChannel, (call) async {
      pathRequests++;
      throw PlatformException(code: 'storage_temporarily_unavailable');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(pathChannel, null));

    await tester.pumpWidget(const RuneNexusApp());
    await pumpUntilFound(tester, find.text('초기화에 실패했습니다'));
    expect(pathRequests, 1);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await pumpUntilFound(tester, find.text('초기화에 실패했습니다'));

    expect(pathRequests, 2);
    expect(find.byType(MainMenuScreen), findsNothing);
    expect(find.text('다시 시도'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
