part of 'rune_nexus_game.dart';

/// Native effect delivery is separate from effect simulation and combat clocks.
extension BattlefieldEffectsPresentation on RuneNexusGame {
  double get _battlefieldEffectNow =>
      _battlefieldEffectClock.elapsedMicroseconds /
      Duration.microsecondsPerSecond;

  double get battlefieldEffectCombatClock => _battlefieldEffectEvents.clock;

  bool _transferBattlefieldEffect(Component component) {
    if (!nativeBattlefieldEffectEvents ||
        !_usesNativeBattlefieldGroup('effects') ||
        !_boardConfigured ||
        nativeBattlefieldSceneEpoch == 0 ||
        (component is! DamageNumberComponent &&
            component is! DeathBurstEffectComponent &&
            component is! GemEquipEffectComponent &&
            !(component is ImpactEffectComponent &&
                (component.style == ImpactEffectStyle.blast
                    ? nativeBattlefieldBlastEffectEvents
                    : nativeBattlefieldImpactEffectEvents)))) {
      return false;
    }
    final id = _battlefieldIds[component] ??= _nextBattlefieldId++;
    final origin = Offset(_origin.x, _origin.y);
    final effect =
        component is ImpactEffectComponent &&
            component.style == ImpactEffectStyle.blast
        ? component.nativeBlastEffect(id, origin, _tileSize)
        : (component as BattlefieldEffectSource).battlefieldEffect(
            id,
            origin,
            _tileSize,
          );
    // Image-only numbers cannot be represented by the native text renderer.
    if (effect == null) return false;
    _battlefieldEffectEvents.add(effect, component);
    return true;
  }

  void _restoreBattlefieldEffectEvents() {
    final entries = _battlefieldEffectEvents.takeLive();
    _restoringBattlefieldEffects = true;
    try {
      for (final entry in entries) {
        final age = _battlefieldEffectEvents.clock - entry.born;
        final source = entry.source;
        final anchor =
            _origin +
            Vector2(
              entry.effect.position.dx * _tileSize,
              entry.effect.position.dy * _tileSize,
            );
        if (source is DamageNumberComponent) {
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
    nativeBattlefieldEffectEvents = false;
    nativeBattlefieldImpactEffectEvents = false;
    nativeBattlefieldBlastEffectEvents = false;
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

  /// Only stop Flame drawing after this source reached an applied native frame.
  /// Image-only damage and the separate 3D cannon blast never enter this set.
  bool isNativeBattlefieldEffect(Component component) {
    if (!_usesNativeBattlefieldGroup('effects')) return false;
    final id = _battlefieldIds[component];
    return id != null && _nativeAppliedEffectIds.contains(id);
  }
}
