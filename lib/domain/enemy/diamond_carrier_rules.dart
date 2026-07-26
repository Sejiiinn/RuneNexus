import 'enemy_type.dart';

abstract final class DiamondCarrierRules {
  static const double carrierChance = 0.005;
  static const double oneDiamondChanceGivenCarrier = 0.7;
  static const double twoDiamondChanceGivenCarrier = 0.2;
  static const double threeDiamondChanceGivenCarrier = 0.1;

  static int rewardForSpawn({
    required EnemyType type,
    required bool isDirectWaveSpawn,
    required double roll,
  }) {
    if (!isDirectWaveSpawn || type.isBoss || roll < 0 || roll >= 1) {
      return 0;
    }
    return _rewardForScaledRoll(roll, scale: carrierChance);
  }

  static int rewardForCarrierRoll(double roll) {
    if (roll < 0 || roll >= 1) {
      return 0;
    }
    return _rewardForScaledRoll(roll, scale: 1);
  }

  static int _rewardForScaledRoll(double roll, {required double scale}) {
    final oneDiamondBoundary = scale * oneDiamondChanceGivenCarrier;
    final twoDiamondBoundary =
        scale * (oneDiamondChanceGivenCarrier + twoDiamondChanceGivenCarrier);
    final threeDiamondBoundary =
        scale *
        (oneDiamondChanceGivenCarrier +
            twoDiamondChanceGivenCarrier +
            threeDiamondChanceGivenCarrier);
    if (roll < oneDiamondBoundary) {
      return 1;
    }
    if (roll < twoDiamondBoundary) {
      return 2;
    }
    if (roll < threeDiamondBoundary) {
      return 3;
    }
    return 0;
  }
}
