import '../../domain/daily_quest/daily_quest_definition.dart';
import '../../domain/daily_quest/daily_quest_type.dart';

const int weeklyAttendanceTargetDays = 5;
const int weeklyAttendanceRewardDiamonds = 40;
const int weeklyQuestAllCompleteRewardDiamonds = 100;
const int weeklyQuestAllCompleteRewardModuleTickets = 4;

const gameWeeklyQuestDefinitions = <DailyQuestType, DailyQuestDefinition>{
  DailyQuestType.clearWaves: DailyQuestDefinition(
    type: DailyQuestType.clearWaves,
    title: '웨이브 150회 클리어',
    targetCount: 150,
    rewardDiamonds: 40,
  ),
  DailyQuestType.killBosses: DailyQuestDefinition(
    type: DailyQuestType.killBosses,
    title: '보스 15회 처치',
    targetCount: 15,
    rewardDiamonds: 40,
  ),
  DailyQuestType.killEnemies: DailyQuestDefinition(
    type: DailyQuestType.killEnemies,
    title: '몹 500회 처치',
    targetCount: 500,
    rewardDiamonds: 40,
  ),
  DailyQuestType.buyRunUpgrades: DailyQuestDefinition(
    type: DailyQuestType.buyRunUpgrades,
    title: '런 강화 25회',
    targetCount: 25,
    rewardDiamonds: 40,
  ),
};
