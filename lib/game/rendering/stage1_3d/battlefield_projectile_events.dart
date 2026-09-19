/// Reliable launch/finish delivery. Positions are sent only at lifecycle edges.
class BattlefieldProjectileEvents {
  int generation = 0;
  int _next = 0;
  final List<Map<String, Object?>> _pending = [];
  final Set<int> _active = {};

  // Live flights must never expire merely because acknowledgement is delayed.
  // Compact an undelivered history into a fresh generation at the next frame.
  bool get needsReseed => _pending.length > 512 + _active.length * 2;

  void clear() {
    generation++;
    _pending.clear();
    _active.clear();
  }

  void launch(
    List<Object?> data,
    double clock,
    double speed,
    double remainingDistance,
  ) {
    if (!_active.add(data[0] as int)) return;
    _pending.add({
      'event': ++_next,
      'data': data,
      'clock': clock,
      'speed': speed,
      'remaining': remainingDistance,
    });
  }

  void finish(List<Object?> data, double clock) {
    _active.remove(data[0]);
    _pending.add({
      'event': ++_next,
      'data': data,
      'clock': clock,
      'speed': 0.0,
    });
  }

  void cancel(int id) {
    if (!_active.remove(id)) return;
    _pending.add({'event': ++_next, 'remove': id});
  }

  Map<String, Object?> snapshot(double clock) => {
    'generation': generation,
    'clock': clock,
    'through': _next,
    'events': List<Map<String, Object?>>.of(_pending),
  };

  void acknowledge(int receivedGeneration, int through) {
    if (receivedGeneration != generation) return;
    _pending.removeWhere((event) => (event['event'] as int) <= through);
  }
}
