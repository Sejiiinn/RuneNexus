import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:rune_nexus/domain/map/map_definition.dart';
import 'package:rune_nexus/data/definitions/game_stage_maps.dart';
import 'package:rune_nexus/domain/map/tile_type.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_frame.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/stage1_scene.dart';

void main() {
  testWidgets('실제 GLB의 발사 시퀀스·교대 포구·반동·풀 복귀와 탄환 위치를 보존한다', (tester) async {
    final view = three.ThreeJS(setup: () {}, onSetupComplete: () {});
    view.scene = three.Scene();
    view.camera = three.OrthographicCamera(-5, 5, 5, -5, 0.1, 100);
    final scene = Stage1Scene(view);
    final map = MapDefinition(
      columns: 4,
      rows: 4,
      tiles: List.generate(4, (_) => List.filled(4, TileType.build)),
      path: const [],
    );
    final viewport = const Size(640, 480);
    BattlefieldFrame frame(
      double time, {
      MapDefinition? terrainMap,
      TurretType type = TurretType.arrow,
      int sequence = 0,
      int id = 7,
      bool present = true,
      List<BattlefieldProjectile> projectiles = const [],
      List<BattlefieldImpact> impacts = const [],
    }) => BattlefieldFrame(
      map: terrainMap ?? map,
      turrets: present
          ? [
              BattlefieldTurret(
                id: id,
                type: type,
                position: const Offset(1.5, 1.5),
                aimAngle: 0,
                fireFeedback: sequence > 0 ? 1 : 0,
                shotSequence: sequence,
                level: 1,
              ),
            ]
          : [],
      enemies: const [],
      projectiles: projectiles,
      impacts: impacts,
      time: time,
      pixelsPerTile: 60,
      zoom: 1,
      screenCenter: const Offset(320, 240),
      nexusHpRatio: 1,
      nexusHit: 0,
      portalAlert: 0,
    );
    three.Object3D visibleNamed(String name) {
      three.Object3D? result;
      view.scene.traverseVisible((node) {
        if (node?.name == name) result = node;
      });
      return result!;
    }

    await tester.runAsync(() async {
      await scene.load();
    });
    scene.update(frame(0), viewport);
    var turret = visibleNamed('turret_root');
    final firstFlash = turret.getObjectByName('weapon_muzzle_flash_0')!;
    final secondFlash = turret.getObjectByName('weapon_muzzle_flash_1')!;
    expect(firstFlash.visible || secondFlash.visible, isFalse);
    scene.update(frame(0.01, sequence: 1), viewport);
    expect(firstFlash.visible, isFalse);
    expect(secondFlash.visible, isTrue);
    expect(secondFlash.position.x, closeTo(0.062, 1e-6));
    scene.update(frame(0.03, sequence: 1), viewport);
    expect(
      turret.getObjectByName('turret_barrel')!.position.z,
      lessThan(-0.015),
    );
    scene.update(frame(0.14, sequence: 1), viewport);
    expect(firstFlash.visible || secondFlash.visible, isFalse);
    scene.update(frame(0.15, sequence: 2), viewport);
    expect(firstFlash.visible, isTrue);
    expect(secondFlash.visible, isFalse);
    expect(firstFlash.position.x, closeTo(-0.062, 1e-6));

    scene.update(frame(0.2, present: false), viewport);
    scene.update(frame(0.21, id: 8), viewport);
    turret = visibleNamed('turret_root');
    expect(turret.getObjectByName('weapon_muzzle_flash_0')!.visible, isFalse);
    expect(turret.getObjectByName('weapon_muzzle_flash_1')!.visible, isFalse);

    scene.update(frame(1, type: TurretType.cannon, id: 9), viewport);
    scene.update(
      frame(1.01, type: TurretType.cannon, id: 9, sequence: 1),
      viewport,
    );
    scene.update(
      frame(1.045, type: TurretType.cannon, id: 9, sequence: 1),
      viewport,
    );
    turret = visibleNamed('turret_root');
    expect(
      turret.getObjectByName('turret_barrel')!.position.z,
      lessThan(-0.07),
    );
    scene.update(
      frame(
        1.4,
        type: TurretType.cannon,
        id: 9,
        sequence: 1,
        projectiles: const [
          BattlefieldProjectile(
            id: 71,
            type: TurretType.cannon,
            position: Offset(2.75, 1.25),
            direction: Offset(1, 0),
          ),
        ],
      ),
      viewport,
    );
    expect(
      turret.getObjectByName('turret_barrel')!.position.z,
      closeTo(0, 1e-6),
    );
    final projectile = visibleNamed('weapon_projectile_cannon');
    expect(projectile.position.x, closeTo(0.75, 1e-6));
    expect(projectile.position.z, closeTo(-0.75, 1e-6));
    expect(
      projectile.children.any((part) => part.geometry is three.SphereGeometry),
      isFalse,
    );
    // 1200초 표시 시간 순환은 동일 발사 시퀀스를 새 발사로 취급하지 않음.
    scene.update(
      frame(1199, type: TurretType.cannon, id: 9, sequence: 2),
      viewport,
    );
    scene.update(
      frame(0, type: TurretType.cannon, id: 9, sequence: 2),
      viewport,
    );
    turret = visibleNamed('turret_root');
    expect(turret.getObjectByName('weapon_muzzle_flash_0')!.visible, isFalse);
    expect(turret.getObjectByName('weapon_muzzle_flash_1')!.visible, isFalse);
    expect(turret.getObjectByName('weapon_smoke_0')!.visible, isFalse);
    expect(turret.getObjectByName('weapon_smoke_1')!.visible, isFalse);

    scene.update(
      frame(
        1,
        present: false,
        impacts: const [
          BattlefieldImpact(
            id: 81,
            position: Offset(2.5, 1.5),
            radius: 0.8,
            progress: 0,
          ),
        ],
      ),
      viewport,
    );
    final impact = visibleNamed('cannon_impact');
    expect(impact.position.x, closeTo(0.5, 1e-6));
    expect(impact.position.z, closeTo(-0.5, 1e-6));
    final impactBody = visibleNamed('cannon_impact_volume');
    expect(impactBody.material, isA<three.ShaderMaterial>());
    expect(impactBody.material!.map, isNull);
    var hasImpactSprite = false;
    impact.traverse((node) {
      if (node is three.Sprite) hasImpactSprite = true;
    });
    expect(hasImpactSprite, isFalse);
    expect(
      impact.getObjectByName('cannon_impact_sparks'),
      isA<three.InstancedMesh>(),
    );
    expect(
      impact.getObjectByName('cannon_impact_fragments'),
      isA<three.InstancedMesh>(),
    );
    final initialImpactHeight = impactBody.scale.y;
    final impactLights = view.scene.children.whereType<three.PointLight>();
    expect(impactLights.where((light) => light.intensity > 0), hasLength(1));
    scene.update(
      frame(
        1.55,
        present: false,
        impacts: const [
          BattlefieldImpact(
            id: 81,
            position: Offset(2.5, 1.5),
            radius: 0.8,
            progress: 0.5,
          ),
        ],
      ),
      viewport,
    );
    // 고정 적분 경계 안에서 먼지가 팽창하고 화염 이후에도 남음.
    expect(impactBody.visible, isTrue);
    expect(impactBody.scale.y, closeTo(initialImpactHeight, 1e-6));
    expect(impactBody.material!.uniforms['uAge']['value'], closeTo(.55, 1e-6));
    // .55초 keyframe(20번)은 이전 표본과 섞인 중간 시간이 아니라 정확한 끝점.
    expect(
      impactBody.material!.uniforms['uFieldMix']['value'],
      closeTo(1, 1e-6),
    );
    final keyframe =
        impactBody.material!.uniforms['uFieldFrame1']['value'] as three.Vector3;
    expect(keyframe.x, closeTo(.5 / 192, 1e-6));
    expect(keyframe.y, closeTo(48.5 / 192, 1e-6));
    expect(keyframe.z, closeTo(48.5 / 96, 1e-6));
    expect(impactLights.where((light) => light.intensity > 0), hasLength(1));
    scene.update(
      frame(
        1.3,
        present: false,
        impacts: const [
          BattlefieldImpact(
            id: 81,
            position: Offset(2.5, 1.5),
            radius: 0.8,
            progress: 0.8,
          ),
        ],
      ),
      viewport,
    );
    expect(impactLights.every((light) => light.intensity == 0), isTrue);
    expect(impactBody.visible, isTrue);
    final originalRay =
        (impactBody.material!.uniforms['uRayDirection']['value']
                as three.Vector3)
            .clone();
    final cameraFrame = frame(
      1.3,
      present: false,
      impacts: const [
        BattlefieldImpact(
          id: 81,
          position: Offset(2.5, 1.5),
          radius: .8,
          progress: .8,
        ),
      ],
    );
    scene.update(cameraFrame, viewport, cameraView: Stage1CameraView.drone);
    final droneRay =
        impactBody.material!.uniforms['uRayDirection']['value']
            as three.Vector3;
    expect(droneRay.y, closeTo(-1, .001));
    expect(originalRay.distanceTo(droneRay), greaterThan(.1));
    expect(impactBody.material!.uniforms['uOrthographic']['value'], 1.0);
    scene.update(frame(1.5, present: false), viewport);
    scene.update(
      frame(
        2,
        present: false,
        impacts: const [
          BattlefieldImpact(
            id: 82,
            position: Offset(1.5, 2.5),
            radius: 1.1,
            progress: 0,
          ),
        ],
      ),
      viewport,
    );
    // 연속 착탄은 풀을 재사용하되 이전 크기·소멸 상태·좌표를 남기지 않음.
    expect(visibleNamed('cannon_impact'), same(impact));
    expect(impact.position.x, closeTo(-0.5, 1e-6));
    expect(impactBody.visible, isTrue);
    expect(impactBody.scale.y, closeTo(initialImpactHeight * 1.1 / 0.8, 1e-6));

    // 동시 착탄과 풀 재사용은 전장 단위의 시간별 체적 아틀라스 하나를 공유.
    final field =
        impactBody.material!.uniforms['uField']['value'] as three.Data3DTexture;
    expect(field.image.width, 192);
    expect(field.image.height, 192);
    expect(field.image.depth, 96);
    // 풀에서 되돌아온 새 폭발은 첫 시간 표본으로 시작.
    expect(impactBody.material!.uniforms['uFieldMix']['value'], 0);
    final firstOffset =
        impactBody.material!.uniforms['uFieldFrame0']['value'] as three.Vector3;
    expect(firstOffset.x, closeTo(.5 / 192, 1e-6));
    expect(firstOffset.y, closeTo(.5 / 192, 1e-6));
    expect(firstOffset.z, closeTo(.5 / 96, 1e-6));
    scene.update(
      frame(
        2.1,
        present: false,
        impacts: const [
          BattlefieldImpact(
            id: 82,
            position: Offset(1.5, 2.5),
            radius: 1.1,
            progress: .1,
          ),
          BattlefieldImpact(
            id: 83,
            position: Offset(2.5, 2.5),
            radius: .8,
            progress: .1,
          ),
        ],
      ),
      viewport,
    );
    var volumeCount = 0;
    view.scene.traverse((node) {
      if (node is three.Mesh && node.name == 'cannon_impact_volume') {
        volumeCount++;
        expect(node.material!.uniforms['uField']['value'], same(field));
      }
    });
    expect(volumeCount, 2);

    // 원본 전장은 실제 타일 배열이 일치할 때만 사용하고 다른 맵은 타일로 구성.
    scene.update(frame(2, terrainMap: gameMap, present: false), viewport);
    final environment = visibleNamed('stage1_environment');
    expect(
      environment.userData['tileTypes'],
      gameMap.tiles.expand((row) => row).map((tile) => tile.name).toList(),
    );
    expect(environment.children.length, 7);
    // 복제된 실제 재질에서도 면광원 방향·색 대비 처리가 유지되어야 함.
    for (final mesh in environment.children.whereType<three.Mesh>()) {
      expect(mesh.material!.onBeforeRender, isNotNull);
      expect(mesh.material!.onBeforeCompile, isNotNull);
    }
    expect(visibleNamed('portal'), isNotNull);
    expect(visibleNamed('core'), isNotNull);
    scene.update(frame(3, present: false), viewport);
    var authoredVisible = false;
    view.scene.traverseVisible((node) {
      if (node?.name == 'stage1_environment') authoredVisible = true;
    });
    expect(authoredVisible, isFalse);

    // 공유 텍스처를 가진 인스턴스·풀·원본을 포함한 종료 경로.
    view.angle = null;
    expect(view.dispose, returnsNormally);
  });
}
