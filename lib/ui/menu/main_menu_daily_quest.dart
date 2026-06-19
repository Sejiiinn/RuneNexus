part of 'main_menu_screen.dart';

Future<void> _openDailyQuestDialog(BuildContext context, RuneNexusGame game) {
  return showDialog<void>(
    context: context,
    builder: (context) => _DailyQuestDialog(game: game),
  );
}

class _DailyQuestEntryButton extends StatefulWidget {
  const _DailyQuestEntryButton({
    required this.snapshot,
    required this.onPressed,
  });

  final GameSnapshot snapshot;
  final VoidCallback onPressed;

  @override
  State<_DailyQuestEntryButton> createState() => _DailyQuestEntryButtonState();
}

class _DailyQuestEntryButtonState extends State<_DailyQuestEntryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  bool get _ready => _dailyQuestClaimableCount(widget.snapshot) > 0;

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _DailyQuestEntryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _syncPulse() {
    if (_ready) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
      return;
    }
    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
    _pulseController.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready;
    return Tooltip(
      message: '일일 임무',
      child: GestureDetector(
        key: const ValueKey('daily-quest-entry-button'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final pulse = ready
                  ? math.sin(_pulseController.value * math.pi)
                  : 0.0;
              final glowAlpha = 0.16 + pulse * 0.24;
              final borderAlpha = ready ? 0.64 + pulse * 0.28 : 0.44;
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xE607111D),
                  border: Border.all(
                    color: _diamondCurrencyColor.withValues(alpha: borderAlpha),
                    width: ready ? 1.4 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    if (ready)
                      BoxShadow(
                        color: _diamondCurrencyColor.withValues(
                          alpha: glowAlpha,
                        ),
                        blurRadius: 13 + pulse * 8,
                        spreadRadius: pulse * 1.2,
                      ),
                    const BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  ready
                      ? Icons.card_giftcard_rounded
                      : Icons.event_available_outlined,
                  color: ready
                      ? _diamondCurrencyColor
                      : const Color(0xFFE8FBFF),
                  size: 20,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DailyQuestDialog extends StatelessWidget {
  const _DailyQuestDialog({required this.game});

  final RuneNexusGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameSnapshot>(
      valueListenable: game.snapshotNotifier,
      builder: (context, snapshot, _) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B1725),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xAA33D8FF)),
          ),
          titlePadding: const EdgeInsets.fromLTRB(18, 16, 14, 0),
          contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          title: Row(
            children: [
              const Icon(
                Icons.event_available_outlined,
                color: _diamondCurrencyColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '일일 임무',
                  style: TextStyle(
                    color: Color(0xFFE8FBFF),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '닫기',
                icon: const Icon(Icons.close, size: 19),
                color: const Color(0xFFB9D6E4),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DailyQuestSummaryCard(game: game, snapshot: snapshot),
                  if (snapshot.dailyQuestClockRollbackDetected) ...[
                    const SizedBox(height: 8),
                    const _DailyQuestWarningCard(),
                  ],
                  const SizedBox(height: 10),
                  for (final entry in gameDailyQuestDefinitions.entries) ...[
                    _DailyQuestRow(
                      game: game,
                      snapshot: snapshot,
                      type: entry.key,
                    ),
                    if (entry.key != gameDailyQuestDefinitions.keys.last)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            SizedBox(
              width: 82,
              child: GameButton(
                onPressed: () => Navigator.of(context).pop(),
                label: '닫기',
                compact: true,
                variant: GameButtonVariant.ghost,
                accentColor: GamePalette.metal,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DailyQuestSummaryCard extends StatelessWidget {
  const _DailyQuestSummaryCard({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final canClaim = _canClaimAllDailyQuestReward(snapshot);
    final claimed = snapshot.dailyQuestAllCompleteClaimed;
    final blocked = snapshot.dailyQuestClockRollbackDetected;
    final buttonLabel = claimed
        ? '수령됨'
        : canClaim
        ? '수령'
        : '대기';

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xAA08131F),
        border: Border.all(color: const Color(0x6633D8FF)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '오늘 진행',
                  style: TextStyle(
                    color: Color(0xFFE8FBFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${snapshot.completedDailyQuestCount}/${gameDailyQuestDefinitions.length} 완료 · 매일 05:00 갱신',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF90AFC0),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                const _DailyQuestRewardText(amount: 20, prefix: '전체 완료'),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: GameButton(
              onPressed: canClaim
                  ? () => game.claimDailyQuestAllCompleteReward()
                  : null,
              label: blocked ? '잠김' : buttonLabel,
              compact: true,
              variant: canClaim
                  ? GameButtonVariant.primary
                  : GameButtonVariant.secondary,
              accentColor: _diamondCurrencyColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyQuestWarningCard extends StatelessWidget {
  const _DailyQuestWarningCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x33FFB55E),
        border: Border.all(color: const Color(0x88FFB55E)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFFFD59A), size: 17),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              '시간 변경이 감지되어 오늘 보상 수령이 잠겼습니다.',
              style: TextStyle(
                color: Color(0xFFFFD59A),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyQuestRow extends StatelessWidget {
  const _DailyQuestRow({
    required this.game,
    required this.snapshot,
    required this.type,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final DailyQuestType type;

  @override
  Widget build(BuildContext context) {
    final definition = gameDailyQuestDefinitions[type]!;
    final progress = (snapshot.dailyQuestProgress[type] ?? 0)
        .clamp(0, definition.targetCount)
        .toInt();
    final complete = progress >= definition.targetCount;
    final claimed = snapshot.claimedDailyQuestRewards.contains(type);
    final canClaim = _canClaimDailyQuestReward(snapshot, type);
    final progressRate = definition.targetCount <= 0
        ? 1.0
        : progress / definition.targetCount;
    final buttonLabel = claimed
        ? '수령됨'
        : canClaim
        ? '수령'
        : complete
        ? '완료'
        : '진행중';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: complete ? const Color(0x2247D7FF) : const Color(0x6607111D),
        border: Border.all(
          color: complete
              ? _diamondCurrencyColor.withValues(alpha: 0.54)
              : const Color(0x33485B68),
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: complete
                    ? _diamondCurrencyColor.withValues(alpha: 0.16)
                    : const Color(0x55223543),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: complete
                      ? _diamondCurrencyColor.withValues(alpha: 0.72)
                      : const Color(0x444A6172),
                ),
              ),
              child: Icon(
                _dailyQuestIcon(type),
                color: complete
                    ? _diamondCurrencyColor
                    : const Color(0xFF90AFC0),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        definition.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE8FBFF),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _DailyQuestRewardText(amount: definition.rewardDiamonds),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progressRate.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: const Color(0x55223543),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      complete ? _diamondCurrencyColor : GamePalette.cyan,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$progress/${definition.targetCount}',
                  style: const TextStyle(
                    color: Color(0xFF90AFC0),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 68,
            child: GameButton(
              onPressed: canClaim
                  ? () => game.claimDailyQuestReward(type)
                  : null,
              label: snapshot.dailyQuestClockRollbackDetected
                  ? '잠김'
                  : buttonLabel,
              compact: true,
              variant: canClaim
                  ? GameButtonVariant.primary
                  : GameButtonVariant.secondary,
              accentColor: _diamondCurrencyColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyQuestRewardText extends StatelessWidget {
  const _DailyQuestRewardText({required this.amount, this.prefix});

  final int amount;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prefix != null) ...[
          Text(
            '$prefix ',
            style: const TextStyle(
              color: Color(0xFF90AFC0),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        Text(
          '+$amount',
          style: const TextStyle(
            color: _diamondCurrencyColor,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 3),
        const CurrencyAssetIcon.diamond(size: 12),
      ],
    );
  }
}

int _dailyQuestClaimableCount(GameSnapshot snapshot) {
  final questCount = gameDailyQuestDefinitions.keys
      .where((type) => _canClaimDailyQuestReward(snapshot, type))
      .length;
  return questCount + (_canClaimAllDailyQuestReward(snapshot) ? 1 : 0);
}

bool _canClaimDailyQuestReward(GameSnapshot snapshot, DailyQuestType type) {
  if (snapshot.dailyQuestClockRollbackDetected ||
      snapshot.claimedDailyQuestRewards.contains(type)) {
    return false;
  }
  final definition = gameDailyQuestDefinitions[type];
  if (definition == null) {
    return false;
  }
  return (snapshot.dailyQuestProgress[type] ?? 0) >= definition.targetCount;
}

bool _canClaimAllDailyQuestReward(GameSnapshot snapshot) {
  return !snapshot.dailyQuestClockRollbackDetected &&
      snapshot.completedDailyQuestCount == gameDailyQuestDefinitions.length &&
      !snapshot.dailyQuestAllCompleteClaimed;
}

IconData _dailyQuestIcon(DailyQuestType type) {
  return switch (type) {
    DailyQuestType.clearWaves => Icons.flag_outlined,
    DailyQuestType.killBosses => Icons.workspace_premium_outlined,
    DailyQuestType.killEnemies => Icons.track_changes,
    DailyQuestType.buyRunUpgrades => Icons.trending_up,
  };
}
