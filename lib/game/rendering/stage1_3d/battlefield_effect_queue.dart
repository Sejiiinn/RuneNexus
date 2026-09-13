import 'battlefield_effects.dart';

/// Keeps a short effect's last visible sample until a native frame applies it.
///
/// [now] is monotonic wall time in seconds, independent of battle speed/pause.
/// The queue never advances animation time or reconstructs a completed effect.
final class BattlefieldEffectQueue {
  BattlefieldEffectQueue({this.capacity = 256, this.maxRetentionSeconds = 2}) {
    if (capacity <= 0) {
      throw RangeError.value(capacity, 'capacity', 'must be positive');
    }
    if (!maxRetentionSeconds.isFinite || maxRetentionSeconds <= 0) {
      throw RangeError.value(
        maxRetentionSeconds,
        'maxRetentionSeconds',
        'must be finite and positive',
      );
    }
  }

  final int capacity;
  final double maxRetentionSeconds;
  final Map<int, _PendingEffect> _pending = {};
  int _acknowledgedSequence = -1;

  /// Capture at source addition, before a single simulation tick can remove it.
  void track(BattlefieldEffect effect, double now) {
    if (!_isVisible(effect)) return;
    _upsert(effect, now);
    _trim();
  }

  /// [live] is the complete current source set, not an incremental update.
  List<BattlefieldEffect> snapshot(
    Iterable<BattlefieldEffect> live,
    double now,
  ) {
    for (final pending in _pending.values) {
      pending.isLive = false;
    }
    for (final effect in live) {
      // A completion sample must not replace the last drawable sample.
      if (_isVisible(effect)) _upsert(effect, now);
    }
    _pending.removeWhere((_, pending) {
      if (pending.isLive) return false;
      final submitted = pending.firstSubmittedSequence;
      return (submitted != null && submitted <= _acknowledgedSequence) ||
          now - pending.lastLiveTime >= maxRetentionSeconds;
    });
    _trim();
    return List.unmodifiable(_pending.values.map((pending) => pending.effect));
  }

  /// Call only after these IDs have actually been included in the sent frame.
  void markSubmitted(int sequence, Iterable<int> ids) {
    for (final id in ids) {
      final pending = _pending[id];
      if (pending == null) continue;
      final previous = pending.firstSubmittedSequence;
      if (previous == null || sequence < previous) {
        pending.firstSubmittedSequence = sequence;
      }
    }
  }

  /// Applied sequences are cumulative: frames may be coalesced by the bridge.
  void acknowledge(int sequence) {
    if (sequence > _acknowledgedSequence) {
      _acknowledgedSequence = sequence;
    }
  }

  void clear() {
    _pending.clear();
    _acknowledgedSequence = -1;
  }

  void _upsert(BattlefieldEffect effect, double now) {
    final pending = _pending[effect.id];
    if (pending == null) {
      _pending[effect.id] = _PendingEffect(effect, now);
      return;
    }
    // A delayed/repeated producer sample cannot rewind an existing animation.
    if (effect.age >= pending.effect.age) pending.effect = effect;
    pending.lastLiveTime = now;
    pending.isLive = true;
  }

  void _trim() {
    if (_pending.length <= capacity) return;
    // Map iteration follows original insertion order. Evict old orphans first;
    // if the entire queue is live, bound it by evicting oldest live sources.
    final orphans = _pending.entries
        .where((entry) => !entry.value.isLive)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final id in orphans) {
      if (_pending.length <= capacity) break;
      _pending.remove(id);
    }
    while (_pending.length > capacity) {
      _pending.remove(_pending.keys.first);
    }
  }

  static bool _isVisible(BattlefieldEffect effect) =>
      effect.age.isFinite &&
      effect.duration.isFinite &&
      effect.age >= 0 &&
      effect.duration > 0 &&
      effect.age < effect.duration;
}

final class _PendingEffect {
  _PendingEffect(this.effect, this.lastLiveTime);

  BattlefieldEffect effect;
  double lastLiveTime;
  bool isLive = true;
  int? firstSubmittedSequence;
}
