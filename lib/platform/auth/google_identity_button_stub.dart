import 'package:flutter/widgets.dart';

class GoogleIdentityButton extends StatelessWidget {
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}
