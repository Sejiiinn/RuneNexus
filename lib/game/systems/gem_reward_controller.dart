import '../../domain/combat/game_phase.dart';
import '../../domain/gem/gem_type.dart';
import 'gem_reward_generator.dart';

class GemRewardController {
  GemRewardController({GemRewardGenerator? rewardGenerator})
    : _rewardGenerator = rewardGenerator ?? GemRewardGenerator();

  final GemRewardGenerator _rewardGenerator;

  bool shouldOfferReward(int completedRound) {
    return _rewardGenerator.shouldOfferReward(completedRound);
  }

  GemChoicePurchase? purchaseGemChoice({
    required GamePhase phase,
    required int gemShards,
    required int purchaseCost,
    required Iterable<GemType> availableGems,
  }) {
    if ((phase != GamePhase.preparation && phase != GamePhase.wave) ||
        gemShards < purchaseCost) {
      return null;
    }

    final rewardOptions = _generateOptions(availableGems);
    if (rewardOptions.isEmpty) {
      return null;
    }

    return GemChoicePurchase(
      gemShards: gemShards - purchaseCost,
      rewardOptions: rewardOptions,
    );
  }

  GemDebugReward openDebugReward({
    required int completedRounds,
    required int roundIndex,
    required Iterable<GemType> availableGems,
  }) {
    return GemDebugReward(
      completedRounds: completedRounds > roundIndex + 1
          ? completedRounds
          : roundIndex + 1,
      rewardOptions: _generateOptions(availableGems),
    );
  }

  GemRoundReward? completeRound({
    required int completedRound,
    required Iterable<GemType> availableGems,
  }) {
    if (!shouldOfferReward(completedRound)) {
      return null;
    }
    return GemRoundReward(rewardOptions: _generateOptions(availableGems));
  }

  bool selectRewardGem({
    required GamePhase phase,
    required List<GemType> rewardOptions,
    required Map<GemType, int> gemInventory,
    required GemType type,
  }) {
    if (phase != GamePhase.reward || !rewardOptions.contains(type)) {
      return false;
    }

    grantGem(gemInventory: gemInventory, type: type);
    rewardOptions.clear();
    return true;
  }

  int? selectRewardGemShards({
    required GamePhase phase,
    required bool isPurchasedGemReward,
    required int gemShards,
    required int shardRewardAmount,
    required List<GemType> rewardOptions,
  }) {
    if (phase != GamePhase.reward || isPurchasedGemReward) {
      return null;
    }

    rewardOptions.clear();
    return gemShards + shardRewardAmount;
  }

  void grantGem({
    required Map<GemType, int> gemInventory,
    required GemType type,
  }) {
    gemInventory[type] = (gemInventory[type] ?? 0) + 1;
  }

  List<GemType> _generateOptions(Iterable<GemType> availableGems) {
    return _rewardGenerator.generateOptions(availableGems: availableGems);
  }
}

class GemChoicePurchase {
  const GemChoicePurchase({
    required this.gemShards,
    required this.rewardOptions,
  });

  final int gemShards;
  final List<GemType> rewardOptions;
}

class GemDebugReward {
  const GemDebugReward({
    required this.completedRounds,
    required this.rewardOptions,
  });

  final int completedRounds;
  final List<GemType> rewardOptions;
}

class GemRoundReward {
  const GemRoundReward({required this.rewardOptions});

  final List<GemType> rewardOptions;
}
