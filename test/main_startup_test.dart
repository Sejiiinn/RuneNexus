import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/app/rune_nexus_app.dart';
import 'package:rune_nexus/main.dart' as entrypoint;

void main() {
  const failureMessage = '앱을 시작하지 못했습니다.\n잠시 후 다시 시도해 주세요.';

  testWidgets('시작 준비 예외와 재시도 실패에도 오류 화면을 유지한다', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    var attempts = 0;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        attempts++;
        throw PlatformException(code: 'startup_unavailable');
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await entrypoint.main();
    await tester.pumpAndSettle();
    expect(find.text(failureMessage), findsOneWidget);
    expect(find.byType(RuneNexusApp), findsNothing);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text(failureMessage), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('재시도 중 중복 실행을 막고 성공하면 앱으로 진입한다', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    final retry = Completer<void>();
    var attempts = 0;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        attempts++;
        if (attempts == 1) throw PlatformException(code: 'startup_unavailable');
        await retry.future;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await entrypoint.main();
    await tester.pumpAndSettle();
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(find.text('다시 시도 중…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('다시 시도 중…'));
    expect(attempts, 2);

    retry.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byType(RuneNexusApp), findsOneWidget);
    expect(find.text(failureMessage), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
