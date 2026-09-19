import 'package:flutter/foundation.dart';

import 'battlefield_selection.dart';

/// Static selection survives frame coalescing until its actual application ACK.
class GodotBattlefieldSelectionTransport {
  BattlefieldSelection? _previous;
  int? _epoch;
  int _revision = 0;
  int _firstSequence = 0;
  bool _acknowledged = false;
  Map<String, Object?> _state = const {};

  int get revision => _revision;

  Map<String, Object?> prepare(
    BattlefieldSelection selection, {
    required int sceneEpoch,
    required int sequence,
  }) {
    if (_epoch != sceneEpoch || !_matches(selection)) {
      _revision = _epoch != sceneEpoch ? 1 : _revision + 1;
      _epoch = sceneEpoch;
      _firstSequence = sequence;
      _acknowledged = false;
      _previous = selection;
      _state = {
        'logicalTileSize': selection.logicalTileSize,
        'visualScale': selection.visualScale,
        'rewardTargeting': selection.rewardTargeting,
        'rewardViewport': selection.rewardViewport == null
            ? null
            : [
                selection.rewardViewport!.left,
                selection.rewardViewport!.top,
                selection.rewardViewport!.width,
                selection.rewardViewport!.height,
              ],
        'turrets': [
          for (final turret in selection.turrets)
            {
              'position': [turret.position.dx, turret.position.dy],
              'color': turret.color.toARGB32(),
              'range': turret.range,
              'selected': turret.selected,
              'previewRange': turret.previewRange,
              'level': turret.level,
              'auraTier': turret.auraTier,
              'phaseOrigin': turret.phaseOrigin,
              'gemColors': [
                for (final color in turret.gemColors) color.toARGB32(),
              ],
            },
        ],
        'tiles': [for (final tile in selection.tiles) tile.toJson()],
        'rewardTargets': [
          for (final target in selection.rewardTargets) target.toJson(),
        ],
      };
    }
    return {
      'revision': _revision,
      if (!_acknowledged) 'state': _state,
      'clock': selection.clock,
      'time': selection.time,
      // Combat aiming remains authoritative, independent of static state.
      'aim': [
        for (var i = 0; i < selection.turrets.length; i++)
          if (selection.turrets[i].aimTarget != null)
            [
              i,
              selection.turrets[i].aimTarget!.dx,
              selection.turrets[i].aimTarget!.dy,
              selection.turrets[i].aimProgress,
            ],
      ],
    };
  }

  void acknowledge({
    required int sceneEpoch,
    required int sequence,
    required Object? revision,
    required bool applied,
  }) {
    if (_epoch != sceneEpoch || sequence < _firstSequence) return;
    _acknowledged = applied && revision == _revision;
  }

  void reset() {
    _epoch = null;
    _previous = null;
    _acknowledged = false;
  }

  bool _matches(BattlefieldSelection next) {
    final old = _previous;
    if (old == null ||
        old.logicalTileSize != next.logicalTileSize ||
        old.visualScale != next.visualScale ||
        old.rewardTargeting != next.rewardTargeting ||
        old.rewardViewport != next.rewardViewport ||
        old.turrets.length != next.turrets.length ||
        old.tiles.length != next.tiles.length ||
        old.rewardTargets.length != next.rewardTargets.length) {
      return false;
    }
    for (var i = 0; i < old.turrets.length; i++) {
      final a = old.turrets[i], b = next.turrets[i];
      if (a.position != b.position ||
          a.color != b.color ||
          a.range != b.range ||
          a.selected != b.selected ||
          a.previewRange != b.previewRange ||
          a.level != b.level ||
          a.auraTier != b.auraTier ||
          a.phaseOrigin != b.phaseOrigin ||
          !listEquals(a.gemColors, b.gemColors)) {
        return false;
      }
    }
    for (var i = 0; i < old.tiles.length; i++) {
      final a = old.tiles[i], b = next.tiles[i];
      if (a.position != b.position ||
          a.kind != b.kind ||
          a.range != b.range ||
          a.color != b.color) {
        return false;
      }
    }
    for (var i = 0; i < old.rewardTargets.length; i++) {
      final a = old.rewardTargets[i], b = next.rewardTargets[i];
      if (a.position != b.position ||
          a.requiresReplacement != b.requiresReplacement) {
        return false;
      }
    }
    return true;
  }
}
