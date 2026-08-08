part of 'rune_nexus_game.dart';

class GameSnapshotBuilder {
  GameSnapshotBuilder(this._game);

  final RuneNexusGame _game;

  GameSnapshot build() {
    final nextWaveSnapshot = _nextWaveSnapshot();
    final selectedTurretSnapshot = _selectedTurretSnapshot();
    final selectedTurret = selectedTurretSnapshot.turret;
    final combatSnapshot = _combatSnapshot();
    final topDamageTurret = combatSnapshot.topDamageTurret;
    final stageProgressSnapshot = _stageProgressSnapshot();
    return GameSnapshot(
      gold: _game._gold,
      gemShards: _game._gemShards,
      nexusHp: _game._nexusHp,
      maxNexusHp: _game._maxNexusHp,
      round: nextWaveSnapshot.round,
      maxRound: _game._waves.length,
      phase: _game._phase,
      restoredPhase: _game._phase == GamePhase.restored
          ? _game._restoredPhase
          : null,
      hasStageProgress: stageProgressSnapshot.hasProgress,
      placedTurretCount: stageProgressSnapshot.placedTurretCount,
      currentStageNumber: _game._currentStageNumber,
      unlockedStageCount: _game._progression.unlockedStageCount,
      bestRoundsByStage: Map.unmodifiable(_game._progression.bestRoundsByStage),
      clearedStageNumbers: Set.unmodifiable(
        _game._progression.clearedStageNumbers,
      ),
      availableTurretTypes: List.unmodifiable(_game._availableTurretTypes()),
      selectedTurretType: _game._selectedTurretType,
      selectedRunPanelTab: _game._selectedRunPanelTab,
      previewText: nextWaveSnapshot.wave.previewText,
      rewardOptions: List.unmodifiable(_game._rewardOptions),
      isPurchasedGemReward: _game._isPurchasedGemReward,
      gemInventory: Map.unmodifiable(_game._gemInventory),
      gemCollection: Map.unmodifiable(combatSnapshot.gemCollection),
      selectedBuildPoint: _game._selectedBuildPoint,
      selectedBuildTurretType: _game._selectedBuildTurretType,
      selectedPortalPoint: _game._selectedPortalPoint,
      selectedCorePoint: _game._selectedCorePoint,
      selectedTurretPoint: _game._selectedTurretPoint,
      selectedTurretName: selectedTurret?.definition.name,
      selectedTurretGems: List.unmodifiable(
        selectedTurret?.equippedGemSlots ?? const [],
      ),
      selectedTurretGemSlotIndex:
          selectedTurret == null || _game._selectedTurretGemSlotIndex == null
          ? null
          : _game._selectedTurretGemSlotIndex!
                .clamp(0, selectedTurret.slotLimit - 1)
                .toInt(),
      selectedTurretSlotLimit: selectedTurret?.slotLimit ?? 0,
      selectedTurretHasLinkUpgrade: selectedTurret?.hasNextLinkUpgrade ?? false,
      selectedTurretCanUpgradeLink: selectedTurret?.canUpgradeLink ?? false,
      selectedTurretLinkUpgradeCost: selectedTurret?.linkUpgradeCost ?? 0,
      selectedTurretNextSlotLimit: selectedTurret?.nextSlotLimit ?? 0,
      selectedTurretLinkUpgradeRequiredLevel:
          selectedTurret?.linkUpgradeRequiredLevel ?? 0,
      selectedTurretLevel: selectedTurret?.level ?? 0,
      selectedTurretMaxLevel: selectedTurret?.maxLevel ?? 0,
      selectedTurretCanLevelUp: selectedTurret?.canLevelUp ?? false,
      selectedTurretLevelUpCost: selectedTurret?.levelUpCost ?? 0,
      selectedTurretLevelUpPreviewActive:
          selectedTurretSnapshot.levelUpPreviewActive,
      selectedTurretNextLevel: selectedTurretSnapshot.nextLevel,
      selectedTurretNextDamage: selectedTurretSnapshot.nextDamage,
      selectedTurretNextRange: selectedTurretSnapshot.nextRange,
      selectedTurretNextAttackRate: selectedTurretSnapshot.nextAttackRate,
      selectedTurretNextBurnDamagePerSecond:
          selectedTurretSnapshot.nextBurnDamagePerSecond,
      selectedTurretNextBurnDuration: selectedTurretSnapshot.nextBurnDuration,
      selectedTurretRefundGold: selectedTurret?.refundGold ?? 0,
      selectedTurretDamage: selectedTurret?.damage ?? 0,
      selectedTurretRange: selectedTurret?.range ?? 0,
      selectedTurretAttackRate: selectedTurret?.attackRate ?? 0,
      selectedTurretCriticalChance: selectedTurret?.criticalChance ?? 0,
      selectedTurretCriticalDamageMultiplier:
          selectedTurret?.criticalDamageMultiplier ?? 1.5,
      selectedTurretBurnDamagePerSecond:
          selectedTurretSnapshot.burnDamagePerSecond,
      selectedTurretBurnDuration: selectedTurretSnapshot.burnDuration,
      selectedTurretDamageDealt: selectedTurret?.damageDealt ?? 0,
      selectedTurretDirectDamageDealt: selectedTurret?.directDamageDealt ?? 0,
      selectedTurretSplashDamageDealt: selectedTurret?.splashDamageDealt ?? 0,
      selectedTurretChainDamageDealt: selectedTurret?.chainDamageDealt ?? 0,
      selectedTurretBurnDamageDealt: selectedTurret?.burnDamageDealt ?? 0,
      canSetTurretTargetPriority: _game._progression.canSetTurretTargetPriority,
      selectedTurretTargetPriority:
          selectedTurret?.targetPriority ?? TurretTargetPriority.first,
      selectedTurretSupportsTraits: selectedTurret?.supportsTraits ?? false,
      selectedTurretPrimaryTraitChoices: List.unmodifiable(
        selectedTurret?.primaryTraitChoices ?? const [],
      ),
      selectedTurretSecondaryTraitChoices: List.unmodifiable(
        selectedTurret?.secondaryTraitChoices ?? const [],
      ),
      selectedTurretPrimaryTrait: selectedTurret?.primaryTrait,
      selectedTurretSecondaryTrait: selectedTurret?.secondaryTrait,
      selectedTurretCanChoosePrimaryTrait:
          selectedTurret?.canChoosePrimaryTrait ?? false,
      selectedTurretCanChooseSecondaryTrait:
          selectedTurret?.canChooseSecondaryTrait ?? false,
      selectedTurretPrimaryTraitCost: _game.primaryTraitGemShardCost,
      selectedTurretSecondaryTraitCost: _game.secondaryTraitGemShardCost,
      selectedTurretPrimaryTraitRequiredLevel:
          RuneNexusGame.primaryTraitRequiredLevel,
      selectedTurretSecondaryTraitRequiredLevel:
          RuneNexusGame.secondaryTraitRequiredLevel,
      topDamageTurretName:
          topDamageTurret == null || topDamageTurret.damageDealt <= 0
          ? null
          : topDamageTurret.definition.name,
      topDamageTurretDamageDealt: topDamageTurret?.damageDealt ?? 0,
      totalTurretDps: combatSnapshot.totalTurretDps,
      nexusCoreBeamIntervalSeconds: _game.nexusCoreBeamIntervalSeconds,
      nexusCoreBeamCooldownSeconds: _game.nexusCoreBeamCooldownSeconds,
      nexusCoreBeamAvailable: _game.nexusCoreBeamAvailable,
      nexusCoreBeamActive: _game.nexusCoreBeamActive,
      nexusCoreBeamDamage: _game.nexusCoreBeamDamage,
      coreCombatSkillDirectDamageDealt: _game.coreCombatSkillDirectDamageDealt,
      coreCombatSkillBonusDamageDealt: _game.coreCombatSkillBonusDamageDealt,
      coreCombatSkillActivationCount: _game.coreCombatSkillActivationCount,
      coreCombatSkill: _game.coreCombatSkill,
      totalCorePoints: _game.totalCorePoints,
      spentCorePoints: _game.spentCorePoints,
      availableCorePoints: _game.availableCorePoints,
      lastRunCorePointReward: _game.lastRunCorePointReward,
      lastRunTurretModuleTicketReward: _game.lastRunTurretModuleTicketReward,
      corePassiveNodeRanks: Map.unmodifiable(_game.corePassiveNodeRanks),
      nextWaveEnemyTypes: List.unmodifiable(nextWaveSnapshot.enemyTypes),
      nextWaveEnemyCounts: Map.unmodifiable(nextWaveSnapshot.enemyCounts),
      nextWaveClearRewardGold: nextWaveSnapshot.wave.clearRewardGold,
      nextWaveKillRewardGold: nextWaveSnapshot.killRewardGold,
      nextWaveClearRewardGemShards: nextWaveSnapshot.clearRewardGemShards,
      autoStartMode: _game._autoStartMode,
      speedMultiplier: _game._speedMultiplier,
      killGoldFractionWallet: _game._killGoldFractionWallet,
      runUpgradeLevels: Map.unmodifiable(_game._runUpgradeLevels),
      towerDamageRunBonusRate: _game._towerDamageRunBonusRate,
      killGoldRunBonusRate: _game._killGoldRunBonusRate,
      waveClearGoldRunBonus: _game._waveClearGoldRunBonus,
      runes: _game._progression.runes,
      diamonds: _game._progression.diamonds,
      turretModuleTickets: _game._progression.turretModuleTickets,
      turretModuleDrawCount: _game._progression.turretModuleDrawCount,
      ownedTurretModules: _game._progression.ownedTurretModules,
      dailyQuestDayKey: _game._progression.dailyQuestDayKey,
      dailyQuestProgress: Map.unmodifiable(
        _game._progression.dailyQuestProgress,
      ),
      claimedDailyQuestRewards: Set.unmodifiable(
        _game._progression.claimedDailyQuestRewards,
      ),
      completedDailyQuestCount: _game._progression.completedDailyQuestCount,
      dailyAttendanceRewardClaimed:
          _game._progression.dailyAttendanceRewardClaimed,
      dailyQuestAllCompleteClaimed:
          _game._progression.dailyQuestAllCompleteClaimed,
      dailyQuestClockRollbackDetected:
          _game._progression.dailyQuestClockRollbackDetected,
      weeklyQuestWeekKey: _game._progression.weeklyQuestWeekKey,
      weeklyQuestProgress: Map.unmodifiable(
        _game._progression.weeklyQuestProgress,
      ),
      claimedWeeklyQuestRewards: Set.unmodifiable(
        _game._progression.claimedWeeklyQuestRewards,
      ),
      completedWeeklyQuestCount: _game._progression.completedWeeklyQuestCount,
      weeklyQuestAllCompleteClaimed:
          _game._progression.weeklyQuestAllCompleteClaimed,
      weeklyAttendanceDays: _game._progression.weeklyAttendanceDayKeys.length,
      weeklyAttendanceRewardClaimed:
          _game._progression.weeklyAttendanceRewardClaimed,
      lastRunRuneReward: _game._progression.lastRunRuneReward,
      projectedFailureRuneReward: stageProgressSnapshot.hasProgress
          ? _game._progression.runeRewardFor(
              _game._roundIndex,
              success: false,
              stageNumber: _game._currentStageNumber,
            )
          : 0,
      lastRunPreviousBestRound: _game._lastRunPreviousBestRound,
      lastRunWasNewBestRound: _game._lastRunWasNewBestRound,
      lastRunUnlockedStageNumber: _game._lastRunUnlockedStageNumber,
      lastRunUnlockedSniperTurret: _game._lastRunUnlockedSniperTurret,
      completedRounds: _game._completedRounds,
      startingGoldUpgradeLevel: _game._progression.startingGoldUpgradeLevel,
      startingGoldUpgradeCost: _game._progression.startingGoldUpgradeCost,
      canUpgradeStartingGold: _game._progression.canUpgradeStartingGold,
      nexusHpUpgradeLevel: _game._progression.nexusHpUpgradeLevel,
      nexusHpUpgradeCost: _game._progression.nexusHpUpgradeCost,
      canUpgradeNexusHp: _game._progression.canUpgradeNexusHp,
      supplyUpgradeLevel: _game._progression.supplyUpgradeLevel,
      supplyUpgradeCost: _game._progression.supplyUpgradeCost,
      canUpgradeSupply: _game._progression.canUpgradeSupply,
      waveClearGoldProgressionBonus: _game._progression.waveClearGoldBonus,
      fireTrainingUpgradeLevel: _game._progression.fireTrainingUpgradeLevel,
      fireTrainingUpgradeCost: _game._progression.fireTrainingUpgradeCost,
      canUpgradeFireTraining: _game._progression.canUpgradeFireTraining,
      fireTrainingDamageBonusRate:
          _game._progression.fireTrainingDamageBonusRate,
      physicalDamageTrainingUpgradeLevel:
          _game._progression.physicalDamageTrainingUpgradeLevel,
      physicalDamageTrainingUpgradeCost:
          _game._progression.physicalDamageTrainingUpgradeCost,
      canUpgradePhysicalDamageTraining:
          _game._progression.isStageCleared(7) &&
          _game._progression.canUpgradePhysicalDamageTraining,
      physicalDamageTrainingBonusRate:
          _game._progression.physicalDamageTrainingBonusRate,
      elementalDamageTrainingUpgradeLevel:
          _game._progression.elementalDamageTrainingUpgradeLevel,
      elementalDamageTrainingUpgradeCost:
          _game._progression.elementalDamageTrainingUpgradeCost,
      canUpgradeElementalDamageTraining:
          _game._progression.isStageCleared(7) &&
          _game._progression.canUpgradeElementalDamageTraining,
      elementalDamageTrainingBonusRate:
          _game._progression.elementalDamageTrainingBonusRate,
      criticalChanceUpgradeLevel: _game._progression.criticalChanceUpgradeLevel,
      criticalChanceUpgradeCost: _game._progression.criticalChanceUpgradeCost,
      canUpgradeCriticalChance:
          _game._progression.isStageCleared(4) &&
          _game._progression.canUpgradeCriticalChance,
      criticalChanceProgressionBonusRate:
          _game.criticalChanceProgressionBonusRate,
      criticalDamageUpgradeLevel: _game._progression.criticalDamageUpgradeLevel,
      criticalDamageUpgradeCost: _game._progression.criticalDamageUpgradeCost,
      canUpgradeCriticalDamage:
          _game._progression.isStageCleared(4) &&
          _game._progression.canUpgradeCriticalDamage,
      criticalDamageProgressionBonusRate:
          _game.criticalDamageProgressionBonusRate,
      killGoldUpgradeLevel: _game._progression.killGoldUpgradeLevel,
      killGoldUpgradeCost: _game._progression.killGoldUpgradeCost,
      canUpgradeKillGold:
          _game._progression.isStageCleared(
            RuneNexusGame.economyUpgradeUnlockStage,
          ) &&
          _game._progression.canUpgradeKillGold,
      killGoldProgressionBonusRate: _game._killGoldProgressionBonusRate,
      emergencySaleUpgradeLevel: _game._progression.emergencySaleUpgradeLevel,
      emergencySaleUpgradeCost: _game._progression.emergencySaleUpgradeCost,
      canUpgradeEmergencySale:
          _game._progression.isStageCleared(
            RuneNexusGame.economyUpgradeUnlockStage,
          ) &&
          _game._progression.canUpgradeEmergencySale,
      turretRefundPercent: _game.turretRefundPercent,
      researchSlotCount: _game._progression.availableResearchSlotCount,
      researchLevels: Map.unmodifiable(_game._progression.researchLevels),
      researchElapsedMillis: Map.unmodifiable(
        _game._progression.researchElapsedMillis,
      ),
      activeResearches: List.unmodifiable(_game._progression.activeResearches),
      startingGemShards: _game._progression.startingGemShards,
    );
  }

