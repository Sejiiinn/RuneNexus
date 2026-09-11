import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// 고정 직교 카메라의 지면 투영. 같은 행렬로 입력·효과 위치를 역변환.
class BattlefieldProjection {
  const BattlefieldProjection({
    required this.origin,
    required this.xAxis,
    required this.yAxis,
    required this.heightAxis,
  });

  final Offset origin;
  final Offset xAxis;
  final Offset yAxis;
  final Offset heightAxis;

  Offset gridToScreen(Offset point, {double height = 0}) =>
      origin + xAxis * point.dx + yAxis * point.dy + heightAxis * height;

  Offset? screenToGrid(Offset point) {
    final determinant = xAxis.dx * yAxis.dy - xAxis.dy * yAxis.dx;
    if (!determinant.isFinite || determinant.abs() < 0.000001) return null;
    final relative = point - origin;
    return Offset(
      (relative.dx * yAxis.dy - relative.dy * yAxis.dx) / determinant,
      (xAxis.dx * relative.dy - xAxis.dy * relative.dx) / determinant,
    );
  }

  double get pixelsPerTile => math.sqrt(xAxis.distance * yAxis.distance);

  void applyWorldTransform(Canvas canvas, Offset worldOrigin, double tileSize) {
    final x = xAxis / tileSize;
    final y = yAxis / tileSize;
    final translation = origin - x * worldOrigin.dx - y * worldOrigin.dy;
    canvas.transform(
      Float64List.fromList([
        x.dx,
        x.dy,
        0,
        0,
        y.dx,
        y.dy,
        0,
        0,
        0,
        0,
        1,
        0,
        translation.dx,
        translation.dy,
        0,
        1,
      ]),
    );
  }
}
