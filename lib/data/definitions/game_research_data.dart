import '../../domain/research/research_definition.dart';
import '../../domain/research/research_type.dart';

const int oneHourResearchDurationMillis = 60 * 60 * 1000;
const int halfHourResearchDurationMillis = 30 * 60 * 1000;
const int fortyFiveMinuteResearchDurationMillis = 45 * 60 * 1000;
const int twentyMinuteResearchDurationMillis = 20 * 60 * 1000;
const int ninetyMinuteResearchDurationMillis = 90 * 60 * 1000;
const int twoHourResearchDurationMillis = 2 * oneHourResearchDurationMillis;
const int threeHourResearchDurationMillis = 3 * oneHourResearchDurationMillis;

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
    requiredClearedStage: 2,
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
    requiredClearedStage: 2,
    baseRuneCost: 105,
    costMultiplier: 1.3,
    durationMillis: oneHourResearchDurationMillis,
    durationMultiplier: 1.25,
  ),
  ResearchType.bossBounty: ResearchDefinition(
    type: ResearchType.bossBounty,
    maxLevel: 20,
    requiredClearedStage: 0,
    baseRuneCost: 30,
    costMultiplier: 1.12,
    durationMillis: halfHourResearchDurationMillis,
    durationMultiplier: 1.1,
  ),
  ResearchType.linkMaintenance: ResearchDefinition(
    type: ResearchType.linkMaintenance,
    maxLevel: 10,
    requiredClearedStage: 0,
    baseRuneCost: 30,
    costMultiplier: 1.13,
    durationMillis: halfHourResearchDurationMillis,
    durationMultiplier: 1.12,
  ),
  ResearchType.crystalRecovery: ResearchDefinition(
    type: ResearchType.crystalRecovery,
    maxLevel: 5,
    requiredClearedStage: 5,
    baseRuneCost: 150,
    costMultiplier: 1.38,
    durationMillis: ninetyMinuteResearchDurationMillis,
    durationMultiplier: 1.25,
  ),
  ResearchType.runeResonance: ResearchDefinition(
    type: ResearchType.runeResonance,
    maxLevel: 20,
    requiredClearedStage: 8,
    baseRuneCost: 180,
    costMultiplier: 1.18,
    durationMillis: threeHourResearchDurationMillis,
    durationMultiplier: 1.08,
  ),
  ResearchType.runUpgradeCostOptimization: ResearchDefinition(
    type: ResearchType.runUpgradeCostOptimization,
    maxLevel: 10,
    requiredClearedStage: 8,
    baseRuneCost: 150,
    costMultiplier: 1.18,
    durationMillis: twoHourResearchDurationMillis,
    durationMultiplier: 1.08,
  ),
  ResearchType.towerDamageLimitExpansion: ResearchDefinition(
    type: ResearchType.towerDamageLimitExpansion,
    maxLevel: 10,
    requiredClearedStage: 15,
    baseRuneCost: 150,
    costMultiplier: 1.18,
    durationMillis: twoHourResearchDurationMillis,
    durationMultiplier: 1.08,
  ),
  ResearchType.killGoldLimitExpansion: ResearchDefinition(
    type: ResearchType.killGoldLimitExpansion,
    maxLevel: 10,
    requiredClearedStage: 15,
    baseRuneCost: 150,
    costMultiplier: 1.18,
    durationMillis: twoHourResearchDurationMillis,
    durationMultiplier: 1.08,
  ),
  ResearchType.waveGoldLimitExpansion: ResearchDefinition(
    type: ResearchType.waveGoldLimitExpansion,
    maxLevel: 10,
    requiredClearedStage: 15,
    baseRuneCost: 150,
    costMultiplier: 1.18,
    durationMillis: twoHourResearchDurationMillis,
    durationMultiplier: 1.08,
  ),
};
