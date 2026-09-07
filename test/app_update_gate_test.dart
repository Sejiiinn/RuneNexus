import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/app/app_update_gate.dart';
import 'package:rune_nexus/platform/update/app_update_service.dart';

import 'app_update_service_test.dart' show manifest, patchManifest;

void main() {
  const channel = MethodChannel('rune_nexus/app_update');
  testWidgets('설치 권한 복귀와 설치 취소 후 재시도는 다운로드를 반복하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var downloads = 0;
    var installs = 0;
    final download = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      switch (call.method) {
        case 'getInstalledVersion':
          return {'versionCode': 1, 'packageName': 'com.example.rune_nexus'};
        case 'downloadUpdate':
          downloads++;
          await download.future;
          return null;
        case 'installUpdate':
          installs++;
          return installs == 1 ? 'permissionRequired' : 'installerOpened';
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      AppUpdateGate(
        service: AppUpdateService(
          manifestUrl: 'https://example.com/update.json',
          readManifest: (_) async => jsonEncode(manifest()),
        ),
        child: const MaterialApp(home: Text('게임 진입')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('게임 진입'), findsNothing);
    await tester.tap(find.text('업데이트'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    download.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('설정에서 이 앱의 설치를 허용'), findsOneWidget);
    await tester.tap(find.text('설치 계속'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설치 계속'));
    await tester.pumpAndSettle();
    expect(downloads, 1);
    expect(installs, 3);
    await tester.tap(find.text('현재 버전으로 계속'));
    await tester.pumpAndSettle();
    expect(find.text('게임 진입'), findsOneWidget);
  });

  testWidgets('확인 실패에도 재시도와 현재 버전 진입을 제공한다', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => {'versionCode': 1, 'packageName': 'com.example.rune_nexus'},
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    var checks = 0;
    await tester.pumpWidget(
      AppUpdateGate(
        service: AppUpdateService(
          manifestUrl: 'https://example.com/update.json',
          readManifest: (_) async {
            checks++;
            throw StateError('offline');
          },
        ),
        child: const MaterialApp(home: Text('게임 진입')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('다시 확인'));
    await tester.pumpAndSettle();
    expect(checks, 2);
    await tester.tap(find.text('현재 버전으로 계속'));
    await tester.pumpAndSettle();
    expect(find.text('게임 진입'), findsOneWidget);
  });
  testWidgets('패치 실패 시 전체 다운로드 전환을 안내하고 전체 실패 때 설치하지 않는다', (tester) async {
    final patchDone = Completer<void>();
    final fullDone = Completer<void>();
    var installs = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'getInstalledVersion') {
        return {
          'versionCode': 2,
          'packageName': 'com.example.rune_nexus',
          'apkSha256': 'b' * 64,
        };
      }
      if (call.method == 'downloadPatch') {
        await patchDone.future;
        throw PlatformException(code: 'update_patch_failed');
      }
      if (call.method == 'downloadUpdate') {
        await fullDone.future;
        throw PlatformException(code: 'update_failed');
      }
      if (call.method == 'installUpdate') installs++;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final value = manifest(version: 3)..['patches'] = [patchManifest()];
    await tester.pumpWidget(
      AppUpdateGate(
        service: AppUpdateService(
          manifestUrl: 'https://example.com/update.json',
          readManifest: (_) async => jsonEncode(value),
        ),
        child: const MaterialApp(home: Text('게임 진입')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('변경분 다운로드'), findsOneWidget);
    await tester.tap(find.text('업데이트'));
    await tester.pump();
    expect(find.text('변경분을 다운로드하고 새 APK를 복원하는 중'), findsOneWidget);
    patchDone.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('변경분을 적용하지 못해 전체 앱을 다운로드하는 중'), findsOneWidget);
    fullDone.complete();
    await tester.pumpAndSettle();
    expect(installs, 0);
    expect(find.textContaining('업데이트를 완료하지 못했습니다'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
