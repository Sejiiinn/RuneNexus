part of 'rune_nexus_game.dart';

/// Native effect delivery is separate from effect simulation and combat clocks.
extension BattlefieldEffectsPresentation on RuneNexusGame {
  double get _battlefieldEffectNow =>
      _battlefieldEffectClock.elapsedMicroseconds /
      Duration.microsecondsPerSecond;

  double get battlefieldEffectCombatClock => _battlefieldEffectEvents.clock;

  int battlefieldEffectTargetId(EnemyComponent target) =>
      _battlefieldIds[target] ??= _nextBattlefieldId++;

  Offset battlefieldEffectTargetPosition(
    EnemyComponent target,
    Offset initial,
  ) {
    if (target.isMounted && !target.isDead && !target.isRemoving) {
      return battlefieldEffectPosition(
        Offset(target.position.x, target.position.y),
        Offset(_origin.x, _origin.y),
        _tileSize,
      );
    }
    return _battlefieldTargetPositions[target] ?? initial;
  }

  int battlefieldChargeOwnerId(TurretComponent owner) =>
      _battlefieldIds[owner] ??= _nextBattlefieldId++;

  bool _transferBattlefieldEffect(Component component) {
    if (!nativeBattlefieldEffectEvents ||
        !_usesNativeBattlefieldGroup('effects') ||
        !_boardConfigured ||
        nativeBattlefieldSceneEpoch == 0 ||
        (component is! DamageNumberComponent &&
            component is! DeathBurstEffectComponent &&
            component is! GemEquipEffectComponent &&
            !((component is NexusCoreBeamComponent ||
                    component is RiftMarkPulseComponent) &&
                nativeBattlefieldLinkedEffectEvents) &&
            !(component is LightningChargeComponent &&
                component.owner != null &&
                nativeBattlefieldChargeEffectEvents) &&
            !(component is LightningChainBeamComponent &&
                nativeBattlefieldChainEffectEvents) &&
            !(component is ImpactEffectComponent &&
                (component.style == ImpactEffectStyle.blast
                    ? nativeBattlefieldBlastEffectEvents
                    : nativeBattlefieldImpactEffectEvents)))) {
      return false;
    }
    final id = _battlefieldIds[component] ??= _nextBattlefieldId++;
    final origin = Offset(_origin.x, _origin.y);
    if (component is LightningChargeComponent) {
      component.nativePresentation = true;
    }
    final effect = component is NexusCoreBeamComponent
        ? component.battlefieldEffect(
            id,
            origin,
            _tileSize,
            includeTargets: true,
          )
        : component is RiftMarkPulseComponent
        ? component.battlefieldEffect(
            id,
            origin,
            _tileSize,
            includeTargets: true,
          )
        : component is LightningChainBeamComponent
        ? component.nativeChainEffect(
            id,
            origin,
            _tileSize,
            battlefieldEffectTargetId,
          )
        : component is ImpactEffectComponent &&
              component.style == ImpactEffectStyle.blast
        ? component.nativeBlastEffect(id, origin, _tileSize)
        : (component as BattlefieldEffectSource).battlefieldEffect(
            id,
            origin,
            _tileSize,
          );
    // Image-only numbers cannot be represented by the native text renderer.
    if (effect == null) {
      if (component is LightningChargeComponent) {
        component.nativePresentation = false;
      }
      return false;
    }
    if (component is NexusCoreBeamComponent && effect.targetIds.isNotEmpty) {
      _battlefieldTargetPositions[component.target] = effect.points.last;
    }
    if (component is LightningChainBeamComponent) {
      if (effect.targetIds[0] >= 0) {
        _battlefieldTargetPositions[component.source!] = effect.points.first;
      }
      if (effect.targetIds[1] >= 0) {
        _battlefieldTargetPositions[component.target] = effect.points.last;
      }
    }
    _battlefieldEffectEvents.add(effect, component);
    if (component is LightningChargeComponent) {
      _nativeBattlefieldCharges.add(component);
      component.finishNativePresentation = (cancelled) {
        _nativeBattlefieldCharges.remove(component);
        if (cancelled) _battlefieldEffectEvents.cancel(id);
      };
      // Combat stays mounted in Flame; only the display becomes event-owned.
      return false;
    }
    return true;
  }

