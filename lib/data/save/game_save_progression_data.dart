part of 'game_save_data.dart';

class SavedProgression {
  const SavedProgression({
    required this.runes,
    this.freeDiamonds = 0,
    this.paidDiamonds = 0,
    this.dailyQuestDayKey = -1,
    this.lastDailyQuestSeenMillis = 0,
    this.dailyQuestClockRollbackDetected = false,
    this.dailyQuestProgress = const {},
    this.claimedDailyQuestRewards = const {},
    this.dailyAttendanceRewardClaimed = false,
    this.dailyQuestAllCompleteClaimed = false,
    this.weeklyQuestWeekKey = -1,
    this.weeklyQuestProgress = const {},
    this.claimedWeeklyQuestRewards = const {},
    this.weeklyQuestAllCompleteClaimed = false,
    this.weeklyAttendanceDayKeys = const {},
    this.weeklyAttendanceRewardClaimed = false,
    required this.lastRunRuneReward,
    required this.startingGoldUpgradeLevel,
    required this.nexusHpUpgradeLevel,
    required this.supplyUpgradeLevel,
    required this.fireTrainingUpgradeLevel,
    this.physicalDamageTrainingUpgradeLevel = 0,
    this.elementalDamageTrainingUpgradeLevel = 0,
    required this.criticalChanceUpgradeLevel,
    required this.criticalDamageUpgradeLevel,
    required this.killGoldUpgradeLevel,
    required this.emergencySaleUpgradeLevel,
    required this.unlockedStageCount,
    required this.bestRoundsByStage,
    required this.clearedStageNumbers,
    required this.researchLevels,
    required this.researchElapsedMillis,
    required this.activeResearches,
    this.researchSlotTwoUnlocked = false,
    this.turretModuleTickets = 0,
    this.turretModuleDrawCount = 0,
    this.turretModuleTicketPurchaseCount = 0,
    this.turretModuleItemSequence = 0,
    this.ownedTurretModules = const [],
    this.coreCombatSkill = CoreCombatSkill.guardianBeam,
    this.totalCorePoints = 0,
    this.lastRunCorePointReward = 0,
    this.lastRunTurretModuleTicketReward = 0,
    this.corePassiveTreeRevision = core_tree.corePassiveTreeRevision,
    this.corePassiveNodeRanks = const {},
    this.claimedCorePointStageRewards = const {},
    this.claimedEventIds = const {},
  });

  final int runes;
  final int freeDiamonds;
  final int paidDiamonds;
  final int dailyQuestDayKey;
  final int lastDailyQuestSeenMillis;
  final bool dailyQuestClockRollbackDetected;
  final Map<DailyQuestType, int> dailyQuestProgress;
  final Set<DailyQuestType> claimedDailyQuestRewards;
  final bool dailyAttendanceRewardClaimed;
  final bool dailyQuestAllCompleteClaimed;
  final int weeklyQuestWeekKey;
  final Map<DailyQuestType, int> weeklyQuestProgress;
  final Set<DailyQuestType> claimedWeeklyQuestRewards;
  final bool weeklyQuestAllCompleteClaimed;
  final Set<int> weeklyAttendanceDayKeys;
  final bool weeklyAttendanceRewardClaimed;
  final int lastRunRuneReward;
  final int startingGoldUpgradeLevel;
  final int nexusHpUpgradeLevel;
  final int supplyUpgradeLevel;
  final int fireTrainingUpgradeLevel;
  final int physicalDamageTrainingUpgradeLevel;
  final int elementalDamageTrainingUpgradeLevel;
  final int criticalChanceUpgradeLevel;
  final int criticalDamageUpgradeLevel;
  final int killGoldUpgradeLevel;
  final int emergencySaleUpgradeLevel;
  final int unlockedStageCount;
  final Map<int, int> bestRoundsByStage;
  final Set<int> clearedStageNumbers;
  final Map<ResearchType, int> researchLevels;
  final Map<ResearchType, int> researchElapsedMillis;
  final List<SavedActiveResearch> activeResearches;
  final bool researchSlotTwoUnlocked;
  final int turretModuleTickets;
  final int turretModuleDrawCount;
  final int turretModuleTicketPurchaseCount;
  final int turretModuleItemSequence;
  final List<SavedTurretModule> ownedTurretModules;
  final CoreCombatSkill? coreCombatSkill;
  final int totalCorePoints;
  final int lastRunCorePointReward;
  final int lastRunTurretModuleTicketReward;
  final int corePassiveTreeRevision;
  final Map<CorePassiveNodeId, int> corePassiveNodeRanks;
  final Set<int> claimedCorePointStageRewards;
  final Set<String> claimedEventIds;

