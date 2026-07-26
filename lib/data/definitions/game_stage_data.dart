import '../../domain/stage/stage_definition.dart';
import 'game_stage_maps.dart';
import 'game_stage_waves.dart';

export 'game_stage_maps.dart';
export 'game_stage_waves.dart';

const int stageElevenFirstClearTurretModuleTicketReward = 5;

final gameStages = List<StageDefinition>.unmodifiable([
  StageDefinition(
    id: 1,
    name: 'Stage 1',
    map: gameMap,
    waves: gameWaves,
    firstClearCorePointReward: 1,
  ),
  StageDefinition(
    id: 2,
    name: 'Stage 2',
    map: gameStage2Map,
    waves: gameStage2Waves,
    firstClearCorePointReward: 1,
  ),
  StageDefinition(
    id: 3,
    name: 'Stage 3',
    map: stage3Map,
    waves: gameStage2Waves,
    firstClearCorePointReward: 1,
  ),
  StageDefinition(
    id: 4,
    name: 'Stage 4',
    map: stage4Map,
    waves: gameStage2Waves,
    firstClearCorePointReward: 1,
  ),
  StageDefinition(
    id: 5,
    name: 'Stage 5',
    map: stage5Map,
    waves: gameStage2Waves,
    firstClearCorePointReward: 2,
  ),
  StageDefinition(
    id: 6,
    name: 'Stage 6',
    map: chapterTwoStage6Map,
    waves: gameChapter2Waves,
    firstClearCorePointReward: 1,
  ),
  StageDefinition(
    id: 7,
    name: 'Stage 7',
    map: chapterTwoStage7Map,
    waves: gameChapter2Stage7Waves,
    firstClearCorePointReward: 1,
  ),
  StageDefinition(
    id: 8,
    name: 'Stage 8',
    map: chapterTwoStage8Map,
    waves: gameChapter2Stage8Waves,
    firstClearCorePointReward: 1,
  ),
  StageDefinition(
    id: 9,
    name: 'Stage 9',
    map: chapterTwoStage9Map,
    waves: gameChapter2Stage9Waves,
    firstClearCorePointReward: 1,
  ),
  StageDefinition(
    id: 10,
    name: 'Stage 10',
    map: chapterTwoStage10Map,
    waves: gameChapter2Stage10Waves,
    firstClearCorePointReward: 3,
  ),
  StageDefinition(
    id: 11,
    name: 'Stage 11',
    map: chapterThreeStage11Map,
    waves: gameChapter3Waves,
    firstClearCorePointReward: 1,
    firstClearTurretModuleTicketReward:
        stageElevenFirstClearTurretModuleTicketReward,
  ),
  StageDefinition(
    id: 12,
    name: 'Stage 12',
    map: chapterThreeStage12Map,
    waves: gameChapter3Stage12Waves,
    firstClearCorePointReward: 1,
  ),
  StageDefinition(
    id: 13,
    name: 'Stage 13',
    map: chapterThreeStage13Map,
    waves: gameChapter3Stage13Waves,
    firstClearCorePointReward: 1,
  ),
  StageDefinition(
    id: 14,
    name: 'Stage 14',
    map: chapterThreeStage14Map,
    waves: gameChapter3Stage14Waves,
    firstClearCorePointReward: 1,
  ),
  StageDefinition(
    id: 15,
    name: 'Stage 15',
    map: chapterThreeStage15Map,
    waves: gameChapter3Stage15Waves,
    firstClearCorePointReward: 3,
  ),
]);
