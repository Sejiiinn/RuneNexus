part of 'rune_nexus_game.dart';

extension NativeCombatGame on RuneNexusGame {
  int nativeCombatEntityId(Object entity) => _nativeId(entity);

  int _nativeId(Object entity) =>
      _battlefieldIds[entity] ??= _nextBattlefieldId++;

  /// A view that left the navigation stack cannot reuse the native scene's
  /// command stream. Rebuild only from its last acknowledged save boundary.
  void prepareNativeCombatScene(int epoch) {
    if (!_nativeCombat.engaged || _nativeCombat.epoch == epoch) return;
    if (!_nativeCombat.suspended) {
      throw StateError(
        'Native combat scene changed without a suspended checkpoint',
      );
    }
    final checkpoint = _nativeCheckpointWithCurrentMeta();
    _restoreController.restoreFromSaveData(checkpoint);
    // _clearActiveCombat invalidated the previous epoch and queued commands.
    // Hold the restored app mirrors until the new bootstrap is acknowledged.
    nativeBattlefieldLoading = true;
    scheduleMicrotask(() {
      if (!_appResourcesDisposed) _publish();
    });
    debugPrint('NATIVE_COMBAT_RESTORED epoch=$epoch');
  }

  GameSaveData _nativeCheckpointWithCurrentMeta() => _buildLiveSaveData();

  /// Commands are retained verbatim until the native owner acknowledges them.
  Map<String, Object?> buildNativeCombatCommand(int epoch) {
    if (_nativeCombat.pending != null) return _nativeCombat.pending!;
    final bootstrap = !_nativeCombat.engaged;
    _nativeCombat.begin(epoch);
    final commands = _captureNativeCommands();
    final steps = List<Map<String, Object?>>.of(_nativeSteps);
    _nativeSteps.clear();
    final packet = _nativeCombat.submit({
      if (bootstrap)
        'bootstrap': {
          'wave': _nativeWaveConfiguration(),
          'coreConfig': _nativeCoreConfiguration(),
          'defense': {
            'config': _nativeDefenseConfiguration(),
            'state': _nativeDefenseState(),
          },
          'enemies': [
            for (final command in commands)
              if (command['kind'] == 'spawn') command['enemy'],
          ],
          'turrets': [
            for (final command in commands)
              if (command['kind'] == 'turret') command['turret'],
          ],
          'path': [
            for (final point in _worldPath) {'x': point.x, 'y': point.y},
          ],
          'boardDistanceScale': boardDistanceScale,
          'tileSize': _tileSize,
          'origin': [_origin.x, _origin.y],
        },
      'running': isWaveRunning,
      'steps': [
        ...steps,
        if (!bootstrap && commands.isNotEmpty)
          {'dt': 0.0, 'commandsAfter': commands, 'running': isWaveRunning},
      ],
    });
    if (_nativeDefenseRestoreIntent != null &&
        _nativeDefenseRestoreSequence == 0) {
      _nativeDefenseRestoreSequence = packet['sequence']! as int;
    }
    return packet;
  }

  List<Map<String, Object?>> _captureNativeCommands() {
    final commands = <Map<String, Object?>>[
      ..._nativeCommands.where((command) => command['kind'] == 'layout'),
    ];
    final defense = _nativeDefenseConfiguration();
    final defenseFingerprint = jsonEncode(defense);
    if (_nativeDefenseConfigFingerprint != defenseFingerprint) {
      _nativeDefenseConfigFingerprint = defenseFingerprint;
      commands.add({'kind': 'defenseConfig', 'config': defense});
    }
    final coreConfig = _nativeCoreConfiguration();
    final coreFingerprint = jsonEncode(coreConfig);
    if (_nativeCoreConfigFingerprint != coreFingerprint) {
      _nativeCoreConfigFingerprint = coreFingerprint;
      commands.add({'kind': 'coreConfig', 'config': coreConfig});
    }
    final currentTurretIds = <int>{};
    for (final turret in _turrets.values) {
      final id = _nativeId(turret);
      currentTurretIds.add(id);
      final config = turret.nativeCombatConfiguration(id);
      final state = Map<String, Object?>.from(config['state']! as Map);
      for (final key in [
        'cooldown',
        'damageDealt',
        'directDamageDealt',
        'splashDamageDealt',
        'chainDamageDealt',
        'burnDamageDealt',
      ]) {
        state.remove(key);
      }
      final fingerprint = jsonEncode({
        'position': config['position'],
        'statInput': config['statInput'],
        'state': state,
      });
      if (_nativeTurretConfigs[id] != fingerprint) {
        _nativeTurretConfigs[id] = fingerprint;
        commands.add({'kind': 'turret', 'turret': config});
      }
    }
    for (final enemy in enemies) {
      final id = _nativeId(enemy);
      if (_nativeKnownEnemies.add(id)) {
        commands.add({
          'kind': 'spawn',
          'enemy': {
            ...enemy.nativeCombatState(id),
            'coreDamage': enemy.definition.coreDamage,
            'isDebug': _debugEnemies.contains(enemy),
          },
        });
      }
    }
    final removed = _nativeTurretConfigs.keys
        .where((id) => !currentTurretIds.contains(id))
        .toList();
    for (final id in removed) {
      _nativeTurretConfigs.remove(id);
      commands.add({'kind': 'removeTurret', 'id': id});
    }
    commands.addAll(
      _nativeCommands.where((command) => command['kind'] != 'layout'),
    );
    _nativeCommands.clear();
    return commands;
  }

  void _recordNativeCombatStep(double dt, List<Map<String, Object?>> before) {
    _nativeSteps.add({
      'dt': dt,
      'running': isWaveRunning,
      'commands': before,
      'commandsAfter': _captureNativeCommands(),
    });
  }

