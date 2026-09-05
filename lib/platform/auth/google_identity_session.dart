import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<void> clearGoogleIdentitySession() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await const MethodChannel(
    'rune_nexus/google_identity',
  ).invokeMethod<void>('clearCredentialState');
}
