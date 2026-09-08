import 'package:flutter/material.dart';

import '../../data/account/account_profile_api.dart';
import '../../domain/account/account_profile.dart';
import '../../l10n/rune_nexus_localizations.dart';
import '../game/game_button.dart';
import '../game/game_modal.dart';
import '../game/game_palette.dart';
import '../game/game_text_styles.dart';

class NicknameSetupDialog extends StatefulWidget {
  const NicknameSetupDialog({required this.save, super.key});

  final Future<AccountProfile> Function(String nickname) save;

  @override
  State<NicknameSetupDialog> createState() => _NicknameSetupDialogState();
}

class _NicknameSetupDialogState extends State<NicknameSetupDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      child: GameModalFrame(
        maxWidth: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.nicknameSetupTitle, style: GameTextStyles.title),
              const SizedBox(height: 12),
              Text(l10n.nicknameSetupDescription, style: GameTextStyles.body),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                enabled: !_submitting,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                style: GameTextStyles.body,
                decoration: InputDecoration(
                  labelText: l10n.nicknameLabel,
                  counterText: l10n.nicknameCounter(
                    AccountProfile.nicknameWeight(_controller.text),
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 8),
              Text(l10n.nicknameRules, style: GameTextStyles.body),
              const SizedBox(height: 12),
              Text(l10n.nicknameTagDescription, style: GameTextStyles.body),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GameTextStyles.withColor(
                    GameTextStyles.body,
                    GamePalette.danger,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              GameButton(
                onPressed: _submitting ? null : _save,
                label: _submitting ? l10n.nicknameSaving : l10n.nicknameSave,
                variant: GameButtonVariant.primary,
              ),
              const SizedBox(height: 8),
              GameButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
                label: l10n.nicknameLogout,
                variant: GameButtonVariant.ghost,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_submitting) return;
    final nickname = _controller.text.trim();
    if (!AccountProfile.isValidNickname(nickname)) {
      setState(() => _error = context.l10n.nicknameInvalid);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final profile = await widget.save(nickname);
      if (!profile.hasNickname) throw StateError('닉네임 설정이 완료되지 않았습니다.');
      if (!mounted) return;
      Navigator.of(context).pop(profile);
    } on Object catch (error) {
      if (!mounted) return;
      final l10n = context.l10n;
      setState(() {
        _submitting = false;
        _error = switch (error) {
          AccountProfileException(code: 'INVALID_NICKNAME') =>
            l10n.nicknameInvalid,
          AccountProfileException(code: 'NICKNAME_TAGS_EXHAUSTED') =>
            l10n.nicknameTagsExhausted,
          _ => l10n.nicknameSaveFailed,
        };
      });
    }
  }
}
