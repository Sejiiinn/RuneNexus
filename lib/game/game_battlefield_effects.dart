part of 'rune_nexus_game.dart';

/// App-created presentation events; Godot owns their animation and lifetime.
extension BattlefieldEffectsPresentation on RuneNexusGame {
  double get battlefieldEffectCombatClock => _battlefieldEffectEvents.clock;

  /// [position] is in board world pixels; other dimensions retain DTO units.
  /// A creation event is retained until native acknowledgement or bounded expiry.
  int? emitBattlefieldEffect({
    required String kind,
    required Vector2 position,
    required double duration,
    Color color = const Color(0xffffffff),
    double radius = 0,
    double visualScale = 1,
    String text = '',
    String feedback = 'neutral',
    String motion = 'rise',
    int arcDirection = 1,
    Offset screenOffset = Offset.zero,
    bool hasImage = false,
    String style = '',
  }) {
    if (!_boardConfigured || !supportsNativeBattlefield) return null;
    final id = _nextBattlefieldId++;
    final effect = BattlefieldEffect(
      id: id,
      kind: kind,
      age: 0,
      duration: duration,
      position: battlefieldEffectPosition(
        Offset(position.x, position.y),
        Offset(_origin.x, _origin.y),
        _tileSize,
      ),
      tileSize: _tileSize,
      color: color,
      radius: radius,
      visualScale: visualScale,
      text: text,
      feedback: feedback,
      motion: motion,
      arcDirection: arcDirection,
      screenOffset: screenOffset,
      hasImage: hasImage,
      style: style,
    );
    _battlefieldEffectEvents.add(effect, effect);
    return id;
  }

  BattlefieldEffects _buildBattlefieldEffects() {
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
      items: const [],
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
    _battlefieldEffectEvents.takeLive();
    nativeProjectileEvents = false;
    nativeBattlefieldEffectEvents = false;
    nativeBattlefieldImpactEffectEvents = false;
    nativeBattlefieldBlastEffectEvents = false;
    nativeBattlefieldLinkedEffectEvents = false;
    nativeBattlefieldChainEffectEvents = false;
    nativeBattlefieldChargeEffectEvents = false;
    _battlefieldEffectSubmissions.clear();
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
    _battlefieldEffectEvents.acknowledge(sequence);
    if (sequence > _nativeEffectAppliedSequence) {
      _nativeEffectAppliedSequence = sequence;
      _battlefieldEffectSubmissions.removeWhere((key, _) => key <= sequence);
    }
  }
}
