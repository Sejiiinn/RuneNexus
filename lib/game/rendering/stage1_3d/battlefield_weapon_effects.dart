part of 'stage1_scene.dart';

/// 공유 이미지 원본. 인스턴스별 UV와 불투명도는 각 Sprite에서 관리.
class WeaponEffectTextures {
  WeaponEffectTextures(this.muzzleFlash, this.gunSmoke);

  final three.Texture muzzleFlash;
  final three.Texture gunSmoke;

  static Future<WeaponEffectTextures> load() async {
    // JS 이미지 로더는 rootBundle을 거치지 않아 Flutter 웹 에셋 루트가 필요.
    final assetRoot = kIsWeb && !kIsWasm ? 'assets/' : '';
    // 네이티브는 픽셀 반전, 웹은 업로드 반전으로 같은 좌하단 UV 기준 유지.
    final maps = await Future.wait([
      three.TextureLoader(flipY: true).fromAsset(
        '${assetRoot}assets/images/stage1_3d/effects/muzzle_flash.png',
      ),
      three.TextureLoader(
        flipY: true,
      ).fromAsset('${assetRoot}assets/images/stage1_3d/effects/gun_smoke.png'),
    ]);
    if (maps.any((map) => map == null)) {
      for (final map in maps) {
        map?.dispose();
      }
      throw StateError('포구·연기 에셋을 읽지 못했습니다.');
    }
    for (final map in maps) {
      map!.colorSpace = three.SRGBColorSpace;
      map.generateMipmaps = false;
      map.minFilter = three.LinearFilter;
      map.magFilter = three.LinearFilter;
    }
    return WeaponEffectTextures(maps[0]!, maps[1]!);
  }

  void dispose() {
    muzzleFlash.dispose();
    gunSmoke.dispose();
  }
}

class _TurretVisual {
  _TurretVisual(this.type, this.root, WeaponEffectTextures textures) {
    head = root.getObjectByName('turret_head')!;
    barrel = root.getObjectByName('turret_barrel')!;
    muzzle = root.getObjectByName('muzzle')!;
    barrelRestZ = barrel.position.z;
    for (var index = 0; index < 2; index++) {
      final flash = _WeaponAtlasSprite(textures.muzzleFlash, additive: true);
      flash.sprite.name = 'weapon_muzzle_flash_$index';
      flash.sprite.center.setValues(0.28, 0.5);
      flash.sprite.position.x = type == TurretType.arrow
          ? (index == 0 ? -0.062 : 0.062)
          : 0;
      flash.sprite.position.z = 0.018;
      muzzle.add(flash.sprite);
      _flashes.add(flash);
      final smoke = _WeaponAtlasSprite(textures.gunSmoke);
      if (type == TurretType.arrow) {
        // 밝은 석재 길에서도 구분되는 서늘한 회색 화약 연기.
        smoke.material.color.setFromHex32(0x697586);
      }
      smoke.sprite.name = 'weapon_smoke_$index';
      smoke.sprite.position.x = flash.sprite.position.x;
      muzzle.add(smoke.sprite);
      _smokes.add(smoke);
    }
    resetFire();
  }

  final TurretType type;
  final three.Object3D root;
  late final three.Object3D head;
  late final three.Object3D barrel;
  late final three.Object3D muzzle;
  late final double barrelRestZ;
  final _flashes = <_WeaponAtlasSprite>[];
  final _smokes = <_WeaponAtlasSprite>[];
  final _smokeStarts = <double>[
    double.negativeInfinity,
    double.negativeInfinity,
  ];
  int? _lastShotSequence;
  double? _lastTime;
  int _activePort = 0;
  double _fireStart = double.negativeInfinity;
  final _worldMuzzle = three.Vector3();
  final _worldForward = three.Vector3();

