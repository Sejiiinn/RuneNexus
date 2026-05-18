import 'dart:math' as math;
import 'dart:ui';

import '../../domain/enemy/enemy_type.dart';

void drawEnemyShape(
  Canvas canvas, {
  required Size size,
  required EnemyType type,
  required Color color,
  double strokeWidth = 2,
  double facingAngle = 0,
}) {
  final center = Offset(size.width / 2, size.height / 2);
  final scale = math.min(size.width, size.height);
  final palette = _EnemyVisualPalette.forType(type, color);
  final facing = _enemyFacingFor(facingAngle);

  canvas.save();
  canvas.translate(center.dx, center.dy);
  _drawShadow(canvas, scale);
  if (facing == _EnemyFacing.left) {
    canvas.scale(-1, 1);
  }

  switch (type) {
    case EnemyType.normal:
      if (facing == _EnemyFacing.front) {
        _drawNormal(canvas, scale, palette, strokeWidth);
      } else if (facing == _EnemyFacing.back) {
        _drawNormalBack(canvas, scale, palette, strokeWidth);
      } else {
        _drawNormalSide(canvas, scale, palette, strokeWidth);
      }
    case EnemyType.armored:
      if (facing == _EnemyFacing.front) {
        _drawArmored(canvas, scale, palette, strokeWidth);
      } else if (facing == _EnemyFacing.back) {
        _drawArmoredBack(canvas, scale, palette, strokeWidth);
      } else {
        _drawArmoredSide(canvas, scale, palette, strokeWidth);
      }
    case EnemyType.fast:
      if (facing == _EnemyFacing.front) {
        _drawFastFront(canvas, scale, palette, strokeWidth);
      } else if (facing == _EnemyFacing.back) {
        _drawFastBack(canvas, scale, palette, strokeWidth);
      } else {
        _drawFast(canvas, scale, palette, strokeWidth);
      }
    case EnemyType.tank:
      if (facing == _EnemyFacing.front) {
        _drawTank(canvas, scale, palette, strokeWidth);
      } else if (facing == _EnemyFacing.back) {
        _drawTankBack(canvas, scale, palette, strokeWidth);
      } else {
        _drawTankSide(canvas, scale, palette, strokeWidth);
      }
    case EnemyType.boss:
      if (facing == _EnemyFacing.front) {
        _drawBoss(canvas, scale, palette, strokeWidth);
      } else if (facing == _EnemyFacing.back) {
        _drawBossBack(canvas, scale, palette, strokeWidth);
      } else {
        _drawBossSide(canvas, scale, palette, strokeWidth);
      }
  }

  canvas.restore();
}

_EnemyFacing _enemyFacingFor(double angle) {
  final horizontal = math.cos(angle);
  final vertical = math.sin(angle);
  if (vertical.abs() >= horizontal.abs()) {
    return vertical >= 0 ? _EnemyFacing.front : _EnemyFacing.back;
  }
  return horizontal >= 0 ? _EnemyFacing.right : _EnemyFacing.left;
}

void _drawNormalShell(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0, -0.5),
      const Offset(0.1, -0.23),
      Offset.zero,
      const Offset(-0.1, -0.23),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(-0.5, 0),
      const Offset(-0.23, -0.1),
      Offset.zero,
      const Offset(-0.23, 0.1),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0.5, 0),
      const Offset(0.23, -0.1),
      Offset.zero,
      const Offset(0.23, 0.1),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawBody(
    canvas,
    scale,
    [
      const Offset(0, -0.39),
      const Offset(0.31, -0.23),
      const Offset(0.42, 0.06),
      const Offset(0.24, 0.34),
      const Offset(0, 0.45),
      const Offset(-0.25, 0.34),
      const Offset(-0.42, 0.06),
      const Offset(-0.31, -0.23),
    ],
    palette,
    strokeWidth,
  );
}

void _drawTankShell(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0, -0.53),
      const Offset(0.12, -0.27),
      Offset.zero,
      const Offset(-0.12, -0.27),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawBody(
    canvas,
    scale,
    [
      const Offset(0, -0.44),
      const Offset(0.38, -0.28),
      const Offset(0.52, 0),
      const Offset(0.38, 0.34),
      const Offset(0, 0.48),
      const Offset(-0.38, 0.34),
      const Offset(-0.52, 0),
      const Offset(-0.38, -0.28),
    ],
    palette,
    strokeWidth,
  );
}

