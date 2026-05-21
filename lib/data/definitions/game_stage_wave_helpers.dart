part of 'game_stage_waves.dart';

const double _standardGroupGap = 0.75;
const double _tightGroupGap = 0.35;

int _clearRewardGoldFor(int round) {
  if (round % 10 == 0) {
    return 70 + round * 3;
  }
  if (round % 5 == 0) {
    return 48 + round * 2;
  }
  return 22 + round;
}

int _tierForRound(int round) {
  if (round <= 5) {
    return 0;
  }
  return (round - 6) ~/ 5;
}

int _cycleStepFor(int round) {
  if (round <= 5) {
    return round;
  }
  return (round - 6) % 5 + 1;
}

double _normalIntervalFor(int tier) {
  return 1.24 - tier * 0.02;
}

double _fastIntervalFor(int tier) {
  return 0.82 - tier * 0.015;
}

double _durableIntervalFor(int tier) {
  return 1.38 - tier * 0.02;
}

double _nextGroupDelay(SpawnGroup previous, {required double gap}) {
  final lastSpawnIndex = previous.count > 0 ? previous.count - 1 : 0;
  return previous.startDelay + previous.interval * lastSpawnIndex + gap;
}
