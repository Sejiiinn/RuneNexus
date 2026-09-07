import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/platform/update/app_update_service.dart';

Map<String, Object> manifest({int version = 2}) => {
  'schemaVersion': 1,
  'versionCode': version,
  'versionName': '0.1.1',
  'packageName': 'com.example.rune_nexus',
  'apkUrl':
      'https://github.com/Sejiiinn/RuneNexus/releases/download/apk-2/app.apk',
  'sha256': 'a' * 64,
  'sizeBytes': 1024,
  'notes': '업데이트 테스트',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('rune_nexus/app_update');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {
        'versionCode': 2,
        'versionName': '0.1.1',
        'packageName': 'com.example.rune_nexus',
      },
    );
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('새 버전만 안내하고 동일 버전과 다운그레이드는 제외한다', () async {
    for (final version in [1, 2, 3]) {
      final service = AppUpdateService(
        manifestUrl: 'https://example.com/update.json',
        readManifest: (_) async => jsonEncode(manifest(version: version)),
      );
      expect((await service.check())?.versionCode, version == 3 ? 3 : null);
    }
  });
  test('잘못된 메타데이터, 비 HTTPS 주소, 다른 패키지는 거부한다', () async {
    for (final entry in <String, Object>{
      'schemaVersion': 2,
      'versionCode': 1.5,
      'sizeBytes': 0,
      'sha256': 'bad',
      'apkUrl': 'http://example.com/app.apk',
      'packageName': 'other.app',
    }.entries) {
      final value = manifest()..[entry.key] = entry.value;
      final service = AppUpdateService(
        manifestUrl: 'https://example.com/update.json',
        readManifest: (_) async => jsonEncode(value),
      );
      await expectLater(service.check(), throwsFormatException);
    }
  });
  test('APK 검증 정보와 대상 버전을 Android에 전달한다', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'installUpdate' ? 'permissionRequired' : null;
    });
    final release = AppUpdateRelease.parse(jsonEncode(manifest()));
    final service = AppUpdateService();
    await service.download(release);
    expect(calls.single.arguments, {
      'url': release.apkUrl.toString(),
      'sha256': release.sha256,
      'sizeBytes': 1024,
      'versionCode': 2,
    });
    expect(await service.install(release), 'permissionRequired');
    expect(calls.last.arguments, {'versionCode': 2});
  });
  test('설치 버전과 APK 해시가 맞는 패치만 선택한다', () async {
    for (final hash in ['b' * 64, 'c' * 64, null]) {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'getInstalledVersion') {
          return {
            'versionCode': 2,
            'packageName': 'com.example.rune_nexus',
            'apkSha256': hash,
          };
        }
        return null;
      });
      final value = manifest(version: 3)..['patches'] = [patchManifest()];
      final service = AppUpdateService(
        manifestUrl: 'https://example.com/update.json',
        readManifest: (_) async => jsonEncode(value),
      );
      final release = (await service.check())!;
      await service.download(release);
      expect(calls.last, hash == 'b' * 64 ? 'downloadPatch' : 'downloadUpdate');
    }
  });

  test('패치 적용 실패 시 전체 APK를 한 번 다운로드하고 검증 정보를 유지한다', () async {
    final calls = <MethodCall>[];
    final transfers = <AppUpdateTransfer>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getInstalledVersion') {
        return {
          'versionCode': 2,
          'packageName': 'com.example.rune_nexus',
          'apkSha256': 'b' * 64,
        };
      }
      if (call.method == 'downloadPatch') {
        throw PlatformException(code: 'update_patch_failed');
      }
      return null;
    });
    final value = manifest(version: 3)..['patches'] = [patchManifest()];
    final service = AppUpdateService(
      manifestUrl: 'https://example.com/update.json',
      readManifest: (_) async => jsonEncode(value),
    );
    final release = (await service.check())!;
    await service.download(release, onTransferChanged: transfers.add);
    expect(calls.map((call) => call.method), [
      'getInstalledVersion',
      'downloadPatch',
      'downloadUpdate',
    ]);
    expect(calls[1].arguments['targetSha256'], release.sha256);
    expect(calls[1].arguments['targetSizeBytes'], release.sizeBytes);
    expect(calls.last.arguments['sha256'], release.sha256);
    expect(transfers, [AppUpdateTransfer.patch, AppUpdateTransfer.fullApk]);
  });

  test('잘못된 선택적 패치 정보는 전체 APK 업데이트를 막지 않는다', () {
    for (final entry in <String, Object>{
      'format': 'unknown',
      'fromVersionCode': 3,
      'fromSha256': 'bad',
      'url': 'http://example.com/patch',
      'sizeBytes': 1024,
    }.entries) {
      final patch = patchManifest()..[entry.key] = entry.value;
      final value = manifest(version: 3)..['patches'] = [patch];
      final release = AppUpdateRelease.parse(jsonEncode(value));
      expect(release.patches, isEmpty);
      expect(release.sizeBytes, 1024);
    }
  });
}

Map<String, Object> patchManifest() => {
  'format': 'rune-apk-delta-v1',
  'fromVersionCode': 2,
  'fromSha256': 'b' * 64,
  'url':
      'https://github.com/Sejiiinn/RuneNexus/releases/download/apk-3/patch-from-2.rndelta',
  'sha256': 'd' * 64,
  'sizeBytes': 512,
};
