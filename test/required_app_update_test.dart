import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/app/app_update_gate.dart';
import 'package:rune_nexus/platform/update/app_update_service.dart';

import 'app_update_service_test.dart' show manifest;

void main() {
  const channel = MethodChannel('rune_nexus/app_update');
  test(
    'minimum version is optional for legacy manifests and strictly validated',
    () {
      expect(
        AppUpdateRelease.parse(
          jsonEncode(manifest()),
        ).minimumSupportedVersionCode,
        0,
      );
      for (final value in [-1, 999999, '2', 1.5]) {
        expect(
          () => AppUpdateRelease.parse(
            jsonEncode(manifest()..['minimumSupportedVersionCode'] = value),
          ),
          throwsFormatException,
        );
      }
    },
  );
  testWidgets('resume checks block input and preserve the mounted game state', (
    tester,
  ) async {
    var installs = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'getInstalledVersion') {
        return {'versionCode': 1, 'packageName': 'com.example.rune_nexus'};
      }
      if (call.method == 'installUpdate') {
        installs++;
        return 'installerOpened';
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    var response = Future.value(jsonEncode(manifest()..['versionCode'] = 1));
    var checks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppUpdateGate(
          service: AppUpdateService(
            manifestUrl: 'https://example.com/update.json',
            readManifest: (_) {
              checks++;
              return response;
            },
          ),
          child: const _StatefulGame(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Count 0'));
    await tester.pump();
    final originalState = tester.state(find.byType(_StatefulGame));
    final pending = Completer<String>();
    response = pending.future;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('업데이트 확인 중'), findsOneWidget);
    expect(find.text('Count 1'), findsNothing);
    expect(find.text('현재 버전으로 계속'), findsNothing);
    pending.complete(jsonEncode(manifest()..['versionCode'] = 1));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(_StatefulGame)), same(originalState));
    expect(find.text('Count 1'), findsOneWidget);

    response = Future.value(
      jsonEncode(
        manifest()
          ..['versionCode'] = 3
          ..['minimumSupportedVersionCode'] = 2,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(checks, 3);
    expect(find.text('필수 업데이트가 있습니다'), findsOneWidget);
    expect(find.text('Count 1'), findsNothing);
    expect(find.text('현재 버전으로 계속'), findsNothing);
    expect(
      tester.state(find.byType(_StatefulGame, skipOffstage: false)),
      same(originalState),
    );
    await tester.ensureVisible(find.text('업데이트'));
    await tester.tap(find.text('업데이트'));
    await tester.pumpAndSettle();
    expect(installs, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      installs,
      1,
      reason: 'Returning from installer must not start another install',
    );
    expect(find.text('현재 버전으로 계속'), findsNothing);
    expect(find.text('Count 1'), findsNothing);
  });

  testWidgets(
    'failed resume check cannot reuse optional release to bypass gate',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => {
          'versionCode': 1,
          'packageName': 'com.example.rune_nexus',
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      var fail = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AppUpdateGate(
            service: AppUpdateService(
              manifestUrl: 'https://example.com/update.json',
              readManifest: (_) async {
                if (fail) throw StateError('offline');
                return jsonEncode(manifest()..['versionCode'] = 3);
              },
            ),
            child: const _StatefulGame(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('현재 버전으로 계속'));
      await tester.tap(find.text('현재 버전으로 계속'));
      await tester.pumpAndSettle();
      fail = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('현재 버전으로 계속'), findsNothing);
      expect(find.text('Count 0'), findsNothing);
      await tester.ensureVisible(find.text('다시 확인'));
      await tester.tap(find.text('다시 확인'));
      await tester.pumpAndSettle();
      expect(find.text('현재 버전으로 계속'), findsNothing);
      expect(find.text('Count 0'), findsNothing);
    },
  );

  for (final installed in [1, 2]) {
    testWidgets(
      'minimum version 2 blocks only older installed version $installed',
      (tester) async {
        var installs = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            if (call.method == 'getInstalledVersion') {
              return {
                'versionCode': installed,
                'packageName': 'com.example.rune_nexus',
              };
            }
            if (call.method == 'installUpdate') {
              installs++;
              return 'installerOpened';
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final release = manifest()
          ..['versionCode'] = 3
          ..['minimumSupportedVersionCode'] = 2;
        await tester.pumpWidget(
          MaterialApp(
            home: AppUpdateGate(
              service: AppUpdateService(
                manifestUrl: 'https://example.com/update.json',
                readManifest: (_) async => jsonEncode(release),
              ),
              child: const Text('게임 진입'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (installed == 1) {
          expect(find.text('필수 업데이트가 있습니다'), findsOneWidget);
          expect(find.text('현재 버전으로 계속'), findsNothing);
          await tester.ensureVisible(find.text('업데이트'));
          await tester.tap(find.text('업데이트'));
          await tester.pumpAndSettle();
          expect(installs, 1);
          expect(find.text('게임 진입'), findsNothing);
          expect(find.text('현재 버전으로 계속'), findsNothing);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('게임 진입'), findsNothing);
        } else {
          await tester.ensureVisible(find.text('현재 버전으로 계속'));
          await tester.tap(find.text('현재 버전으로 계속'));
          await tester.pumpAndSettle();
          expect(find.text('게임 진입'), findsOneWidget);
        }
      },
    );
  }
}

class _StatefulGame extends StatefulWidget {
  const _StatefulGame();
  @override
  State<_StatefulGame> createState() => _StatefulGameState();
}

class _StatefulGameState extends State<_StatefulGame> {
  int count = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('Count $count'),
  );
}