void _drawBossShell(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0, -0.58),
      const Offset(0.13, -0.29),
      Offset.zero,
      const Offset(-0.13, -0.29),
    ],
    palette.spike,
    strokeWidth * 0.8,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(-0.57, -0.13),
      const Offset(-0.25, -0.22),
      const Offset(-0.35, -0.03),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0.57, -0.13),
      const Offset(0.25, -0.22),
      const Offset(0.35, -0.03),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(-0.37, 0.43),
      const Offset(-0.2, 0.22),
      const Offset(-0.12, 0.48),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0.37, 0.43),
      const Offset(0.2, 0.22),
      const Offset(0.12, 0.48),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawBody(
    canvas,
    scale,
    [
      const Offset(0, -0.47),
      const Offset(0.41, -0.29),
      const Offset(0.57, 0),
      const Offset(0.41, 0.36),
      const Offset(0, 0.54),
      const Offset(-0.41, 0.36),
      const Offset(-0.57, 0),
      const Offset(-0.41, -0.29),
    ],
    palette,
    strokeWidth,
  );
}

void _drawNormal(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0, -0.5),
      const Offset(0.1, -0.23),
      Offset.zero,
      const Offset(-0.1, -0.23),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(-0.5, 0),
      const Offset(-0.23, -0.1),
      Offset.zero,
      const Offset(-0.23, 0.1),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0.5, 0),
      const Offset(0.23, -0.1),
      Offset.zero,
      const Offset(0.23, 0.1),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );

  _drawBody(
    canvas,
    scale,
    [
      const Offset(0, -0.39),
      const Offset(0.31, -0.23),
      const Offset(0.42, 0.06),
      const Offset(0.24, 0.34),
      const Offset(0, 0.45),
      const Offset(-0.25, 0.34),
      const Offset(-0.42, 0.06),
      const Offset(-0.31, -0.23),
    ],
    palette,
    strokeWidth,
  );

  _drawPlate(
    canvas,
    scale,
    [
      const Offset(0, -0.31),
      const Offset(0.2, -0.18),
      const Offset(0, -0.1),
      const Offset(-0.2, -0.18),
    ],
    palette.accent.withValues(alpha: 0.48),
    strokeWidth * 0.45,
  );
  _drawCore(canvas, scale, palette.accent, radius: 0.16);
}

void _drawNormalSide(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  _drawShard(
    canvas,
    scale,
    [
      const Offset(-0.44, -0.2),
      const Offset(-0.62, -0.34),
      const Offset(-0.32, -0.3),
    ],
    palette.spike,
    strokeWidth * 0.7,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(-0.44, 0.2),
      const Offset(-0.62, 0.34),
      const Offset(-0.32, 0.3),
    ],
    palette.spike,
    strokeWidth * 0.7,
  );
  _drawShard(
    canvas,
    scale,
    [const Offset(0.48, 0), const Offset(0.27, -0.1), const Offset(0.27, 0.1)],
    palette.spike,
    strokeWidth * 0.7,
  );
  _drawBody(
    canvas,
    scale,
    [
      const Offset(-0.4, 0),
      const Offset(-0.12, -0.36),
      const Offset(0.34, -0.25),
      const Offset(0.48, 0),
      const Offset(0.34, 0.25),
      const Offset(-0.12, 0.36),
    ],
    palette,
    strokeWidth,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.08, -0.26),
      const Offset(0.18, -0.17),
      const Offset(-0.02, -0.04),
      const Offset(-0.27, -0.05),
    ],
    palette.accent.withValues(alpha: 0.45),
    strokeWidth * 0.45,
  );
  _drawCore(
    canvas,
    scale,
    palette.accent,
    center: const Offset(0.1, 0),
    radius: 0.15,
  );
}

