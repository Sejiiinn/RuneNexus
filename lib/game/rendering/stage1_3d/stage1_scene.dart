import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

import 'package:flutter/foundation.dart' show kIsWeb, kIsWasm;
import 'package:three_js/three_js.dart' as three;

import '../../../domain/enemy/enemy_type.dart';
import '../../../domain/map/map_definition.dart';
import '../../../domain/map/tile_type.dart';
import '../../../domain/turret/turret_type.dart';
import 'battlefield_frame.dart';
import 'battlefield_projection.dart';

part 'battlefield_weapon_effects.dart';
part 'stage1_lighting.dart';
part 'battlefield_impact_effects.dart';
part 'cannon_impact_field.dart';

enum Stage1CameraView { angled, drone }

/// 기존 전투 상태를 공유 GLB 인스턴스로 표시하는 스테이지 1 전장.
class Stage1Scene {
  Stage1Scene(this.view) {
    view.toDispose(() => _impactField?.texture.dispose());
  }

  final three.ThreeJS view;
  final _areaLightView = _Stage1AreaLightView();
  final _library = three.Group()..visible = false;
  final _terrain = three.Group();
  final _actors = three.Group();
  final _pool = three.Group()..visible = false;
  final _terrainModels = <String, three.Object3D>{};
  final _enemyModels = <EnemyType, three.Object3D>{};
  final _turretModels = <TurretType, three.Object3D>{};
  final _enemies = <int, _EnemyVisual>{};
  final _turrets = <int, _TurretVisual>{};
  final _previewModels = <TurretType, _TurretVisual>{};
  _TurretVisual? _activePreview;
  final _projectiles = <int, _ProjectileVisual>{};
  final _impacts = <int, _CannonImpactVisual>{};
  final _impactPool = <_CannonImpactVisual>[];
  _CannonImpactField? _impactField;
  final _impactLights = List.generate(
    4,
    (_) => three.PointLight(0xffb65c, 0, 3, 2),
  );
  final _enemyPool = <EnemyType, List<_EnemyVisual>>{};
  final _turretPool = <TurretType, List<_TurretVisual>>{};
  final _projectilePool = <TurretType, List<_ProjectileVisual>>{};
  final _portals = <three.Object3D>[];
  final _cores = <three.Object3D>[];
  MapDefinition? _map;
  late final three.DirectionalLight _sun;
  late final WeaponEffectTextures _weaponTextures;
  MapDefinition? _cameraMap;
  Stage1CameraView? _cameraView;
  Rect _cameraBounds = Rect.zero;
  double _cameraFit = 1;

  Future<void> load() async {
    view.scene.add(_library);
    view.scene.add(_terrain);
    view.scene.add(_actors);
    view.scene.add(_pool);
    // 광원 수를 고정해 착탄마다 셰이더 재컴파일이 발생하지 않도록 유지.
    for (final light in _impactLights) {
      view.scene.add(light);
    }
    view.scene.add(three.HemisphereLight(0xc7d9dd, 0x292d23, 0.04));
    _sun = three.DirectionalLight(0xe6f0ff, 0.45)..castShadow = true;
    _sun.position.setValues(-3, 9, 1);
    _sun.shadow!.mapSize.setValues(2048, 2048);
    _sun.shadow!.bias = -0.0005;
    _sun.shadow!.normalBias = 0.01;
    view.scene.add(_sun);
    view.scene.add(_sun.target!);
    await _loadAreaLightTextures(view);
    // 승인 원본의 위치·크기를 절반으로 변환. 면적당 방사 휘도로 환산.
    for (final source in [
      (
        position: three.Vector3(-3, 9, 1),
        size: 5.0,
        power: 575.0,
        color: three.Color(0.9, 0.94, 1.0),
      ),
      (
        position: three.Vector3(4, 6.5, -3),
        size: 4.5,
        power: 425.0,
        color: three.Color(1.0, 0.86, 0.66),
      ),
      (
        position: three.Vector3(0.5, 6, 6),
        size: 5.0,
        power: 162.5,
        color: three.Color(0.7, 0.83, 1.0),
      ),
    ]) {
      final light = three.RectAreaLight(
        0xffffff,
        source.power / (math.pi * source.size * source.size),
        source.size,
        source.size,
      );
      light.color!.setFrom(source.color);
      light.position.setFrom(source.position);
      light.lookAt(three.Vector3());
      view.scene.add(light);
    }

    _impactField = await _CannonImpactField.load();
    _weaponTextures = await WeaponEffectTextures.load();
    view.toDispose(_weaponTextures.dispose);

    // 로더별 요청 상태를 분리하고 에셋 준비를 병렬 처리.
    await Future.wait([
      _loadTerrain(),
      for (final type in const [
        EnemyType.normal,
        EnemyType.armored,
        EnemyType.shielded,
        EnemyType.fast,
        EnemyType.tank,
        EnemyType.boss,
      ])
        _loadEnemy(type),
      for (final type in TurretType.values) _loadTurret(type),
    ]);
  }

