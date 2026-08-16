import 'game_save_data.dart';
import 'save_repository.dart';

class LocalSaveCoordinator implements SaveRepository {
  LocalSaveCoordinator(this._delegate);

  final SaveRepository _delegate;
  Future<void> _tail = Future<void>.value();

  @override
  Future<GameSaveData?> load() => _enqueue(_delegate.load);

  @override
  Future<void> save(GameSaveData data) {
    return _enqueue(() => _delegate.save(data));
  }

  @override
  Future<void> clear() => _enqueue(_delegate.clear);

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
