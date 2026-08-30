import '../research/research_type.dart';
import '../daily_quest/daily_quest_type.dart';
import '../turret/turret_type.dart';
import '../turret_module/turret_module_type.dart';

abstract interface class AuthoritativeEconomyCommands {
  Future<List<TurretModuleInventoryItem>> drawTurretModules(
    int count, {
    required TurretType turretType,
    required bool buyMissingTicketsWithDiamonds,
  });

  Future<bool> disassembleTurretModules(Iterable<String> ids);

  Future<bool> completeResearchWithDiamonds(ResearchType type);

  Future<bool> unlockResearchSlotTwo();

  Future<bool> claimDailyQuestReward(DailyQuestType type);

  Future<bool> claimDailyQuestAllCompleteReward();

  Future<bool> claimDailyAttendanceReward();

  Future<void> queueRunSettlement({
    required String runId,
    required int stageNumber,
    required int completedRounds,
    required bool success,
    required int pendingDiamonds,
    required int firstClearModuleTickets,
  });
}
