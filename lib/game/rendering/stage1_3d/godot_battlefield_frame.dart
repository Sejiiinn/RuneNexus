import 'dart:ui';

import 'battlefield_frame.dart';

/// 본게임과 검수 앱이 공유하는 Godot 표시 입력. 저장·전투 객체는 변경하지 않음.
Map<String, Object?> encodeGodotBattlefieldFrame(
  BattlefieldFrame frame, {
  required int sequence,
  Size? viewport,
}) {
  List<Object> turretData(BattlefieldTurret turret) => [
    turret.id,
    turret.position.dx,
    turret.position.dy,
    turret.aimAngle,
    turret.shotSequence,
    turret.fireFeedback,
    turret.type.name,
    turret.level,
  ];

  return {
    'seq': sequence,
    'time': frame.time,
    'map': {
      'columns': frame.map.columns,
      'rows': frame.map.rows,
      'tiles': [
        for (final row in frame.map.tiles)
          for (final tile in row) tile.name,
      ],
    },
    'turrets': [for (final turret in frame.turrets) turretData(turret)],
    'buildPreview': frame.buildPreview == null
        ? null
        : turretData(frame.buildPreview!),
    'enemies': [
      for (final enemy in frame.enemies)
        [
          enemy.id,
          enemy.position.dx,
          enemy.position.dy,
          enemy.facingAngle,
          enemy.phase,
          enemy.scale,
          enemy.hitFlash,
          enemy.type.name,
          enemy.burning,
          enemy.slowed,
          enemy.poisoned,
          enemy.diamondCarrier,
        ],
    ],
    'projectiles': [
      for (final projectile in [
        ...frame.projectiles,
        ...frame.finishedProjectiles,
      ])
        [
          projectile.id,
          projectile.position.dx,
          projectile.position.dy,
          projectile.direction.dx,
          projectile.direction.dy,
          projectile.type.name,
          if (projectile.origin != null) ...[
            projectile.origin!.dx,
            projectile.origin!.dy,
            projectile.ownerId,
            projectile.shotSequence,
            projectile.isChain,
            projectile.finishedAt ?? -1,
            projectile.hitTarget?.dx,
            projectile.hitTarget?.dy,
          ],
        ],
    ],
    'impacts': [
      for (final impact in frame.impacts)
        [
          impact.id,
          impact.position.dx,
          impact.position.dy,
          impact.radius,
          impact.progress,
        ],
    ],
    if (viewport != null) ...{
      'viewport': [viewport.width, viewport.height],
      'screenCenter': [frame.screenCenter.dx, frame.screenCenter.dy],
      'pixelsPerTile': frame.pixelsPerTile,
      'zoom': frame.zoom,
    },
    'nexusHpRatio': frame.nexusHpRatio,
    'nexusHit': frame.nexusHit,
    'portalAlert': frame.portalAlert,
  };
}
