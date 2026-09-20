/// A single acknowledged command stream owns combat. An uncertain transport
/// remains frozen; it must never implicitly re-enable Flame damage.
class NativeCombatProtocol {
  int epoch = 0;
  int _sequence = 0;
  int _lastEvent = 0;
  int _ackSequence = 0;
  int _stateRevision = -1;
  int get lastEvent => _lastEvent;
  bool engaged = false;
  bool active = false;
  bool suspended = false;
  Map<String, Object?>? pending;

  void reset() {
    epoch = 0;
    _sequence = 0;
    _lastEvent = 0;
    _ackSequence = 0;
    _stateRevision = -1;
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
        response['accepted'] != true) {
      return false;
    }
    final ack = response['ackSequence'];
    if (ack is! int || ack < _ackSequence || ack > _sequence) return false;
    final revision = response['stateRevision'];
    if (revision is int) {
      if (revision <= _stateRevision) return false;
      if (!active && (pending == null || ack != pending!['sequence'])) {
        return false;
      }
      _stateRevision = revision;
    } else if (pending == null || ack != pending!['sequence']) {
      return false;
    }
    _ackSequence = ack;
    if (pending?['sequence'] == ack) pending = null;
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
