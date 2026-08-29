String? platformReadLegacyTransferToken() => null;

Uri platformCreateLegacyTransferLink(String token) =>
    Uri.base.replace(fragment: 'legacy-transfer=$token');

bool platformOpenLegacyTransferLink(Uri uri) => false;

void platformClearLegacyTransferToken() {}