  _NextWaveSnapshot _nextWaveSnapshot() {
    final round = math.min(_game._roundIndex + 1, _game._waves.length);
    final wave = _game._roundIndex < _game._waves.length
        ? _game._waves[_game._roundIndex]
        : _game._waves.last;
    return _NextWaveSnapshot(
      wave: wave,
      round: round,
      enemyTypes: RuneNexusGame._enemyTypesFor(wave),
      enemyCounts: RuneNexusGame._enemyCountsFor(wave),
      killRewardGold: RuneNexusGame._killRewardGoldFor(wave),
      clearRewardGemShards: RuneNexusGame._roundClearGemShardRewardFor(round),
    );
  }

  _SelectedTurretSnapshot _selectedTurretSnapshot() {
    final selectedTurret = _game._selectedTurretPoint == null
        ? null
        : _game._turrets[_game._selectedTurretPoint];
    final levelUpPreviewActive =
        _game._levelUpPreviewPoint != null &&
        _game._levelUpPreviewPoint == _game._selectedTurretPoint &&
        selectedTurret != null &&
        selectedTurret.canLevelUp &&
        _game._gold >= selectedTurret.levelUpCost;
    final nextLevel = levelUpPreviewActive ? selectedTurret.level + 1 : 0;
    return _SelectedTurretSnapshot(
      turret: selectedTurret,
      levelUpPreviewActive: levelUpPreviewActive,
      nextLevel: nextLevel,
      nextDamage: levelUpPreviewActive
          ? selectedTurret.damageAtLevel(nextLevel)
          : 0,
      nextRange: levelUpPreviewActive
          ? selectedTurret.rangeAtLevel(nextLevel)
          : 0,
      nextAttackRate: levelUpPreviewActive
          ? selectedTurret.attackRateAtLevel(nextLevel)
          : 0,
      burnDamagePerSecond: selectedTurret == null
          ? 0
          : _game._turretBurnDamagePerSecondAtLevel(
              selectedTurret,
              selectedTurret.level,
            ),
      burnDuration: selectedTurret == null
          ? 0
          : _game._turretBurnDuration(selectedTurret),
      nextBurnDamagePerSecond: levelUpPreviewActive
          ? _game._turretBurnDamagePerSecondAtLevel(selectedTurret, nextLevel)
          : 0,
      nextBurnDuration: levelUpPreviewActive
          ? _game._turretBurnDuration(selectedTurret)
          : 0,
    );
  }

