import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:rune_nexus/domain/map/map_definition.dart';
import 'package:rune_nexus/domain/map/tile_type.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_frame.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/stage1_scene.dart';

void main() {
  late three.ThreeJS view;
  late Stage1Scene scene;
  // ThreeJS 행렬의 Float32 연산 오차: 화면 좌표 0.005px 이내.
  final map = MapDefinition(
    columns: 8,
    rows: 12,
    tiles: List.generate(12, (_) => List.filled(8, TileType.build)),
    path: const [],
  );
  BattlefieldFrame frame({
    Offset center = const Offset(320, 240),
    double zoom = 1,
  }) => BattlefieldFrame(
    map: map,
    turrets: const [],
    enemies: const [],
    projectiles: const [],
    time: 0,
    pixelsPerTile: 60,
    zoom: zoom,
    screenCenter: center,
    nexusHpRatio: 1,
    nexusHit: 0,
    portalAlert: 0,
  );

  setUp(() {
    view = three.ThreeJS(setup: () {}, onSetupComplete: () {});
    view.scene = three.Scene();
    view.camera = three.OrthographicCamera(-1, 1, 1, -1, 0.1, 100);
    scene = Stage1Scene(view);
  });
  tearDown(() {
    // 플랫폼 뷰 초기화 없이 생성한 순수 3D 수학 객체만 해제.
    view.camera.dispose();
    view.scene.dispose();
  });

  test('격자 중심은 화면 중심에 놓이고 실제 카메라의 X/Z 방향과 일치한다', () {
    final projection = scene.updateCamera(frame(), const Size(640, 480));
    expect(projection.gridToScreen(const Offset(4, 6)).dx, closeTo(320, 0.005));
    expect(projection.gridToScreen(const Offset(4, 6)).dy, closeTo(240, 0.005));
    expect(projection.xAxis.dx, greaterThan(0));
    expect(projection.xAxis.dy, greaterThan(0));
    expect(projection.yAxis.dx, lessThan(0));
    expect(projection.yAxis.dy, greaterThan(0));
    expect(projection.heightAxis.dy, lessThan(0));
    final corners = [
      Offset.zero,
      const Offset(8, 0),
      const Offset(0, 12),
      const Offset(8, 12),
    ].map(projection.gridToScreen).toList();
    final minX = corners.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    final maxX = corners.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    expect(maxX - minX, lessThanOrEqualTo(8 * 60 + 0.005));
  });

  for (final cameraView in Stage1CameraView.values) {
    test('$cameraView 이동·확대·뷰포트 변경 후 실제 카메라와 입력 역변환이 일치한다', () {
      for (final size in [const Size(640, 480), const Size(1080, 720)]) {
        for (final zoom in [0.65, 1.0, 2.2]) {
          final projection = scene.updateCamera(
            frame(center: const Offset(271, 193), zoom: zoom),
            size,
            cameraView: cameraView,
          );
          for (final grid in [
            Offset.zero,
            const Offset(1.5, 9.5),
            const Offset(8, 12),
          ]) {
            final world = three.Vector3(grid.dx - 4, 0, grid.dy - 6)
              ..project(view.camera);
            final actual = Offset(
              (world.x + 1) * size.width / 2,
              (1 - world.y) * size.height / 2,
            );
            final projected = projection.gridToScreen(grid);
            expect((actual - projected).distance, lessThan(0.005));
            expect(
              (projection.screenToGrid(actual)! - grid).distance,
              lessThan(0.005),
            );
          }
        }
      }
    });
  }

  test('같은 맵의 드론 전환과 기본 시점 복귀에서 경계·맞춤 배율을 갱신한다', () {
    const size = Size(640, 480);
    final angled = scene.updateCamera(frame(), size);
    final drone = scene.updateCamera(
      frame(),
      size,
      cameraView: Stage1CameraView.drone,
    );
    expect(drone.xAxis.dx, closeTo(60, 0.005));
    expect(drone.xAxis.dy, closeTo(0, 0.005));
    expect(drone.yAxis.dx, closeTo(0, 0.005));
    expect(drone.yAxis.dy, closeTo(60, 0.005));
    expect(drone.gridToScreen(const Offset(4, 6)).dx, closeTo(320, 0.005));
    expect(drone.gridToScreen(const Offset(4, 6)).dy, closeTo(240, 0.005));
    expect(drone.heightAxis.distance, lessThan(0.005));
    expect((drone.xAxis - angled.xAxis).distance, greaterThan(1));

    final restored = scene.updateCamera(frame(), size);
    for (final grid in [Offset.zero, const Offset(8, 12)]) {
      expect(
        (restored.gridToScreen(grid) - angled.gridToScreen(grid)).distance,
        lessThan(0.005),
      );
    }
  });
}
