part of 'rune_nexus_game.dart';

class GameRestoreController {
  GameRestoreController(this._game);

  final RuneNexusGame _game;

  void restoreMenuStateFromSaveData(GameSaveData data) {
    _restoreSavedMeta(data);
    _game._savedTurretCountForMenu = data.turrets.length;

    if (!data.hasActiveRun) {
      _game._savedTurretCountForMenu = 0;
      _restoreInactiveRunState(data);
      _resetRunPanelSelection();
      return;
    }

    _restoreActiveRunState(data);
    _resetRunPanelSelection();
    _applyRestoredPhase(data, restoreWaveAsPaused: true);
  }

  void restoreFromSaveData(GameSaveData data) {
    _restoreSavedMeta(data);
    _clearBoardEntities();

    if (!data.hasActiveRun) {
      _restoreInactiveRunState(data);
      return;
    }

    _restoreActiveRunState(data);
    _resetRunPanelSelection();

    if (_game._saveAdapter.hasSavedRunMapMismatch(data, _game._map)) {
      _refundSavedTurretsForMapChange(data.turrets);
      _game._phase = GamePhase.preparation;
      _game._restoredPhase = null;
      _game._rewardOptions.clear();
      _game._isPurchasedGemReward = false;
      _game._rewardReturnPhase = null;
      _resetBoardSelection();
      _game._requestLocalSave(immediate: true);
      return;
    }

    _restoreTurrets(data.turrets);
    _restoreEnemies(data.enemies);
    _game._waveSpawner.restoreFromSaveData(data.spawnQueue);
    _applyRestoredPhase(data, restoreWaveAsPaused: true);
  }

  void _restoreSavedMeta(GameSaveData data) {
    _game._autoStartMode = data.autoStartMode;
    _game._progression.restoreFromSaveData(data.progression);
    _restoreRunUpgradeState(data);
    _game._gemInventory
      ..clear()
      ..addEntries(data.gemInventory.entries.where((entry) => entry.value > 0));
    _game._rewardOptions
      ..clear()
      ..addAll(data.rewardOptions);
    _game._gemShards = math.max(0, data.gemShards);
    _game._isPurchasedGemReward = data.isPurchasedGemReward;
    _game._rewardReturnPhase = data.isPurchasedGemReward
        ? data.rewardReturnPhase
        : null;
  }

  void _restoreInactiveRunState(GameSaveData data) {
    _game._selectStage(_game._clampedStageNumber(data.stageNumber));
    _game._captureRunCoreLoadoutFromProgression();
    _game._gold = _game._initialGold;
    _game._gemShards = 0;
    _game._nexusHp = _game._maxNexusHp;
    _game._roundIndex = 0;
    _game._completedRounds = 0;
    _game._runUpgradeLevels.clear();
    _game._killGoldFractionWallet = 0;
    _resetLastRunResult();
    _game._phase = GamePhase.preparation;
    _game._restoredPhase = null;
    _game._isPurchasedGemReward = false;
    _game._rewardReturnPhase = null;
  }

  void _restoreActiveRunState(GameSaveData data) {
    _game._restoreRunCoreLoadoutFromSave(data);
    _game._gold = math.max(0, data.gold);
    _game._gemShards = math.max(0, data.gemShards);
    _game._selectStage(_game._clampedStageNumber(data.stageNumber));
    _game._nexusHp = data.nexusHp.clamp(0, _game._maxNexusHp).toInt();
    _game._roundIndex = data.roundIndex
        .clamp(0, _game._waves.length - 1)
        .toInt();
    _game._completedRounds = data.completedRounds
        .clamp(0, _game._waves.length)
        .toInt();
    _resetLastRunResult();
  }

  void _resetLastRunResult() {
    _game._lastRunPreviousBestRound = 0;
    _game._lastRunWasNewBestRound = false;
    _game._lastRunUnlockedStageNumber = null;
    _game._lastRunUnlockedSniperTurret = false;
  }

  void _resetRunPanelSelection() {
    _game._selectedTurretType = TurretType.arrow;
    _game._selectedRunPanelTab = RunPanelTab.turrets;
    _resetBoardSelection();
  }

  void _resetBoardSelection() {
    _game._selectedBuildTurretType = null;
    _game._selectedBuildPoint = null;
    _game._selectedPortalPoint = null;
    _game._selectedCorePoint = null;
    _game._selectedTurretPoint = null;
    _game._selectedTurretGemSlotIndex = null;
  }

