import 'dart:ui';

/// 전투에서 확정한 선택·범위 표시. 위치와 반경은 타일 단위이다.
class BattlefieldSelection {
  BattlefieldSelection({
    required this.logicalTileSize,
    required this.visualScale,
    required this.time,
    required this.rewardTargeting,
    this.rewardViewport,
    Iterable<BattlefieldTurretSelection> turrets = const [],
    Iterable<BattlefieldTileSelection> tiles = const [],
    Iterable<BattlefieldRewardTarget> rewardTargets = const [],
  }) : turrets = List.unmodifiable(turrets),
       tiles = List.unmodifiable(tiles),
       rewardTargets = List.unmodifiable(rewardTargets);

  final double logicalTileSize;
  final double visualScale;
  final double time;
  final bool rewardTargeting;
  final Rect? rewardViewport;
  final List<BattlefieldTurretSelection> turrets;
  final List<BattlefieldTileSelection> tiles;
  final List<BattlefieldRewardTarget> rewardTargets;

  Map<String, Object?> toJson() => {
    'logicalTileSize': logicalTileSize,
    'visualScale': visualScale,
    'time': time,
    'rewardTargeting': rewardTargeting,
    'rewardViewport': rewardViewport == null
        ? null
        : [
            rewardViewport!.left,
            rewardViewport!.top,
            rewardViewport!.width,
            rewardViewport!.height,
          ],
    'turrets': [for (final value in turrets) value.toJson()],
    'tiles': [for (final value in tiles) value.toJson()],
    'rewardTargets': [for (final value in rewardTargets) value.toJson()],
  };
}

class BattlefieldTurretSelection {
  BattlefieldTurretSelection({
    required this.position,
    required this.color,
    required this.range,
    required this.selected,
    this.previewRange,
    required this.auraTier,
    required this.animationPhase,
    Iterable<Color> gemColors = const [],
    this.aimTarget,
    required this.aimProgress,
  }) : gemColors = List.unmodifiable(gemColors);
  final Offset position;
  final Color color;
  final double range;
  final bool selected;
  final double? previewRange;
  final int auraTier;
  final double animationPhase;
  final List<Color> gemColors;
  final Offset? aimTarget;
  final double aimProgress;
  Map<String, Object?> toJson() => {
    'position': [position.dx, position.dy],
    'color': color.toARGB32(),
    'range': range,
    'selected': selected,
    'previewRange': previewRange,
    'auraTier': auraTier,
    'animationPhase': animationPhase,
    'gemColors': [for (final color in gemColors) color.toARGB32()],
    'aimTarget': aimTarget == null ? null : [aimTarget!.dx, aimTarget!.dy],
    'aimProgress': aimProgress,
  };
}

class BattlefieldTileSelection {
  const BattlefieldTileSelection({
    required this.position,
    required this.kind,
    this.range,
    this.color,
  });
  final Offset position;
  final String kind;
  final double? range;
  final Color? color;
  Map<String, Object?> toJson() => {
    'position': [position.dx, position.dy],
    'kind': kind,
    'range': range,
    'color': color?.toARGB32(),
  };
}

class BattlefieldRewardTarget {
  const BattlefieldRewardTarget({
    required this.position,
    required this.requiresReplacement,
  });
  final Offset position;
  final bool requiresReplacement;
  Map<String, Object?> toJson() => {
    'position': [position.dx, position.dy],
    'requiresReplacement': requiresReplacement,
  };
}