  // Mesh.clone이 재질 콜백을 복사하지 않으므로 실제 인스턴스에 조명·대비 적용.
  three.Object3D _instantiateModel(three.Object3D source) {
    final model = source.clone();
    model.traverse((part) {
      final material = part.material;
      if (material is! three.MeshStandardMaterial) return;
      material.onBeforeRender = _areaLightView.update;
      // AgX 기본 룩의 들뜬 중간 명도를 낮춰 시안의 석재 대비 유지.
      material.onBeforeCompile = (three.Parameters shader, renderer) {
        shader.fragmentShader = shader.fragmentShader.replaceFirst(
          '#include <tonemapping_fragment>',
          '''#include <tonemapping_fragment>
gl_FragColor.rgb = pow(max(gl_FragColor.rgb, vec3(0.0)), vec3(1.4));''',
        );
      };
      material.customProgramCacheKey = () => 'stage1-agx-stone-contrast-v1';
    });
    return model;
  }

  /// 원본의 낮은 하늘 반사 환경과 면광원 계산 준비. 전장 초기화 때 한 번 생성.
  void prepareEnvironment(three.AngleRenderer renderer) {
    // 첫 착탄 프레임에 대용량 텍스처 업로드가 겹치지 않도록 선행 준비.
    renderer.initTexture(_impactField!.texture);
    final environment = three.Scene()
      ..background = three.Color(0.11 * 0.33, 0.16 * 0.33, 0.18 * 0.33);
    final generator = _Stage1EnvironmentGenerator(renderer);
    // 이 패키지의 generator.dispose는 renderer도 해제하므로 전장 종료까지 유지.
    view.toDispose(generator.dispose);
    try {
      final reflection = generator.fromScene(environment);
      view.scene.environment = reflection.texture;
      view.scene.environmentIntensity = 1.0;
      view.toDispose(reflection.dispose);
    } finally {
      environment.dispose();
    }
  }

  Future<void> _loadTerrain() async {
    final data = await three.GLTFLoader().fromAsset(
      'assets/images/stage1_3d/environment/terrain.glb',
    );
    if (data == null) throw StateError('스테이지 1 지형 GLB를 읽지 못했습니다.');
    _library.add(data.scene);
    final authored = data.scene.getObjectByName('stage1_environment');
    if (authored != null) {
      authored.traverse((part) {
        part.castShadow = part is three.Mesh;
        part.receiveShadow = part is three.Mesh;
      });
      _terrainModels['stage1_environment'] = authored;
    }
    for (final name in [
      'build_tile',
      'path_tile',
      'blocked_tile',
      'portal',
      'core',
    ]) {
      final node = data.scene.getObjectByName(name);
      if (node == null) throw StateError('지형 GLB 필수 노드 누락: $name');
      node.traverse((part) {
        part.castShadow = part is three.Mesh;
        part.receiveShadow = part is three.Mesh;
      });
      _terrainModels[name] = node;
    }
  }

  Future<void> _loadEnemy(EnemyType type) async {
    final data = await three.GLTFLoader().fromAsset(
      'assets/images/stage1_3d/enemies/${type.name}.glb',
    );
    if (data == null) throw StateError('적 GLB를 읽지 못했습니다: ${type.name}');
    data.scene.traverse((part) {
      part.castShadow = part is three.Mesh;
    });
    _enemyModels[type] = data.scene;
    _library.add(data.scene);
  }

