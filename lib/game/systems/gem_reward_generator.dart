import 'dart:math' as math;

import '../../domain/gem/gem_type.dart';

class GemRewardGenerator {
  GemRewardGenerator({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  bool shouldOfferReward(int completedRound) {
    return completedRound % 5 == 0;
  }

  List<GemType> generateOptions({Iterable<GemType>? availableGems}) {
    final gems = (availableGems ?? GemType.values).toList()..shuffle(_random);
    return gems.take(3).toList();
  }
}
