import '../../../domain/map/map_definition.dart';
import '../../../domain/map/tile_type.dart';

/// Static map delivery stays pending until Godot confirms actual application.
/// Every pending frame carries the map, so latest-frame coalescing is safe.
class GodotBattlefieldMapTransport {
  int? _epoch;
  int _revision = 0;
  int _firstSequence = 0;
  int _lastResponseSequence = -1;
  bool _acknowledged = false;
  int _columns = 0;
  int _rows = 0;
  String _theme = '';
  List<TileType> _tiles = const [];
  Map<String, Object?> _payload = const {};

  int get revision => _revision;

  Map<String, Object?> prepare(
    MapDefinition map, {
    required int sceneEpoch,
    required int sequence,
  }) {
    final newScene = _epoch != sceneEpoch;
    if (newScene || !_matches(map)) {
      _epoch = sceneEpoch;
      _revision = newScene ? 1 : _revision + 1;
      _firstSequence = sequence;
      _lastResponseSequence = -1;
      _acknowledged = false;
      _columns = map.columns;
      _rows = map.rows;
      _theme = map.tileTheme.kind.name;
      _tiles = [for (final row in map.tiles) ...row];
      _payload = {
        'theme': _theme,
        'columns': _columns,
        'rows': _rows,
        'tiles': [for (final tile in _tiles) tile.name],
      };
    }
    return {'mapRevision': _revision, if (!_acknowledged) 'map': _payload};
  }

  // MapDefinition exposes lists: compare values even when identity is unchanged.
  // No per-frame flattened list, enum-name list or map payload allocation.
  bool _matches(MapDefinition map) {
    if (map.columns != _columns ||
        map.rows != _rows ||
        map.tileTheme.kind.name != _theme) {
      return false;
    }
    var index = 0;
    for (final row in map.tiles) {
      for (final tile in row) {
        if (index >= _tiles.length || _tiles[index++] != tile) return false;
      }
    }
    return index == _tiles.length;
  }

  /// Caller validates epoch, viewport and submitted/applied sequence bounds first.
  void acknowledge({
    required int sceneEpoch,
    required int sequence,
    required Object? mapRevision,
  }) {
    if (sceneEpoch != _epoch ||
        mapRevision != _revision ||
        sequence < _firstSequence ||
        sequence < _lastResponseSequence) {
      return;
    }
    _lastResponseSequence = sequence;
    _acknowledged = true;
  }

  /// Recovery metadata is not a rendered frame and never releases the ready gate.
  void requestMap({
    required int sceneEpoch,
    required int sequence,
    required Object? mapRevision,
  }) {
    if (sceneEpoch != _epoch ||
        mapRevision != _revision ||
        sequence < _firstSequence ||
        sequence < _lastResponseSequence) {
      return;
    }
    _lastResponseSequence = sequence;
    _firstSequence = sequence + 1;
    _acknowledged = false;
  }
}