  Future<void> _loadTurret(TurretType type) async {
    final data = await three.GLTFLoader().fromAsset(
      'assets/images/stage1_3d/turrets/${type.name}.glb',
    );
    if (data == null) throw StateError('포탑 GLB를 읽지 못했습니다: ${type.name}');
    _library.add(data.scene);
    for (final name in ['turret_head', 'turret_barrel', 'muzzle']) {
      if (data.scene.getObjectByName(name) == null) {
        throw StateError('${type.name} GLB 필수 노드 누락: $name');
      }
    }
    data.scene.traverse((part) {
      part.castShadow = part is three.Mesh;
      part.receiveShadow = part is three.Mesh;
    });
    _turretModels[type] = data.scene;
  }

  BattlefieldProjection update(
    BattlefieldFrame frame,
    Size viewport, {
    Stage1CameraView cameraView = Stage1CameraView.angled,
  }) {
    if (!identical(_map, frame.map)) _buildTerrain(frame.map);
    final projection = updateCamera(frame, viewport, cameraView: cameraView);
    _updateTurrets(frame);
    _updateBuildPreview(frame);
    _updateEnemies(frame);
    _updateProjectiles(frame);
    _updateImpacts(frame);
    for (final portal in _portals) {
      final pulse =
          1 + math.sin(frame.time * 3) * (0.012 + frame.portalAlert * 0.018);
      portal.scale.setValues(pulse, 1, pulse);
    }
    for (final core in _cores) {
      final pulse =
          1 + math.sin(frame.time * 2.5) * 0.012 + frame.nexusHit * 0.025;
      core.scale.setValues(1, pulse, 1);
    }
    return projection;
  }

  void _updateImpacts(BattlefieldFrame frame) {
    final live = frame.impacts.map((impact) => impact.id).toSet();
    for (final id in _impacts.keys.toList()) {
      if (live.contains(id)) continue;
      final visual = _impacts.remove(id)!;
      _pool.add(visual.root);
      _impactPool.add(visual);
    }
    for (final impact in frame.impacts) {
      final visual = _impacts.putIfAbsent(impact.id, () {
        final created = _impactPool.isEmpty
            ? _CannonImpactVisual(_impactField!)
            : _impactPool.removeLast();
        _actors.add(created.root);
        return created;
      });
      visual.root.position.setValues(
        impact.position.dx - frame.map.columns / 2,
        0,
        impact.position.dy - frame.map.rows / 2,
      );
      visual.update(impact, view.camera);
    }
    for (final light in _impactLights) {
      light.intensity = 0;
    }
    var index = 0;
    // 가장 최근 섬광 네 개까지 지형·적·포탑에 실제 빛 반응.
    for (final impact in frame.impacts.reversed) {
      if (impact.progress >= 0.68 || index == _impactLights.length) continue;
      final light = _impactLights[index++];
      light.position.setValues(
        impact.position.dx - frame.map.columns / 2,
        0.3 + impact.radius * 0.12,
        impact.position.dy - frame.map.rows / 2,
      );
      light.distance = impact.radius * 3.2;
      light.intensity = 1.6 * math.pow(1 - impact.progress / 0.68, 2);
    }
  }