void _drawNormalBack(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  _drawNormalShell(canvas, scale, palette, strokeWidth);
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(0, -0.27),
      const Offset(0.18, -0.1),
      const Offset(0.12, 0.17),
      const Offset(0, 0.29),
      const Offset(-0.12, 0.17),
      const Offset(-0.18, -0.1),
    ],
    palette.armor.withValues(alpha: 0.62),
    strokeWidth * 0.48,
  );
}

void _drawFast(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  _drawTrail(canvas, scale, const Offset(-0.37, -0.13), palette.accent);
  _drawTrail(canvas, scale, const Offset(-0.37, 0.13), palette.accent);
  _drawShard(
    canvas,
    scale,
    [
      const Offset(-0.35, -0.24),
      const Offset(-0.55, -0.39),
      const Offset(-0.25, -0.33),
    ],
    palette.spike,
    strokeWidth * 0.7,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(-0.35, 0.24),
      const Offset(-0.55, 0.39),
      const Offset(-0.25, 0.33),
    ],
    palette.spike,
    strokeWidth * 0.7,
  );

  _drawBody(
    canvas,
    scale,
    [
      const Offset(-0.52, 0),
      const Offset(-0.12, -0.38),
      const Offset(0.36, -0.26),
      const Offset(0.5, 0),
      const Offset(0.36, 0.26),
      const Offset(-0.12, 0.38),
    ],
    palette,
    strokeWidth,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.16, -0.25),
      const Offset(0.16, -0.16),
      const Offset(-0.06, -0.02),
      const Offset(-0.36, -0.02),
    ],
    palette.accent.withValues(alpha: 0.42),
    strokeWidth * 0.45,
  );
  _drawCore(
    canvas,
    scale,
    palette.accent,
    center: const Offset(0.13, 0),
    radius: 0.14,
  );
}

void _drawArmored(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  _drawBody(
    canvas,
    scale,
    [
      const Offset(0, -0.42),
      const Offset(0.33, -0.2),
      const Offset(0.47, 0.07),
      const Offset(0.31, 0.35),
      const Offset(0, 0.48),
      const Offset(-0.31, 0.35),
      const Offset(-0.47, 0.07),
      const Offset(-0.33, -0.2),
    ],
    palette,
    strokeWidth,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.34, -0.12),
      const Offset(-0.12, -0.22),
      const Offset(-0.08, 0.34),
      const Offset(-0.3, 0.27),
      const Offset(-0.42, 0.05),
    ],
    palette.armor.withValues(alpha: 0.82),
    strokeWidth * 0.55,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(0.34, -0.12),
      const Offset(0.12, -0.22),
      const Offset(0.08, 0.34),
      const Offset(0.3, 0.27),
      const Offset(0.42, 0.05),
    ],
    palette.armor.withValues(alpha: 0.82),
    strokeWidth * 0.55,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(0, -0.43),
      const Offset(0.25, -0.27),
      const Offset(0.2, -0.02),
      const Offset(0, 0.1),
      const Offset(-0.2, -0.02),
      const Offset(-0.25, -0.27),
    ],
    palette.armor,
    strokeWidth * 0.6,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.2, -0.17),
      const Offset(0.2, -0.17),
      const Offset(0.14, 0),
      const Offset(-0.14, 0),
    ],
    palette.body,
    strokeWidth * 0.45,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.17, -0.37),
      const Offset(0.17, -0.27),
      const Offset(0.04, -0.18),
      const Offset(-0.18, -0.23),
    ],
    palette.edge.withValues(alpha: 0.5),
    strokeWidth * 0.32,
  );
  _drawCore(
    canvas,
    scale,
    palette.accent,
    center: const Offset(0, 0.2),
    radius: 0.13,
  );
}

