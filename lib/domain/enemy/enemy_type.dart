enum EnemyType {
  normal,
  armored,
  shielded,
  fast,
  tank,
  boss,
  shieldBoss,
  forgeBoss,
}

extension EnemyTypeCategory on EnemyType {
  bool get isBoss =>
      this == EnemyType.boss ||
      this == EnemyType.shieldBoss ||
      this == EnemyType.forgeBoss;
}
