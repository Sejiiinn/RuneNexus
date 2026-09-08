class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.stageNumber,
    required this.completedRounds,
    required this.achievedAt,
    required this.isMe,
  });

  final int rank;
  final String displayName;
  final int stageNumber;
  final int completedRounds;
  final DateTime achievedAt;
  final bool isMe;
}

class LeaderboardSnapshot {
  const LeaderboardSnapshot({
    required this.rulesVersion,
    required this.asOf,
    required this.entries,
    required this.myEntry,
  });

  final int rulesVersion;
  final DateTime asOf;
  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? myEntry;
}
