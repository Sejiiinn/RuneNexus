import 'package:flutter/material.dart';

import '../../data/save/account_save_selection.dart';
import '../../data/save/game_save_data.dart';
import '../../l10n/rune_nexus_localizations.dart';
import '../game/game_button.dart';
import '../game/game_modal.dart';
import '../game/game_palette.dart';
import '../game/game_text_styles.dart';

class AccountSaveSelectionDialog extends StatelessWidget {
  const AccountSaveSelectionDialog({required this.state, super.key});

  final AccountSaveSelectionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GameModalFrame(
      maxWidth: 430,
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      accentColor: GamePalette.cyan,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_sync_outlined,
                color: GamePalette.cyan,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.saveSelectionTitle,
                  style: GameTextStyles.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(l10n.saveSelectionDescription, style: GameTextStyles.body),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.currentProgress != null) ...[
                    _SaveCandidateCard(
                      title: l10n.currentProgress,
                      description: l10n.currentProgressDescription,
                      icon: Icons.person_outline_rounded,
                      data: state.currentProgress!,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (state.accountProgress != null) ...[
                    _SaveCandidateCard(
                      title: l10n.googleAccountProgress,
                      description: l10n.googleAccountProgressDescription,
                      icon: Icons.account_circle_outlined,
                      data: state.accountProgress!,
                    ),
                    const SizedBox(height: 8),
                  ],
                  _BackupNotice(message: l10n.saveSelectionBackupNotice),
                  const SizedBox(height: 12),
                  for (final choice in state.availableChoices) ...[
                    GameButton(
                      key: ValueKey('account-save-choice-${choice.name}'),
                      onPressed: () => Navigator.of(context).pop(choice),
                      label: _choiceLabel(l10n, choice),
                      icon: Icon(_choiceIcon(choice), size: 17),
                      variant: _choiceVariant(choice),
                    ),
                    if (choice != state.availableChoices.last)
                      const SizedBox(height: 7),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _choiceLabel(
    RuneNexusLocalizations l10n,
    AccountSaveSelectionChoice choice,
  ) {
    return switch (choice) {
      AccountSaveSelectionChoice.keepCurrentProgress => l10n.linkProgressLater,
      AccountSaveSelectionChoice.linkCurrentProgress =>
        l10n.linkCurrentProgress,
      AccountSaveSelectionChoice.useAccountProgress =>
        l10n.useGoogleAccountProgress,
      AccountSaveSelectionChoice.startNewAccount =>
        l10n.startNewAccountProgress,
    };
  }

  static IconData _choiceIcon(AccountSaveSelectionChoice choice) {
    return switch (choice) {
      AccountSaveSelectionChoice.keepCurrentProgress => Icons.schedule_rounded,
      AccountSaveSelectionChoice.linkCurrentProgress =>
        Icons.drive_file_move_outline,
      AccountSaveSelectionChoice.useAccountProgress =>
        Icons.account_circle_outlined,
      AccountSaveSelectionChoice.startNewAccount => Icons.add_circle_outline,
    };
  }

  static GameButtonVariant _choiceVariant(AccountSaveSelectionChoice choice) {
    return switch (choice) {
      AccountSaveSelectionChoice.linkCurrentProgress ||
      AccountSaveSelectionChoice.useAccountProgress =>
        GameButtonVariant.primary,
      AccountSaveSelectionChoice.startNewAccount => GameButtonVariant.secondary,
      AccountSaveSelectionChoice.keepCurrentProgress => GameButtonVariant.ghost,
    };
  }
}

class _SaveCandidateCard extends StatelessWidget {
  const _SaveCandidateCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.data,
  });

  final String title;
  final String description;
  final IconData icon;
  final GameSaveData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeRun = data.activeRun;
    final stageNumber =
        activeRun?.stageNumber ?? data.preferences.selectedStageNumber;
    final completedRounds = activeRun?.completedRounds ?? 0;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: GamePalette.panelInset,
        border: Border.all(color: const Color(0x665D7182)),
        borderRadius: BorderRadius.circular(GamePalette.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: GamePalette.cyan, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GameTextStyles.sectionTitle),
                const SizedBox(height: 3),
                Text(description, style: GameTextStyles.caption),
                const SizedBox(height: 3),
                Text(
                  l10n.saveSelectionSummary(
                    stageNumber: stageNumber,
                    completedRounds: completedRounds,
                    runes: data.progression.runes,
                  ),
                  style: GameTextStyles.body,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.saveSelectionPlayTime(
                    data.progression.totalPlayTimeMillis,
                  ),
                  style: GameTextStyles.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.saveSelectionSavedAt(_formatSavedAt(data.savedAtMillis)),
                  style: GameTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatSavedAt(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}.${twoDigits(date.month)}.${twoDigits(date.day)} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
}

class _BackupNotice extends StatelessWidget {
  const _BackupNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_outlined, color: GamePalette.green, size: 16),
        const SizedBox(width: 7),
        Expanded(child: Text(message, style: GameTextStyles.caption)),
      ],
    );
  }
}
