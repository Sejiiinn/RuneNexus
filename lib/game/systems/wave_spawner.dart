import '../../data/save/game_save_data.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/wave/wave_definition.dart';

class WaveSpawner {
  final List<SpawnRequest> _queue = [];

  bool get isEmpty => _queue.isEmpty;

  void start(WaveDefinition wave) {
    _queue
      ..clear()
      ..addAll(_buildSpawnQueue(wave));
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

  List<SpawnRequest> _buildSpawnQueue(WaveDefinition wave) {
    final requests = <SpawnRequest>[];
    for (final group in wave.groups) {
      for (var i = 0; i < group.count; i++) {
        requests.add(
          SpawnRequest(
            enemyType: group.enemyType,
            delay: group.startDelay + group.interval * i,
          ),
        );
      }
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
