part of 'rune_nexus_game.dart';

/// Native effect delivery is separate from effect simulation and combat clocks.
extension BattlefieldEffectsPresentation on RuneNexusGame {
  double get _battlefieldEffectNow =>
      _battlefieldEffectClock.elapsedMicroseconds /
      Duration.microsecondsPerSecond;

  void _trackBattlefieldEffect(Component component) {
    if (!_boardConfigured ||
        nativeBattlefieldSceneEpoch == 0 ||
        _activeStage.id != 1 ||
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
    );
  }

  /// Epoch ownership protects a new native view from an old view's callbacks.
  void resetNativeBattlefieldEffects(int sceneEpoch) {
    if (nativeBattlefieldSceneEpoch != sceneEpoch) return;
    _battlefieldEffectQueue.clear();
    _battlefieldEffectSubmissions.clear();
    _nativeAppliedEffectIds = const {};
    _nativeEffectAppliedSequence = -1;
  }

  void markNativeBattlefieldEffectsSubmitted(
    int sceneEpoch,
    int sequence,
    Iterable<int> ids,
  ) {
    if (nativeBattlefieldSceneEpoch != sceneEpoch) return;
    final submitted = Set<int>.unmodifiable(ids);
    _battlefieldEffectQueue.markSubmitted(sequence, submitted);
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