  /// 실제 렌더 카메라와 터치·HUD 투영을 함께 갱신.
  BattlefieldProjection updateCamera(
    BattlefieldFrame frame,
    Size viewport, {
    Stage1CameraView cameraView = Stage1CameraView.angled,
  }) {
    final camera = view.camera;
    switch (cameraView) {
      case Stage1CameraView.angled:
        camera.position.setValues(5, 27, 13);
        camera.up.setValues(0, 1, 0);
      case Stage1CameraView.drone:
        camera.position.setValues(0, 30, 0.001);
        // 정수직 시점에서도 행 증가 방향은 화면 아래로 유지.
        camera.up.setValues(0, 0, -1);
    }
    camera.lookAt(three.Vector3());
    camera.updateMatrixWorld(true);
    if (!identical(_cameraMap, frame.map) || _cameraView != cameraView) {
      _cameraMap = frame.map;
      _cameraView = cameraView;
      var left = double.infinity, right = double.negativeInfinity;
      var bottom = double.infinity, top = double.negativeInfinity;
      var minColumn = frame.map.columns, maxColumn = 0;
      var minRow = frame.map.rows, maxRow = 0;
      for (var row = 0; row < frame.map.rows; row++) {
        for (var col = 0; col < frame.map.columns; col++) {
          if (frame.map.tiles[row][col] == TileType.blocked) continue;
          minColumn = math.min(minColumn, col);
          maxColumn = math.max(maxColumn, col + 1);
          minRow = math.min(minRow, row);
          maxRow = math.max(maxRow, row + 1);
          for (final corner in const [
            Offset.zero,
            Offset(1, 0),
            Offset(0, 1),
            Offset(1, 1),
          ]) {
            final point = three.Vector3(
              col + corner.dx - frame.map.columns / 2,
              0,
              row + corner.dy - frame.map.rows / 2,
            )..applyMatrix4(camera.matrixWorldInverse);
            left = math.min(left, point.x);
            right = math.max(right, point.x);
            bottom = math.min(bottom, point.y);
            top = math.max(top, point.y);
          }
        }
      }
      _cameraBounds = left.isFinite
          ? Rect.fromLTRB(left, bottom, right, top)
          : const Rect.fromLTWH(-0.5, -0.5, 1, 1);
      // 기울어진 전장의 실제 사용 칸 경계로 기존 HUD 가용 폭·높이 보존.
      _cameraFit = math
          .min(
            (maxColumn - minColumn) / _cameraBounds.width,
            (maxRow - minRow) / _cameraBounds.height,
          )
          .clamp(0.1, 1.0);
    }
    final ppu = math.max(1.0, frame.pixelsPerTile * frame.zoom * _cameraFit);
    final halfWidth = viewport.width / (2 * ppu);
    final halfHeight = viewport.height / (2 * ppu);
    final centerX =
        _cameraBounds.center.dx +
        (viewport.width / 2 - frame.screenCenter.dx) / ppu;
    final centerY =
        _cameraBounds.center.dy +
        (frame.screenCenter.dy - viewport.height / 2) / ppu;
    camera.left = centerX - halfWidth;
    camera.right = centerX + halfWidth;
    camera.top = centerY + halfHeight;
    camera.bottom = centerY - halfHeight;
    camera.near = 0.1;
    camera.far = 100;
    camera.updateProjectionMatrix();
    camera.updateMatrixWorld(true);

    final origin = _project(0, 0, 0, frame.map, viewport);
    return BattlefieldProjection(
      origin: origin,
      xAxis: _project(1, 0, 0, frame.map, viewport) - origin,
      yAxis: _project(0, 1, 0, frame.map, viewport) - origin,
      heightAxis: _project(0, 0, 1, frame.map, viewport) - origin,
    );
  }

  Offset _project(
    double x,
    double z,
    double height,
    MapDefinition map,
    Size size,
  ) {
    final point = three.Vector3(x - map.columns / 2, height, z - map.rows / 2)
      ..project(view.camera);
    return Offset(
      (point.x + 1) * size.width / 2,
      (1 - point.y) * size.height / 2,
    );
  }

