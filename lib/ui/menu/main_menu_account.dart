part of 'main_menu_screen.dart';

class _AccountEntryButton extends StatelessWidget {
  const _AccountEntryButton({
    required this.session,
    required this.onPressed,
    this.compact = false,
  });

  final AccountSession session;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visual = _AccountStatusVisual.forSession(session);
    final size = compact ? 32.0 : 40.0;
    return Tooltip(
      message: context.l10n.accountAndSave,
      child: Semantics(
        button: true,
        label: '${context.l10n.accountAndSave}, ${visual.statusLabel(context)}',
        child: Material(
          key: const ValueKey('main-menu-account-button'),
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            splashColor: visual.accent.withValues(alpha: 0.18),
            highlightColor: visual.accent.withValues(alpha: 0.08),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xEE10283A), Color(0xF207111D)],
                ),
                border: Border.all(
                  color: visual.accent.withValues(alpha: 0.72),
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: visual.accent.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    visual.icon,
                    color: visual.accent,
                    size: compact ? 18 : 21,
                  ),
                  Positioned(
                    right: compact ? 3 : 4,
                    bottom: compact ? 3 : 4,
                    child: Container(
                      width: compact ? 6 : 7,
                      height: compact ? 6 : 7,
                      decoration: BoxDecoration(
                        color: visual.indicator,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: GamePalette.voidBlack,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: visual.indicator.withValues(alpha: 0.55),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountDialog extends StatelessWidget {
  const _AccountDialog({
    required this.session,
    required this.onConnectPlayGames,
    required this.onConnectGoogle,
    required this.onCreateLegacyTransfer,
    required this.onSyncAccount,
    required this.onSignOut,
  });

  final AccountSession session;
  final VoidCallback? onConnectPlayGames;
  final VoidCallback? onConnectGoogle;
  final VoidCallback? onCreateLegacyTransfer;
  final VoidCallback? onSyncAccount;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visual = _AccountStatusVisual.forSession(session);
    return GameModalFrame(
      maxWidth: 420,
      maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      accentColor: visual.accent,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.manage_accounts_outlined,
                color: visual.accent,
                size: 21,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.accountAndSave, style: GameTextStyles.title),
              ),
              GameModalCloseButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AccountSummaryCard(session: session, visual: visual),
                  if (session.isGuest) ...[
                    if (onConnectPlayGames != null) ...[
                      const SizedBox(height: 10),
                      _AccountConnectCard(
                        provider: AccountIdentityProvider.playGames,
                        onPressed: () =>
                            _closeAndInvoke(context, onConnectPlayGames!),
                      ),
                    ],
                    if (onConnectGoogle != null) ...[
                      const SizedBox(height: 10),
                      _AccountConnectCard(
                        provider: AccountIdentityProvider.google,
                        onPressed: () =>
                            _closeAndInvoke(context, onConnectGoogle!),
                      ),
                    ],
                    if (onCreateLegacyTransfer != null) ...[
                      const SizedBox(height: 10),
                      _LegacyTransferCard(
                        onPressed: () =>
                            _closeAndInvoke(context, onCreateLegacyTransfer!),
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 12),
                    for (final identity in session.identities) ...[
                      _LinkedIdentityCard(identity: identity),
                      const SizedBox(height: 8),
                    ],
                    if (session.identityFor(AccountIdentityProvider.google) ==
                            null &&
                        onConnectGoogle != null) ...[
                      _AccountConnectCard(
                        provider: AccountIdentityProvider.google,
                        onPressed: () =>
                            _closeAndInvoke(context, onConnectGoogle!),
                        supportingText: l10n.googleWebSyncHint,
                      ),
                      const SizedBox(height: 8),
                    ],
                    _CloudSaveCard(session: session),
                    if (onSyncAccount != null || onSignOut != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (onSyncAccount != null)
                            Expanded(
                              child: GameButton(
                                key: const ValueKey('account-sync-now'),
                                onPressed:
                                    session.syncStatus ==
                                        OnlineSaveSyncStatus.syncing
                                    ? null
                                    : () => _closeAndInvoke(
                                        context,
                                        onSyncAccount!,
                                      ),
                                label: l10n.syncNow,
                                icon: const Icon(Icons.sync_rounded, size: 17),
                                variant: GameButtonVariant.secondary,
                              ),
                            ),
                          if (onSyncAccount != null && onSignOut != null)
                            const SizedBox(width: 8),
                          if (onSignOut != null)
                            Expanded(
                              child: GameButton(
                                key: const ValueKey('account-sign-out'),
                                onPressed: () => _confirmSignOut(context),
                                label: l10n.signOut,
                                icon: const Icon(
                                  Icons.logout_rounded,
                                  size: 16,
                                ),
                                variant: GameButtonVariant.ghost,
                                accentColor: GamePalette.metal,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  _AccountSafetyNotice(isGuest: session.isGuest),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _closeAndInvoke(BuildContext context, VoidCallback callback) {
    Navigator.of(context).pop();
    callback();
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showGameDialog<bool>(
      context: context,
      builder: (confirmationContext) => _SignOutConfirmationDialog(
        onCancel: () => Navigator.of(confirmationContext).pop(false),
        onConfirm: () => Navigator.of(confirmationContext).pop(true),
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    _closeAndInvoke(context, onSignOut!);
  }
}

class _LegacyTransferCard extends StatelessWidget {
  const _LegacyTransferCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _AccountSectionCard(
      key: const ValueKey('legacy-transfer-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.move_to_inbox_outlined,
                size: 20,
                color: GamePalette.cyan,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  '카카오 브라우저 진행 옮기기',
                  style: GameTextStyles.sectionTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '이 브라우저에 저장된 기존 진행을 외부 브라우저의 Google 계정으로 옮깁니다.',
            style: GameTextStyles.body,
          ),
          const SizedBox(height: 10),
          GameButton(
            key: const ValueKey('legacy-transfer-start'),
            onPressed: onPressed,
            label: '기존 진행 옮기기',
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            variant: GameButtonVariant.secondary,
          ),
        ],
      ),
    );
  }
}

class _AccountSummaryCard extends StatelessWidget {
  const _AccountSummaryCard({required this.session, required this.visual});

  final AccountSession session;
  final _AccountStatusVisual visual;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      key: const ValueKey('account-summary-card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: visual.accent.withValues(alpha: 0.08),
        border: Border.all(color: visual.accent.withValues(alpha: 0.48)),
        borderRadius: BorderRadius.circular(GamePalette.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: visual.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: visual.accent.withValues(alpha: 0.48)),
            ),
            child: Icon(visual.icon, color: visual.accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.isGuest ? l10n.guestPlaying : l10n.onlineConnected,
                  style: GameTextStyles.sectionTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  session.isGuest
                      ? l10n.guestSaveDescription
                      : visual.statusLabel(context),
                  style: GameTextStyles.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountConnectCard extends StatelessWidget {
  const _AccountConnectCard({
    required this.provider,
    required this.onPressed,
    this.supportingText,
  });

  final AccountIdentityProvider provider;
  final VoidCallback onPressed;
  final String? supportingText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final providerName = _providerName(l10n, provider);
    final buttonLabel = switch (provider) {
      AccountIdentityProvider.playGames => l10n.connectPlayGames,
      AccountIdentityProvider.google => l10n.connectGoogle,
      AccountIdentityProvider.apple => providerName,
    };
    return _AccountSectionCard(
      key: ValueKey('account-connect-${provider.name}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _ProviderIcon(provider: provider),
              const SizedBox(width: 9),
              Expanded(
                child: Text(providerName, style: GameTextStyles.sectionTitle),
              ),
            ],
          ),
          if (supportingText != null) ...[
            const SizedBox(height: 8),
            Text(supportingText!, style: GameTextStyles.body),
          ],
          const SizedBox(height: 10),
          GameButton(
            key: ValueKey('account-connect-${provider.name}-button'),
            onPressed: onPressed,
            label: buttonLabel,
            icon: const Icon(Icons.link_rounded, size: 17),
            variant: GameButtonVariant.primary,
          ),
        ],
      ),
    );
  }
}

class _LinkedIdentityCard extends StatelessWidget {
  const _LinkedIdentityCard({required this.identity});

  final AccountIdentity identity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _AccountSectionCard(
      key: ValueKey('account-identity-${identity.provider.name}'),
      child: Row(
        children: [
          _ProviderIcon(provider: identity.provider),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _providerName(l10n, identity.provider),
                  style: GameTextStyles.caption,
                ),
                const SizedBox(height: 3),
                Text(identity.displayName, style: GameTextStyles.sectionTitle),
                if (identity.detail != null) ...[
                  const SizedBox(height: 2),
                  Text(identity.detail!, style: GameTextStyles.caption),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: GamePalette.green,
                size: 15,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.connected,
                style: GameTextStyles.withColor(
                  GameTextStyles.caption,
                  GamePalette.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CloudSaveCard extends StatelessWidget {
  const _CloudSaveCard({required this.session});

  final AccountSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visual = _AccountStatusVisual.forSession(session);
    final lastSyncedAt = session.lastSyncedAt;
    final details = <String>[
      if (lastSyncedAt != null) l10n.lastSynced(_formatSyncTime(lastSyncedAt)),
      if (lastSyncedAt == null &&
          session.syncStatus == OnlineSaveSyncStatus.synchronized)
        l10n.notSyncedYet,
      if (session.pendingSaveCount > 0)
        l10n.pendingSaves(session.pendingSaveCount),
    ];
    return _AccountSectionCard(
      key: const ValueKey('account-cloud-save'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(visual.icon, color: visual.accent, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.cloudSave, style: GameTextStyles.sectionTitle),
                const SizedBox(height: 4),
                Text(
                  visual.statusLabel(context),
                  style: GameTextStyles.withColor(
                    GameTextStyles.body,
                    visual.accent,
                  ),
                ),
                for (final detail in details) ...[
                  const SizedBox(height: 3),
                  Text(detail, style: GameTextStyles.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSafetyNotice extends StatelessWidget {
  const _AccountSafetyNotice({required this.isGuest});

  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    if (!isGuest) {
      return const SizedBox.shrink();
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.shield_outlined,
          color: GamePalette.textMuted,
          size: 15,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            context.l10n.accountConnectSafety,
            style: GameTextStyles.caption,
          ),
        ),
      ],
    );
  }
}

class _AccountSectionCard extends StatelessWidget {
  const _AccountSectionCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: GamePalette.panelInset,
        border: Border.all(color: const Color(0x665D7182)),
        borderRadius: BorderRadius.circular(GamePalette.radius),
      ),
      child: child,
    );
  }
}

class _ProviderIcon extends StatelessWidget {
  const _ProviderIcon({required this.provider});

  final AccountIdentityProvider provider;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (provider) {
      AccountIdentityProvider.playGames => (
        Icons.sports_esports_outlined,
        GamePalette.green,
      ),
      AccountIdentityProvider.google => (
        Icons.account_circle_outlined,
        GamePalette.cyan,
      ),
      AccountIdentityProvider.apple => (Icons.apple, GamePalette.textPrimary),
    };
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }
}

class _SignOutConfirmationDialog extends StatelessWidget {
  const _SignOutConfirmationDialog({
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GameModalFrame(
      maxWidth: 350,
      accentColor: GamePalette.warning,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                color: GamePalette.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.signOutTitle, style: GameTextStyles.title),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(l10n.signOutDescription, style: GameTextStyles.body),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GameButton(
                  onPressed: onCancel,
                  label: l10n.cancel,
                  variant: GameButtonVariant.ghost,
                  accentColor: GamePalette.metal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                  key: const ValueKey('account-sign-out-confirm'),
                  onPressed: onConfirm,
                  label: l10n.signOut,
                  variant: GameButtonVariant.danger,
                  icon: const Icon(Icons.logout_rounded, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountStatusVisual {
  const _AccountStatusVisual({
    required this.icon,
    required this.accent,
    required this.indicator,
    required this.statusLabel,
  });

  final IconData icon;
  final Color accent;
  final Color indicator;
  final String Function(BuildContext context) statusLabel;

  factory _AccountStatusVisual.forSession(AccountSession session) {
    if (session.isGuest) {
      return _AccountStatusVisual(
        icon: Icons.person_outline_rounded,
        accent: GamePalette.metal,
        indicator: GamePalette.textDisabled,
        statusLabel: (context) => context.l10n.guestPlaying,
      );
    }
    return switch (session.syncStatus) {
      OnlineSaveSyncStatus.synchronized => _AccountStatusVisual(
        icon: Icons.cloud_done_outlined,
        accent: GamePalette.cyan,
        indicator: GamePalette.green,
        statusLabel: (context) => context.l10n.syncComplete,
      ),
      OnlineSaveSyncStatus.syncing => _AccountStatusVisual(
        icon: Icons.cloud_sync_outlined,
        accent: GamePalette.cyan,
        indicator: GamePalette.cyan,
        statusLabel: (context) => context.l10n.syncing,
      ),
      OnlineSaveSyncStatus.offline => _AccountStatusVisual(
        icon: Icons.cloud_off_outlined,
        accent: GamePalette.warning,
        indicator: GamePalette.warning,
        statusLabel: (context) => context.l10n.offlinePlaying,
      ),
      OnlineSaveSyncStatus.actionRequired => _AccountStatusVisual(
        icon: Icons.priority_high_rounded,
        accent: GamePalette.danger,
        indicator: GamePalette.danger,
        statusLabel: (context) =>
            session.issueMessage ?? context.l10n.syncActionRequired,
      ),
      OnlineSaveSyncStatus.unavailable => _AccountStatusVisual(
        icon: Icons.person_outline_rounded,
        accent: GamePalette.metal,
        indicator: GamePalette.textDisabled,
        statusLabel: (context) => context.l10n.guestPlaying,
      ),
    };
  }
}

String _providerName(
  RuneNexusLocalizations l10n,
  AccountIdentityProvider provider,
) {
  return switch (provider) {
    AccountIdentityProvider.playGames => l10n.playGames,
    AccountIdentityProvider.google => l10n.googleAccount,
    AccountIdentityProvider.apple => 'Apple',
  };
}

String _formatSyncTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final local = value.toLocal();
  return '${local.year}.${twoDigits(local.month)}.${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
