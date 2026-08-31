part of 'main_menu_screen.dart';

class _WeeklyQuestContent extends StatelessWidget {
  const _WeeklyQuestContent({
    required this.snapshot,
    required this.claimInProgress,
    required this.onClaim,
  });

  final GameSnapshot snapshot;
  final bool claimInProgress;
  final ValueChanged<WeeklyRewardClaimTarget> onClaim;

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
        _WeeklyQuestSummaryCard(
          snapshot: snapshot,
          claimInProgress: claimInProgress,
          onClaim: () => onClaim(const WeeklyRewardClaimTarget.allComplete()),
        ),
        if (claimInProgress) ...[
          const SizedBox(height: 6),
          const Text(
            '서버에서 보상 수령을 확인하는 중입니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF90AFC0),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
          claimable: attendanceClaimable && !claimInProgress,
          blocked: blocked,
          onClaim: () => onClaim(const WeeklyRewardClaimTarget.attendance()),
        ),
        const SizedBox(height: 5),
        for (final entry in gameWeeklyQuestDefinitions.entries) ...[
          _WeeklyQuestRow(
            snapshot: snapshot,
            type: entry.key,
            claimInProgress: claimInProgress,
            onClaim: () => onClaim(WeeklyRewardClaimTarget.quest(entry.key)),
          ),
          if (entry.key != gameWeeklyQuestDefinitions.keys.last)
            const SizedBox(height: 5),
        ],
      ],
    );
  }
}

class _WeeklyQuestSummaryCard extends StatelessWidget {
  const _WeeklyQuestSummaryCard({
    required this.snapshot,
    required this.claimInProgress,
    required this.onClaim,
  });

  final GameSnapshot snapshot;
  final bool claimInProgress;
  final VoidCallback onClaim;

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

    return _QuestAssetSurface(
      key: const ValueKey('weekly-quest-summary-card'),
      asset: questSummaryFrameAsset,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Text(
                      '이번 주 진행',
                      style: TextStyle(
                        color: Color(0xFFE8FBFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '월요일 05:00 갱신',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF90AFC0),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _WeeklyCompletionRewardText(
                  progressText:
                      '${snapshot.completedWeeklyQuestCount}/${gameWeeklyQuestDefinitions.length} 완료',
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _QuestActionButton(
            onPressed: canClaim && !claimInProgress ? onClaim : null,
            label: blocked ? '잠김' : buttonLabel,
            highlighted: canClaim,
          ),
        ],
      ),
    );
  }
}

class _WeeklyCompletionRewardText extends StatelessWidget {
  const _WeeklyCompletionRewardText({required this.progressText});

  final String progressText;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _DailyQuestRewardText(
          amount: weeklyQuestAllCompleteRewardDiamonds,
          prefix: progressText,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              turretModuleTicketIconAsset,
              width: 16,
              height: 16,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
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
    required this.snapshot,
    required this.type,
    required this.claimInProgress,
    required this.onClaim,
  });

  final GameSnapshot snapshot;
  final DailyQuestType type;
  final bool claimInProgress;
  final VoidCallback onClaim;

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

    return _QuestAssetSurface(
      asset: questRowFrameAsset,
      highlighted: complete,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          _QuestIconSocket(
            complete: complete,
            child: Opacity(
              opacity: complete ? 1 : 0.58,
              child: Image.asset(
                _dailyQuestIconAsset(type),
                width: 18,
                height: 18,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                semanticLabel: definition.title,
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
          _QuestActionButton(
            onPressed: canClaim && !claimInProgress ? onClaim : null,
            label: snapshot.dailyQuestClockRollbackDetected
                ? '잠김'
                : buttonLabel,
            highlighted: canClaim,
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