  void resetFire() {
    _lastShotSequence = null;
    _lastTime = null;
    _fireStart = double.negativeInfinity;
    barrel.position.z = barrelRestZ;
    for (var index = 0; index < 2; index++) {
      _flashes[index].sprite.visible = false;
      _smokes[index].sprite.visible = false;
      _smokeStarts[index] = double.negativeInfinity;
    }
  }

  void updateFire({
    required int shotSequence,
    required double time,
    required double feedback,
    required three.Camera camera,
  }) {
    final previousSequence = _lastShotSequence;
    if (_lastTime != null && time < _lastTime!) {
      // 표시 시간의 주기 순환 시 이전 잔상을 지우고 발사 시퀀스는 유지.
      resetFire();
      _lastShotSequence = previousSequence;
    }
    _lastTime = time;
    if ((previousSequence != null && previousSequence != shotSequence) ||
        (previousSequence == null && shotSequence > 0 && feedback > 0)) {
      _fireStart = time;
      _activePort = shotSequence % 2;
      _smokeStarts[_activePort] = time;
    }
    _lastShotSequence = shotSequence;
    final age = math.max(0.0, time - _fireStart);
    final heavy = type == TurretType.cannon;
    final machineGun = type == TurretType.arrow;
    final duration = heavy ? 0.11 : (machineGun ? 0.12 : 0.085);
    final recovery = heavy ? 0.34 : (machineGun ? 0.075 : 0.14);
    // 빠른 후퇴 후 완만한 복귀. 전투 발사 주기와 독립된 표시 반동.
    final kick = age < 0.018
        ? age / 0.018
        : math
              .pow((1 - (age - 0.018) / recovery).clamp(0.0, 1.0), 2)
              .toDouble();
    barrel.position.z =
        barrelRestZ - kick * (heavy ? 0.12 : (machineGun ? 0.025 : 0.045));

    muzzle.getWorldPosition(_worldMuzzle);
    _worldForward.setValues(0, 0, 1);
    muzzle.localToWorld(_worldForward);
    _worldMuzzle.project(camera);
    _worldForward.project(camera);
    final aspect = (camera.right - camera.left) / (camera.top - camera.bottom);
    final angle = math.atan2(
      _worldForward.y - _worldMuzzle.y,
      (_worldForward.x - _worldMuzzle.x) * aspect,
    );
    for (var index = 0; index < 2; index++) {
      final flash = _flashes[index];
      flash.sprite.visible = index == _activePort && age < duration;
      if (flash.sprite.visible) {
        final progress = age / duration;
        flash.setFrame((progress * 8).floor().clamp(0, 7));
        flash.material.rotation = angle;
        flash.material.opacity = (1 - progress * 0.65) * (heavy ? 0.95 : 0.8);
        final growth = 0.8 + math.sin(progress * math.pi) * 0.35;
        flash.sprite.scale.setValues(
          // 셀의 투명 여백을 제외한 기관총 섬광 폭 약 0.5타일.
          (heavy ? 0.60 : (machineGun ? 0.90 : 0.26)) * growth,
          (heavy ? 0.29 : (machineGun ? 0.70 : 0.18)) * growth,
          1,
        );
      }
      final smoke = _smokes[index];
      final smokeAge = time - _smokeStarts[index];
      final smokeDuration = heavy ? 0.60 : (machineGun ? 0.65 : 0.36);
      smoke.sprite.visible = smokeAge >= 0 && smokeAge < smokeDuration;
      if (smoke.sprite.visible) {
        final progress = smokeAge / smokeDuration;
        smoke.setFrame((progress * 8).floor().clamp(0, 7));
        // 아틀라스 자체 소멸 알파와 중복해서 연기를 너무 빨리 지우지 않음.
        smoke.material.opacity = machineGun
            ? 0.85 * (1 - progress * 0.35)
            : (heavy ? 0.35 : 0.17) * (1 - progress);
        smoke.material.rotation = 0.18 * math.sin(index + progress);
        smoke.sprite.position.y = 0.02 + progress * (heavy ? 0.17 : 0.09);
        smoke.sprite.position.z = 0.06 + progress * (heavy ? 0.14 : 0.07);
        // 초기 연기는 셀의 약 15%만 차지하므로 실제 내용 크기로 보정.
        final size =
            (heavy ? 0.25 : (machineGun ? 0.80 : 0.11)) * (1 + progress * 1.4);
        smoke.sprite.scale.setValues(size, size, 1);
      }
    }
  }
}