  void _applyRestoredPhase(
    GameSaveData data, {
    required bool restoreWaveAsPaused,
  }) {
    final restoredPhase = data.phase == GamePhase.restored
        ? GamePhase.preparation
        : data.phase;
    if (restoredPhase != GamePhase.wave || !restoreWaveAsPaused) {
      _game._phase = restoredPhase;
      _game._restoredPhase = null;
      if (restoredPhase != GamePhase.reward || !_game._isPurchasedGemReward) {
        _game._rewardReturnPhase = null;
      }
      _restoreEmptyRewardOptionsIfNeeded();
      return;
    }

    _game._phase = GamePhase.restored;
    _game._restoredPhase = restoredPhase;
    _game._isPurchasedGemReward = false;
    _game._rewardReturnPhase = null;
    _restoreEmptyRewardOptionsIfNeeded();
  }

  void _restoreEmptyRewardOptionsIfNeeded() {
    if (_game._phase != GamePhase.reward || _game._rewardOptions.isNotEmpty) {
      return;
    }

    final fallbackOptions = _game._availableGemTypes().take(3).toList();
    if (fallbackOptions.isNotEmpty) {
      _game._rewardOptions.addAll(fallbackOptions);
      _game._requestLocalSave(immediate: true);
      return;
    }

    _game._phase = GamePhase.preparation;
    _game._restoredPhase = null;
    _game._isPurchasedGemReward = false;
    _game._rewardReturnPhase = null;
    _game._requestLocalSave(immediate: true);
  }

  void _clearBoardEntities() {
    _game._clearActiveCombat();
    for (final turret in _game._turrets.values.toList()) {
      turret.removeFromParent();
    }
    _game._turrets.clear();
  }

  void _restoreTurrets(List<SavedTurret> savedTurrets) {
    for (final savedTurret in savedTurrets) {
      final definition = gameTurrets[savedTurret.type];
      if (definition == null || !_game._map.contains(savedTurret.point)) {
        continue;
      }
      final turret = TurretComponent(
        gridPoint: savedTurret.point,
        definition: definition,
        game: _game,
        center: _game._centerOf(savedTurret.point),
        tileSize: _game._tileSize,
      )..restoreFromSaveData(savedTurret);
      for (final gem in savedTurret.equippedGemSlots.skip(turret.slotLimit)) {
        if (gem != null) {
          _game._gemInventory[gem] = (_game._gemInventory[gem] ?? 0) + 1;
        }
      }
      _game._turrets[savedTurret.point] = turret;
      _game.add(turret);
    }
  }

  void _restoreEnemies(List<SavedEnemy> savedEnemies) {
    for (final savedEnemy in savedEnemies) {
      final definition = gameEnemies[savedEnemy.type];
      if (definition == null || savedEnemy.hp <= 0) {
        continue;
      }
      final enemy = EnemyComponent(
        definition: definition,
        maxHp: savedEnemy.maxHp > 0
            ? savedEnemy.maxHp
            : scaledEnemyMaxHp(
                definition,
                _game._waves[_game._roundIndex].round,
                stageNumber: _game._currentStageNumber,
              ),
        maxShield: scaledEnemyMaxShield(
          definition,
          _game._waves[_game._roundIndex].round,
          stageNumber: _game._currentStageNumber,
        ),
        maxArmor: scaledEnemyMaxArmor(
          definition,
          _game._waves[_game._roundIndex].round,
          stageNumber: _game._currentStageNumber,
        ),
        path: _game._worldPath,
        game: _game,
      )..restoreFromSaveData(savedEnemy);
      _game.enemies.add(enemy);
      _game.add(enemy);
    }
  }

  void _refundSavedTurretsForMapChange(List<SavedTurret> savedTurrets) {
    final refund = _game._saveAdapter.refundSavedTurretsForMapChange(
      savedTurrets: savedTurrets,
      baseCostFor: (type) => gameTurrets[type]?.cost,
      primaryTraitCost: RuneNexusGame.primaryTraitCost,
      secondaryTraitCost: RuneNexusGame.secondaryTraitCost,
      firstLinkUpgradeDiscountRate: _game.firstLinkUpgradeDiscountRate,
    );
    _game._gold += refund.gold;
    _game._gemShards += refund.gemShards;
    for (final entry in refund.gemInventory.entries) {
      _game._gemInventory[entry.key] =
          (_game._gemInventory[entry.key] ?? 0) + entry.value;
    }
    _game._waveSpawner.clear();
  }

  void _restoreRunUpgradeState(GameSaveData data) {
    _game._runUpgradeLevels
      ..clear()
      ..addEntries(
        data.runUpgradeLevels.entries
            .where((entry) {
              final definition = gameRunUpgrades[entry.key];
              return definition != null && entry.value > 0;
            })
            .map((entry) {
              final maxLevel = gameRunUpgrades[entry.key]!.maxLevel;
              return MapEntry(
                entry.key,
                entry.value.clamp(0, maxLevel).toInt(),
              );
            }),
      );
    _game._killGoldFractionWallet = data.killGoldFractionWallet
        .clamp(0.0, 0.999999)
        .toDouble();
  }
}
