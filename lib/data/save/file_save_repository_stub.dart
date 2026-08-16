import 'game_save_data.dart';
import 'local_save_slot.dart';
import 'save_repository.dart';

class FileSaveRepository implements SaveRepository {
  FileSaveRepository({LocalSaveSlot slot = LocalSaveSlot.guest});

  GameSaveData? _data;

  @override
  Future<GameSaveData?> load() async => _data;

  @override
  Future<void> save(GameSaveData data) async {
    _data = data;
  }

  @override
  Future<void> clear() async {
    _data = null;
  }
}
