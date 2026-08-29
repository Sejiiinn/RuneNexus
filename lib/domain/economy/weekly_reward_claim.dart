import '../daily_quest/daily_quest_type.dart';

enum WeeklyRewardKind { quest, allComplete, attendance }

class WeeklyRewardClaimTarget {
  const WeeklyRewardClaimTarget.quest(this.questType)
    : kind = WeeklyRewardKind.quest;

  const WeeklyRewardClaimTarget.allComplete()
    : kind = WeeklyRewardKind.allComplete,
      questType = null;

  const WeeklyRewardClaimTarget.attendance()
    : kind = WeeklyRewardKind.attendance,
      questType = null;

  final WeeklyRewardKind kind;
  final DailyQuestType? questType;

  String get key => switch (kind) {
    WeeklyRewardKind.quest => 'quest:${questType!.name}',
    WeeklyRewardKind.allComplete => 'all_complete',
    WeeklyRewardKind.attendance => 'attendance',
  };
}

class WeeklyRewardReceipt {
  const WeeklyRewardReceipt({
    required this.rewardKey,
    required this.periodKey,
    required this.weekKey,
    required this.target,
    required this.diamonds,
    required this.moduleTickets,
    required this.sourceSaveRevision,
    required this.claimedAt,
  });

  final String rewardKey;
  final String periodKey;
  final int weekKey;
  final WeeklyRewardClaimTarget target;
  final int diamonds;
  final int moduleTickets;
  final int sourceSaveRevision;
  final DateTime claimedAt;
}

class WeeklyRewardClaimFailure implements Exception {
  const WeeklyRewardClaimFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
