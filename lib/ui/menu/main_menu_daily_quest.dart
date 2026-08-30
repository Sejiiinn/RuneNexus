part of 'main_menu_screen.dart';

const String _questImageAssetRoot = 'assets/images/quests';
const String _questEntryDefaultAsset =
    '$_questImageAssetRoot/entry_default.jpg';
const String _questEntryRewardReadyAsset =
    '$_questImageAssetRoot/entry_reward_ready.jpg';

Future<void> _claimDailyReward(
  BuildContext context,
  Future<bool> Function() claim,
) async {
  try {
    if (await claim() || !context.mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('현재 진행으로는 이 보상을 받을 수 없습니다.')));
  } on Object {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('보상 서버에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.')),
    );
  }
}

const String _questTitleIconAsset =
    '$_questImageAssetRoot/title_flag_compact.png';
const String _questAttendanceIconAsset = '$_questImageAssetRoot/attendance.png';
const String _questWarningIconAsset = '$_questImageAssetRoot/warning.png';
const String _questCloseIconAsset = '$_questImageAssetRoot/close.png';

Future<void> _openDailyQuestDialog(
  BuildContext context,
  RuneNexusGame game,
  Future<void> Function(WeeklyRewardClaimTarget target)? onClaimWeeklyReward,
) {
  return showGameDialog<void>(
    context: context,
    builder: (context) =>
        _DailyQuestDialog(game: game, onClaimWeeklyReward: onClaimWeeklyReward),
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
    return GestureDetector(
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
            final glowAlpha = 0.28 + pulse * 0.34;
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  if (ready)
                    BoxShadow(
                      color: _diamondCurrencyColor.withValues(alpha: glowAlpha),
                      blurRadius: 16 + pulse * 12,
                      spreadRadius: 1 + pulse * 2.4,
                    ),
                  const BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  ready ? _questEntryRewardReadyAsset : _questEntryDefaultAsset,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _QuestPeriod { daily, weekly }

class _DailyQuestDialog extends StatefulWidget {
  const _DailyQuestDialog({
    required this.game,
    required this.onClaimWeeklyReward,
  });

  final RuneNexusGame game;
  final Future<void> Function(WeeklyRewardClaimTarget target)?
  onClaimWeeklyReward;

  @override
  State<_DailyQuestDialog> createState() => _DailyQuestDialogState();
}

class _DailyQuestDialogState extends State<_DailyQuestDialog> {
  _QuestPeriod _period = _QuestPeriod.daily;
  String? _claimingWeeklyRewardKey;

  Future<void> _claimWeeklyReward(WeeklyRewardClaimTarget target) async {
    if (_claimingWeeklyRewardKey != null) {
      return;
    }
    final claim = widget.onClaimWeeklyReward;
    if (claim == null) {
      _showWeeklyRewardMessage('Google 계정을 연결한 뒤 주간 보상을 받을 수 있습니다.');
      return;
    }
    setState(() => _claimingWeeklyRewardKey = target.key);
    try {
      await claim(target);
      if (mounted) {
        _showWeeklyRewardMessage('주간 보상을 받았습니다.');
      }
    } on WeeklyRewardClaimFailure catch (error) {
      if (mounted) {
        _showWeeklyRewardMessage(error.message);
      }
    } on Object {
      if (mounted) {
        _showWeeklyRewardMessage('주간 보상을 받지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => _claimingWeeklyRewardKey = null);
      }
    }
  }

  void _showWeeklyRewardMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameSnapshot>(
      valueListenable: widget.game.snapshotNotifier,
      builder: (context, snapshot, _) {
        return GameModalFrame(
          maxWidth: 430,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          accentColor: _diamondCurrencyColor,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Image.asset(
                    _questTitleIconAsset,
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    semanticLabel: '임무',
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('임무', style: GameTextStyles.title),
                  ),
                  GameButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    compact: true,
                    variant: GameButtonVariant.ghost,
                    accentColor: _diamondCurrencyColor,
                    width: 32,
                    height: 32,
                    padding: EdgeInsets.zero,
                    child: Center(
                      child: Image.asset(
                        _questCloseIconAsset,
                        width: 17,
                        height: 17,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _QuestPeriodSelector(
                        period: _period,
                        onChanged: (value) => setState(() => _period = value),
                      ),
                      const SizedBox(height: 8),
                      if (_period == _QuestPeriod.daily)
                        _DailyQuestContent(
                          game: widget.game,
                          snapshot: snapshot,
                        )
                      else
                        _WeeklyQuestContent(
                          snapshot: snapshot,
                          claimInProgress: _claimingWeeklyRewardKey != null,
                          onClaim: _claimWeeklyReward,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuestPeriodSelector extends StatelessWidget {
  const _QuestPeriodSelector({required this.period, required this.onChanged});

  final _QuestPeriod period;
  final ValueChanged<_QuestPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xB306111D),
        border: Border.all(color: const Color(0x5533D8FF)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          for (final value in _QuestPeriod.values)
            Expanded(
              child: GestureDetector(
                key: ValueKey('quest-period-${value.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: period == value
                        ? _diamondCurrencyColor.withValues(alpha: 0.16)
                        : Colors.transparent,
                    border: Border.all(
                      color: period == value
                          ? _diamondCurrencyColor.withValues(alpha: 0.72)
                          : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    value == _QuestPeriod.daily ? '일일' : '주간',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: period == value
                          ? const Color(0xFFE8FBFF)
                          : const Color(0xFF90AFC0),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DailyQuestContent extends StatelessWidget {
  const _DailyQuestContent({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final blocked = snapshot.dailyQuestClockRollbackDetected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DailyQuestSummaryCard(game: game, snapshot: snapshot),
        if (blocked) ...[
          const SizedBox(height: 6),
          const _DailyQuestWarningCard(),
        ],
        const SizedBox(height: 8),
        _AttendanceQuestRow(
          title: '오늘 출석',
          subtitle: '매일 05:00 갱신',
          progressText: '1/1일',
          progress: 1,
          target: 1,
          rewardAmount: dailyAttendanceRewardDiamonds,
          claimed: snapshot.dailyAttendanceRewardClaimed,
          claimable: !blocked && !snapshot.dailyAttendanceRewardClaimed,
          blocked: blocked,
          onClaim: () {
            unawaited(
              _claimDailyReward(context, game.claimDailyAttendanceReward),
            );
          },
        ),
        const SizedBox(height: 5),
        for (final entry in gameDailyQuestDefinitions.entries) ...[
          _DailyQuestRow(game: game, snapshot: snapshot, type: entry.key),
          if (entry.key != gameDailyQuestDefinitions.keys.last)
            const SizedBox(height: 5),
        ],
      ],
    );
  }
}

class _AttendanceQuestRow extends StatelessWidget {
  const _AttendanceQuestRow({
    required this.title,
    required this.subtitle,
    required this.progressText,
    required this.progress,
    required this.target,
    required this.rewardAmount,
    required this.claimed,
    required this.claimable,
    required this.blocked,
    required this.onClaim,
  });

  final String title;
  final String subtitle;
  final String progressText;
  final int progress;
  final int target;
  final int rewardAmount;
  final bool claimed;
  final bool claimable;
  final bool blocked;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final complete = progress >= target;
    final progressRate = target <= 0 ? 1.0 : progress / target;
    final buttonLabel = claimed
        ? '수령됨'
        : claimable
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
              child: Center(
                child: Opacity(
                  opacity: complete ? 1 : 0.58,
                  child: Image.asset(
                    _questAttendanceIconAsset,
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    semanticLabel: '출석 임무',
                  ),
                ),
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
                        title,
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
                    _DailyQuestRewardText(amount: rewardAmount),
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
                  '$progressText · $subtitle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              onPressed: claimable ? onClaim : null,
              label: blocked ? '잠김' : buttonLabel,
              compact: true,
              variant: claimable
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
      key: const ValueKey('daily-quest-summary-card'),
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
                const Row(
                  children: [
                    Text(
                      '오늘 진행',
                      style: TextStyle(
                        color: Color(0xFFE8FBFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '매일 05:00 갱신',
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
                _DailyQuestRewardText(
                  amount: 20,
                  prefix:
                      '${snapshot.completedDailyQuestCount}/${gameDailyQuestDefinitions.length} 완료',
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 68,
            child: GameButton(
              onPressed: canClaim
                  ? () {
                      unawaited(
                        _claimDailyReward(
                          context,
                          game.claimDailyQuestAllCompleteReward,
                        ),
                      );
                    }
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
      child: Row(
        children: [
          Image.asset(
            _questWarningIconAsset,
            width: 17,
            height: 17,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            semanticLabel: '경고',
          ),
          const SizedBox(width: 7),
          const Expanded(
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
              child: Center(
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
                  ? () {
                      unawaited(
                        _claimDailyReward(
                          context,
                          () => game.claimDailyQuestReward(type),
                        ),
                      );
                    }
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
        const DiamondCurrencyIcon(size: 12),
      ],
    );
  }
}

int _dailyQuestClaimableCount(GameSnapshot snapshot) {
  final questCount = gameDailyQuestDefinitions.keys
      .where((type) => _canClaimDailyQuestReward(snapshot, type))
      .length;
  final attendanceCount =
      !snapshot.dailyQuestClockRollbackDetected &&
          !snapshot.dailyAttendanceRewardClaimed
      ? 1
      : 0;
  return questCount +
      (_canClaimAllDailyQuestReward(snapshot) ? 1 : 0) +
      attendanceCount +
      _weeklyQuestClaimableCount(snapshot);
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

String _dailyQuestIconAsset(DailyQuestType type) {
  return switch (type) {
    DailyQuestType.clearWaves => '$_questImageAssetRoot/clear_waves.png',
    DailyQuestType.killBosses => '$_questImageAssetRoot/kill_bosses.png',
    DailyQuestType.killEnemies => '$_questImageAssetRoot/kill_enemies.png',
    DailyQuestType.buyRunUpgrades =>
      '$_questImageAssetRoot/buy_run_upgrades.png',
  };
}
