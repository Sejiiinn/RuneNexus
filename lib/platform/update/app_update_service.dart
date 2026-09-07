import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_update_manifest_stub.dart'
    if (dart.library.io) 'app_update_manifest_io.dart';

enum AppUpdateTransfer { patch, fullApk }

class AppUpdatePatch {
  const AppUpdatePatch({
    required this.fromVersionCode,
    required this.fromSha256,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
  });

  // 선택적 패치 정보가 잘못됐으면 전체 APK 경로 사용.
  static AppUpdatePatch? tryParse(
    Object? value,
    int targetVersion,
    int fullSize,
  ) {
    if (value is! Map<String, dynamic> ||
        value['format'] != 'rune-apk-delta-v1' ||
        value['fromVersionCode'] is! int ||
        value['fromVersionCode'] <= 0 ||
        value['fromVersionCode'] >= targetVersion ||
        value['fromSha256'] is! String ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value['fromSha256'] as String) ||
        value['sha256'] is! String ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value['sha256'] as String) ||
        value['sizeBytes'] is! int ||
        value['sizeBytes'] <= 0 ||
        value['sizeBytes'] >= fullSize ||
        value['url'] is! String) {
      return null;
    }
    final url = Uri.tryParse(value['url'] as String);
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasFragment) {
      return null;
    }
    return AppUpdatePatch(
      fromVersionCode: value['fromVersionCode'] as int,
      fromSha256: (value['fromSha256'] as String).toLowerCase(),
      url: url,
      sha256: (value['sha256'] as String).toLowerCase(),
      sizeBytes: value['sizeBytes'] as int,
    );
  }

  final int fromVersionCode;
  final String fromSha256;
  final Uri url;
  final String sha256;
  final int sizeBytes;
}

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.versionCode,
    required this.versionName,
    required this.packageName,
    required this.apkUrl,
    required this.sha256,
    required this.sizeBytes,
    required this.notes,
    this.patches = const [],
  });

  factory AppUpdateRelease.parse(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic> ||
        json['schemaVersion'] != 1 ||
        json['versionCode'] is! int ||
        json['versionCode'] <= 0 ||
        json['versionCode'] > 2100000000 ||
        json['versionName'] is! String ||
        (json['versionName'] as String).trim().isEmpty ||
        json['packageName'] is! String ||
        json['apkUrl'] is! String ||
        json['sha256'] is! String ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(json['sha256'] as String) ||
        json['sizeBytes'] is! int ||
        json['sizeBytes'] <= 0 ||
        json['sizeBytes'] > 512 * 1024 * 1024 ||
        json['notes'] is! String) {
      throw const FormatException('업데이트 정보가 올바르지 않습니다.');
    }
    final url = Uri.parse(json['apkUrl'] as String);
    if (url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasFragment) {
      throw const FormatException('APK 주소가 올바르지 않습니다.');
    }
    return AppUpdateRelease(
      versionCode: json['versionCode'] as int,
      versionName: json['versionName'] as String,
      packageName: json['packageName'] as String,
      apkUrl: url,
      sha256: (json['sha256'] as String).toLowerCase(),
      sizeBytes: json['sizeBytes'] as int,
      notes: json['notes'] as String,
      patches: List.unmodifiable([
        if (json['patches'] is List && (json['patches'] as List).length <= 3)
          for (final value in json['patches'] as List)
            ?AppUpdatePatch.tryParse(
              value,
              json['versionCode'] as int,
              json['sizeBytes'] as int,
            ),
      ]),
    );
  }

  final int versionCode;
  final String versionName;
  final String packageName;
  final Uri apkUrl;
  final String sha256;
  final int sizeBytes;
  final String notes;
  final List<AppUpdatePatch> patches;
}

class AppUpdateService {
  AppUpdateService({
    this.manifestUrl = const String.fromEnvironment(
      'RUNE_NEXUS_UPDATE_MANIFEST_URL',
    ),
    MethodChannel channel = const MethodChannel('rune_nexus/app_update'),
    Future<String> Function(Uri)? readManifest,
  }) : _channel = channel,
       _readManifest = readManifest ?? readUpdateManifest;

  static bool get enabled =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      const String.fromEnvironment('RUNE_NEXUS_UPDATE_MANIFEST_URL').isNotEmpty;

  final String manifestUrl;
  final MethodChannel _channel;
  final Future<String> Function(Uri) _readManifest;
  int? _installedVersion;
  String? _installedApkSha256;

  AppUpdatePatch? patchFor(AppUpdateRelease release) {
    AppUpdatePatch? selected;
    for (final patch in release.patches) {
      if (patch.fromVersionCode == _installedVersion &&
          patch.fromSha256 == _installedApkSha256 &&
          (selected == null || patch.sizeBytes < selected.sizeBytes)) {
        selected = patch;
      }
    }
    return selected;
  }

  Future<AppUpdateRelease?> check() async {
    final uri = Uri.parse(manifestUrl);
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const FormatException('업데이트 서버 주소가 올바르지 않습니다.');
    }
    final installed = await _channel.invokeMapMethod<String, dynamic>(
      'getInstalledVersion',
    );
    if (installed == null ||
        installed['versionCode'] is! int ||
        installed['packageName'] is! String) {
      throw const FormatException('설치된 앱 정보를 확인하지 못했습니다.');
    }
    _installedVersion = installed['versionCode'] as int;
    final installedHash = installed['apkSha256'];
    _installedApkSha256 = installedHash is String
        ? installedHash.toLowerCase()
        : null;
    final release = AppUpdateRelease.parse(await _readManifest(uri));
    if (release.packageName != installed['packageName']) {
      throw const FormatException('다른 앱의 업데이트입니다.');
    }
    return release.versionCode > (installed['versionCode'] as int)
        ? release
        : null;
  }

  Future<void> download(
    AppUpdateRelease release, {
    ValueChanged<AppUpdateTransfer>? onTransferChanged,
  }) async {
    final patch = patchFor(release);
    if (patch != null) {
      onTransferChanged?.call(AppUpdateTransfer.patch);
      try {
        await _channel.invokeMethod<void>('downloadPatch', {
          'url': patch.url.toString(),
          'sha256': patch.sha256,
          'sizeBytes': patch.sizeBytes,
          'versionCode': release.versionCode,
          'targetSha256': release.sha256,
          'targetSizeBytes': release.sizeBytes,
          'baseSha256': patch.fromSha256,
        });
        return;
      } on PlatformException {
        // 패치 실패는 설치로 이어지지 않으며 전체 APK도 동일 검증 수행.
      } on MissingPluginException {
        // 패치 도구가 없는 이전 클라이언트와의 호환 경로.
      }
    }
    onTransferChanged?.call(AppUpdateTransfer.fullApk);
    await _channel.invokeMethod<void>('downloadUpdate', {
      'url': release.apkUrl.toString(),
      'sha256': release.sha256,
      'sizeBytes': release.sizeBytes,
      'versionCode': release.versionCode,
    });
  }

  Future<String> install(AppUpdateRelease release) async {
    final result = await _channel.invokeMethod<String>('installUpdate', {
      'versionCode': release.versionCode,
    });
    if (result != 'permissionRequired' && result != 'installerOpened') {
      throw const FormatException('설치 화면을 열지 못했습니다.');
    }
    return result!;
  }
}
