import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/domain/leaderboard/leaderboard.dart';
import 'package:rune_nexus/data/leaderboard/leaderboard_api.dart';
import 'package:rune_nexus/ui/game/game_image_assets.dart';
import 'package:rune_nexus/ui/menu/leaderboard_dialog.dart';

LeaderboardSnapshot exampleSnapshot() {
  final date = DateTime.utc(2026, 9, 8, 9, 30);
  final entries = List.generate(
    100,
    (index) => LeaderboardEntry(
      rank: index + 1,
      displayName: index == 0
          ? '별빛수호자#1042'
          : '룬기사${index + 1}#${1000 + index}',
      stageNumber: 12 - index ~/ 10,
      completedRounds: 20 - index % 10,
      achievedAt: date,
      isMe: false,
    ),
  );
  return LeaderboardSnapshot(
    rulesVersion: 1,
    asOf: date,
    entries: entries,
    myEntry: LeaderboardEntry(
      rank: 128,
      displayName: '루나#4821',
      stageNumber: 2,
      completedRounds: 14,
      achievedAt: date,
      isMe: true,
    ),
  );
}

Widget harness({
  Future<LeaderboardSnapshot> Function()? load,
  VoidCallback? onOpenAccount,
  Listenable? refreshListenable,
  double scale = 1,
  GlobalKey? boundaryKey,
}) => RepaintBoundary(
  key: boundaryKey,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'NotoSansKR'),
    ),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(lobbyBackgroundAsset, fit: BoxFit.cover),
            ),
            const Positioned.fill(child: ColoredBox(color: Color(0xA602070D))),
            LeaderboardDialog(
              load: load,
              onOpenAccount: onOpenAccount ?? () {},
              refreshListenable: refreshListenable,
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('로딩 후 실제 응답과 내 순위를 표시하고 수동 갱신한다', (tester) async {
    final completer = Completer<LeaderboardSnapshot>();
    var calls = 0;
    await tester.pumpWidget(
      harness(
        load: () {
          calls++;
          return calls == 1
              ? completer.future
              : Future.value(exampleSnapshot());
        },
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(exampleSnapshot());
    await tester.pumpAndSettle();
    expect(find.text('별빛수호자#1042'), findsOneWidget);
    expect(find.text('내 순위'), findsOneWidget);
    expect(find.text('128'), findsOneWidget);
    await tester.tap(find.byTooltip('순위 새로고침'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('게스트 계정 연결과 네트워크 오류 재시도', (tester) async {
    var opened = false;
    await tester.pumpWidget(harness(onOpenAccount: () => opened = true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('계정 연결'));
    expect(opened, isTrue);
    var calls = 0;
    await tester.pumpWidget(
      harness(
        load: () async {
          if (++calls == 1) throw StateError('offline');
          return exampleSnapshot();
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('순위를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('별빛수호자#1042'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('외부 갱신과 앱 복귀 시 재조회하며 이전 응답을 무시한다', (tester) async {
    final notifier = ChangeNotifier();
    addTearDown(notifier.dispose);
    final first = Completer<LeaderboardSnapshot>();
    var calls = 0;
    await tester.pumpWidget(
      harness(
        refreshListenable: notifier,
        load: () {
          calls++;
          return calls == 1 ? first.future : Future.value(exampleSnapshot());
        },
      ),
    );
    notifier.notifyListeners();
    await tester.pumpAndSettle();
    first.complete(
      LeaderboardSnapshot(
        rulesVersion: 1,
        asOf: DateTime.utc(2026),
        entries: const [],
        myEntry: null,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('별빛수호자#1042'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls, 3);
  });

  testWidgets('320×568 글자 2배에서도 목록만 스크롤하며 내 순위를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      harness(load: () async => exampleSnapshot(), scale: 2),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('루나#4821'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('leaderboard-list'))).height,
      greaterThan(100),
    );
    final footer = tester.getTopLeft(
      find.byKey(const ValueKey('leaderboard-my-rank')),
    );
    final close = tester.getTopLeft(find.byTooltip('닫기'));
    await tester.drag(
      find.byKey(const ValueKey('leaderboard-list')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('leaderboard-my-rank'))),
      footer,
    );
    expect(tester.getTopLeft(find.byTooltip('닫기')), close);
    expect(tester.takeException(), isNull);
  });

  testWidgets('가로 화면 글자 2배에서도 고정 정보와 목록 영역을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      harness(load: () async => exampleSnapshot(), scale: 2),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('루나#4821'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('leaderboard-list'))).height,
      greaterThan(50),
    );
  });

  testWidgets('진행 기록 동기화 실패 시 이전 순위를 지우고 정확한 재시도 안내를 표시한다', (tester) async {
    var calls = 0;
    const message =
        '현재 진행 기록을 서버에 저장하지 못해 순위를 갱신하지 않았습니다. 연결 상태를 확인한 뒤 다시 시도해 주세요.';
    await tester.pumpWidget(
      harness(
        load: () async {
          if (++calls == 1 || calls == 3) return exampleSnapshot();
          throw const LeaderboardException(
            code: 'LEADERBOARD_SAVE_SYNC_REQUIRED',
            message: message,
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('루나#4821'), findsOneWidget);
    await tester.tap(find.byTooltip('순위 새로고침'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    expect(find.text('루나#4821'), findsNothing);
    expect(find.text('별빛수호자#1042'), findsNothing);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('루나#4821'), findsOneWidget);
  });

  for (final status in [401, 403, null]) {
    testWidgets('인증 변경 $status 응답은 이전 순위와 내 기록을 지운다', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        harness(
          load: () async {
            if (++calls == 1) return exampleSnapshot();
            throw LeaderboardException(
              code: status == null
                  ? 'LEADERBOARD_SESSION_CHANGED'
                  : 'AUTH_REQUIRED',
              message: 'auth',
              statusCode: status,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('순위 새로고침'));
      await tester.pumpAndSettle();
      expect(find.text('별빛수호자#1042'), findsNothing);
      expect(find.text('계정 연결'), findsOneWidget);
      expect(find.text('계정 연결 후 확인할 수 있습니다.'), findsOneWidget);
    });
  }

  if (const bool.fromEnvironment('CAPTURE_LEADERBOARD')) {
    testWidgets('예시 데이터를 사용한 리더보드 시각 검증', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await (FontLoader(
          'NotoSansKR',
        )..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'))).load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      final key = GlobalKey();
      await tester.pumpWidget(
        harness(load: () async => exampleSnapshot(), boundaryKey: key),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final image in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(
            image.image,
            tester.element(find.byType(LeaderboardDialog)),
          );
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('design/leaderboard/implemented_preview.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
