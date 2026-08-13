part of 'game_save_data.dart';

GameSaveData _gameSaveDataFromVersion1(Map<String, Object?> json) {
  final progression = SavedProgression.fromJson(json['progression']);
  final legacyRun = SavedRunState.fromJson(
    json,
    missingRunCoreCombatSkill: progression.coreCombatSkill,
  );
  return GameSaveData(
    savedAtMillis: _intValue(json['savedAtMillis']),
    preferences: SavedPreferences(
      selectedStageNumber: _intValue(json['stageNumber'], fallback: 1),
      autoStartMode:
          _enumValue(AutoStartMode.values, json['autoStartMode']) ??
          AutoStartMode.pauseEachRound,
    ),
    progression: progression,
    turretModules: SavedTurretModuleInventory.fromLegacyProgressionJson(
      json['progression'],
    ),
    // v1은 활성 런 여부를 여러 평면 필드의 조합으로 판정했다.
    activeRun: legacyRun?.hasProgress == true ? legacyRun : null,
  );
}
