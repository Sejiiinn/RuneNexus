import 'package:rune_nexus/data/save/account_save_selection.dart';
import 'package:rune_nexus/ui/account/account_save_selection_dialog.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  testWidgets('현재 기록과 Google 계정 기록만 구분해 표시한다', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final state = AccountSaveSelectionState(
      accountId: '0198b955-3656-7c40-b3cb-87f427b90be2',
      currentProgress: _saveData(10, totalPlayTimeMillis: 65 * 60 * 1000),
      accountProgress: _saveData(30, totalPlayTimeMillis: 25 * 60 * 60 * 1000),
      remoteRevision: 4,
    );

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
        home: Scaffold(body: AccountSaveSelectionDialog(state: state)),
      ),
    );
    await pumpGameFrames(tester);

    expect(find.text('Google 계정에 사용할 기록'), findsOneWidget);
    expect(find.text('현재 플레이 기록'), findsOneWidget);
    expect(find.text('Google 계정 기록'), findsOneWidget);
    expect(find.text('이 기기의 계정 진행'), findsNothing);
    expect(find.text('클라우드 진행'), findsNothing);
    expect(find.text('총 플레이타임 1시간 5분'), findsOneWidget);
    expect(find.text('총 플레이타임 1일 1시간'), findsOneWidget);
    expect(find.text('선택을 적용하기 전에 현재 기록과 기존 계정 기록을 백업합니다.'), findsOneWidget);
    for (final choice in state.availableChoices) {
      expect(
        find.byKey(ValueKey('account-save-choice-${choice.name}')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });
}

GameSaveData _saveData(int savedAtMillis, {required int totalPlayTimeMillis}) {
  return GameSaveData.fromJson(<String, Object?>{
    'version': 2,
    'savedAtMillis': savedAtMillis,
    'preferences': const <String, Object?>{'selectedStageNumber': 3},
    'progression': <String, Object?>{
      'runes': 25,
      'totalPlayTimeMillis': totalPlayTimeMillis,
    },
    'turretModules': const <String, Object?>{},
    'activeRun': null,
  })!;
}