  bool applyNativeCombatResponse(Map<String, dynamic> response) {
    final activating = !_nativeCombat.active;
    if (!_nativeCombat.accept(response)) return false;
    if (activating) {
      debugPrint(
        'NATIVE_COMBAT_ACTIVE epoch=${_nativeCombat.epoch} seq=${response['ackSequence']}',
      );
    }
    _nativeApplyingResponse = true;
    try {
      final nativeDefense = response['defense'];
      if (nativeDefense is Map) {
        if (_nativeDefenseRestoreSequence > 0 &&
            (response['ackSequence'] as int) >= _nativeDefenseRestoreSequence) {
          _nativeDefenseRestoreIntent = null;
          _nativeDefenseRestoreSequence = 0;
        }
        _applyNativeDefenseSnapshot(
          Map<String, dynamic>.from(
            _nativeDefenseRestoreIntent ?? nativeDefense,
          ),
        );
      }
      _applyNativeWaveSnapshot(response);
      final nativeCore = response['core'];
      if (nativeCore is Map) {
        final oldActivations = _coreCombatSkillController.activationCount;
        _coreCombatSkillController.applyNativeRuntimeState(
          Map<String, dynamic>.from(nativeCore),
        );
        _emergencyChargeUsedThisRound =
            nativeCore['emergencyChargeUsedThisRound'] == true;
        if (_coreCombatSkillController.activationCount > oldActivations) {
          debugPrint(
            'NATIVE_CORE_ACTIVATED wave=$_nativeWaveId count=${_coreCombatSkillController.activationCount}',
          );
        }
      }
      final byId = {for (final enemy in enemies) _nativeId(enemy): enemy};
      for (final raw in response['enemies'] as List? ?? const []) {
        final state = Map<String, dynamic>.from(raw as Map);
        final id = (state['id'] as num).toInt();
        if (!byId.containsKey(id) && !_nativeKnownEnemies.contains(id)) {
          byId[id] = _createNativeEnemyMirror(state);
        }
        byId[id]?.applyNativeCombatState(state);
      }
      final turrets = {
        for (final turret in _turrets.values) _nativeId(turret): turret,
      };
      for (final raw in response['turrets'] as List? ?? const []) {
        final state = Map<String, dynamic>.from(raw as Map);
        turrets[(state['id'] as num).toInt()]?.applyNativeCombatState(state);
      }
      var nativeWaveCompleted = false;
      for (final raw in response['events'] as List? ?? const []) {
        final event = Map<String, dynamic>.from(raw as Map);
        if (!_nativeCombat.acceptEvent((event['id'] as num).toInt())) continue;
        final enemy = byId[(event['enemyId'] as num?)?.toInt()];
        switch (event['kind']) {
          case 'kill':
            if (enemy != null) enemyKilled(enemy);
          case 'arrival':
            if (enemy != null) _removeNativeCoreArrival(enemy);
          case 'coreDefeated':
            _startCoreDestructionSequence();
          case 'coreRecovered':
            debugPrint('NATIVE_CORE_RECOVERED amount=${event['amount']}');
          case 'waveStarted':
            debugPrint('NATIVE_WAVE_STARTED wave=${event['waveId']}');
          case 'waveCompleted':
            if (event['waveId'] == _nativeWaveId &&
                _nativeWaveId == _roundIndex + 1 &&
                _phase == GamePhase.wave &&
                _nexusHp > 0) {
              debugPrint('NATIVE_WAVE_COMPLETED wave=$_nativeWaveId');
              _completeWave(native: true);
              nativeWaveCompleted = true;
            }
          case 'damageNumber':
            if (enemy != null) {
              showDamageNumber(
                position: enemy.visualPosition,
                damage: (event['damage'] as num).toDouble(),
                color: event['effectKind'] == 'poison'
                    ? const Color(0xFF9DFF4A)
                    : const Color(0xFFFF8A2A),
                motion: DamageNumberMotion.fallArc,
                damageMultiplier:
                    (event['damageMultiplier'] as num?)?.toDouble() ?? 1,
              );
            }
          case 'coreBonusDamage':
            if (nativeCore is! Map) {
              recordCoreCombatSkillBonusDamage(
                (event['damage'] as num).toDouble(),
              );
            }
          case 'coreDamage':
            if (nativeCore is! Map) {
              _coreCombatSkillController.recordDirectDamage(
                (event['damage'] as num).toDouble(),
              );
            }
        }
      }
      if (nativeWaveCompleted) {
        // Serialize once, after this synchronous authoritative batch is complete.
        scheduleMicrotask(() => unawaited(_saveRoundCheckpoint()));
      }
      _requestCombatStatsPublish();
      return true;
    } finally {
      _nativeApplyingResponse = false;
      if (_nativeSaveRequested) {
        final immediate = _nativeSaveImmediate;
        _nativeSaveRequested = false;
        _nativeSaveImmediate = false;
        _requestLocalSave(immediate: immediate);
      }
    }
  }

  void _removeNativeCoreArrival(EnemyComponent enemy) {
    if (!enemies.remove(enemy)) return;
    _debugEnemies.remove(enemy);
    _triggerNexusHitAlert();
    _finishDebugCombatIfIdle();
    enemy.removeFromParent();
    _publish();
  }

  void suspendNativeCombat() {
    if (_nativeCombat.engaged && !_nativeCombat.suspended) {
      debugPrint('NATIVE_COMBAT_SUSPENDED epoch=${_nativeCombat.epoch}');
    }
    _nativeCombat.suspend();
  }
}
