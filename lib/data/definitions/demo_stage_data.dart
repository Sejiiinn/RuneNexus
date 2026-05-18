import '../../domain/stage/stage_definition.dart';
import 'demo_stage_maps.dart';
import 'demo_stage_waves.dart';

export 'demo_stage_maps.dart';
export 'demo_stage_waves.dart';

final demoStages = List<StageDefinition>.unmodifiable([
  StageDefinition(id: 1, name: 'Stage 1', map: demoMap, waves: demoWaves),
  StageDefinition(
    id: 2,
    name: 'Stage 2',
    map: demoStage2Map,
    waves: demoStage2Waves,
  ),
  StageDefinition(
    id: 3,
    name: 'Stage 3',
    map: stage3Map,
    waves: demoStage2Waves,
  ),
  StageDefinition(
    id: 4,
    name: 'Stage 4',
    map: stage4Map,
    waves: demoStage2Waves,
  ),
  StageDefinition(
    id: 5,
    name: 'Stage 5',
    map: stage5Map,
    waves: demoStage2Waves,
  ),
]);
