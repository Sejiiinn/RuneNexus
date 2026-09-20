part of 'rune_nexus_game.dart';

extension NativeCombatGame on RuneNexusGame {
  int nativeCombatEntityId(Object entity) => _nativeId(entity);

  int _nativeId(Object entity) =>
      _battlefieldIds[entity] ??= _nextBattlefieldId++;

  /// A view that left the navigation stack cannot reuse the native scene's
  /// command stream. Rebuild only from its last acknowledged save boundary.
  void prepareNativeCombatScene(int epoch) {
    if (!_nativeCombat.engaged || _nativeCombat.epoch == epoch) return;
    if (!_nativeCombat.suspended || _nativeConfirmedSave == null) {
      throw StateError(
        'Native combat scene changed without a suspended checkpoint',
      );
    }
    final checkpoint = _nativeCheckpointWithCurrentMeta();
    _restoreController.restoreFromSaveData(checkpoint);
    // _clearActiveCombat invalidated the previous epoch and queued commands.
    // Hold the recreated Flame mirrors until the new bootstrap is acknowledged.
    nativeBattlefieldLoading = true;
    scheduleMicrotask(() {
      if (!_appResourcesDisposed) _publish();
    });
    debugPrint('NATIVE_COMBAT_RESTORED epoch=$epoch');
  }

  GameSaveData _nativeCheckpointWithCurrentMeta() {
    final live = _buildLiveSaveData().toJson();
    live['activeRun'] = _nativeConfirmedSave!.activeRun?.toJson();
    return GameSaveData.fromJson(live)!;
  }

  /// Commands are retained verbatim until the native owner acknowledges them.
  Map<String, Object?> buildNativeCombatCommand(int epoch) {
    if (_nativeCombat.pending != null) return _nativeCombat.pending!;
    final bootstrap = !_nativeCombat.engaged;
    final liveSave = _buildLiveSaveData();
    _nativeConfirmedSave ??= liveSave;
    _nativePendingSave = liveSave.toJson();
    _nativePendingSavedTurrets = {
      for (final turret in _turrets.values)
        _nativeId(turret): turret.toSaveData().toJson(),
    };
    _nativeCombat.begin(epoch);
    final commands = _captureNativeCommands();
    final steps = List<Map<String, Object?>>.of(_nativeSteps);
    _nativeSteps.clear();
    return _nativeCombat.submit({
      if (bootstrap)
        'bootstrap': {
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
  }

  List<Map<String, Object?>> _captureNativeCommands() {
    final commands = <Map<String, Object?>>[
      ..._nativeCommands.where((command) => command['kind'] == 'layout'),
    ];
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
        commands.add({'kind': 'spawn', 'enemy': enemy.nativeCombatState(id)});
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
    final goldBefore = _gold;
    final shardsBefore = _gemShards;
    final hpBefore = _nexusHp;
    final diamondsBefore = _pendingEconomyDiamonds;
    final byId = {for (final enemy in enemies) _nativeId(enemy): enemy};
    for (final raw in response['enemies'] as List? ?? const []) {
      final state = Map<String, dynamic>.from(raw as Map);
      byId[(state['id'] as num).toInt()]?.applyNativeCombatState(state);
    }
    final turrets = {
      for (final turret in _turrets.values) _nativeId(turret): turret,
    };
    for (final raw in response['turrets'] as List? ?? const []) {
      final state = Map<String, dynamic>.from(raw as Map);
      turrets[(state['id'] as num).toInt()]?.applyNativeCombatState(state);
    }
    for (final raw in response['events'] as List? ?? const []) {
      final event = Map<String, dynamic>.from(raw as Map);
      if (!_nativeCombat.acceptEvent((event['id'] as num).toInt())) continue;
      final enemy = byId[(event['enemyId'] as num?)?.toInt()];
      switch (event['kind']) {
        case 'kill':
          if (enemy != null) enemyKilled(enemy);
        case 'arrival':
          if (enemy != null) enemyReachedCore(enemy);
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
          recordCoreCombatSkillBonusDamage((event['damage'] as num).toDouble());
        case 'coreDamage':
          _coreCombatSkillController.recordDirectDamage(
            (event['damage'] as num).toDouble(),
          );
      }
    }
    _confirmNativeSave(
      response,
      goldDelta: _gold - goldBefore,
      shardDelta: _gemShards - shardsBefore,
      hpDelta: _nexusHp - hpBefore,
      diamondDelta: _pendingEconomyDiamonds - diamondsBefore,
    );
    _requestCombatStatsPublish();
    _checkWaveClear();
    return true;
  }

  void _confirmNativeSave(
    Map<String, dynamic> response, {
    required int goldDelta,
    required int shardDelta,
    required double hpDelta,
    required int diamondDelta,
  }) {
    final data = _nativePendingSave;
    if (data == null || data['activeRun'] is! Map) return;
    final run = Map<String, Object?>.from(data['activeRun']! as Map);
    final removed = <int>{};
    for (final raw in response['events'] as List? ?? const []) {
      final event = raw as Map;
      if (event['kind'] == 'kill' || event['kind'] == 'arrival') {
        removed.add((event['enemyId'] as num).toInt());
      }
    }
    run['enemies'] = [
      for (final raw in response['enemies'] as List? ?? const [])
        if (!removed.contains((raw['id'] as num).toInt()) &&
            (raw['hp'] as num) > 0)
          SavedEnemy.fromJson(Map<String, Object?>.from(raw as Map))!.toJson(),
    ];
    for (final raw in response['turrets'] as List? ?? const []) {
      final state = Map<String, Object?>.from(raw as Map);
      final saved = _nativePendingSavedTurrets[(state['id'] as num).toInt()];
      if (saved == null) continue;
      for (final key in [
        'cooldown',
        'directDamageDealt',
        'splashDamageDealt',
        'chainDamageDealt',
        'burnDamageDealt',
      ]) {
        if (state.containsKey(key)) saved[key] = state[key];
      }
    }
    run['turrets'] = _nativePendingSavedTurrets.values.toList();
    run['gold'] = (run['gold'] as num) + goldDelta;
    run['gemShards'] = (run['gemShards'] as num) + shardDelta;
    run['nexusHp'] = (run['nexusHp'] as num) + hpDelta;
    run['pendingEconomyDiamonds'] =
        (run['pendingEconomyDiamonds'] as num) + diamondDelta;
    final skillStats = Map<String, Object?>.from(
      run['runCoreCombatSkillStats']! as Map,
    );
    skillStats['directDamageDealt'] =
        _coreCombatSkillController.directDamageDealt;
    skillStats['bonusDamageDealt'] =
        _coreCombatSkillController.bonusDamageDealt;
    run['runCoreCombatSkillStats'] = skillStats;
    run['killGoldFractionWallet'] = _killGoldFractionWallet;
    run['roundNexusHpLost'] = _roundNexusHpLost;
    run['emergencyChargeUsedThisRound'] = _emergencyChargeUsedThisRound;
    run['finalDefenseUsedThisRound'] = _finalDefenseUsedThisRound;
    if (_phase == GamePhase.coreDestruction || _phase == GamePhase.failure) {
      run['phase'] = GamePhase.failure.name;
    }
    data['activeRun'] = run;
    data['progression'] = _progression.toSaveData().toJson();
    _nativeConfirmedSave = GameSaveData.fromJson(data);
    _nativePendingSave = null;
  }

  void suspendNativeCombat() {
    if (_nativeCombat.engaged && !_nativeCombat.suspended) {
      debugPrint('NATIVE_COMBAT_SUSPENDED epoch=${_nativeCombat.epoch}');
    }
    _nativeCombat.suspend();
  }
}
