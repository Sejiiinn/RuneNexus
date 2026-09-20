part of 'rune_nexus_game.dart';

extension _NativeWaveGame on RuneNexusGame {
  Map<String, Object?> _nativeWaveConfiguration() {
    _nativeWaveId = _roundIndex + 1;
    return {
      'id': _nativeWaveId,
      'active':
          _phase == GamePhase.wave ||
          (_phase == GamePhase.restored && _restoredPhase == GamePhase.wave),
      'spawnQueue': [
        for (final request in _waveSpawner.toSaveData())
          {
            ...request.toJson(),
            'enemy': _nativePlannedEnemy(request.enemyType),
          },
      ],
      'core': {
        ..._coreCombatSkillController.nativeRuntimeState(),
        'emergencyChargeUsedThisRound': _emergencyChargeUsedThisRound,
      },
      'emergencyChargeUsedThisRound': _emergencyChargeUsedThisRound,
    };
  }

  Map<String, Object?> _nativePlannedEnemy(EnemyType type) {
    final definition = gameEnemies[type]!;
    final round = _waves[_roundIndex].round;
    final enemy = EnemyComponent(
      definition: definition,
      maxHp: scaledEnemyMaxHp(
        definition,
        round,
        stageNumber: _currentStageNumber,
      ),
      maxShield: scaledEnemyMaxShield(
        definition,
        round,
        stageNumber: _currentStageNumber,
      ),
      maxArmor: scaledEnemyMaxArmor(
        definition,
        round,
        stageNumber: _currentStageNumber,
      ),
      laneOffsetRatio: _enemyLaneOffsetRatioFor(type),
      visualPhase: _enemyVisualPhase(),
      diamondReward: definition.type.isBoss
          ? 0
          : DiamondCarrierRules.rewardForSpawn(
              type: type,
              isDirectWaveSpawn: true,
              roll: _diamondCarrierRoll(),
            ),
      path: _worldPath,
      game: this,
    )..updateLayout(tileSize: _tileSize, newPath: _worldPath);
    return {
      ...enemy.nativeCombatState(_nextBattlefieldId++),
      'coreDamage': definition.coreDamage,
      'isDebug': false,
    };
  }

  Map<String, Object?> _nativeDefenseConfiguration() {
    final ranks = _progression.corePassiveNodeRanks;
    final undamaged = corePassiveNexusDamageMultiplier(
      ranks,
      lostDurabilityRatio: 0,
    );
    final damaged = corePassiveNexusDamageMultiplier(
      ranks,
      lostDurabilityRatio: 1,
    );
    return {
      'maxHp': _maxNexusHp,
      'impactDispersionRate': 1 - undamaged,
      'threatWeakeningRate': undamaged <= 0 ? 0 : 1 - damaged / undamaged,
      'hasFinalDefense': corePassiveHasFinalDefense(ranks),
      'emergencyRecoveryRate': corePassiveEmergencyChargeRecoveryRate(ranks),
      'roundRecoveryRate': corePassiveRoundRecoveryRate(ranks),
      'damageRestorationRate': corePassiveDamageRestorationRate(ranks),
    };
  }

  Map<String, Object?> _nativeDefenseState() => {
    'hp': _nexusHp,
    'roundHpLost': _roundNexusHpLost,
    'finalDefenseUsedThisRound': _finalDefenseUsedThisRound,
    'emergencyChargeUsedThisRound': _emergencyChargeUsedThisRound,
  };

  void _queueNativeDefenseRestore() {
    if (!nativeCombatOwned) return;
    _nativeDefenseRestoreIntent = _nativeDefenseState();
    _nativeDefenseRestoreSequence = 0;
    _nativeCommands.add({
      'kind': 'defenseRestore',
      'state': _nativeDefenseRestoreIntent,
    });
  }

  void _applyNativeDefenseSnapshot(Map<String, dynamic> state) {
    _nexusHp = (state['hp'] as num).toDouble();
    _roundNexusHpLost = (state['roundHpLost'] as num).toDouble();
    _finalDefenseUsedThisRound = state['finalDefenseUsedThisRound'] == true;
    _emergencyChargeUsedThisRound =
        state['emergencyChargeUsedThisRound'] == true;
  }

