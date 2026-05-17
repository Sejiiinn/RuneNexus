import 'dart:async';

class SaveScheduler {
  SaveScheduler({
    required Future<void> Function() saveNow,
    this.throttle = const Duration(seconds: 2),
  }) : _saveNow = saveNow;

  final Future<void> Function() _saveNow;
  final Duration throttle;

  Timer? _timer;
  bool _inFlight = false;
  bool _pending = false;
  Future<void>? _inFlightFlush;

  void requestSave({bool immediate = false}) {
    if (immediate) {
      _timer?.cancel();
      _timer = null;
      unawaited(flush());
      return;
    }
    _timer ??= Timer(throttle, () {
      _timer = null;
      unawaited(flush());
    });
  }

  Future<void> flush() {
    if (_inFlight) {
      _pending = true;
      final inFlightFlush = _inFlightFlush;
      if (inFlightFlush != null) {
        return inFlightFlush;
      }
      return Future<void>.value();
    }

    _inFlight = true;
    final future = _flushLoop();
    _inFlightFlush = future;
    return future;
  }

  Future<void> _flushLoop() async {
    try {
      do {
        _pending = false;
        await _saveNow();
      } while (_pending);
    } finally {
      _inFlight = false;
      _inFlightFlush = null;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
