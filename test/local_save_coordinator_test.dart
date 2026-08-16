import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/local_save_coordinator.dart';
import 'package:rune_nexus/data/save/save_repository.dart';

void main() {
  test('동시에 요청된 로컬 저장을 한 번에 하나씩 실행한다', () async {
    final repository = _DelayedSaveRepository();
    final coordinator = LocalSaveCoordinator(repository);
    final first = coordinator.save(_saveData(1));
    final second = coordinator.save(_saveData(2));

    await Future<void>.delayed(Duration.zero);
    expect(repository.startedSavedAtMillis, [1]);
    expect(repository.maxActiveSaveCount, 1);

    repository.completions.removeAt(0).complete();
    await Future<void>.delayed(Duration.zero);
    expect(repository.startedSavedAtMillis, [1, 2]);
    expect(repository.maxActiveSaveCount, 1);

    repository.completions.removeAt(0).complete();
    await Future.wait([first, second]);
    expect(repository.activeSaveCount, 0);
  });

  test('앞선 저장 실패 뒤에도 다음 저장을 실행한다', () async {
    final repository = _FailOnceSaveRepository();
    final coordinator = LocalSaveCoordinator(repository);

    await expectLater(coordinator.save(_saveData(1)), throwsStateError);
    await coordinator.save(_saveData(2));

    expect(repository.savedAtMillis, [2]);
  });
}

GameSaveData _saveData(int savedAtMillis) {
  return GameSaveData.fromJson(<String, Object?>{
    'version': 2,
    'savedAtMillis': savedAtMillis,
    'preferences': const <String, Object?>{},
    'progression': const <String, Object?>{},
    'turretModules': const <String, Object?>{},
    'activeRun': null,
  })!;
}

class _DelayedSaveRepository implements SaveRepository {
  final List<Completer<void>> completions = [];
  final List<int> startedSavedAtMillis = [];
  int activeSaveCount = 0;
  int maxActiveSaveCount = 0;

  @override
  Future<GameSaveData?> load() async => null;

  @override
  Future<void> save(GameSaveData data) {
    startedSavedAtMillis.add(data.savedAtMillis);
    activeSaveCount++;
    if (activeSaveCount > maxActiveSaveCount) {
      maxActiveSaveCount = activeSaveCount;
    }
    final completion = Completer<void>();
    completions.add(completion);
    return completion.future.whenComplete(() => activeSaveCount--);
  }

  @override
  Future<void> clear() async {}
}

class _FailOnceSaveRepository implements SaveRepository {
  bool shouldFail = true;
  final List<int> savedAtMillis = [];

  @override
  Future<GameSaveData?> load() async => null;

  @override
  Future<void> save(GameSaveData data) async {
    if (shouldFail) {
      shouldFail = false;
      throw StateError('first save failed');
    }
    savedAtMillis.add(data.savedAtMillis);
  }

  @override
  Future<void> clear() async {}
}
