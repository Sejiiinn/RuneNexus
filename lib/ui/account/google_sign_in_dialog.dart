import 'package:flutter/material.dart';

import '../../data/auth/google_authentication_api.dart';
import '../../domain/account/online_account_credentials.dart';
import '../../l10n/rune_nexus_localizations.dart';
import '../../platform/auth/google_identity_button.dart';
import '../game/game_modal.dart';
import '../game/game_palette.dart';
import '../game/game_text_styles.dart';

class GoogleSignInDialog extends StatefulWidget {
  const GoogleSignInDialog({
    required this.clientId,
    required this.authenticate,
    this.description,
    super.key,
  });

  final String clientId;
  final Future<OnlineAccountCredentials> Function(String idToken) authenticate;
  final String? description;

  @override
  State<GoogleSignInDialog> createState() => _GoogleSignInDialogState();
}

class _GoogleSignInDialogState extends State<GoogleSignInDialog> {
  bool _submitting = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GameModalFrame(
      maxWidth: 360,
      accentColor: GamePalette.cyan,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_circle_outlined,
                color: GamePalette.cyan,
                size: 21,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.googleSignInTitle,
                  style: GameTextStyles.title,
                ),
              ),
              GameModalCloseButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.description ?? l10n.googleSignInDescription,
            style: GameTextStyles.body,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GamePalette.danger.withValues(alpha: 0.08),
                border: Border.all(
                  color: GamePalette.danger.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(GamePalette.radius),
              ),
              child: Text(
                _errorMessage!,
                style: GameTextStyles.withColor(
                  GameTextStyles.body,
                  GamePalette.danger,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_submitting)
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(l10n.googleSignInVerifying, style: GameTextStyles.body),
                ],
              ),
            )
          else
            GoogleIdentityButton(
              clientId: widget.clientId,
              onCredential: _authenticate,
              onUnavailable: () {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _errorMessage = l10n.googleSignInUnavailable;
                });
              },
            ),
        ],
      ),
    );
  }

  Future<void> _authenticate(String idToken) async {
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final credentials = await widget.authenticate(idToken);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(credentials);
    } on GoogleAuthenticationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = _messageForError(context.l10n, error.code);
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = context.l10n.googleSignInUnavailable;
      });
    }
  }

  String _messageForError(RuneNexusLocalizations l10n, String code) {
    return switch (code) {
      'GOOGLE_AUTH_REJECTED' => l10n.googleSignInRejected,
      'ACCOUNT_NOT_ACTIVE' => l10n.accountNotActive,
      'AUTH_PROVIDER_UNAVAILABLE' => l10n.googleSignInUnavailable,
      _ => l10n.googleSignInFailed,
    };
  }
}