void _drawArmoredSide(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  _drawBody(
    canvas,
    scale,
    [
      const Offset(-0.38, -0.1),
      const Offset(-0.14, -0.35),
      const Offset(0.3, -0.28),
      const Offset(0.48, 0),
      const Offset(0.3, 0.28),
      const Offset(-0.14, 0.35),
      const Offset(-0.38, 0.1),
    ],
    palette,
    strokeWidth,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.28, -0.25),
      const Offset(0.21, -0.22),
      const Offset(0.32, -0.03),
      const Offset(0.08, 0.12),
      const Offset(-0.32, 0.04),
    ],
    palette.armor,
    strokeWidth * 0.58,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.1, -0.14),
      const Offset(0.22, -0.12),
      const Offset(0.14, 0.01),
      const Offset(-0.16, 0.01),
    ],
    palette.body,
    strokeWidth * 0.42,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.21, -0.27),
      const Offset(0.14, -0.24),
      const Offset(0.05, -0.17),
      const Offset(-0.24, -0.18),
    ],
    palette.edge.withValues(alpha: 0.48),
    strokeWidth * 0.3,
  );
  _drawCore(
    canvas,
    scale,
    palette.accent,
    center: const Offset(0.13, 0.18),
    radius: 0.12,
  );
}

void _drawArmoredBack(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  _drawBody(
    canvas,
    scale,
    [
      const Offset(0, -0.42),
      const Offset(0.33, -0.2),
      const Offset(0.47, 0.07),
      const Offset(0.31, 0.35),
      const Offset(0, 0.48),
      const Offset(-0.31, 0.35),
      const Offset(-0.47, 0.07),
      const Offset(-0.33, -0.2),
    ],
    palette,
    strokeWidth,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(0, -0.36),
      const Offset(0.29, -0.14),
      const Offset(0.2, 0.27),
      const Offset(0, 0.4),
      const Offset(-0.2, 0.27),
      const Offset(-0.29, -0.14),
    ],
    palette.armor,
    strokeWidth * 0.6,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(0, -0.18),
      const Offset(0.14, -0.03),
      const Offset(0, 0.12),
      const Offset(-0.14, -0.03),
    ],
    palette.body.withValues(alpha: 0.58),
    strokeWidth * 0.42,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.11, -0.29),
      const Offset(0.18, -0.14),
      const Offset(0.13, -0.05),
      const Offset(-0.16, -0.19),
    ],
    palette.edge.withValues(alpha: 0.46),
    strokeWidth * 0.3,
  );
}

void _drawFastFront(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0, -0.52),
      const Offset(0.11, -0.26),
      Offset.zero,
      const Offset(-0.11, -0.26),
    ],
    palette.spike,
    strokeWidth * 0.7,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(-0.38, 0.28),
      const Offset(-0.18, 0.14),
      const Offset(-0.12, 0.44),
    ],
    palette.spike,
    strokeWidth * 0.65,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0.38, 0.28),
      const Offset(0.18, 0.14),
      const Offset(0.12, 0.44),
    ],
    palette.spike,
    strokeWidth * 0.65,
  );
  _drawBody(
    canvas,
    scale,
    [
      const Offset(0, -0.43),
      const Offset(0.28, -0.22),
      const Offset(0.36, 0.16),
      const Offset(0, 0.43),
      const Offset(-0.36, 0.16),
      const Offset(-0.28, -0.22),
    ],
    palette,
    strokeWidth,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(0, -0.3),
      const Offset(0.18, -0.16),
      const Offset(0, -0.03),
      const Offset(-0.18, -0.16),
    ],
    palette.accent.withValues(alpha: 0.42),
    strokeWidth * 0.45,
  );
  _drawCore(canvas, scale, palette.accent, radius: 0.13);
}

void _drawFastBack(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0, -0.5),
      const Offset(0.1, -0.25),
      Offset.zero,
      const Offset(-0.1, -0.25),
    ],
    palette.spike,
    strokeWidth * 0.7,
  );
  _drawBody(
    canvas,
    scale,
    [
      const Offset(0, -0.43),
      const Offset(0.28, -0.22),
      const Offset(0.36, 0.16),
      const Offset(0, 0.43),
      const Offset(-0.36, 0.16),
      const Offset(-0.28, -0.22),
    ],
    palette,
    strokeWidth,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(0, -0.24),
      const Offset(0.16, -0.06),
      const Offset(0, 0.24),
      const Offset(-0.16, -0.06),
    ],
    palette.armor.withValues(alpha: 0.5),
    strokeWidth * 0.45,
  );
}