  Map<String, Object?> _nativeCoreConfiguration() => {
    'runSkill': _coreCombatSkillController.runSkill?.name,
    'cooldownRecoveryMultiplier': _coreCombatSkillCooldownRecoveryMultiplier,
    'guardianBeamInterval': RuneNexusGame._nexusCoreBeamInterval,
    'guardianBeamDuration': RuneNexusGame._nexusCoreBeamDuration,
    'guardianBeamTickInterval': RuneNexusGame._nexusCoreBeamTickInterval,
    'riftMarkInterval': RuneNexusGame._riftMarkInterval,
    'attackSyncDuration': _coreCombatSkillController.attackSyncDuration,
    'normalMaxHp': scaledEnemyMaxHp(
      gameEnemies[EnemyType.normal]!,
      _waves[math.min(_roundIndex, _waves.length - 1)].round,
      stageNumber: _currentStageNumber,
    ),
    'guardianMinNormalHpRate': RuneNexusGame._nexusCoreBeamMinNormalHpRate,
    'guardianDpsRate': RuneNexusGame._nexusCoreBeamDpsRate,
    'enemyHpCapRate': RuneNexusGame._nexusCoreBeamEnemyHpCapRate,
    'bossHpCapRate': RuneNexusGame._nexusCoreBeamBossHpCapRate,
    'powerMultiplier': _coreCombatSkillPowerMultiplierForActivation(1),
    'powerEveryThirdMultiplier':
        _coreCombatSkillPowerMultiplierForActivation(3) /
        _coreCombatSkillPowerMultiplierForActivation(1),
    'attackSyncDamageMultiplier':
        1 +
        corePassiveTurretDamageAmplification(_progression.corePassiveNodeRanks),
    'attackSyncAttackRateMultiplier':
        1 +
        corePassiveTurretAttackRateAmplification(
          _progression.corePassiveNodeRanks,
        ),
    'riftMarkDuration': RuneNexusGame._riftMarkDuration,
    'riftMarkTargetCount': RuneNexusGame._riftMarkTargetCount,
    'riftMarkDamageAmplification': RuneNexusGame._riftMarkDamageAmplification,
    'riftMarkBossDamageAmplification':
        RuneNexusGame._riftMarkBossDamageAmplification,
  };

  EnemyComponent _createNativeEnemyMirror(Map<String, dynamic> state) {
    final id = (state['id'] as num).toInt();
    final type = EnemyType.values.byName(state['type'] as String);
    final enemy = EnemyComponent(
      definition: gameEnemies[type]!,
      maxHp: (state['maxHp'] as num).toDouble(),
      maxShield: (state['maxShield'] as num?)?.toDouble() ?? 0,
      maxArmor: (state['maxArmor'] as num?)?.toDouble() ?? 0,
      laneOffsetRatio: (state['laneOffsetRatio'] as num?)?.toDouble() ?? 0,
      visualPhase: (state['visualPhase'] as num?)?.toDouble() ?? 0,
      diamondReward: (state['diamondReward'] as num?)?.toInt() ?? 0,
      path: _worldPath,
      game: this,
    )..updateLayout(tileSize: _tileSize, newPath: _worldPath);
    _battlefieldIds[enemy] = id;
    _nativeKnownEnemies.add(id);
    enemies.add(enemy);
    registerEnemy(enemy);
    return enemy;
  }

  void _applyNativeWaveSnapshot(Map<String, dynamic> response) {
    final raw = response['wave'];
    if (raw is! Map || raw['id'] != _nativeWaveId) return;
    final queue = <SavedSpawnRequest>[];
    for (final item in raw['spawnQueue'] as List? ?? const []) {
      final saved = SavedSpawnRequest.fromJson(
        Map<String, Object?>.from(item as Map),
      );
      if (saved == null) throw StateError('Invalid native spawn queue');
      queue.add(saved);
    }
    _waveSpawner.restoreFromSaveData(queue);
  }
}