class _WeaponAtlasSprite {
  _WeaponAtlasSprite(three.Texture source, {bool additive = false}) {
    texture = source.clone()..needsUpdate = true;
    // 셀 가장자리의 1px 여백으로 인접 프레임 색 번짐 방지.
    texture.repeat.setValues(254 / 1024, 254 / 512);
    material = three.SpriteMaterial.fromMap({
      'map': texture,
      'color': 0xffffff,
      'transparent': true,
      'depthWrite': false,
      'toneMapped': false,
      'blending': additive ? three.AdditiveBlending : three.NormalBlending,
    });
    sprite = three.Sprite(material)..visible = false;
    sprite.geometry = sprite.geometry!.clone();
  }
  late final three.Texture texture;
  late final three.SpriteMaterial material;
  late final three.Sprite sprite;

  void setFrame(int frame) {
    // 원본은 좌→우·상→하, 텍스처 UV는 좌하단 기준.
    texture.offset.setValues(
      (frame % 4 * 256 + 1) / 1024,
      ((1 - frame ~/ 4) * 256 + 1) / 512,
    );
  }
}

class _ProjectileVisual {
  _ProjectileVisual(this.type) {
    mesh = three.Group()..name = 'weapon_projectile_${type.name}';
    final heavy = type == TurretType.cannon;
    final ballistic =
        heavy || type == TurretType.arrow || type == TurretType.sniper;
    final radius = heavy ? 0.028 : (type == TurretType.sniper ? 0.011 : 0.009);
    final length = heavy ? 0.13 : 0.075;
    final material = ballistic
        ? three.MeshStandardMaterial.fromMap({
            'color': heavy ? 0x45494d : 0xc8a269,
            'metalness': heavy ? 0.5 : 0.72,
            'roughness': heavy ? 0.65 : 0.42,
          })
        : three.MeshBasicMaterial.fromMap({'color': _projectileColor(type)});
    final body = three.Mesh(
      three.CylinderGeometry(radius, radius, length, 8),
      material,
    );
    body.rotation.x = math.pi / 2;
    mesh.add(body);
    final nose = three.Mesh(
      three.ConeGeometry(radius, length * 0.32, 8),
      material,
    );
    nose.rotation.x = math.pi / 2;
    nose.position.z = length * 0.66;
    mesh.add(nose);
    final tracerLength = heavy ? 0.10 : 0.13;
    final tracer = three.Mesh(
      three.CylinderGeometry(
        heavy ? 0.007 : 0.0035,
        heavy ? 0.002 : 0.0015,
        tracerLength,
        5,
      ),
      three.MeshBasicMaterial.fromMap({
        'color': _projectileColor(type),
        'transparent': true,
        'opacity': heavy ? 0.32 : 0.55,
        'depthWrite': false,
      }),
    );
    tracer.rotation.x = math.pi / 2;
    tracer.position.z = -(length + tracerLength) / 2;
    mesh.add(tracer);
  }

  final TurretType type;
  late final three.Group mesh;

  void reset() {
    mesh.visible = false;
  }

  void update(
    BattlefieldProjectile unit,
    MapDefinition map, {
    required double time,
  }) {
    mesh.visible = true;
    mesh.position.setValues(
      unit.position.dx - map.columns / 2,
      type == TurretType.cannon ? 0.56 : 0.45,
      unit.position.dy - map.rows / 2,
    );
    mesh.rotation.y =
        math.pi / 2 - math.atan2(unit.direction.dy, unit.direction.dx);
  }
}
