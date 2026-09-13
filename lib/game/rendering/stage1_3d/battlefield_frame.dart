import 'dart:ui';

import '../../../domain/enemy/enemy_type.dart';
import '../../../domain/map/map_definition.dart';
import '../../../domain/turret/turret_type.dart';
import 'battlefield_labels.dart';
import 'battlefield_effects.dart';
import 'battlefield_selection.dart';

/// 전투 규칙과 독립적인 3D 표시 입력. 위치·크기는 타일 단위.
class BattlefieldFrame {
  const BattlefieldFrame({
    required this.map,
    required this.turrets,
    required this.enemies,
    required this.projectiles,
    required this.time,
    required this.pixelsPerTile,
    required this.zoom,
    required this.screenCenter,
    required this.nexusHpRatio,
    required this.nexusHit,
    required this.portalAlert,
    this.buildPreview,
    this.impacts = const [],
    this.finishedProjectiles = const [],
    this.labels,
    this.effects,
    this.selection,
  });

  final MapDefinition map;
  final List<BattlefieldTurret> turrets;

  /// 실제 포탑과 분리된 건설 미리보기. 예약 ID -1.
  final BattlefieldTurret? buildPreview;
  final List<BattlefieldEnemy> enemies;
  final List<BattlefieldProjectile> projectiles;
  final List<BattlefieldProjectile> finishedProjectiles;
  final List<BattlefieldImpact> impacts;
  final double time;
  final double pixelsPerTile;
  final double zoom;
  final Offset screenCenter;
  final double nexusHpRatio;
  final double nexusHit;
  final double portalAlert;
  final BattlefieldLabels? labels;
  final BattlefieldEffects? effects;
  final BattlefieldSelection? selection;
}

class BattlefieldTurret {
  const BattlefieldTurret({
    required this.id,
    required this.type,
    required this.position,
    required this.aimAngle,
    required this.fireFeedback,
    this.shotSequence = 0,
    required this.level,
  });
  final int id;
  final TurretType type;
  final Offset position;

  /// 게임의 +X 기준 시계 방향 각도. GLB는 +Z 정면.
  final double aimAngle;
  final double fireFeedback;
  final int shotSequence;
  final int level;
}

class BattlefieldEnemy {
  const BattlefieldEnemy({
    required this.id,
    required this.type,
    required this.position,
    required this.facingAngle,
    required this.scale,
    required this.phase,
    required this.hitFlash,
    required this.burning,
    required this.slowed,
    required this.poisoned,
    required this.diamondCarrier,
  });
  final int id;
  final EnemyType type;
  final Offset position;
  final double facingAngle;
  final double scale;
  final double phase;
  final double hitFlash;
  final bool burning;
  final bool slowed;
  final bool poisoned;
  final bool diamondCarrier;
}

class BattlefieldProjectile {
  const BattlefieldProjectile({
    required this.id,
    required this.type,
    required this.position,
    required this.direction,
    this.origin,
    this.ownerId,
    this.shotSequence = 0,
    this.isChain = false,
    this.finishedAt,
    this.hitTarget,
  });
  final int id;
  final TurretType type;
  final Offset position;
  final Offset direction;
  final Offset? origin;
  final int? ownerId;
  final int shotSequence;
  final bool isChain;

  /// 배속과 독립적인 표시 시각. null이면 아직 이동 중인 탄환.
  final double? finishedAt;
  final Offset? hitTarget;
}

/// 피해 판정이 끝난 착탄의 표시 상태. 시간은 전투 컴포넌트에서 전달.
class BattlefieldImpact {
  const BattlefieldImpact({
    required this.id,
    required this.position,
    required this.radius,
    required this.progress,
  });

  static const duration = 1.1;
  final int id;
  final Offset position;
  final double radius;
  final double progress;
}
