import '../../domain/daily_quest/daily_quest_definition.dart';
import '../../domain/daily_quest/daily_quest_type.dart';

const int dailyQuestAllCompleteRewardDiamonds = 20;

const gameDailyQuestDefinitions = <DailyQuestType, DailyQuestDefinition>{
  DailyQuestType.clearWaves: DailyQuestDefinition(
    type: DailyQuestType.clearWaves,
    title: '웨이브 30회 클리어',
    targetCount: 30,
    rewardDiamonds: 10,
  ),
  DailyQuestType.killBosses: DailyQuestDefinition(
    type: DailyQuestType.killBosses,
    title: '보스 3회 처치',
    targetCount: 3,
    rewardDiamonds: 10,
  ),
  DailyQuestType.killEnemies: DailyQuestDefinition(
    type: DailyQuestType.killEnemies,
    title: '몹 100회 처치',
    targetCount: 100,
    rewardDiamonds: 10,
  ),
  DailyQuestType.buyRunUpgrades: DailyQuestDefinition(
    type: DailyQuestType.buyRunUpgrades,
    title: '런 강화 5회',
    targetCount: 5,
    rewardDiamonds: 10,
  ),
};
