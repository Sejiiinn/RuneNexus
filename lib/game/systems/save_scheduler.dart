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

  Future<void> flush() async {
    if (_inFlight) {
      _pending = true;
      return;
    }

    _inFlight = true;
    try {
      do {
        _pending = false;
        await _saveNow();
      } while (_pending);
    } finally {
      _inFlight = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
