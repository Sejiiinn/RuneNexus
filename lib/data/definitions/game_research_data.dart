import '../../domain/research/research_definition.dart';
import '../../domain/research/research_type.dart';

const int oneHourResearchDurationMillis = 60 * 60 * 1000;
const int halfHourResearchDurationMillis = 30 * 60 * 1000;
const int fortyFiveMinuteResearchDurationMillis = 45 * 60 * 1000;
const int twentyMinuteResearchDurationMillis = 20 * 60 * 1000;

const gameResearchDefinitions = {
  ResearchType.researchEfficiency: ResearchDefinition(
    type: ResearchType.researchEfficiency,
    maxLevel: 20,
    requiredClearedStage: 0,
    baseRuneCost: 50,
    costMultiplier: 1.32,
    durationMillis: halfHourResearchDurationMillis,
    durationMultiplier: 1.25,
  ),
  ResearchType.researchCostEfficiency: ResearchDefinition(
    type: ResearchType.researchCostEfficiency,
    maxLevel: 20,
    requiredClearedStage: 0,
    baseRuneCost: 70,
    costMultiplier: 1.37,
    durationMillis: fortyFiveMinuteResearchDurationMillis,
    durationMultiplier: 1.25,
  ),
  ResearchType.turretTargetPriority: ResearchDefinition(
    type: ResearchType.turretTargetPriority,
    maxLevel: 1,
    requiredClearedStage: 3,
    baseRuneCost: 80,
    costMultiplier: 1,
    durationMillis: twentyMinuteResearchDurationMillis,
    durationMultiplier: 1,
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
    baseRuneCost: 105,
    costMultiplier: 1.3,
    durationMillis: oneHourResearchDurationMillis,
    durationMultiplier: 1.25,
  ),
};
