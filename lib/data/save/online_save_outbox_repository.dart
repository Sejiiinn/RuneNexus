import 'online_save_outbox.dart';

abstract interface class OnlineSaveOutboxRepository {
  Future<OnlineSaveOutboxState?> load();

  Future<void> save(OnlineSaveOutboxState state);

  Future<void> clear();
}

class MemoryOnlineSaveOutboxRepository implements OnlineSaveOutboxRepository {
  OnlineSaveOutboxState? state;

  @override
  Future<OnlineSaveOutboxState?> load() async => state;

  @override
  Future<void> save(OnlineSaveOutboxState state) async {
    this.state = state;
  }

  @override
  Future<void> clear() async {
    state = null;
  }
}

class OnlineSaveOutboxController {
  OnlineSaveOutboxController({
    required String accountId,
    required OnlineSaveOutboxRepository repository,
  }) : _accountId = accountId.toLowerCase(),
       _repository = repository;

  final String _accountId;
  final OnlineSaveOutboxRepository _repository;
  Future<void> _tail = Future<void>.value();
  OnlineSaveOutboxState? _state;

  OnlineSaveOutboxState get state {
    final current = _state;
    if (current == null) {
      throw StateError('온라인 저장 Outbox가 초기화되지 않았습니다.');
    }
    return current;
  }

  Future<OnlineSaveOutboxState> initialize({required int remoteRevision}) {
    return _enqueue(() async {
      if (_state != null) {
        return _state!;
      }
      final loaded = await _repository.load();
      if (loaded != null && loaded.accountIdBinding != _accountId) {
        throw StateError('Outbox와 인증 계정이 일치하지 않습니다.');
      }
      final resolved =
          loaded ??
          OnlineSaveOutboxState.initial(
            accountId: _accountId,
            remoteRevision: remoteRevision,
          );
      if (loaded == null) {
        await _repository.save(resolved);
      }
      _state = resolved;
      return resolved;
    });
  }

  Future<OnlineSaveOutboxState> mutate(
    OnlineSaveOutboxState Function(OnlineSaveOutboxState current) update,
  ) {
    return _enqueue(() async {
      final next = update(state);
      if (next.accountIdBinding != _accountId) {
        throw StateError('Outbox의 계정 binding은 변경할 수 없습니다.');
      }
      await _repository.save(next);
      _state = next;
      return next;
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
