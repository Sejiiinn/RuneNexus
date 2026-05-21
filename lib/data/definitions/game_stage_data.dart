import '../../domain/stage/stage_definition.dart';
import 'game_stage_maps.dart';
import 'game_stage_waves.dart';

export 'game_stage_maps.dart';
export 'game_stage_waves.dart';

final gameStages = List<StageDefinition>.unmodifiable([
  StageDefinition(id: 1, name: 'Stage 1', map: gameMap, waves: gameWaves),
  StageDefinition(
    id: 2,
    name: 'Stage 2',
    map: gameStage2Map,
    waves: gameStage2Waves,
  ),
  StageDefinition(
    id: 3,
    name: 'Stage 3',
    map: stage3Map,
    waves: gameStage2Waves,
  ),
  StageDefinition(
    id: 4,
    name: 'Stage 4',
    map: stage4Map,
    waves: gameStage2Waves,
  ),
  StageDefinition(
    id: 5,
    name: 'Stage 5',
    map: stage5Map,
    waves: gameStage2Waves,
  ),
  StageDefinition(
    id: 6,
    name: 'Stage 6',
    map: chapterTwoStage6Map,
    waves: gameChapter2Waves,
  ),
  StageDefinition(
    id: 7,
    name: 'Stage 7',
    map: chapterTwoStage7Map,
    waves: gameChapter2Stage7Waves,
  ),
  StageDefinition(
    id: 8,
    name: 'Stage 8',
    map: chapterTwoStage8Map,
    waves: gameChapter2Stage8Waves,
  ),
  StageDefinition(
    id: 9,
    name: 'Stage 9',
    map: chapterTwoStage9Map,
    waves: gameChapter2Stage9Waves,
  ),
  StageDefinition(
    id: 10,
    name: 'Stage 10',
    map: chapterTwoStage10Map,
    waves: gameChapter2Stage10Waves,
  ),
]);
