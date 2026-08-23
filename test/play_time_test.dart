import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';

void main() {
  test('플레이타임은 밀리초 단위로 누적되어 저장과 복원 후 이어진다', () {
    final progression = RunProgression();

    progression.recordPlayTime(1.25);
    progression.recordPlayTime(0.0005);
    progression.recordPlayTime(0.0005);

    expect(progression.totalPlayTimeMillis, 1251);

    final restored = RunProgression()
      ..restoreFromSaveData(progression.toSaveData());
    restored.recordPlayTime(0.749);

    expect(restored.totalPlayTimeMillis, 2000);
    expect(restored.toSaveData().totalPlayTimeMillis, 2000);
  });

  test('게임 업데이트의 실제 경과 시간이 저장 데이터에 반영된다', () async {
    final repository = MemorySaveRepository();
    final game = RuneNexusGame(saveRepository: repository);
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    game.update(1.5);
    await game.saveNow();

    expect(repository.data!.progression.totalPlayTimeMillis, 1500);

    final restored = RuneNexusGame(saveRepository: repository);
    restored.onGameResize(Vector2(400, 800));
    await restored.onLoad();
    restored.update(0.5);
    await restored.saveNow();

    expect(repository.data!.progression.totalPlayTimeMillis, 2000);
  });
}