  void _buildTerrain(MapDefinition map) {
    // 공유 재질 해제를 막기 위해 이전 지형을 분리 보관, 최종 scene에서 정리.
    for (final tile in _terrain.children.toList()) {
      _pool.add(tile);
    }
    _portals.clear();
    _cores.clear();
    _map = map;
    final authored = _terrainModels['stage1_environment'];
    final authoredTiles = authored?.userData['tileTypes'];
    final useAuthored =
        authored != null &&
        authored.userData['columns'] == map.columns &&
        authored.userData['rows'] == map.rows &&
        authoredTiles is List &&
        authoredTiles.length == map.columns * map.rows &&
        map.tiles
            .expand((row) => row)
            .indexed
            .every((entry) => authoredTiles[entry.$1] == entry.$2.name);
    if (useAuthored) _terrain.add(_instantiateModel(authored));
    for (var y = 0; y < map.rows; y++) {
      for (var x = 0; x < map.columns; x++) {
        final type = map.tiles[y][x];
        if (type == TileType.blocked) continue;
        if (useAuthored && type != TileType.spawn && type != TileType.core) {
          continue;
        }
        final name = switch (type) {
          TileType.path => 'path_tile',
          TileType.build => 'build_tile',
          TileType.blocked => 'blocked_tile',
          TileType.spawn => 'portal',
          TileType.core => 'core',
        };
        // 포털·코어는 독립 모델이며 지면 상단 Y=0인 길 타일 위에 배치.
        if (!useAuthored && (type == TileType.spawn || type == TileType.core)) {
          final foundation = _instantiateModel(_terrainModels['path_tile']!);
          foundation.position.setValues(
            x + 0.5 - map.columns / 2,
            0,
            y + 0.5 - map.rows / 2,
          );
          _terrain.add(foundation);
        }
        final tile = _instantiateModel(_terrainModels[name]!);
        tile.position.setValues(
          x + 0.5 - map.columns / 2,
          0,
          y + 0.5 - map.rows / 2,
        );
        _terrain.add(tile);
        if (type == TileType.spawn) _portals.add(tile);
        if (type == TileType.core) _cores.add(tile);
      }
    }
    final extent = math.max(map.columns, map.rows) / 2 + 2;
    final shadowCamera = _sun.shadow!.camera!;
    shadowCamera.left = -extent;
    shadowCamera.right = extent;
    shadowCamera.top = extent;
    shadowCamera.bottom = -extent;
    shadowCamera.near = 1;
    shadowCamera.far = 50;
    shadowCamera.updateProjectionMatrix();
  }

  void _updateTurrets(BattlefieldFrame frame) {
    final live = frame.turrets.map((unit) => unit.id).toSet();
    for (final id in _turrets.keys.toList()) {
      if (live.contains(id)) continue;
      final visual = _turrets.remove(id)!;
      visual.resetFire();
      _pool.add(visual.root);
      (_turretPool[visual.type] ??= []).add(visual);
    }
    for (final unit in frame.turrets) {
      final visual = _turrets.putIfAbsent(unit.id, () {
        final available = _turretPool[unit.type];
        final visual = available != null && available.isNotEmpty
            ? available.removeLast()
            : _TurretVisual(
                unit.type,
                _instantiateModel(_turretModels[unit.type]!),
                _weaponTextures,
              );
        _actors.add(visual.root);
        return visual;
      });
      visual.root.position.setValues(
        unit.position.dx - frame.map.columns / 2,
        0,
        unit.position.dy - frame.map.rows / 2,
      );
      // +Z 전방 모델을 게임의 +X 기준 시계 방향 조준각으로 변환.
      visual.head.rotation.y = math.pi / 2 - unit.aimAngle;
      visual.updateFire(
        shotSequence: unit.shotSequence,
        time: frame.time,
        feedback: unit.fireFeedback,
        camera: view.camera,
      );
    }
  }

  void _updateBuildPreview(BattlefieldFrame frame) {
    final unit = frame.buildPreview;
    final previous = _activePreview;
    if (previous != null && (unit == null || previous.type != unit.type)) {
      _pool.add(previous.root);
      _activePreview = null;
    }
    if (unit == null) return;
    final visual = _activePreview ??= _previewModels.putIfAbsent(unit.type, () {
      final visual = _TurretVisual(
        unit.type,
        _instantiateModel(_turretModels[unit.type]!),
        _weaponTextures,
      );
      // 공유 재질을 보존하고 부유·사거리 표시로 건설 미리보기 구분.
      visual.root.traverse((part) {
        part.castShadow = false;
      });
      return visual;
    });
    if (visual.root.parent != _actors) _actors.add(visual.root);
    visual.root.position.setValues(
      unit.position.dx - frame.map.columns / 2,
      0.10 + math.sin(frame.time * 3) * 0.02,
      unit.position.dy - frame.map.rows / 2,
    );
    visual.head.rotation.y = math.pi / 2 - unit.aimAngle;
    visual.barrel.position.z = visual.barrelRestZ;
    visual.resetFire();
  }

