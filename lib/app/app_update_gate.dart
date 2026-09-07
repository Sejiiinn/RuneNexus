import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/update/app_update_service.dart';
import '../ui/game/game_palette.dart';

/// 게임 저장소를 열기 전 업데이트 확인 및 Android 설치 화면 연결.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({required this.child, this.service, super.key});

  final Widget child;
  final AppUpdateService? service;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  late final AppUpdateService _service = widget.service ?? AppUpdateService();
  AppUpdateRelease? _release;
  bool _checking = true;
  bool _busy = false;
  bool _downloaded = false;
  bool _continue = false;
  String? _error;
  String? _installMessage;
  AppUpdateTransfer? _transfer;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final release = await _service.check();
      if (!mounted) return;
      setState(() {
        _release = release;
        _continue = release == null;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _error = '업데이트 정보를 확인하지 못했습니다. 인터넷 연결을 확인하고 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _update() async {
    final release = _release;
    if (_busy || release == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _installMessage = null;
    });
    try {
      if (!_downloaded) {
        await _service.download(
          release,
          onTransferChanged: (transfer) {
            if (mounted) setState(() => _transfer = transfer);
          },
        );
        if (!mounted) return;
        setState(() => _downloaded = true);
      }
      final result = await _service.install(release);
      if (!mounted) return;
      setState(() {
        _installMessage = result == 'permissionRequired'
            ? '설정에서 이 앱의 설치를 허용한 뒤 돌아와 ‘설치 계속’을 눌러 주세요.'
            : 'Android 설치 화면에서 업데이트를 완료해 주세요. 설치를 취소했다면 다시 시도할 수 있습니다.';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _downloaded = false;
        _error =
            error is PlatformException &&
                error.code == 'update_signature_mismatch'
            ? '설치된 앱과 업데이트의 서명이 다릅니다. 앱을 삭제하지 말고 배포 담당자에게 알려 주세요.'
            : '업데이트를 완료하지 못했습니다. 연결과 저장 공간을 확인하고 다시 시도해 주세요.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_continue) return widget.child;
    final release = _release;
    final patch = release == null ? null : _service.patchFor(release);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: GamePalette.cyanDeep,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: GamePalette.backdrop,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.system_update,
                      size: 48,
                      color: GamePalette.cyan,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _checking
                          ? '업데이트 확인 중'
                          : release == null
                          ? '업데이트 확인'
                          : '새 버전이 있습니다',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (release != null) ...[
                      Text(
                        '${release.versionName} · ${(release.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                        textAlign: TextAlign.center,
                      ),
                      if (patch != null &&
                          _transfer != AppUpdateTransfer.fullApk)
                        Text(
                          '변경분 다운로드 ${(patch.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                          textAlign: TextAlign.center,
                        ),
                      if (release.notes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(release.notes),
                      ],
                    ],
                    if (_checking || _busy) ...[
                      const SizedBox(height: 20),
                      const LinearProgressIndicator(),
                      if (_busy)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _downloaded
                                ? '설치 준비 중'
                                : _transfer == AppUpdateTransfer.patch
                                ? '변경분을 다운로드하고 새 APK를 복원하는 중'
                                : patch != null
                                ? '변경분을 적용하지 못해 전체 앱을 다운로드하는 중'
                                : '업데이트를 다운로드하고 확인하는 중',
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: GamePalette.warning),
                        ),
                      ),
                    if (_installMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(_installMessage!),
                      ),
                    if (!_checking) ...[
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : release == null
                            ? _check
                            : _update,
                        child: Text(
                          release == null
                              ? '다시 확인'
                              : _downloaded
                              ? '설치 계속'
                              : '업데이트',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _continue = true),
                        child: const Text('현재 버전으로 계속'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