  Map<String, Object?> toJson() {
    return {
      'runes': runes,
      'freeDiamonds': freeDiamonds,
      'paidDiamonds': paidDiamonds,
      'dailyQuestDayKey': dailyQuestDayKey,
      'lastDailyQuestSeenMillis': lastDailyQuestSeenMillis,
      'dailyQuestClockRollbackDetected': dailyQuestClockRollbackDetected,
      'dailyQuestProgress': dailyQuestProgress.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'claimedDailyQuestRewards': claimedDailyQuestRewards
          .map((type) => type.name)
          .toList(),
      'dailyAttendanceRewardClaimed': dailyAttendanceRewardClaimed,
      'dailyQuestAllCompleteClaimed': dailyQuestAllCompleteClaimed,
      'weeklyQuestWeekKey': weeklyQuestWeekKey,
      'weeklyQuestProgress': weeklyQuestProgress.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'claimedWeeklyQuestRewards': claimedWeeklyQuestRewards
          .map((type) => type.name)
          .toList(),
      'weeklyQuestAllCompleteClaimed': weeklyQuestAllCompleteClaimed,
      'weeklyAttendanceDayKeys': weeklyAttendanceDayKeys.toList(),
      'weeklyAttendanceRewardClaimed': weeklyAttendanceRewardClaimed,
      'lastRunRuneReward': lastRunRuneReward,
      'startingGoldUpgradeLevel': startingGoldUpgradeLevel,
      'nexusHpUpgradeLevel': nexusHpUpgradeLevel,
      'supplyUpgradeLevel': supplyUpgradeLevel,
      'fireTrainingUpgradeLevel': fireTrainingUpgradeLevel,
      'physicalDamageTrainingUpgradeLevel': physicalDamageTrainingUpgradeLevel,
      'elementalDamageTrainingUpgradeLevel':
          elementalDamageTrainingUpgradeLevel,
      'criticalChanceUpgradeLevel': criticalChanceUpgradeLevel,
      'criticalDamageUpgradeLevel': criticalDamageUpgradeLevel,
      'killGoldUpgradeLevel': killGoldUpgradeLevel,
      'emergencySaleUpgradeLevel': emergencySaleUpgradeLevel,
      'unlockedStageCount': unlockedStageCount,
      'bestRoundsByStage': bestRoundsByStage.map(
        (key, value) => MapEntry('$key', value),
      ),
      'clearedStageNumbers': clearedStageNumbers.toList(),
      'researchLevels': researchLevels.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'researchElapsedMillis': researchElapsedMillis.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'activeResearches': activeResearches
          .map((research) => research.toJson())
          .toList(),
      'researchSlotTwoUnlocked': researchSlotTwoUnlocked,
      'turretModuleTickets': turretModuleTickets,
      'turretModuleDrawCount': turretModuleDrawCount,
      'turretModuleTicketPurchaseCount': turretModuleTicketPurchaseCount,
      'turretModuleItemSequence': turretModuleItemSequence,
      'ownedTurretModules': ownedTurretModules
          .map((module) => module.toJson())
          .toList(),
      'coreCombatSkill': coreCombatSkill?.name,
      'totalCorePoints': totalCorePoints,
      'lastRunCorePointReward': lastRunCorePointReward,
      'lastRunTurretModuleTicketReward': lastRunTurretModuleTicketReward,
      'corePassiveTreeRevision': corePassiveTreeRevision,
      'corePassiveNodeRanks': corePassiveNodeRanks.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'claimedCorePointStageRewards': claimedCorePointStageRewards.toList(),
      'claimedEventIds': claimedEventIds.toList(),
    };
  }

