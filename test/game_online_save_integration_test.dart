import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/online_save_repository.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';

void main() {
  test('중요 체크포인트는 로컬 저장 성공 뒤 온라인 Outbox에 전달한다', () async {
    final calls = <String>[];
    final local = _RecordingSaveRepository(calls);
    final online = _RecordingOnlineSaveRepository(calls);
    final game = RuneNexusGame(
      saveRepository: local,
      onlineSaveRepository: online,
    );
    addTearDown(game.disposeAppResources);

    await game.settleCurrentRunAsFailure();

    expect(calls, ['local', 'online']);
    expect(online.data, same(local.data));
  });

  test('로컬 저장 실패 시 저장되지 않은 체크포인트를 온라인으로 보내지 않는다', () async {
    final calls = <String>[];
    final local = _RecordingSaveRepository(calls, failSave: true);
    final online = _RecordingOnlineSaveRepository(calls);
    final game = RuneNexusGame(
      saveRepository: local,
      onlineSaveRepository: online,
    );
    addTearDown(game.disposeAppResources);

    await game.settleCurrentRunAsFailure();

    expect(calls, ['local']);
    expect(online.data, isNull);
  });
}

class _RecordingSaveRepository implements SaveRepository {
  _RecordingSaveRepository(this.calls, {this.failSave = false});

  final List<String> calls;
  final bool failSave;
  GameSaveData? data;

  @override
  Future<GameSaveData?> load() async => data;

  @override
  Future<void> save(GameSaveData data) async {
    calls.add('local');
    if (failSave) {
      throw StateError('local save failed');
    }
    this.data = data;
  }

  @override
  Future<void> clear() async {
    data = null;
  }
}

class _RecordingOnlineSaveRepository implements OnlineSaveRepository {
  _RecordingOnlineSaveRepository(this.calls);

  final List<String> calls;
  GameSaveData? data;

  @override
  Future<void> saveRoundCheckpoint(GameSaveData data) async {
    calls.add('online');
    this.data = data;
  }
}
