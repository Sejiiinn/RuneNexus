import 'game_save_data.dart';

abstract class SaveRepository {
  Future<GameSaveData?> load();
  Future<void> save(GameSaveData data);
  Future<void> clear();
}

class MemorySaveRepository implements SaveRepository {
  GameSaveData? data;

  @override
  Future<GameSaveData?> load() async => data;

  @override
  Future<void> save(GameSaveData data) async {
    this.data = data;
  }

  @override
  Future<void> clear() async {
    data = null;
  }
}