  void _restoreBattlefieldEffectEvents() {
    for (final source in _nativeBattlefieldCharges) {
      source.nativePresentation = false;
      source.finishNativePresentation = null;
    }
    _nativeBattlefieldCharges.clear();
    final entries = _battlefieldEffectEvents.takeLive();
    _restoringBattlefieldEffects = true;
    try {
      for (final entry in entries) {
        final age = _battlefieldEffectEvents.clock - entry.born;
        final source = entry.source;
        if (source is LightningChargeComponent) {
          source.nativePresentation = false;
          source.finishNativePresentation = null;
          continue;
        }
        final anchor =
            _origin +
            Vector2(
              entry.effect.position.dx * _tileSize,
              entry.effect.position.dy * _tileSize,
            );
        if (source is NexusCoreBeamComponent) {
          final endpoint = entry.effect.targetIds.isEmpty
              ? entry.effect.points.last
              : battlefieldEffectTargetPosition(
                  source.target,
                  entry.effect.points.last,
                );
          source.restoreNativePresentation(
            age,
            anchor,
            _origin + Vector2(endpoint.dx * _tileSize, endpoint.dy * _tileSize),
          );
        } else if (source is LightningChainBeamComponent) {
          final start = entry.effect.targetIds[0] < 0
              ? entry.effect.points.first
              : battlefieldEffectTargetPosition(
                  source.source!,
                  entry.effect.points.first,
                );
          final end = entry.effect.targetIds[1] < 0
              ? entry.effect.points.last
              : battlefieldEffectTargetPosition(
                  source.target,
                  entry.effect.points.last,
                );
          source.restoreNativePresentation(
            age,
            _origin + Vector2(start.dx * _tileSize, start.dy * _tileSize),
            _origin + Vector2(end.dx * _tileSize, end.dy * _tileSize),
          );
        } else if (source is RiftMarkPulseComponent) {
          source.restoreNativePresentation(age, anchor);
        } else if (source is DamageNumberComponent) {
          source.restorePresentationTime(
            age,
            _battlefieldEffectEvents.squaredSteps - entry.bornSquared,
            spawnPosition: anchor,
          );
        } else if (source is ImpactEffectComponent) {
          source.restoreNativePresentation(
            age,
            anchor,
            entry.effect.radius * _tileSize / entry.effect.tileSize,
          );
        } else {
          (source as PositionComponent).position.setFrom(anchor);
          source.update(age);
        }
        add(source);
      }
    } finally {
      _restoringBattlefieldEffects = false;
    }
  }

  void _trackBattlefieldEffect(Component component) {
    if (component is LightningChargeComponent && component.nativePresentation) {
      return;
    }
    if (!_boardConfigured ||
        nativeBattlefieldSceneEpoch == 0 ||
        !supportsNativeBattlefield ||
        component is! BattlefieldEffectSource) {
      return;
    }
    final effect = (component as BattlefieldEffectSource).battlefieldEffect(
      _battlefieldIds[component] ??= _nextBattlefieldId++,
      Offset(_origin.x, _origin.y),
      _tileSize,
    );
    if (effect != null) {
      _battlefieldEffectQueue.track(effect, _battlefieldEffectNow);
    }
  }

