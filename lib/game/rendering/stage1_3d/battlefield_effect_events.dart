import 'battlefield_effects.dart';

/// Bounded creation journal. The receiver owns animation; retained initial data
/// is only for reliable delivery across native scene updates.
class BattlefieldEffectEvents<T> {
  BattlefieldEffectEvents({this.capacity = 256}) : assert(capacity > 0);
  final int capacity;
  final Map<int, BattlefieldEffectEvent<T>> _entries = {};
  int generation = 0;
  double clock = 0;
  double squaredSteps = 0;
  final _wallClock = Stopwatch()..start();
  double get _now => _wallClock.elapsedMicroseconds / 1000000;

  Set<int> get linkedTargetIds => {
    for (final entry in _entries.values)
      if (entry.effect.kind == 'coreBeam' ||
          entry.effect.kind == 'rift' ||
          entry.effect.kind == 'chain')
        ...entry.effect.targetIds.where((id) => id >= 0),
  };

  void advance(double dt) {
    clock += dt;
    squaredSteps += dt * dt;
  }

  void add(BattlefieldEffect effect, T source) {
    _prune();
    _entries[effect.id] = BattlefieldEffectEvent(
      effect,
      source,
      clock,
      squaredSteps,
    );
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  List<Map<String, Object>> pending() {
    _prune();
    for (final entry in _entries.values) {
      final age = clock - entry.born;
      if (age < entry.effect.duration) {
        entry.retainedAge = age;
        entry.retainedSquared = squaredSteps - entry.bornSquared;
      }
    }
    return [
      for (final entry in _entries.values)
        if (!entry.acknowledged) entry.toJson(),
    ];
  }

  void markSubmitted(
    int sequence,
    Iterable<int> ids, {
    int? submittedGeneration,
  }) {
    if (submittedGeneration != null && submittedGeneration != generation) {
      return;
    }
    for (final id in ids) {
      final entry = _entries[id];
      if (entry != null) entry.firstSubmitted ??= sequence;
    }
  }

  void acknowledge(int sequence) {
    for (final entry in _entries.values) {
      if (entry.firstSubmitted != null && entry.firstSubmitted! <= sequence) {
        entry.acknowledged = true;
      }
    }
  }

  List<BattlefieldEffectEvent<T>> takeLive() {
    _prune();
    final result = _entries.values
        .where((entry) => clock - entry.born < entry.effect.duration)
        .toList(growable: false);
    if (_entries.isNotEmpty) generation++;
    _entries.clear();
    return result;
  }

  /// A generation change reliably invalidates cancelled starts, even if a
  /// start was already submitted but its application ACK has not returned.
  void cancel(int id) {
    if (_entries.remove(id) == null) return;
    _entries.removeWhere(
      (_, entry) => clock - entry.born >= entry.effect.duration,
    );
    generation++;
    for (final entry in _entries.values) {
      entry.acknowledged = false;
      entry.firstSubmitted = null;
    }
  }

  void cancelKinds(Set<String> kinds) {
    _entries.removeWhere(
      (_, entry) =>
          kinds.contains(entry.effect.kind) ||
          clock - entry.born >= entry.effect.duration,
    );
    generation++;
    for (final entry in _entries.values) {
      entry.acknowledged = false;
      entry.firstSubmitted = null;
    }
  }

  void _prune() => _entries.removeWhere((_, entry) {
    if (clock - entry.born < entry.effect.duration) return false;
    entry.expiredAt ??= _now;
    return entry.acknowledged || _now - entry.expiredAt! >= 2;
  });
}

class BattlefieldEffectEvent<T> {
  BattlefieldEffectEvent(this.effect, this.source, this.born, this.bornSquared);
  final BattlefieldEffect effect;
  final T source;
  final double born;
  final double bornSquared;
  int? firstSubmitted;
  bool acknowledged = false;
  double retainedAge = 0;
  double retainedSquared = 0;
  double? expiredAt;

  Map<String, Object> toJson() => {
    ...effect.toJson(),
    'born': born,
    'bornSquared': bornSquared,
    'retainedAge': retainedAge,
    'retainedSquared': retainedSquared,
  };
}
