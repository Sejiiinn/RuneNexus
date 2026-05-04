import 'game_save_data.dart';

abstract class OnlineSaveRepository {
  Future<void> saveRoundCheckpoint(GameSaveData data);
}

class NoopOnlineSaveRepository implements OnlineSaveRepository {
  const NoopOnlineSaveRepository();

  @override
  Future<void> saveRoundCheckpoint(GameSaveData data) async {}
}
