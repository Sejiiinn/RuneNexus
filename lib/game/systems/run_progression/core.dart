part of '../run_progression.dart';

mixin _CoreProgression {
  int get unlockedStageCount;
  Set<int> get clearedStageNumbers;

  CoreCombatSkill? coreCombatSkill = CoreCombatSkill.guardianBeam;
  int totalCorePoints = 0;
  int lastRunCorePointReward = 0;
  int corePassiveTreeRevision = core_tree.corePassiveTreeRevision;
  final Map<CorePassiveNodeId, int> corePassiveNodeRanks = {};
  final Set<int> claimedCorePointStageRewards = {};

  int get spentCorePoints =>
      core_tree.corePassiveSpentPoints(corePassiveNodeRanks);
  int get availableCorePoints => totalCorePoints - spentCorePoints;

  int corePassiveNodeRank(CorePassiveNodeId id) =>
      corePassiveNodeRanks[id] ?? 0;

  bool equipCoreCombatSkill(CoreCombatSkill skill) {
    if (!_isCoreCombatSkillUnlocked(skill) || coreCombatSkill == skill) {
      return _isCoreCombatSkillUnlocked(skill);
    }
    coreCombatSkill = skill;
    return true;
  }

  bool _isCoreCombatSkillUnlocked(CoreCombatSkill skill) {
    return switch (skill) {
      CoreCombatSkill.guardianBeam => true,
      CoreCombatSkill.riftMark => unlockedStageCount >= 6,
    };
  }

  bool unequipCoreCombatSkill() {
    if (coreCombatSkill == null) {
      return false;
    }
    coreCombatSkill = null;
    return true;
  }

  void _sanitizeCoreCombatSkill() {
    final skill = coreCombatSkill;
    if (skill != null && !_isCoreCombatSkillUnlocked(skill)) {
      coreCombatSkill = CoreCombatSkill.guardianBeam;
    }
  }

  bool setCorePassiveNodeRank(CorePassiveNodeId id, int targetRank) {
    final candidate = Map<CorePassiveNodeId, int>.of(corePassiveNodeRanks);
    if (targetRank == 0) {
      candidate.remove(id);
    } else {
      candidate[id] = targetRank;
    }
    return setCorePassiveNodeRanks(candidate);
  }

  bool setCorePassiveNodeRanks(Map<CorePassiveNodeId, int> ranks) {
    final candidate = <CorePassiveNodeId, int>{};
    for (final entry in ranks.entries) {
      final definition = core_tree.corePassiveNodeDefinitions[entry.key];
      if (definition == null ||
          entry.value < 0 ||
          entry.value > definition.maxRank) {
        return false;
      }
      if (entry.value > 0) {
        candidate[entry.key] = entry.value;
      }
    }
    final unchanged =
        candidate.length == corePassiveNodeRanks.length &&
        candidate.entries.every(
          (entry) => corePassiveNodeRanks[entry.key] == entry.value,
        );
    if (unchanged ||
        !core_tree.isValidCorePassiveAllocation(candidate) ||
        core_tree.corePassiveSpentPoints(candidate) > totalCorePoints) {
      return false;
    }
    corePassiveNodeRanks
      ..clear()
      ..addAll(candidate);
    return true;
  }

  bool resetCorePassiveTree() {
    if (corePassiveNodeRanks.isEmpty) {
      return false;
    }
    corePassiveNodeRanks.clear();
    return true;
  }

  void grantCorePoints(int amount) {
    if (amount > 0) {
      totalCorePoints += amount;
    }
  }

  int grantFirstClearCorePoints({
    required int stageNumber,
    required int reward,
  }) {
    if (stageNumber <= 0 ||
        reward < 0 ||
        claimedCorePointStageRewards.contains(stageNumber)) {
      return 0;
    }
    claimedCorePointStageRewards.add(stageNumber);
    grantCorePoints(reward);
    return reward;
  }

  int grantRetroactiveCorePointRewards(Map<int, int> rewardsByStage) {
    var granted = 0;
    for (final stageNumber in clearedStageNumbers) {
      final reward = rewardsByStage[stageNumber];
      if (reward == null) {
        continue;
      }
      granted += grantFirstClearCorePoints(
        stageNumber: stageNumber,
        reward: reward,
      );
    }
    return granted;
  }
}
