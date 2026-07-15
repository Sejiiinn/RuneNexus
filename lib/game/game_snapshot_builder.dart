part of 'rune_nexus_game.dart';

class GameSnapshotBuilder {
  GameSnapshotBuilder(this._game);

  final RuneNexusGame _game;

  GameSnapshot build() {
    final nextWave = _game._roundIndex < _game._waves.length
        ? _game._waves[_game._roundIndex]
        : _game._waves.last;
    final selectedTurret = _game._selectedTurretPoint == null
        ? null
        : _game._turrets[_game._selectedTurretPoint];
    final levelUpPreviewActive =
        _game._levelUpPreviewPoint != null &&
        _game._levelUpPreviewPoint == _game._selectedTurretPoint &&
        selectedTurret != null &&
        selectedTurret.canLevelUp &&
        _game._gold >= selectedTurret.levelUpCost;
    if (!levelUpPreviewActive) {
      _game._levelUpPreviewPoint = null;
    }
    final selectedTurretNextLevel = levelUpPreviewActive
        ? selectedTurret.level + 1
        : 0;
    final selectedTurretBurnDamagePerSecond = selectedTurret == null
        ? 0.0
        : _game._turretBurnDamagePerSecondAtLevel(
            selectedTurret,
            selectedTurret.level,
          );
    final selectedTurretBurnDuration = selectedTurret == null
        ? 0.0
        : _game._turretBurnDuration(selectedTurret);
    final selectedTurretNextBurnDamagePerSecond = levelUpPreviewActive
        ? _game._turretBurnDamagePerSecondAtLevel(
            selectedTurret,
            selectedTurretNextLevel,
          )
        : 0.0;
    final selectedTurretNextBurnDuration = levelUpPreviewActive
        ? _game._turretBurnDuration(selectedTurret)
        : 0.0;
    final topDamageTurret = _game._turrets.values.fold<TurretComponent?>(null, (
      current,
      turret,
    ) {
      if (current == null || turret.damageDealt > current.damageDealt) {
        return turret;
      }
      return current;
    });
    final totalTurretDps = _game._totalTurretDps;
    final nextWaveEnemyTypes = RuneNexusGame._enemyTypesFor(nextWave);
    final nextWaveEnemyCounts = RuneNexusGame._enemyCountsFor(nextWave);
    final gemCollection = _gemCollectionTotals();
    final hasStageProgress =
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
    return GameSnapshot(
      gold: _game._gold,
      gemShards: _game._gemShards,
      nexusHp: _game._nexusHp,
      maxNexusHp: _game._maxNexusHp,
      round: math.min(_game._roundIndex + 1, _game._waves.length),
      maxRound: _game._waves.length,
      phase: _game._phase,
      restoredPhase: _game._phase == GamePhase.restored
          ? _game._restoredPhase
          : null,
      hasStageProgress: hasStageProgress,
      placedTurretCount: placedTurretCount,
      currentStageNumber: _game._currentStageNumber,
      unlockedStageCount: _game._progression.unlockedStageCount,
      bestRoundsByStage: Map.unmodifiable(_game._progression.bestRoundsByStage),
      clearedStageNumbers: Set.unmodifiable(
        _game._progression.clearedStageNumbers,
      ),
      availableTurretTypes: List.unmodifiable(_game._availableTurretTypes()),
      selectedTurretType: _game._selectedTurretType,
      selectedRunPanelTab: _game._selectedRunPanelTab,
      previewText: nextWave.previewText,
      rewardOptions: List.unmodifiable(_game._rewardOptions),
      isPurchasedGemReward: _game._isPurchasedGemReward,
      gemInventory: Map.unmodifiable(_game._gemInventory),
      gemCollection: Map.unmodifiable(gemCollection),
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
      selectedTurretLevelUpPreviewActive: levelUpPreviewActive,
      selectedTurretNextLevel: selectedTurretNextLevel,
      selectedTurretNextDamage: levelUpPreviewActive
          ? selectedTurret.damageAtLevel(selectedTurretNextLevel)
          : 0,
      selectedTurretNextRange: levelUpPreviewActive
          ? selectedTurret.rangeAtLevel(selectedTurretNextLevel)
          : 0,
      selectedTurretNextAttackRate: levelUpPreviewActive
          ? selectedTurret.attackRateAtLevel(selectedTurretNextLevel)
          : 0,
      selectedTurretNextBurnDamagePerSecond:
          selectedTurretNextBurnDamagePerSecond,
      selectedTurretNextBurnDuration: selectedTurretNextBurnDuration,
      selectedTurretRefundGold: selectedTurret?.refundGold ?? 0,
      selectedTurretDamage: selectedTurret?.damage ?? 0,
      selectedTurretRange: selectedTurret?.range ?? 0,
      selectedTurretAttackRate: selectedTurret?.attackRate ?? 0,
      selectedTurretCriticalChance: selectedTurret?.criticalChance ?? 0,
      selectedTurretCriticalDamageMultiplier:
          selectedTurret?.criticalDamageMultiplier ?? 1.5,
      selectedTurretBurnDamagePerSecond: selectedTurretBurnDamagePerSecond,
      selectedTurretBurnDuration: selectedTurretBurnDuration,
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
      selectedTurretPrimaryTraitCost: RuneNexusGame.primaryTraitCost,
      selectedTurretSecondaryTraitCost: RuneNexusGame.secondaryTraitCost,
      selectedTurretPrimaryTraitRequiredLevel:
          RuneNexusGame.primaryTraitRequiredLevel,
      selectedTurretSecondaryTraitRequiredLevel:
          RuneNexusGame.secondaryTraitRequiredLevel,
      topDamageTurretName:
          topDamageTurret == null || topDamageTurret.damageDealt <= 0
          ? null
          : topDamageTurret.definition.name,
      topDamageTurretDamageDealt: topDamageTurret?.damageDealt ?? 0,
      totalTurretDps: totalTurretDps,
      nexusCoreBeamIntervalSeconds: _game.nexusCoreBeamIntervalSeconds,
      nexusCoreBeamCooldownSeconds: _game.nexusCoreBeamCooldownSeconds,
      nexusCoreBeamAvailable: _game.nexusCoreBeamAvailable,
      nexusCoreBeamActive: _game.nexusCoreBeamActive,
      nexusCoreBeamDamage: _game.nexusCoreBeamDamage,
      coreCombatSkillDirectDamageDealt: _game.coreCombatSkillDirectDamageDealt,
      coreCombatSkillBonusDamageDealt: _game.coreCombatSkillBonusDamageDealt,
      coreCombatSkillActivationCount: _game.coreCombatSkillActivationCount,
      coreCombatSkill: _game.coreCombatSkill,
      corePassiveSlots: _game.corePassiveSlots,
      corePassiveSlotCount: _game.corePassiveSlotCount,
      corePassiveSlotUnlockCost: _game.corePassiveSlotUnlockCost,
      canUnlockCorePassiveSlot: _game.canUnlockCorePassiveSlot,
      unlockedCorePassiveAbilities: _game.unlockedCorePassiveAbilities,
      nextWaveEnemyTypes: List.unmodifiable(nextWaveEnemyTypes),
      nextWaveEnemyCounts: Map.unmodifiable(nextWaveEnemyCounts),
      nextWaveClearRewardGold: nextWave.clearRewardGold,
      nextWaveKillRewardGold: RuneNexusGame._killRewardGoldFor(nextWave),
      nextWaveClearRewardGemShards: RuneNexusGame._roundClearGemShardRewardFor(
        math.min(_game._roundIndex + 1, _game._waves.length),
      ),
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
      projectedFailureRuneReward: hasStageProgress
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

  Map<GemType, int> _gemCollectionTotals() {
    final totals = <GemType, int>{..._game._gemInventory};
    for (final turret in _game._turrets.values) {
      for (final gem in turret.equippedGems) {
        totals[gem] = (totals[gem] ?? 0) + 1;
      }
    }
    return totals;
  }
}
