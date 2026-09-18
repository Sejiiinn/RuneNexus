// 본게임 App/HUD/전투를 그대로 실행하며 저장만 메모리로 격리한다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rune_nexus/app/rune_nexus_app.dart';
import 'package:rune_nexus/data/definitions/game_stage_data.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final game = RuneNexusGame(
    stage: gameStages.firstWhere((stage) => stage.id == 13),
    saveRepository: MemorySaveRepository(),
  );
  await game.prepareForAppStart();
  game.debugSetClearedStageCount(12);
  await game.saveNow();
  runApp(RuneNexusApp(game: game));
}
