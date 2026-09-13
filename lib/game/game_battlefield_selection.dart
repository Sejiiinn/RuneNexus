part of 'rune_nexus_game.dart';

extension _BattlefieldSelectionPresentation on RuneNexusGame {
  BattlefieldSelection _buildBattlefieldSelection() {
    Offset grid(Vector2 point) => Offset(
      (point.x - _origin.x) / _tileSize,
      (point.y - _origin.y) / _tileSize,
    );
    Offset center(GridPoint point) => Offset(point.x + 0.5, point.y + 0.5);
    final buildType = _selectedBuildTurretType;
    final build = buildType == null ? null : gameTurrets[buildType]!;
    return BattlefieldSelection(
      logicalTileSize: _tileSize,
      visualScale: boardDistanceScale,
      time: _spaceTime,
      rewardTargeting: isGemRewardTargeting,
      rewardViewport: _gemRewardBoardViewport,
      turrets: [
        for (final turret in _turrets.values)
          BattlefieldTurretSelection(
            position: grid(turret.position),
            color: turret.definition.color,
            range:
                turret.range *
                (turret.definition.centeredAreaAttack
                    ? turret.effectAreaMultiplier
                    : 1) /
                _tileSize,
            selected: isTurretSelected(turret.gridPoint),
            previewRange:
                isTurretSelected(turret.gridPoint) &&
                    levelUpPreviewRangeFor(turret.gridPoint) != null
                ? levelUpPreviewRangeFor(turret.gridPoint)! *
                      (turret.definition.centeredAreaAttack
                          ? turret.effectAreaMultiplier
                          : 1) /
                      _tileSize
                : null,
            auraTier: turret.level <= 1
                ? 0
                : turret.level >= 10
                ? 4
                : turret.level >= 8
                ? 3
                : turret.level >= 5
                ? 2
                : 1,
            animationPhase: turret.visualGemRingPhase,
            gemColors: turret.equippedGems
                .take(turret.maxSlotLimit)
                .map(colorForGem),
            aimTarget: turret.visualAimTargetPosition == null
                ? null
                : (turret.visualAimTargetPosition! -
                          Offset(_origin.x, _origin.y)) /
                      _tileSize,
            aimProgress: turret.aimProgressRatio,
          ),
      ],
      tiles: [
        if (_selectedPortalPoint != null)
          BattlefieldTileSelection(
            position: center(_selectedPortalPoint!),
            kind: 'portal',
          ),
        if (_selectedCorePoint != null)
          BattlefieldTileSelection(
            position: center(_selectedCorePoint!),
            kind: 'core',
          ),
        if (_selectedBuildPoint != null)
          BattlefieldTileSelection(
            position: center(_selectedBuildPoint!),
            kind: 'build',
            range: build == null
                ? null
                : build.range * boardDistanceScale / _tileSize,
            color: build?.color,
          ),
      ],
      rewardTargets: [
        if (isGemRewardTargeting)
          for (final point in _turrets.keys)
            if (gemRewardTargetStatus(point) !=
                    GemRewardTargetStatus.unavailable &&
                (_rewardSelection.replacementPoint == null ||
                    _rewardSelection.replacementPoint == point))
              BattlefieldRewardTarget(
                position: center(point),
                requiresReplacement:
                    gemRewardTargetStatus(point) ==
                    GemRewardTargetStatus.replacement,
              ),
      ],
    );
  }
}
