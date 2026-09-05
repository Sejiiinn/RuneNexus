import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GoogleIdentityButton extends StatefulWidget {
  const GoogleIdentityButton({
    required this.clientId,
    required this.onCredential,
    required this.onUnavailable,
    super.key,
  });

  final String clientId;
  final ValueChanged<String> onCredential;
  final VoidCallback onUnavailable;

  @override
  State<GoogleIdentityButton> createState() => _GoogleIdentityButtonState();
}

class _GoogleIdentityButtonState extends State<GoogleIdentityButton> {
  static const _channel = MethodChannel('rune_nexus/google_identity');
  bool _signingIn = false;

  Future<void> _signIn() async {
    if (_signingIn) return;
    setState(() => _signingIn = true);
    try {
      final credential = await _channel.invokeMethod<String>('signIn', {
        'clientId': widget.clientId,
      });
      if (!mounted) return;
      if (credential == null || credential.isEmpty) {
        widget.onUnavailable();
      } else {
        widget.onCredential(credential);
      }
    } on PlatformException catch (error) {
      if (mounted && error.code != 'sign_in_cancelled') {
        widget.onUnavailable();
      }
    } on MissingPluginException {
      if (mounted) widget.onUnavailable();
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: _signingIn ? null : _signIn,
        child: const Text('Google 계정으로 계속하기'),
      ),
    );
  }
}