void _drawTank(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0, -0.53),
      const Offset(0.12, -0.27),
      Offset.zero,
      const Offset(-0.12, -0.27),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawBody(
    canvas,
    scale,
    [
      const Offset(0, -0.44),
      const Offset(0.38, -0.28),
      const Offset(0.52, 0),
      const Offset(0.38, 0.34),
      const Offset(0, 0.48),
      const Offset(-0.38, 0.34),
      const Offset(-0.52, 0),
      const Offset(-0.38, -0.28),
    ],
    palette,
    strokeWidth,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.39, -0.19),
      const Offset(-0.13, -0.31),
      const Offset(-0.17, 0.31),
      const Offset(-0.4, 0.2),
      const Offset(-0.5, 0),
    ],
    palette.armor,
    strokeWidth * 0.65,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(0.39, -0.19),
      const Offset(0.13, -0.31),
      const Offset(0.17, 0.31),
      const Offset(0.4, 0.2),
      const Offset(0.5, 0),
    ],
    palette.armor,
    strokeWidth * 0.65,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.17, -0.3),
      const Offset(0.17, -0.3),
      const Offset(0.27, -0.11),
      const Offset(0, 0),
      const Offset(-0.27, -0.11),
    ],
    palette.accent.withValues(alpha: 0.78),
    strokeWidth * 0.55,
  );
  _drawCore(
    canvas,
    scale,
    palette.accent,
    center: const Offset(0, 0.08),
    radius: 0.15,
  );
}

void _drawTankSide(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0.52, 0),
      const Offset(0.28, -0.12),
      const Offset(0.28, 0.12),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawBody(
    canvas,
    scale,
    [
      const Offset(-0.47, -0.22),
      const Offset(-0.18, -0.38),
      const Offset(0.31, -0.32),
      const Offset(0.51, 0),
      const Offset(0.31, 0.32),
      const Offset(-0.18, 0.38),
      const Offset(-0.47, 0.22),
    ],
    palette,
    strokeWidth,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.43, -0.18),
      const Offset(-0.13, -0.31),
      const Offset(-0.16, 0.31),
      const Offset(-0.43, 0.18),
    ],
    palette.armor,
    strokeWidth * 0.65,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(0.02, -0.33),
      const Offset(0.33, -0.22),
      const Offset(0.22, 0.05),
      const Offset(-0.1, -0.02),
    ],
    palette.accent.withValues(alpha: 0.78),
    strokeWidth * 0.55,
  );
  _drawCore(
    canvas,
    scale,
    palette.accent,
    center: const Offset(0.15, 0.03),
    radius: 0.15,
  );
}

void _drawTankBack(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  _drawTankShell(canvas, scale, palette, strokeWidth);
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.24, -0.25),
      const Offset(0.24, -0.25),
      const Offset(0.3, 0.21),
      const Offset(0, 0.36),
      const Offset(-0.3, 0.21),
    ],
    palette.armor.withValues(alpha: 0.76),
    strokeWidth * 0.6,
  );
}

void _drawBoss(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  canvas.drawCircle(
    Offset.zero,
    scale * 0.55,
    Paint()
      ..color = palette.accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.1,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0, -0.58),
      const Offset(0.13, -0.29),
      Offset.zero,
      const Offset(-0.13, -0.29),
    ],
    palette.spike,
    strokeWidth * 0.8,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(-0.57, -0.13),
      const Offset(-0.25, -0.22),
      const Offset(-0.35, -0.03),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0.57, -0.13),
      const Offset(0.25, -0.22),
      const Offset(0.35, -0.03),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(-0.37, 0.43),
      const Offset(-0.2, 0.22),
      const Offset(-0.12, 0.48),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0.37, 0.43),
      const Offset(0.2, 0.22),
      const Offset(0.12, 0.48),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );

  _drawBody(
    canvas,
    scale,
    [
      const Offset(0, -0.47),
      const Offset(0.41, -0.29),
      const Offset(0.57, 0),
      const Offset(0.41, 0.36),
      const Offset(0, 0.54),
      const Offset(-0.41, 0.36),
      const Offset(-0.57, 0),
      const Offset(-0.41, -0.29),
    ],
    palette,
    strokeWidth,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.31, -0.25),
      const Offset(-0.04, -0.38),
      const Offset(-0.09, -0.06),
      const Offset(-0.44, -0.04),
    ],
    palette.armor,
    strokeWidth * 0.55,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(0.31, -0.25),
      const Offset(0.04, -0.38),
      const Offset(0.09, -0.06),
      const Offset(0.44, -0.04),
    ],
    palette.armor,
    strokeWidth * 0.55,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.34, 0.27),
      const Offset(-0.05, 0.15),
      const Offset(0, 0.45),
      const Offset(-0.24, 0.38),
    ],
    palette.armor.withValues(alpha: 0.85),
    strokeWidth * 0.55,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(0.34, 0.27),
      const Offset(0.05, 0.15),
      const Offset(0, 0.45),
      const Offset(0.24, 0.38),
    ],
    palette.armor.withValues(alpha: 0.85),
    strokeWidth * 0.55,
  );
  _drawCore(canvas, scale, palette.accent, radius: 0.23);
}