  _CombatSnapshot _combatSnapshot() {
    final topDamageTurret = _game._turrets.values.fold<TurretComponent?>(null, (
      current,
      turret,
    ) {
      if (current == null || turret.damageDealt > current.damageDealt) {
        return turret;
      }
      return current;
    });
    final gemCollection = <GemType, int>{..._game._gemInventory};
    for (final turret in _game._turrets.values) {
      for (final gem in turret.equippedGems) {
        gemCollection[gem] = (gemCollection[gem] ?? 0) + 1;
      }
    }
    return _CombatSnapshot(
      topDamageTurret: topDamageTurret,
      totalTurretDps: _game._totalTurretDps,
      gemCollection: gemCollection,
    );
  }

  _StageProgressSnapshot _stageProgressSnapshot() {
    final hasProgress =
        _game._phase == GamePhase.wave ||
        _game._phase == GamePhase.reward ||
        _game._phase == GamePhase.restored ||
        _game._roundIndex > 0 ||
        _game._completedRounds > 0 ||
        _game._turrets.isNotEmpty ||
        _game._savedTurretCountForMenu > 0 ||
        _game._runUpgradeLevels.isNotEmpty ||
        _game.enemies.isNotEmpty ||
        !_game._waveSpawner.isEmpty ||
        _game._killGoldFractionWallet > 0 ||
        _game._rewardOptions.isNotEmpty;
    final placedTurretCount = _game._turrets.isNotEmpty
        ? _game._turrets.length
        : _game._savedTurretCountForMenu;
    return _StageProgressSnapshot(
      hasProgress: hasProgress,
      placedTurretCount: placedTurretCount,
    );
  }
}

