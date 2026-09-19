import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/update/app_update_service.dart';
import '../platform/update/app_update_reload_stub.dart'
    if (dart.library.js_interop) '../platform/update/app_update_reload_web.dart';
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

  /// 서버가 요구한 업데이트는 manifest의 선택 여부와 무관하게 완료해야 한다.
  static Future<void> requireUpdate(BuildContext context) => context
      .findAncestorStateOfType<_AppUpdateGateState>()!
      ._startRequiredUpdate();

  final Widget child;
  final AppUpdateService? service;
  final bool enabled;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  late final AppUpdateService _service = widget.service ?? AppUpdateService();
  AppUpdateRelease? _release;
  bool _checking = false;
  bool _serverRequired = false;
  bool _busy = false;
  bool _downloaded = false;
  bool _continue = false;
  bool _childMounted = false;
  String? _error;
  String? _installMessage;
  AppUpdateTransfer? _transfer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.enabled) {
      _check();
    } else {
      _continue = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (widget.enabled || _serverRequired) &&
        !_checking &&
        !_busy) {
      _check();
    }
  }

  Future<void> _startRequiredUpdate() async {
    if (_busy || _checking) return;
    setState(() => _serverRequired = true);
    await _check();
    if (mounted && _release != null && _error == null) await _update();
  }

  bool _isRequired(AppUpdateRelease release) =>
      _serverRequired || _service.isRequired(release);

  Future<void> _check() async {
    final previousRelease = _release;
    setState(() {
      _checking = true;
      _continue = false;
      _release = null;
      _error = null;
    });
    try {
      if (_serverRequired &&
          widget.service == null &&
          !AppUpdateService.enabled) {
        if (reloadForAppUpdate()) return;
        throw UnsupportedError('automatic_update_unavailable');
      }
      final release = await _service.check();
      if (!mounted) return;
      setState(() {
        _release = release;
        if (release?.versionCode != previousRelease?.versionCode ||
            release?.sha256 != previousRelease?.sha256) {
          _downloaded = false;
          _transfer = null;
          _installMessage = null;
        }
        _continue = release == null && !_serverRequired;
        if (release == null && _serverRequired) {
          _error = '서버에서 새 버전을 요구하고 있습니다. 업데이트 배포를 확인하지 못했으니 잠시 후 다시 시도해 주세요.';
        }
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is UnsupportedError
            ? '이 환경에서는 자동 업데이트를 지원하지 않습니다. 계정과 저장 데이터는 유지됩니다. 최신 배포본으로 업데이트해 주세요.'
            : '업데이트 정보를 확인하지 못했습니다. 인터넷 연결을 확인하고 다시 시도해 주세요.',
      );
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
    if (_continue) _childMounted = true;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_childMounted)
          Offstage(
            offstage: !_continue,
            child: ExcludeFocus(
              excluding: !_continue,
              child: TickerMode(enabled: _continue, child: widget.child),
            ),
          ),
        if (!_continue) _buildUpdateScreen(),
      ],
    );
  }

  Widget _buildUpdateScreen() {
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
        ? _serverRequired
              ? '필수 업데이트가 있습니다'
              : '업데이트 확인'
        : _isRequired(release)
        ? '필수 업데이트가 있습니다'
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
                  if (_isRequired(release))
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        '게임을 시작하려면 업데이트를 완료해 주세요.',
                        textAlign: TextAlign.center,
                      ),
                    ),
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
                      ? _serverRequired
                            ? _startRequiredUpdate
                            : _check
                      : _update,
                  label: _error != null
                      ? '다시 시도'
                      : release == null
                      ? '다시 시도'
                      : _downloaded
                      ? '설치 계속'
                      : _isRequired(release)
                      ? '업데이트하기'
                      : '업데이트',
                ),
                if (release != null && !_isRequired(release)) ...[
                  const SizedBox(height: 10),
                  AppStartupButton(
                    primary: false,
                    onPressed: _busy
                        ? null
                        : () => setState(() => _continue = true),
                    label: '현재 버전으로 계속',
                  ),
                ],
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