void _drawBossSide(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  canvas.drawCircle(
    Offset.zero,
    scale * 0.55,
    Paint()
      ..color = palette.accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.1,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(-0.48, -0.34),
      const Offset(-0.66, -0.53),
      const Offset(-0.3, -0.43),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(-0.48, 0.34),
      const Offset(-0.66, 0.53),
      const Offset(-0.3, 0.43),
    ],
    palette.spike,
    strokeWidth * 0.75,
  );
  _drawShard(
    canvas,
    scale,
    [
      const Offset(0.62, 0),
      const Offset(0.34, -0.14),
      const Offset(0.34, 0.14),
    ],
    palette.spike,
    strokeWidth * 0.8,
  );
  _drawBody(
    canvas,
    scale,
    [
      const Offset(-0.52, 0),
      const Offset(-0.22, -0.45),
      const Offset(0.35, -0.35),
      const Offset(0.58, 0),
      const Offset(0.35, 0.35),
      const Offset(-0.22, 0.45),
    ],
    palette,
    strokeWidth,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.32, -0.34),
      const Offset(0.04, -0.42),
      const Offset(-0.02, -0.08),
      const Offset(-0.42, -0.05),
    ],
    palette.armor,
    strokeWidth * 0.55,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.32, 0.34),
      const Offset(0.04, 0.42),
      const Offset(-0.02, 0.08),
      const Offset(-0.42, 0.05),
    ],
    palette.armor.withValues(alpha: 0.85),
    strokeWidth * 0.55,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(0.03, -0.32),
      const Offset(0.35, -0.22),
      const Offset(0.23, 0.05),
      const Offset(-0.08, -0.03),
    ],
    palette.accent.withValues(alpha: 0.5),
    strokeWidth * 0.5,
  );
  _drawCore(
    canvas,
    scale,
    palette.accent,
    center: const Offset(0.14, 0),
    radius: 0.22,
  );
}

void _drawBossBack(
  Canvas canvas,
  double scale,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  canvas.drawCircle(
    Offset.zero,
    scale * 0.55,
    Paint()
      ..color = palette.accent.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.1,
  );
  _drawBossShell(canvas, scale, palette, strokeWidth);
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(-0.26, -0.31),
      const Offset(0.26, -0.31),
      const Offset(0.32, 0.24),
      const Offset(0, 0.44),
      const Offset(-0.32, 0.24),
    ],
    palette.armor.withValues(alpha: 0.8),
    strokeWidth * 0.55,
  );
  _drawPlate(
    canvas,
    scale,
    [
      const Offset(0, -0.18),
      const Offset(0.15, 0),
      const Offset(0, 0.18),
      const Offset(-0.15, 0),
    ],
    palette.accent.withValues(alpha: 0.24),
    strokeWidth * 0.45,
  );
}

void _drawBody(
  Canvas canvas,
  double scale,
  List<Offset> points,
  _EnemyVisualPalette palette,
  double strokeWidth,
) {
  final path = _pathFromUnitPoints(points, scale);
  canvas.drawPath(path, Paint()..color = palette.body);
  canvas.drawPath(
    path,
    Paint()
      ..color = palette.edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round,
  );
}

