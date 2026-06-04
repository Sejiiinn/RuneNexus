import 'dart:math' as math;

import '../../data/save/game_save_data.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/wave/wave_definition.dart';

class WaveSpawner {
  final List<SpawnRequest> _queue = [];
  double _elapsed = 0;
  int _nextIndex = 0;

  bool get isEmpty => _nextIndex >= _queue.length;

  void start(WaveDefinition wave, {double initialDelay = 0}) {
    _queue
      ..clear()
      ..addAll(_buildSpawnQueue(wave, initialDelay: initialDelay));
    _elapsed = 0;
    _nextIndex = 0;
  }

  void clear() {
    _queue.clear();
    _elapsed = 0;
    _nextIndex = 0;
  }

  List<SavedSpawnRequest> toSaveData() {
    return [
      for (var i = _nextIndex; i < _queue.length; i++)
        SavedSpawnRequest(
          enemyType: _queue[i].enemyType,
          delay: math.max(0, _queue[i].delay - _elapsed),
        ),
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
    _queue.sort((a, b) => a.delay.compareTo(b.delay));
    _elapsed = 0;
    _nextIndex = 0;
  }

  List<EnemyType> update(double dt) {
    if (dt < 0) {
      return const [];
    }
    if (dt > 0) {
      _elapsed += dt;
    }

    if (isEmpty || _queue[_nextIndex].delay > _elapsed) {
      return const [];
    }

    final ready = <EnemyType>[];
    while (_nextIndex < _queue.length && _queue[_nextIndex].delay <= _elapsed) {
      ready.add(_queue[_nextIndex].enemyType);
      _nextIndex++;
    }
    return ready;
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
