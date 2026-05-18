import '../../domain/research/research_definition.dart';
import '../../domain/research/research_type.dart';

const int oneHourResearchDurationMillis = 60 * 60 * 1000;

const demoResearchDefinitions = {
  ResearchType.linkExpansionOne: ResearchDefinition(
    type: ResearchType.linkExpansionOne,
    maxLevel: 1,
    requiredClearedStage: 5,
    baseRuneCost: 250,
    costMultiplier: 1,
    durationMillis: oneHourResearchDurationMillis,
  ),
  ResearchType.gemAttunement: ResearchDefinition(
    type: ResearchType.gemAttunement,
    maxLevel: 5,
    requiredClearedStage: 3,
    baseRuneCost: 150,
    costMultiplier: 1.5,
    durationMillis: oneHourResearchDurationMillis,
  ),
};