void _drawPlate(
  Canvas canvas,
  double scale,
  List<Offset> points,
  Color color,
  double strokeWidth,
) {
  final path = _pathFromUnitPoints(points, scale);
  canvas.drawPath(path, Paint()..color = color);
  canvas.drawPath(
    path,
    Paint()
      ..color = const Color(0xCCF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round,
  );
}

void _drawShard(
  Canvas canvas,
  double scale,
  List<Offset> points,
  Color color,
  double strokeWidth,
) {
  final path = _pathFromUnitPoints(points, scale);
  canvas.drawPath(path, Paint()..color = color);
  canvas.drawPath(
    path,
    Paint()
      ..color = const Color(0xFF6F879B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round,
  );
}

void _drawCore(
  Canvas canvas,
  double scale,
  Color color, {
  Offset center = Offset.zero,
  required double radius,
}) {
  final coreCenter = Offset(center.dx * scale, center.dy * scale);
  canvas.drawCircle(
    coreCenter,
    scale * radius,
    Paint()..color = color.withValues(alpha: 0.95),
  );
  canvas.drawCircle(
    coreCenter,
    scale * radius,
    Paint()
      ..color = const Color(0xFFF7FBFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale * 0.035,
  );
  canvas.drawCircle(
    coreCenter,
    scale * radius * 0.42,
    Paint()..color = const Color(0xEFFFFFFF),
  );
}

void _drawTrail(Canvas canvas, double scale, Offset anchor, Color color) {
  final start = Offset(anchor.dx * scale, anchor.dy * scale);
  final end = Offset((anchor.dx - 0.22) * scale, (anchor.dy * 1.25) * scale);
  canvas.drawLine(
    start,
    end,
    Paint()
      ..color = color.withValues(alpha: 0.56)
      ..strokeWidth = scale * 0.045
      ..strokeCap = StrokeCap.round,
  );
}

void _drawShadow(Canvas canvas, double scale) {
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(0, scale * 0.47),
      width: scale * 0.95,
      height: scale * 0.16,
    ),
    Paint()..color = const Color(0x55000000),
  );
}

Path _pathFromUnitPoints(List<Offset> points, double scale) {
  final path = Path()..moveTo(points.first.dx * scale, points.first.dy * scale);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx * scale, point.dy * scale);
  }
  return path..close();
}

class _EnemyVisualPalette {
  const _EnemyVisualPalette({
    required this.body,
    required this.spike,
    required this.edge,
    required this.armor,
    required this.accent,
  });

  final Color body;
  final Color spike;
  final Color edge;
  final Color armor;
  final Color accent;

  static _EnemyVisualPalette forType(EnemyType type, Color fallbackAccent) {
    return switch (type) {
      EnemyType.normal => _EnemyVisualPalette(
        body: const Color(0xFF2F4355),
        spike: const Color(0xFF1E3142),
        edge: const Color(0xFFC7D2DF),
        armor: const Color(0xFFAEB7C1),
        accent: fallbackAccent,
      ),
      EnemyType.armored => _EnemyVisualPalette(
        body: const Color(0xFF4A4F55),
        spike: const Color(0xFF30343A),
        edge: const Color(0xFFF0F2F4),
        armor: const Color(0xFFD0D3D6),
        accent: fallbackAccent,
      ),
      EnemyType.fast => _EnemyVisualPalette(
        body: const Color(0xFF123E4A),
        spike: const Color(0xFF0B2C36),
        edge: const Color(0xFF7DEBFF),
        armor: const Color(0xFF2CB7C8),
        accent: fallbackAccent,
      ),
      EnemyType.tank => _EnemyVisualPalette(
        body: const Color(0xFF4A3B27),
        spike: const Color(0xFF332A1F),
        edge: const Color(0xFFE3C982),
        armor: const Color(0xFFC0964D),
        accent: fallbackAccent,
      ),
      EnemyType.boss => _EnemyVisualPalette(
        body: const Color(0xFF4E1824),
        spike: const Color(0xFF35121C),
        edge: const Color(0xFFFF8791),
        armor: const Color(0xFFB6394B),
        accent: fallbackAccent,
      ),
    };
  }
}

enum _EnemyFacing { front, back, right, left }
