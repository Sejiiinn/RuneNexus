import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/save/legacy_save_transfer_api.dart';
import '../../platform/legacy_transfer/legacy_transfer_link.dart';
import '../game/game_button.dart';
import '../game/game_modal.dart';
import '../game/game_palette.dart';
import '../game/game_text_styles.dart';

class LegacySaveTransferDialog extends StatefulWidget {
  const LegacySaveTransferDialog({required this.createTransfer, super.key});

  final Future<LegacySaveTransferDraft> Function() createTransfer;

  @override
  State<LegacySaveTransferDialog> createState() =>
      _LegacySaveTransferDialogState();
}

class _LegacySaveTransferDialogState extends State<LegacySaveTransferDialog> {
  bool _creating = false;
  Uri? _transferUri;
  DateTime? _expiresAt;
  String? _message;
  bool _failure = false;

  @override
  Widget build(BuildContext context) {
    return GameModalFrame(
      maxWidth: 420,
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      accentColor: GamePalette.cyan,
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.move_to_inbox_outlined,
                  color: GamePalette.cyan,
                  size: 21,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('기존 진행 옮기기', style: GameTextStyles.title),
                ),
                GameModalCloseButton(
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '카카오 인앱 브라우저에 저장된 현재 진행을 외부 브라우저의 Google 계정으로 옮깁니다.',
              style: GameTextStyles.body,
            ),
            const SizedBox(height: 10),
            _notice('이전 링크는 15분 동안 한 번만 사용할 수 있습니다.'),
            const SizedBox(height: 8),
            _notice('Google 계정에 진행이 있으면 서버에 백업한 뒤 현재 카카오 진행으로 교체됩니다.'),
            const SizedBox(height: 8),
            _notice('구매 다이아가 포함된 저장 데이터는 자동 이전되지 않습니다.'),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: GameTextStyles.withColor(
                  GameTextStyles.body,
                  _failure ? GamePalette.danger : GamePalette.green,
                ),
              ),
            ],
            if (_transferUri == null) ...[
              const SizedBox(height: 16),
              GameButton(
                key: const ValueKey('legacy-transfer-create'),
                onPressed: _creating ? null : _create,
                label: _creating ? '이전 링크 생성 중' : '이전 링크 만들기',
                icon: _creating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_rounded, size: 17),
              ),
            ] else ...[
              const SizedBox(height: 14),
              Text(
                '유효 시각 ${_formatExpiry(_expiresAt!)}까지',
                style: GameTextStyles.caption,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GamePalette.voidBlack.withValues(alpha: 0.45),
                  border: Border.all(
                    color: GamePalette.cyan.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(GamePalette.radius),
                ),
                child: SelectableText(
                  _transferUri.toString(),
                  style: GameTextStyles.caption,
                ),
              ),
              const SizedBox(height: 10),
              GameButton(
                key: const ValueKey('legacy-transfer-copy'),
                onPressed: _copy,
                label: '이전 링크 복사',
                icon: const Icon(Icons.copy_rounded, size: 17),
              ),
              const SizedBox(height: 8),
              GameButton(
                key: const ValueKey('legacy-transfer-open'),
                onPressed: _open,
                label: '새 창으로 열기',
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                variant: GameButtonVariant.secondary,
              ),
              const SizedBox(height: 8),
              const Text(
                '카카오에서 계속 열리면 링크를 복사한 뒤 Chrome 또는 Safari 주소창에 붙여 넣어 주세요.',
                style: GameTextStyles.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _notice(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 15,
          color: GamePalette.metal,
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: GameTextStyles.caption)),
      ],
    );
  }

  Future<void> _create() async {
    setState(() {
      _creating = true;
      _message = null;
      _failure = false;
    });
    try {
      final draft = await widget.createTransfer();
      if (!mounted) {
        return;
      }
      setState(() {
        _transferUri = createLegacyTransferLink(draft.token);
        _expiresAt = draft.expiresAt.toLocal();
        _message = '이전 링크가 준비되었습니다.';
      });
    } on LegacySaveTransferException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failure = true;
        _message = error.message;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _failure = true;
        _message = '이전 링크를 만들지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _copy() async {
    final uri = _transferUri;
    if (uri == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (mounted) {
      setState(() {
        _failure = false;
        _message = '이전 링크를 복사했습니다.';
      });
    }
  }

  void _open() {
    final uri = _transferUri;
    if (uri == null) {
      return;
    }
    final opened = openLegacyTransferLink(uri);
    setState(() {
      _failure = !opened;
      _message = opened
          ? '열린 창에서 Google 로그인을 완료해 주세요.'
          : '새 창을 열 수 없습니다. 이전 링크를 복사해 외부 브라우저에서 열어 주세요.';
    });
  }

  String _formatExpiry(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}
