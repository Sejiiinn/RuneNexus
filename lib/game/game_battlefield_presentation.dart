part of 'rune_nexus_game.dart';

/// 타일 단위 표시 입력과 투영만 담당. 전투 객체의 좌표·갱신은 변경하지 않음.
extension _BattlefieldPresentation on RuneNexusGame {
  BattlefieldFrame? _buildBattlefieldFrame() {
    if (!_boardConfigured || !readyNotifier.value || _activeStage.id != 1) {
      return null;
    }
    Offset grid(Vector2 position) => Offset(
      (position.x - _origin.x) / _tileSize,
      (position.y - _origin.y) / _tileSize,
    );
    int id(Object object) => _battlefieldIds[object] ??= _nextBattlefieldId++;
    final center = _boardCamera.worldToScreen(
      _origin +
          Vector2(_map.columns * _tileSize / 2, _map.rows * _tileSize / 2),
    );
    final enemyFrames = <BattlefieldEnemy>[];
    for (final enemy in enemies) {
      if (enemy.isDead) continue;
      final visual = enemy.visualRenderState;
      enemyFrames.add(
        BattlefieldEnemy(
          id: id(enemy),
          type: enemy.definition.type,
          position: grid(enemy.position) + visual.visualOffset / _tileSize,
          facingAngle: visual.facingAngle,
          scale: enemy.size.x / _tileSize,
          phase: enemy.visualPhase,
          hitFlash: visual.hitFlashRemaining,
          burning: visual.isBurning,
          slowed: visual.isSlowed,
          poisoned: visual.isPoisoned,
          diamondCarrier: visual.isDiamondCarrier,
        ),
      );
    }
    return BattlefieldFrame(
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
      turrets: [
        for (final turret in _turrets.values)
          BattlefieldTurret(
            id: id(turret),
            type: turret.definition.type,
            position: grid(turret.position),
            aimAngle: turret.visualAimAngle,
            fireFeedback: turret.visualFireFeedback,
            shotSequence: turret.visualShotSequence,
            level: turret.level,
          ),
      ],
      enemies: enemyFrames,
      projectiles: [
        for (final projectile in children.whereType<ProjectileComponent>())
          if (!projectile.isRemoving)
            BattlefieldProjectile(
              id: id(projectile),
              type: projectile.owner.definition.type,
              position: grid(projectile.position),
              direction: projectile.visualDirection,
              origin:
                  (projectile.visualOrigin - Offset(_origin.x, _origin.y)) /
                  _tileSize,
              ownerId: id(projectile.owner),
              shotSequence: projectile.visualShotSequence,
              isChain: projectile.isChain,
            ),
      ],
      finishedProjectiles: List.unmodifiable(_finishedProjectiles),
      impacts: [
        for (final impact in children.whereType<ImpactEffectComponent>())
          if (!impact.isRemoving && impact.style == ImpactEffectStyle.blast)
            BattlefieldImpact(
              id: id(impact),
              position: grid(impact.position),
              radius: impact.radius / _tileSize,
              progress: impact.visualProgress,
            ),
      ],
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

  void _applyBattlefieldTransform(Canvas canvas) {
    final projection = battlefieldProjection;
    if (projection == null) {
      _boardCamera.applyTransform(canvas);
    } else {
      projection.applyWorldTransform(
        canvas,
        Offset(_origin.x, _origin.y),
        _tileSize,
      );
    }
  }

  void _renderBattlefieldLabels(Canvas canvas) {
    final projection = battlefieldProjection!;
    final scale = projection.xAxis.distance / _tileSize;
    for (final child in children) {
      if (child is! PositionComponent || child.isRemoving) continue;
      if (child is! EnemyComponent &&
          child is! TurretComponent &&
          child is! DamageNumberComponent &&
          child is! DiamondRewardEffectComponent) {
        continue;
      }
      final visualOffset = child is EnemyComponent
          ? child.visualRenderState.visualOffset
          : Offset.zero;
      final point = projection.gridToScreen(
        Offset(
          (child.position.x + visualOffset.dx - _origin.x) / _tileSize,
          (child.position.y + visualOffset.dy - _origin.y) / _tileSize,
        ),
        height: child is EnemyComponent ? 0.3 : 0,
      );
      // 수치·상태 아이콘은 지면 기울기를 적용하지 않는 화면 정면 표시.
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.scale(scale);
      canvas.translate(-child.size.x / 2, -child.size.y / 2);
      if (child is EnemyComponent) {
        child.renderBattlefieldStatus(canvas);
      } else if (child is TurretComponent) {
        child.renderBattlefieldLevel(canvas);
      } else {
        child.render(canvas);
      }
      canvas.restore();
    }
  }
}