  static SavedProgression fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    final activeResearches = _objectList(
      map['activeResearches'],
      SavedActiveResearch.fromJson,
    );
    final turretModuleItemSequence = _nonNegativeInt(
      map['turretModuleItemSequence'],
    );
    final turretModuleDrawCount = map.containsKey('turretModuleDrawCount')
        ? _nonNegativeInt(map['turretModuleDrawCount'])
        : turretModuleItemSequence;
    return SavedProgression(
      runes: _intValue(map['runes']),
      freeDiamonds: _intValue(map['freeDiamonds']),
      paidDiamonds: _intValue(map['paidDiamonds']),
      dailyQuestDayKey: _intValue(map['dailyQuestDayKey'], fallback: -1),
      lastDailyQuestSeenMillis: _intValue(map['lastDailyQuestSeenMillis']),
      dailyQuestClockRollbackDetected: _boolValue(
        map['dailyQuestClockRollbackDetected'],
      ),
      dailyQuestProgress: _enumIntMap(
        DailyQuestType.values,
        map['dailyQuestProgress'],
      ),
      claimedDailyQuestRewards: _enumSet(
        DailyQuestType.values,
        map['claimedDailyQuestRewards'],
      ),
      dailyAttendanceRewardClaimed: _boolValue(
        map['dailyAttendanceRewardClaimed'],
      ),
      dailyQuestAllCompleteClaimed: _boolValue(
        map['dailyQuestAllCompleteClaimed'],
      ),
      weeklyQuestWeekKey: _intValue(map['weeklyQuestWeekKey'], fallback: -1),
      weeklyQuestProgress: _enumIntMap(
        DailyQuestType.values,
        map['weeklyQuestProgress'],
      ),
      claimedWeeklyQuestRewards: _enumSet(
        DailyQuestType.values,
        map['claimedWeeklyQuestRewards'],
      ),
      weeklyQuestAllCompleteClaimed: _boolValue(
        map['weeklyQuestAllCompleteClaimed'],
      ),
      weeklyAttendanceDayKeys: _intSet(map['weeklyAttendanceDayKeys']),
      weeklyAttendanceRewardClaimed: _boolValue(
        map['weeklyAttendanceRewardClaimed'],
      ),
      lastRunRuneReward: _intValue(map['lastRunRuneReward']),
      startingGoldUpgradeLevel: _intValue(map['startingGoldUpgradeLevel']),
      nexusHpUpgradeLevel: _intValue(map['nexusHpUpgradeLevel']),
      supplyUpgradeLevel: _intValue(map['supplyUpgradeLevel']),
      fireTrainingUpgradeLevel: _intValue(map['fireTrainingUpgradeLevel']),
      physicalDamageTrainingUpgradeLevel: _intValue(
        map['physicalDamageTrainingUpgradeLevel'],
      ),
      elementalDamageTrainingUpgradeLevel: _intValue(
        map['elementalDamageTrainingUpgradeLevel'],
      ),
      criticalChanceUpgradeLevel: _intValue(map['criticalChanceUpgradeLevel']),
      criticalDamageUpgradeLevel: _intValue(map['criticalDamageUpgradeLevel']),
      killGoldUpgradeLevel: _intValue(map['killGoldUpgradeLevel']),
      emergencySaleUpgradeLevel: _intValue(map['emergencySaleUpgradeLevel']),
      unlockedStageCount: _intValue(map['unlockedStageCount'], fallback: 1),
      bestRoundsByStage: _intIntMap(map['bestRoundsByStage']),
      clearedStageNumbers: _intSet(map['clearedStageNumbers']),
      researchLevels: _enumIntMap(ResearchType.values, map['researchLevels']),
      researchElapsedMillis: _enumIntMap(
        ResearchType.values,
        map['researchElapsedMillis'],
      ),
      activeResearches: activeResearches,
      researchSlotTwoUnlocked: _boolValue(
        map['researchSlotTwoUnlocked'],
        fallback: activeResearches.length > 1,
      ),
      turretModuleTickets: _intValue(map['turretModuleTickets']),
      turretModuleDrawCount: turretModuleDrawCount,
      turretModuleTicketPurchaseCount:
          map.containsKey('turretModuleTicketPurchaseCount')
          ? _nonNegativeInt(map['turretModuleTicketPurchaseCount'])
          : turretModuleDrawCount,
      turretModuleItemSequence: turretModuleItemSequence,
      ownedTurretModules: _objectList(
        map['ownedTurretModules'],
        SavedTurretModule.fromJson,
      ),
      coreCombatSkill: _coreCombatSkillFromSave(map),
      totalCorePoints: _nonNegativeInt(map['totalCorePoints']),
      lastRunCorePointReward: _nonNegativeInt(map['lastRunCorePointReward']),
      lastRunTurretModuleTicketReward: _nonNegativeInt(
        map['lastRunTurretModuleTicketReward'],
      ),
      corePassiveTreeRevision: _intValue(
        map['corePassiveTreeRevision'],
        fallback: core_tree.corePassiveTreeRevision,
      ),
      corePassiveNodeRanks: _corePassiveNodeRanksFromSave(
        map['corePassiveNodeRanks'],
      ),
      claimedCorePointStageRewards: _intSet(
        map['claimedCorePointStageRewards'],
      ).where((stage) => stage > 0).toSet(),
      claimedEventIds: _stringSet(map['claimedEventIds']),
    );
  }
}

