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
  bool _paused = false;
  bool _disposed = false;
  Future<void>? _inFlightFlush;

  void requestSave({bool immediate = false}) {
    if (_paused || _disposed) {
      return;
    }
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
    if (_paused || _disposed) {
      return _inFlightFlush ?? Future<void>.value();
    }
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
      } while (_pending && !_paused && !_disposed);
    } finally {
      _inFlight = false;
      _inFlightFlush = null;
    }
  }

  void dispose() {
    _disposed = true;
    _paused = true;
    _pending = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> quiesce() async {
    _paused = true;
    _pending = false;
    _timer?.cancel();
    _timer = null;
    await (_inFlightFlush ?? Future<void>.value());
  }

  void resume() {
    if (!_disposed) {
      _paused = false;
    }
  }
}
