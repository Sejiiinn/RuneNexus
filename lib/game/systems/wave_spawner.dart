import 'dart:math' as math;

import '../../data/save/game_save_data.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/wave/wave_definition.dart';

class WaveSpawner {
  final List<SpawnRequest> _queue = [];

  bool get isEmpty => _queue.isEmpty;

  void start(WaveDefinition wave, {double initialDelay = 0}) {
    _queue
      ..clear()
      ..addAll(_buildSpawnQueue(wave, initialDelay: initialDelay));
  }

  void clear() {
    _queue.clear();
  }

  List<SavedSpawnRequest> toSaveData() {
    return [
      for (final request in _queue)
        SavedSpawnRequest(enemyType: request.enemyType, delay: request.delay),
    ];
  }

  void restoreFromSaveData(List<SavedSpawnRequest> requests) {
    _queue
      ..clear()
      ..addAll(
        requests.map(
          (request) =>
              SpawnRequest(enemyType: request.enemyType, delay: request.delay),
        ),
      );
  }

  List<EnemyType> update(double dt) {
    for (final request in _queue) {
      request.delay -= dt;
    }

    final ready = _queue.where((request) => request.delay <= 0).toList();
    _queue.removeWhere((request) => request.delay <= 0);
    return ready.map((request) => request.enemyType).toList();
  }

  List<SpawnRequest> _buildSpawnQueue(
    WaveDefinition wave, {
    required double initialDelay,
  }) {
    final requests = <SpawnRequest>[];
    double? previousGroupEndDelay;
    for (final group in wave.groups) {
      var groupStartDelay = initialDelay + group.startDelay;
      if (group.startAfterPrevious && previousGroupEndDelay != null) {
        groupStartDelay = math.max(
          groupStartDelay,
          previousGroupEndDelay + group.followDelay,
        );
      }
      for (var i = 0; i < group.count; i++) {
        requests.add(
          SpawnRequest(
            enemyType: group.enemyType,
            delay: groupStartDelay + group.interval * i,
          ),
        );
      }
      final lastSpawnIndex = group.count > 0 ? group.count - 1 : 0;
      final groupEndDelay = groupStartDelay + group.interval * lastSpawnIndex;
      previousGroupEndDelay = previousGroupEndDelay == null
          ? groupEndDelay
          : math.max(previousGroupEndDelay, groupEndDelay);
    }
    requests.sort((a, b) => a.delay.compareTo(b.delay));
    const minSpawnGap = 0.18;
    var previousDelay = -minSpawnGap;
    for (final request in requests) {
      if (request.delay < previousDelay + minSpawnGap) {
        request.delay = previousDelay + minSpawnGap;
      }
      previousDelay = request.delay;
    }
    return requests;
  }
}

class SpawnRequest {
  SpawnRequest({required this.enemyType, required this.delay});

  final EnemyType enemyType;
  double delay;
}
