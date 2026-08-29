// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _fragmentPrefix = 'legacy-transfer=';

String? platformReadLegacyTransferToken() {
  final fragment = Uri.base.fragment;
  if (!fragment.startsWith(_fragmentPrefix)) {
    return null;
  }
  final token = fragment.substring(_fragmentPrefix.length);
  return token.isEmpty ? null : token;
}

Uri platformCreateLegacyTransferLink(String token) {
  return Uri.base.replace(fragment: '$_fragmentPrefix$token');
}

bool platformOpenLegacyTransferLink(Uri uri) {
  html.window.open(uri.toString(), '_blank');
  return true;
}

void platformClearLegacyTransferToken() {
  final clean = Uri.base.replace(fragment: '');
  html.window.history.replaceState(null, html.document.title, clean.toString());
}