  BattlefieldEffects _buildBattlefieldEffects() {
    final live = <BattlefieldEffect>[];
    for (final child in children) {
      if (child.isRemoving || child is! BattlefieldEffectSource) continue;
      if (child is LightningChargeComponent && child.nativePresentation) {
        continue;
      }
      final effect = (child as BattlefieldEffectSource).battlefieldEffect(
        _battlefieldIds[child] ??= _nextBattlefieldId++,
        Offset(_origin.x, _origin.y),
        _tileSize,
      );
      if (effect != null) live.add(effect);
    }
    var shake = Offset.zero;
    if (_phase == GamePhase.coreDestruction) {
      final progress =
          (_coreDestructionElapsed /
                  RuneNexusGame._coreDestructionTotalDuration)
              .clamp(0.0, 1.0);
      final x =
          math.sin(_coreDestructionElapsed * 78) *
          (1 - progress) *
          3.4 *
          boardDistanceScale;
      shake = Offset(x, -x * 0.45);
    }
    return BattlefieldEffects(
      items: _battlefieldEffectQueue.snapshot(live, _battlefieldEffectNow),
      shake: shake,
      events: _battlefieldEffectEvents.pending(),
      clock: _battlefieldEffectEvents.clock,
      generation: _battlefieldEffectEvents.generation,
      squaredSteps: _battlefieldEffectEvents.squaredSteps,
    );
  }

  /// Epoch ownership protects a new native view from an old view's callbacks.
  void resetNativeBattlefieldEffects(
    int sceneEpoch, {
    bool restoreLive = true,
  }) {
    if (nativeBattlefieldSceneEpoch != sceneEpoch) return;
    if (restoreLive) {
      _restoreBattlefieldEffectEvents();
    } else {
      _battlefieldEffectEvents.takeLive();
    }
    nativeProjectileEvents = false;
    nativeBattlefieldEffectEvents = false;
    nativeBattlefieldImpactEffectEvents = false;
    nativeBattlefieldBlastEffectEvents = false;
    nativeBattlefieldLinkedEffectEvents = false;
    nativeBattlefieldChainEffectEvents = false;
    nativeBattlefieldChargeEffectEvents = false;
    _battlefieldEffectQueue.clear();
    _battlefieldEffectSubmissions.clear();
    _nativeAppliedEffectIds = const {};
    _nativeEffectAppliedSequence = -1;
  }

  void markNativeBattlefieldEffectsSubmitted(
    int sceneEpoch,
    int sequence,
    Iterable<int> ids, {
    int? eventGeneration,
  }) {
    if (nativeBattlefieldSceneEpoch != sceneEpoch) return;
    final submitted = Set<int>.unmodifiable(ids);
    _battlefieldEffectQueue.markSubmitted(sequence, submitted);
    _battlefieldEffectEvents.markSubmitted(
      sequence,
      submitted,
      submittedGeneration: eventGeneration,
    );
    _battlefieldEffectSubmissions[sequence] = submitted;
    while (_battlefieldEffectSubmissions.length > 64) {
      _battlefieldEffectSubmissions.remove(
        _battlefieldEffectSubmissions.keys.first,
      );
    }
  }

  void acknowledgeNativeBattlefieldEffects(int sceneEpoch, int sequence) {
    if (nativeBattlefieldSceneEpoch != sceneEpoch ||
        sequence < _nativeEffectAppliedSequence) {
      return;
    }
    _battlefieldEffectQueue.acknowledge(sequence);
    _battlefieldEffectEvents.acknowledge(sequence);
    if (sequence > _nativeEffectAppliedSequence) {
      _nativeAppliedEffectIds =
          _battlefieldEffectSubmissions[sequence] ?? const {};
      _nativeEffectAppliedSequence = sequence;
      _battlefieldEffectSubmissions.removeWhere((key, _) => key <= sequence);
    }
  }

  /// Snapshot sources stop drawing after their native frame is applied.
  /// Event-owned charge visuals follow the negotiated event capability.
  /// Image-only damage and the separate 3D cannon blast never enter this set.
  bool isNativeBattlefieldEffect(Component component) {
    if (!_usesNativeBattlefieldGroup('effects')) return false;
    if (component is LightningChargeComponent && component.nativePresentation) {
      return true;
    }
    final id = _battlefieldIds[component];
    return id != null && _nativeAppliedEffectIds.contains(id);
  }
}