class _NextWaveSnapshot {
  const _NextWaveSnapshot({
    required this.wave,
    required this.round,
    required this.enemyTypes,
    required this.enemyCounts,
    required this.killRewardGold,
    required this.clearRewardGemShards,
  });

  final WaveDefinition wave;
  final int round;
  final List<EnemyType> enemyTypes;
  final Map<EnemyType, int> enemyCounts;
  final int killRewardGold;
  final int clearRewardGemShards;
}

class _SelectedTurretSnapshot {
  const _SelectedTurretSnapshot({
    required this.turret,
    required this.levelUpPreviewActive,
    required this.nextLevel,
    required this.nextDamage,
    required this.nextRange,
    required this.nextAttackRate,
    required this.burnDamagePerSecond,
    required this.burnDuration,
    required this.nextBurnDamagePerSecond,
    required this.nextBurnDuration,
  });

  final TurretComponent? turret;
  final bool levelUpPreviewActive;
  final int nextLevel;
  final double nextDamage;
  final double nextRange;
  final double nextAttackRate;
  final double burnDamagePerSecond;
  final double burnDuration;
  final double nextBurnDamagePerSecond;
  final double nextBurnDuration;
}

class _CombatSnapshot {
  const _CombatSnapshot({
    required this.topDamageTurret,
    required this.totalTurretDps,
    required this.gemCollection,
  });

  final TurretComponent? topDamageTurret;
  final double totalTurretDps;
  final Map<GemType, int> gemCollection;
}

class _StageProgressSnapshot {
  const _StageProgressSnapshot({
    required this.hasProgress,
    required this.placedTurretCount,
  });

  final bool hasProgress;
  final int placedTurretCount;
}