CoreCombatSkill? _coreCombatSkillFromSave(Map<String, Object?> map) {
  return _nullableCoreCombatSkillFromSave(
    map,
    key: 'coreCombatSkill',
    missingFallback: CoreCombatSkill.guardianBeam,
  );
}

CoreCombatSkill? _nullableCoreCombatSkillFromSave(
  Map<String, Object?> map, {
  required String key,
  required CoreCombatSkill? missingFallback,
}) {
  if (!map.containsKey(key)) {
    return missingFallback;
  }
  final value = map[key];
  if (value == null) {
    return null;
  }
  return _enumValue(CoreCombatSkill.values, value) ??
      CoreCombatSkill.guardianBeam;
}

Map<CorePassiveNodeId, int> _corePassiveNodeRanksFromSave(Object? json) {
  final rawRanks = _enumIntMap(CorePassiveNodeId.values, json);
  return {
    for (final entry in rawRanks.entries)
      if (entry.value > 0)
        entry.key: entry.value
            .clamp(0, core_tree.corePassiveNodeById(entry.key).maxRank)
            .toInt(),
  };
}

class SavedActiveResearch {
  const SavedActiveResearch({
    required this.type,
    required this.targetLevel,
    required this.startedAtMillis,
    required this.durationMillis,
    required this.initialElapsedMillis,
  });

  final ResearchType type;
  final int targetLevel;
  final int startedAtMillis;
  final int durationMillis;
  final int initialElapsedMillis;

  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'targetLevel': targetLevel,
      'startedAtMillis': startedAtMillis,
      'durationMillis': durationMillis,
      'initialElapsedMillis': initialElapsedMillis,
    };
  }

  static SavedActiveResearch? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final type = _enumValue(ResearchType.values, json['type']);
    if (type == null) {
      return null;
    }
    return SavedActiveResearch(
      type: type,
      targetLevel: _intValue(json['targetLevel'], fallback: 1),
      startedAtMillis: _intValue(json['startedAtMillis']),
      durationMillis: _intValue(json['durationMillis']),
      initialElapsedMillis: _intValue(json['initialElapsedMillis']),
    );
  }
}

class SavedTurretModule {
  const SavedTurretModule({
    required this.id,
    required this.turretType,
    required this.part,
    required this.family,
    required this.grade,
    required this.options,
    required this.acquiredOrder,
    required this.equipped,
  });

  final String id;
  final TurretType turretType;
  final TurretModulePart part;
  final TurretModuleFamily family;
  final TurretModuleGrade grade;
  final List<SavedTurretModuleOption> options;
  final int acquiredOrder;
  final bool equipped;

  TurretModuleKey get key {
    return TurretModuleKey(
      turretType: turretType,
      part: part,
      family: family,
      grade: grade,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'turretType': turretType.name,
      'part': part.name,
      'family': family.name,
      'grade': grade.name,
      'options': options.map((option) => option.toJson()).toList(),
      'acquiredOrder': acquiredOrder,
      'equipped': equipped,
    };
  }

  static SavedTurretModule? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final id = _stringValue(json['id']);
    final turretType = _enumValue(TurretType.values, json['turretType']);
    final part = _enumValue(TurretModulePart.values, json['part']);
    final family = _enumValue(TurretModuleFamily.values, json['family']);
    final grade = _enumValue(TurretModuleGrade.values, json['grade']);
    final options = _objectList(
      json['options'],
      SavedTurretModuleOption.fromJson,
    );
    if (id == null ||
        turretType == null ||
        part == null ||
        family == null ||
        grade == null ||
        options.isEmpty) {
      return null;
    }
    return SavedTurretModule(
      id: id,
      turretType: turretType,
      part: part,
      family: family,
      grade: grade,
      options: List.unmodifiable(options),
      acquiredOrder: _intValue(json['acquiredOrder']),
      equipped: _boolValue(json['equipped']),
    );
  }
}

class SavedTurretModuleOption {
  const SavedTurretModuleOption({required this.type, required this.value});

  final TurretModuleOptionType type;
  final int value;

  Map<String, Object?> toJson() {
    return {'type': type.name, 'value': value};
  }

  static SavedTurretModuleOption? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final type = _enumValue(TurretModuleOptionType.values, json['type']);
    if (type == null) {
      return null;
    }
    return SavedTurretModuleOption(type: type, value: _intValue(json['value']));
  }
}
