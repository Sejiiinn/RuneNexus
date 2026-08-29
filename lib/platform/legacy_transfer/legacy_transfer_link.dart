import 'legacy_transfer_link_stub.dart'
    if (dart.library.html) 'legacy_transfer_link_web.dart';

String? readLegacyTransferToken() => platformReadLegacyTransferToken();

Uri createLegacyTransferLink(String token) =>
    platformCreateLegacyTransferLink(token);

bool openLegacyTransferLink(Uri uri) => platformOpenLegacyTransferLink(uri);

void clearLegacyTransferToken() => platformClearLegacyTransferToken();
