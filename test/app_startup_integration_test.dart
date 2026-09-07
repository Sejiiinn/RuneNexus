import 'dart:async';

import 'package:rune_nexus/app/app_startup_screen.dart';
import 'package:rune_nexus/platform/update/app_update_service.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  for (final updateAvailable in [false, true]) {
    testWidgets(
      updateAvailable
          ? '업데이트 선택 전 저장 읽기를 보류하고 현재 버전 계속 후 시작한다'
          : '업데이트 확인 중 저장 읽기를 보류하고 최신 버전 확인 후 시작한다',
      (tester) async {
        final service = _PendingUpdateService();
        final repository = _CountingSaveRepository();
        final game = RuneNexusGame(saveRepository: repository);
        await tester.pumpWidget(
          RuneNexusApp(game: game, updateService: service),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(service.checks, 1);
        expect(repository.loads, 0);
        expect(find.byType(AppStartupScreen), findsOneWidget);
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(find.byType(MainMenuScreen), findsNothing);

        service.result.complete(
          updateAvailable
              ? AppUpdateRelease(
                  versionCode: 2,
                  versionName: '0.2.0',
                  packageName: 'com.example.rune_nexus',
                  apkUrl: Uri.parse('https://example.com/update.apk'),
                  sha256: 'a' * 64,
                  sizeBytes: 1024,
                  notes: '룬 넥서스 업데이트',
                )
              : null,
        );
        await tester.pump();
        if (updateAvailable) {
          expect(repository.loads, 0);
          await tester.ensureVisible(find.text('현재 버전으로 계속'));
          await tester.pump();
          await tester.tap(find.text('현재 버전으로 계속'));
          await tester.pump();
        }
        await pumpUntilLoadedApp(tester);
        expect(repository.loads, 1);
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(find.byType(MainMenuScreen), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

class _PendingUpdateService extends AppUpdateService {
  final result = Completer<AppUpdateRelease?>();
  int checks = 0;

  @override
  Future<AppUpdateRelease?> check() {
    checks++;
    return result.future;
  }
}

class _CountingSaveRepository extends MemorySaveRepository {
  int loads = 0;

  @override
  Future<GameSaveData?> load() {
    loads++;
    return super.load();
  }
}
