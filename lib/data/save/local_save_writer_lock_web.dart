import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('navigator.locks')
external JSObject? get _navigatorLocks;

class PlatformLocalSaveWriterLock {
  static const _lockName = 'rune-nexus-local-save-writer';

  Completer<void>? _releaseSignal;
  bool _acquired = false;

  Future<bool> acquire() async {
    if (_acquired) {
      return true;
    }
    final locks = _navigatorLocks;
    if (locks == null) {
      // Web Locks 미지원 환경은 서버 writer generation으로 최종 방어한다.
      return true;
    }

    final decision = Completer<bool>();
    final releaseSignal = Completer<void>();
    _releaseSignal = releaseSignal;
    JSAny? holdLock(JSAny? lock) {
      final acquired = lock != null;
      if (!decision.isCompleted) {
        decision.complete(acquired);
      }
      return acquired ? releaseSignal.future.toJS : null;
    }

    final options = JSObject()
      ..['mode'] = 'exclusive'.toJS
      ..['ifAvailable'] = true.toJS;
    try {
      final requestPromise = locks.callMethod<JSPromise<JSAny?>>(
        'request'.toJS,
        _lockName.toJS,
        options,
        holdLock.toJS,
      );
      unawaited(
        requestPromise.toDart.catchError((Object error) {
          if (!decision.isCompleted) {
            decision.completeError(error);
          }
          return null;
        }),
      );
      _acquired = await decision.future;
      if (!_acquired && !releaseSignal.isCompleted) {
        releaseSignal.complete();
      }
      return _acquired;
    } on Object {
      _releaseSignal = null;
      rethrow;
    }
  }

  void release() {
    if (!_acquired) {
      return;
    }
    _acquired = false;
    final signal = _releaseSignal;
    _releaseSignal = null;
    if (signal != null && !signal.isCompleted) {
      signal.complete();
    }
  }
}
