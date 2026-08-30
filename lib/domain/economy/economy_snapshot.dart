import '../turret/turret_type.dart';
import '../turret_module/turret_module_type.dart';

class EconomyWallet {
  const EconomyWallet({
    required this.freeDiamonds,
    required this.paidDiamonds,
    required this.moduleTickets,
  });

  final int freeDiamonds;
  final int paidDiamonds;
  final int moduleTickets;

  int get diamonds => freeDiamonds + paidDiamonds;
}

class EconomyModule {
  const EconomyModule({
    required this.id,
    required this.legacyItemId,
    required this.turretType,
    required this.part,
    required this.family,
    required this.grade,
    required this.options,
    required this.acquiredOrder,
  });

  final String id;
  final String? legacyItemId;
  final TurretType turretType;
  final TurretModulePart part;
  final TurretModuleFamily family;
  final TurretModuleGrade grade;
  final List<TurretModuleOptionRoll> options;
  final int acquiredOrder;

  TurretModuleKey get key => TurretModuleKey(
    turretType: turretType,
    part: part,
    family: family,
    grade: grade,
  );
}

class EconomyProgressionEffect {
  const EconomyProgressionEffect({
    required this.id,
    required this.effectType,
    required this.payload,
  });

  final String id;
  final String effectType;
  final Map<String, Object?> payload;
}

class EconomySnapshot {
  const EconomySnapshot({
    required this.authorityEpoch,
    required this.authorityState,
    required this.authorityVersion,
    required this.revision,
    required this.catalogVersion,
    required this.serverTime,
    required this.wallet,
    required this.moduleDrawCount,
    required this.moduleTicketPurchaseCount,
    required this.modules,
    required this.researchSlotTwoUnlocked,
    required this.pendingProgressionEffects,
    required this.claimedRewardKeys,
  });

  final String authorityEpoch;
  final String authorityState;
  final int authorityVersion;
  final int revision;
  final int catalogVersion;
  final DateTime serverTime;
  final EconomyWallet wallet;
  final int moduleDrawCount;
  final int moduleTicketPurchaseCount;
  final List<EconomyModule> modules;
  final bool researchSlotTwoUnlocked;
  final List<EconomyProgressionEffect> pendingProgressionEffects;
  final Set<String> claimedRewardKeys;
}

class EconomyCommandResult {
  const EconomyCommandResult({
    required this.snapshot,
    this.drawnModules = const [],
    this.progressionEffect,
    this.rewardKey,
    this.grantedDiamonds = 0,
    this.grantedModuleTickets = 0,
  });

  final EconomySnapshot snapshot;
  final List<EconomyModule> drawnModules;
  final EconomyProgressionEffect? progressionEffect;
  final String? rewardKey;
  final int grantedDiamonds;
  final int grantedModuleTickets;
}

class EconomyBootstrapResult {
  const EconomyBootstrapResult({
    required this.snapshot,
    required this.importedLegacyIdMap,
    required this.clearedEquippedIds,
    required this.bootstrapSaveRevision,
  });

  final EconomySnapshot snapshot;
  final Map<String, String> importedLegacyIdMap;
  final Set<String> clearedEquippedIds;
  final int bootstrapSaveRevision;
}
