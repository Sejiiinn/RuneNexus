part of 'rune_nexus_game.dart';

/// 타일 단위 표시 입력과 투영만 담당. 전투 객체의 좌표·갱신은 변경하지 않음.
extension _BattlefieldPresentation on RuneNexusGame {
  bool _usesNativeBattlefieldGroup(String group) =>
      battlefieldProjection != null && nativeBattlefieldGroups.contains(group);

  BattlefieldFrame? _buildBattlefieldFrame() {
    if (!_boardConfigured ||
        !readyNotifier.value ||
        !supportsNativeBattlefield) {
      return null;
    }
    final center = _boardCamera.worldToScreen(
      _origin +
          Vector2(_map.columns * _tileSize / 2, _map.rows * _tileSize / 2),
    );
    return BattlefieldFrame(
      labels: _buildBattlefieldLabels(),
      effects: _buildBattlefieldEffects(),
      selection: _buildBattlefieldSelection(),
      map: _map,
      buildPreview:
          _selectedBuildPoint != null && _selectedBuildTurretType != null
          ? BattlefieldTurret(
              id: -1,
              type: _selectedBuildTurretType!,
              position: Offset(
                _selectedBuildPoint!.x + 0.5,
                _selectedBuildPoint!.y + 0.5,
              ),
              aimAngle: -math.pi / 2,
              fireFeedback: 0,
              level: 1,
            )
          : null,
      // Godot decorates the frame with its authoritative combat actors.
      turrets: const [],
      enemies: const [],
      projectiles: const [],
      time: _spaceTime,
      pixelsPerTile: _tileSize,
      zoom: _boardCamera.zoom,
      screenCenter: Offset(center.x, center.y),
      nexusHpRatio: (_nexusHp / _maxNexusHp).clamp(0, 1),
      nexusHit: (_nexusHitAlertTimer / RuneNexusGame._nexusHitAlertDuration)
          .clamp(0, 1),
      portalAlert: (_portalAlertTimer / RuneNexusGame._portalAlertDuration)
          .clamp(0, 1),
    );
  }

  Vector2 _battlefieldWorldFromScreen(Vector2 position) {
    final grid = battlefieldProjection?.screenToGrid(
      Offset(position.x, position.y),
    );
    return grid == null
        ? _boardCamera.screenToWorld(position)
        : _origin + Vector2(grid.dx * _tileSize, grid.dy * _tileSize);
  }
}
