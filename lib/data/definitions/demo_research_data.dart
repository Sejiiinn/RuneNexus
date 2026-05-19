import '../../domain/research/research_definition.dart';
import '../../domain/research/research_type.dart';

const int oneHourResearchDurationMillis = 60 * 60 * 1000;
const int halfHourResearchDurationMillis = 30 * 60 * 1000;
const int fortyFiveMinuteResearchDurationMillis = 45 * 60 * 1000;

const demoResearchDefinitions = {
  ResearchType.researchEfficiency: ResearchDefinition(
    type: ResearchType.researchEfficiency,
    maxLevel: 20,
    requiredClearedStage: 0,
    baseRuneCost: 50,
    costMultiplier: 1.35,
    durationMillis: halfHourResearchDurationMillis,
    durationMultiplier: 1.25,
  ),
  ResearchType.researchCostEfficiency: ResearchDefinition(
    type: ResearchType.researchCostEfficiency,
    maxLevel: 20,
    requiredClearedStage: 0,
    baseRuneCost: 70,
    costMultiplier: 1.4,
    durationMillis: fortyFiveMinuteResearchDurationMillis,
    durationMultiplier: 1.25,
  ),
  ResearchType.linkExpansionOne: ResearchDefinition(
    type: ResearchType.linkExpansionOne,
    maxLevel: 1,
    requiredClearedStage: 5,
    baseRuneCost: 250,
    costMultiplier: 1,
    durationMillis: oneHourResearchDurationMillis,
    durationMultiplier: 1,
  ),
  ResearchType.gemAttunement: ResearchDefinition(
    type: ResearchType.gemAttunement,
    maxLevel: 5,
    requiredClearedStage: 3,
    baseRuneCost: 150,
    costMultiplier: 1.5,
    durationMillis: oneHourResearchDurationMillis,
    durationMultiplier: 1.25,
  ),
};
