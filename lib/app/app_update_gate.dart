import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/update/app_update_service.dart';
import '../ui/game/game_palette.dart';
import 'app_startup_screen.dart';

/// 게임 저장소를 열기 전 업데이트 확인 및 Android 설치 화면 연결.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({
    required this.child,
    this.service,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final AppUpdateService? service;
  final bool enabled;

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
    if (widget.enabled) {
      _check();
    } else {
      _continue = true;
    }
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
    final status = _checking
        ? '업데이트 확인 중'
        : _busy
        ? _downloaded
              ? '설치 준비 중'
              : _transfer == AppUpdateTransfer.patch
              ? '변경분을 다운로드하고 새 APK를 복원하는 중'
              : patch != null
              ? '변경분을 적용하지 못해 전체 앱을 다운로드하는 중'
              : '업데이트를 다운로드하고 확인하는 중'
        : release == null
        ? '업데이트 확인'
        : '새 버전이 있습니다';
    return AppStartupScreen(
      status: status,
      boundedDetails: !_checking,
      busy: _checking || _busy,
      details: _checking
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (release != null) ...[
                  Text(
                    '${release.versionName} · ${(release.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: GamePalette.cyan),
                  ),
                  if (patch != null && _transfer != AppUpdateTransfer.fullApk)
                    Text(
                      '변경분 다운로드 ${(patch.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                      textAlign: TextAlign.center,
                    ),
                  if (release.notes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Flexible(child: _ReleaseNotes(notes: release.notes)),
                  ],
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: GamePalette.warning),
                  ),
                ],
                if (_installMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_installMessage!),
                ],
                const SizedBox(height: 24),
                AppStartupButton(
                  onPressed: _busy
                      ? null
                      : release == null
                      ? _check
                      : _update,
                  label: release == null
                      ? '다시 확인'
                      : _downloaded
                      ? '설치 계속'
                      : '업데이트',
                ),
                const SizedBox(height: 10),
                AppStartupButton(
                  primary: false,
                  onPressed: _busy
                      ? null
                      : () => setState(() => _continue = true),
                  label: '현재 버전으로 계속',
                ),
              ],
            ),
    );
  }
}

class _ReleaseNotes extends StatefulWidget {
  const _ReleaseNotes({required this.notes});

  final String notes;

  @override
  State<_ReleaseNotes> createState() => _ReleaseNotesState();
}

class _ReleaseNotesState extends State<_ReleaseNotes> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 기존 줄바꿈과 문장 끝 기준 분리. 버전·소수점·쉼표는 유지.
    final entries = widget.notes
        .split(RegExp(r'\r\n?|\n|(?<=[.!?])\s+'))
        .map((line) => line.trim().replaceFirst(RegExp(r'^[-*•]\s+'), ''))
        .where((line) => line.isNotEmpty)
        .toList();
    return Container(
      key: const ValueKey('update-release-notes'),
      decoration: BoxDecoration(
        color: const Color(0xD908151E),
        border: Border.all(color: GamePalette.cyan.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '업데이트 내용',
            style: TextStyle(
              color: GamePalette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                key: const ValueKey('update-release-notes-scroll'),
                controller: _scrollController,
                primary: false,
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    for (var index = 0; index < entries.length; index++)
                      Padding(
                        padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '•',
                              style: TextStyle(color: GamePalette.cyan),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(entries[index])),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
