part of 'main_menu_screen.dart';

class _WeeklyQuestContent extends StatelessWidget {
  const _WeeklyQuestContent({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final blocked = snapshot.dailyQuestClockRollbackDetected;
    final attendanceClaimable =
        !blocked &&
        snapshot.weeklyAttendanceDays >= weeklyAttendanceTargetDays &&
        !snapshot.weeklyAttendanceRewardClaimed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeeklyQuestSummaryCard(game: game, snapshot: snapshot),
        if (blocked) ...[
          const SizedBox(height: 6),
          const _DailyQuestWarningCard(),
        ],
        const SizedBox(height: 8),
        _AttendanceQuestRow(
          title: '이번 주 출석',
          subtitle: '월요일 05:00 갱신',
          progressText:
              '${snapshot.weeklyAttendanceDays.clamp(0, 7)}/$weeklyAttendanceTargetDays일',
          progress: snapshot.weeklyAttendanceDays,
          target: weeklyAttendanceTargetDays,
          rewardAmount: weeklyAttendanceRewardDiamonds,
          claimed: snapshot.weeklyAttendanceRewardClaimed,
          claimable: attendanceClaimable,
          blocked: blocked,
          onClaim: game.claimWeeklyAttendanceReward,
        ),
        const SizedBox(height: 5),
        for (final entry in gameWeeklyQuestDefinitions.entries) ...[
          _WeeklyQuestRow(game: game, snapshot: snapshot, type: entry.key),
          if (entry.key != gameWeeklyQuestDefinitions.keys.last)
            const SizedBox(height: 5),
        ],
      ],
    );
  }
}

class _WeeklyQuestSummaryCard extends StatelessWidget {
  const _WeeklyQuestSummaryCard({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final canClaim = _canClaimAllWeeklyQuestReward(snapshot);
    final claimed = snapshot.weeklyQuestAllCompleteClaimed;
    final blocked = snapshot.dailyQuestClockRollbackDetected;
    final buttonLabel = claimed
        ? '수령됨'
        : canClaim
        ? '수령'
        : '대기';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  '이번 주 진행',
                  style: TextStyle(
                    color: Color(0xFFE8FBFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${snapshot.completedWeeklyQuestCount}/${gameWeeklyQuestDefinitions.length} 완료 · 월요일 05:00 갱신',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF90AFC0),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const _WeeklyCompletionRewardText(),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 68,
            child: GameButton(
              onPressed: canClaim
                  ? game.claimWeeklyQuestAllCompleteReward
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

class _WeeklyCompletionRewardText extends StatelessWidget {
  const _WeeklyCompletionRewardText();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const _DailyQuestRewardText(
          amount: weeklyQuestAllCompleteRewardDiamonds,
          prefix: '전체 완료',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              color: Color(0xFFFFD166),
              size: 13,
            ),
            const SizedBox(width: 3),
            Text(
              '모듈권 +$weeklyQuestAllCompleteRewardModuleTickets',
              style: const TextStyle(
                color: Color(0xFFFFD166),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeeklyQuestRow extends StatelessWidget {
  const _WeeklyQuestRow({
    required this.game,
    required this.snapshot,
    required this.type,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final DailyQuestType type;

  @override
  Widget build(BuildContext context) {
    final definition = gameWeeklyQuestDefinitions[type]!;
    final progress = (snapshot.weeklyQuestProgress[type] ?? 0)
        .clamp(0, definition.targetCount)
        .toInt();
    final complete = progress >= definition.targetCount;
    final claimed = snapshot.claimedWeeklyQuestRewards.contains(type);
    final canClaim = _canClaimWeeklyQuestReward(snapshot, type);
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
          const SizedBox(width: 8),
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
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progressRate.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: const Color(0x55223543),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      complete ? _diamondCurrencyColor : GamePalette.cyan,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
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
          const SizedBox(width: 8),
          SizedBox(
            width: 68,
            child: GameButton(
              onPressed: canClaim
                  ? () => game.claimWeeklyQuestReward(type)
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

bool _canClaimWeeklyQuestReward(GameSnapshot snapshot, DailyQuestType type) {
  if (snapshot.dailyQuestClockRollbackDetected ||
      snapshot.claimedWeeklyQuestRewards.contains(type)) {
    return false;
  }
  final definition = gameWeeklyQuestDefinitions[type];
  if (definition == null) {
    return false;
  }
  return (snapshot.weeklyQuestProgress[type] ?? 0) >= definition.targetCount;
}

bool _canClaimAllWeeklyQuestReward(GameSnapshot snapshot) {
  return !snapshot.dailyQuestClockRollbackDetected &&
      snapshot.completedWeeklyQuestCount == gameWeeklyQuestDefinitions.length &&
      !snapshot.weeklyQuestAllCompleteClaimed;
}

int _weeklyQuestClaimableCount(GameSnapshot snapshot) {
  final questCount = gameWeeklyQuestDefinitions.keys
      .where((type) => _canClaimWeeklyQuestReward(snapshot, type))
      .length;
  final attendanceCount =
      !snapshot.dailyQuestClockRollbackDetected &&
          snapshot.weeklyAttendanceDays >= weeklyAttendanceTargetDays &&
          !snapshot.weeklyAttendanceRewardClaimed
      ? 1
      : 0;
  return questCount +
      (_canClaimAllWeeklyQuestReward(snapshot) ? 1 : 0) +
      attendanceCount;
}