  void _updateEnemies(BattlefieldFrame frame) {
    final live = frame.enemies.map((unit) => unit.id).toSet();
    for (final id in _enemies.keys.toList()) {
      if (live.contains(id)) continue;
      final visual = _enemies.remove(id)!;
      _pool.add(visual.root);
      (_enemyPool[visual.type] ??= []).add(visual);
    }
    for (final unit in frame.enemies) {
      if (!_enemyModels.containsKey(unit.type)) {
        throw StateError('스테이지 1에서 지원하지 않는 적: ${unit.type.name}');
      }
      final visual = _enemies.putIfAbsent(unit.id, () {
        final available = _enemyPool[unit.type];
        final visual = available != null && available.isNotEmpty
            ? available.removeLast()
            : _EnemyVisual(
                unit.type,
                _instantiateModel(_enemyModels[unit.type]!),
              );
        _actors.add(visual.root);
        return visual;
      });
      final hover = switch (unit.type) {
        EnemyType.normal || EnemyType.fast || EnemyType.shielded => 0.025,
        _ => 0.008,
      };
      visual.root.position.setValues(
        unit.position.dx - frame.map.columns / 2,
        math.sin(unit.phase) * hover,
        unit.position.dy - frame.map.rows / 2,
      );
      visual.root.rotation.y = math.pi / 2 - unit.facingAngle;
      visual.root.scale.setScalar(unit.scale);
      visual.burn.visible = unit.burning;
      visual.slow.visible = unit.slowed;
      visual.poison.visible = unit.poisoned;
      visual.hit.visible = unit.hitFlash > 0;
      visual.diamond.visible = unit.diamondCarrier;
      visual.diamond.rotation.y = frame.time * 1.8;
      visual.hit.scale.setScalar(1 + unit.hitFlash * 0.15);
    }
  }

  void _updateProjectiles(BattlefieldFrame frame) {
    final live = frame.projectiles.map((unit) => unit.id).toSet();
    for (final id in _projectiles.keys.toList()) {
      if (live.contains(id)) continue;
      final visual = _projectiles.remove(id)!;
      visual.reset();
      _pool.add(visual.mesh);
      (_projectilePool[visual.type] ??= []).add(visual);
    }
    for (final unit in frame.projectiles) {
      final visual = _projectiles.putIfAbsent(unit.id, () {
        final available = _projectilePool[unit.type];
        final visual = available != null && available.isNotEmpty
            ? available.removeLast()
            : _ProjectileVisual(unit.type);
        _actors.add(visual.mesh);
        return visual;
      });
      visual.update(unit, frame.map, time: frame.time);
    }
  }
}

class _EnemyVisual {
  _EnemyVisual(this.type, this.root) {
    burn = _statusRing(0xff873d, 0.29, 0.035);
    slow = _statusRing(0x83ddff, 0.34, 0.04);
    poison = _statusRing(0x9ee25b, 0.39, 0.045);
    hit = _statusRing(0xfff1cb, 0.44, 0.05);
    diamond = three.Mesh(
      three.OctahedronGeometry(0.10),
      three.MeshBasicMaterial.fromMap({'color': 0x8effed}),
    );
    diamond.position.y = 0.8;
    root.add(diamond);
  }
  final EnemyType type;
  final three.Object3D root;
  late final three.Mesh burn, slow, poison, hit, diamond;

  three.Mesh _statusRing(int color, double radius, double height) {
    final ring = three.Mesh(
      three.RingGeometry(radius, radius + 0.025, 24),
      three.MeshBasicMaterial.fromMap({
        'color': color,
        'transparent': true,
        'opacity': 0.85,
        'depthWrite': false,
        'side': three.DoubleSide,
      }),
    );
    ring.rotation.x = -math.pi / 2;
    ring.position.y = height;
    root.add(ring);
    return ring;
  }
}

/// 패키지 0.0.1의 유한수 판정 오류 보정: 거칠기별 반사 필터의 표본 간격 유지.
class _Stage1EnvironmentGenerator extends three.PMREMGenerator {
  _Stage1EnvironmentGenerator(super.renderer);

  @override
  bool isFinite(double value) => value.isFinite;
}

int _projectileColor(TurretType type) => switch (type) {
  TurretType.arrow => 0xffe3a3,
  TurretType.cannon => 0xffb261,
  TurretType.magic => 0xd59bff,
  TurretType.frost => 0x94e6ff,
  TurretType.sniper => 0xffeec4,
  TurretType.lightning => 0xc7d8ff,
};
