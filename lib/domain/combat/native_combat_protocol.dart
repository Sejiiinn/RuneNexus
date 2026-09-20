/// A single acknowledged command stream owns combat. An uncertain transport
/// remains frozen; it must never implicitly re-enable Flame damage.
class NativeCombatProtocol {
  int epoch = 0;
  int _sequence = 0;
  int _lastEvent = 0;
  bool engaged = false;
  bool active = false;
  bool suspended = false;
  Map<String, Object?>? pending;

  void reset() {
    epoch = 0;
    _sequence = 0;
    _lastEvent = 0;
    engaged = false;
    active = false;
    suspended = false;
    pending = null;
  }

  void begin(int value) {
    if (engaged && epoch != value) {
      throw StateError(
        'An active combat session cannot be replaced implicitly',
      );
    }
    epoch = value;
    engaged = true;
  }

  Map<String, Object?> submit(Map<String, Object?> payload) => pending ??= {
    ...payload,
    'version': 1,
    'epoch': epoch,
    'sequence': ++_sequence,
    'ackEvent': _lastEvent,
  };

  bool accept(Map<String, dynamic> response) {
    if (suspended ||
        response['epoch'] != epoch ||
        pending == null ||
        response['ackSequence'] != pending!['sequence'] ||
        response['accepted'] != true) {
      return false;
    }
    pending = null;
    active = true;
    return true;
  }

  bool acceptEvent(int id) {
    if (id <= _lastEvent) return false;
    _lastEvent = id;
    return true;
  }

  void suspend() {
    if (engaged) suspended = true;
  }
}
