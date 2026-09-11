part of 'stage1_scene.dart';

/// 포탄 파열: 하나의 입체 먼지장, 짧은 중심 화염, 탄도로 분리되는 금속 조각.
class _CannonImpactVisual {
  _CannonImpactVisual(this._field) {
    volume =
        three.Mesh(
            three.BoxGeometry(2, 2, 2),
            three.ShaderMaterial.fromMap({
              'uniforms': {
                // 두 시간 표본을 같은 3D 아틀라스에서 보간. 복셀 중심 안으로 제한해 이웃 프레임 누출 방지.
                'uField': {'value': _field.texture},
                'uFieldFrame0': {'value': three.Vector3()},
                'uFieldFrame1': {'value': three.Vector3()},
                'uFieldMix': {'value': 0.0},
                'uFieldUvScale': {
                  'value': three.Vector3(
                    (_field.gridSize - 1) /
                        (_field.gridSize * _field.bricks[0]),
                    (_field.gridSize - 1) /
                        (_field.gridSize * _field.bricks[1]),
                    (_field.gridSize - 1) /
                        (_field.gridSize * _field.bricks[2]),
                  ),
                },
                'uFieldMin': {'value': _field.boundsMin.clone()},
                'uFieldExtent': {
                  'value': _field.boundsMax.clone().sub(_field.boundsMin),
                },
                'uFieldDensityScale': {'value': _field.densityScale},
                'uFieldEmissionScale': {'value': _field.emissionScale},
                'uAge': {'value': 0.0},
                'uProgress': {'value': 0.0},
                'uAngle': {'value': 0.0},
                'uOrthographic': {'value': 1.0},
                'uCameraInside': {'value': 0.0},
                'uCameraLocal': {'value': three.Vector3()},
                'uRayDirection': {'value': three.Vector3(0, -1, 0)},
                'uLightDirection': {'value': three.Vector3(-0.70, 0.45, 0.55)},
              },
              'vertexShader': _volumeVertex,
              'fragmentShader': _volumeFragment,
              'transparent': true,
              'depthWrite': false,
              'side': three.DoubleSide,
              'toneMapped': true,
            }),
          )
          ..name = 'cannon_impact_volume'
          ..frustumCulled = false;
    // 패키지의 map setter에는 없는 공개 속성. 양면 볼륨 중복 패스 방지.
    volume.material!.forceSinglePass = true;
    sparks =
        three.InstancedMesh(
            _sparkGeometry(),
            three.MeshBasicMaterial.fromMap({
              'color': three.Color(6.0, 1.45, 0.14),
              'toneMapped': true,
            }),
            _sparkCount,
          )
          ..name = 'cannon_impact_sparks'
          ..frustumCulled = false;
    fragments =
        three.InstancedMesh(
            _fragmentGeometry(),
            three.MeshStandardMaterial.fromMap({
              'color': three.Color(0.019, 0.020, 0.021),
              'metalness': 0.48,
              'roughness': 0.72,
              // 렌더러의 intensity 0 처리와 무관하게 자체 발광 제거.
              'emissive': 0x000000,
              'emissiveIntensity': 0.0,
            }),
            _fragmentCount,
          )
          ..name = 'cannon_impact_fragments'
          ..frustumCulled = false;
    root.add(volume);
    root.add(sparks);
    root.add(fragments);
    final random = math.Random(1404);
    for (var index = 0; index < _sparkCount + _fragmentCount; index++) {
      final spark = index < _sparkCount;
      // 굵은 파편 일부와 많은 작은 조각의 비대칭 크기 분포.
      final large = !spark && index % 5 == 0;
      _particles.add((
        angle: random.nextDouble() * math.pi * 2,
        speed: spark
            ? 1.8 + random.nextDouble() * 3.8
            : 1.4 + random.nextDouble() * 3.1,
        rise: spark
            ? 1.2 + random.nextDouble() * 3.6
            : 1.3 + random.nextDouble() * 3.1,
        death: spark
            ? 0.19 + random.nextDouble() * 0.39
            : 0.65 + random.nextDouble() * 0.43,
        delay: random.nextDouble() * 0.018,
        width: spark
            ? 0.0025 + random.nextDouble() * 0.0035
            : large
            ? 0.12 + random.nextDouble() * 0.06
            : 0.032 + random.nextDouble() * 0.052,
        length: 0.045 + random.nextDouble() * 0.085,
        stretch: 0.55 + random.nextDouble() * 1.1,
        spin: 3.0 + random.nextDouble() * 8.0,
      ));
    }
  }

  final _CannonImpactField _field;

  static const _sparkCount = 56;
  static const _fragmentCount = 34;
  // 게임 타일 반경 단위의 고정 적분 경계. 실제 분출 크기는 밀도장에서 성장.
  static const _halfWidth = 2.35;
  static const _halfHeight = 1.45;
  final root = three.Group()..name = 'cannon_impact';
  late final three.Mesh volume;
  late final three.InstancedMesh sparks;
  late final three.InstancedMesh fragments;
  final _transform = three.Object3D();
  final _direction = three.Vector3();
  final _forward = three.Vector3(0, 0, 1);
  final _inverse = three.Matrix4.identity();
  final _particles =
      <
        ({
          double angle,
          double speed,
          double rise,
          double death,
          double delay,
          double width,
          double length,
          double stretch,
          double spin,
        })
      >[];

  static three.BufferGeometry _sparkGeometry() {
    const points = [
      [-1.0, 0.0, 0.0],
      [1.0, 0.0, 0.0],
      [0.0, -1.0, 0.0],
      [0.0, 1.0, 0.0],
      [0.0, 0.0, -0.5],
      [0.0, 0.0, 0.5],
    ];
    final geometry = three.BufferGeometry();
    geometry.setAttributeFromString(
      'position',
      three.Float32BufferAttribute.fromList([
        for (final i in [
          0,
          3,
          5,
          3,
          1,
          5,
          1,
          2,
          5,
          2,
          0,
          5,
          3,
          0,
          4,
          1,
          3,
          4,
          2,
          1,
          4,
          0,
          2,
          4,
        ])
          ...points[i],
      ], 3),
    );
    geometry.computeVertexNormals();
    return geometry;
  }

  static three.BufferGeometry _fragmentGeometry() {
    // 찢어진 외곽과 두께가 다른 앞뒷면. 삼각형별 법선으로 파단면을 보존.
    const rim = [
      [-0.95, -0.50],
      [-0.20, -0.90],
      [0.78, -0.64],
      [0.53, -0.08],
      [1.0, 0.61],
      [0.19, 0.38],
      [-0.35, 0.91],
      [-0.70, 0.19],
    ];
    final positions = <double>[];
    for (var index = 0; index < rim.length; index++) {
      final a = rim[index];
      final b = rim[(index + 1) % rim.length];
      final frontA = [a[0], a[1], 0.12 + (index % 3) * 0.045];
      final frontB = [b[0], b[1], 0.12 + ((index + 1) % 3) * 0.045];
      final backA = [a[0] * 0.87, a[1] * 0.94, -0.17];
      final backB = [b[0] * 0.87, b[1] * 0.94, -0.17];
      positions.addAll([
        0.04,
        -0.03,
        0.36,
        ...frontA,
        ...frontB,
        -0.07,
        0.04,
        -0.21,
        ...backB,
        ...backA,
        ...frontA,
        ...backA,
        ...backB,
        ...frontA,
        ...backB,
        ...frontB,
      ]);
    }
    final geometry = three.BufferGeometry();
    geometry.setAttributeFromString(
      'position',
      three.Float32BufferAttribute.fromList(positions, 3),
    );
    geometry.computeVertexNormals();
    return geometry;
  }

  void update(BattlefieldImpact impact, three.Camera camera) {
    final progress = impact.progress.clamp(0.0, 1.0);
    final age = progress * BattlefieldImpact.duration;
    final radius = math.max(impact.radius, 0.001);
    final angle = (impact.id % 23) * 0.317;
    root.visible = progress < 1;
    volume.visible = progress < 1;
    sparks.visible = age < 0.6;
    fragments.visible = progress < 1;
    volume.position.setValues(0, _halfHeight * radius, 0);
    volume.scale.setValues(
      _halfWidth * radius,
      _halfHeight * radius,
      _halfWidth * radius,
    );
    root.updateWorldMatrix(true, true);
    _inverse.setFrom(volume.matrixWorld).invert();
    final uniforms = volume.material!.uniforms;
    uniforms['uAge']['value'] = age;
    uniforms['uProgress']['value'] = progress;
    uniforms['uAngle']['value'] = angle;
    var frame = 0;
    while (frame < _field.times.length - 2 && _field.times[frame + 1] < age) {
      frame++;
    }
    uniforms['uFieldMix']['value'] =
        ((age - _field.times[frame]) /
                (_field.times[frame + 1] - _field.times[frame]))
            .clamp(0.0, 1.0);
    for (var next = 0; next < 2; next++) {
      final index = frame + next;
      final offset =
          uniforms[next == 0 ? 'uFieldFrame0' : 'uFieldFrame1']['value']
              as three.Vector3;
      // 프레임의 첫 복셀 중심: 공간 보간이 다른 시간 블록으로 넘어가지 않는 경계.
      offset.setValues(
        (index % _field.bricks[0] + 0.5 / _field.gridSize) / _field.bricks[0],
        (index ~/ _field.bricks[0] % _field.bricks[1] + 0.5 / _field.gridSize) /
            _field.bricks[1],
        (index ~/ (_field.bricks[0] * _field.bricks[1]) +
                0.5 / _field.gridSize) /
            _field.bricks[2],
      );
    }
    uniforms['uOrthographic']['value'] = camera is three.OrthographicCamera
        ? 1.0
        : 0.0;
    final cameraLocal = uniforms['uCameraLocal']['value'] as three.Vector3;
    cameraLocal
        .setFromMatrixPosition(camera.matrixWorld)
        .applyMatrix4(_inverse);
    uniforms['uCameraInside']['value'] =
        cameraLocal.x.abs() < 1 &&
            cameraLocal.y.abs() < 1 &&
            cameraLocal.z.abs() < 1
        ? 1.0
        : 0.0;
    camera.getWorldDirection(uniforms['uRayDirection']['value']);
    (uniforms['uRayDirection']['value'] as three.Vector3).transformDirection(
      _inverse,
    );

    // 매 프레임 모든 변환을 기록하여 회수·다른 반경 재사용·시간 되감기 대응.
    for (var index = 0; index < _particles.length; index++) {
      final particle = _particles[index];
      final spark = index < _sparkCount;
      final mesh = spark ? sparks : fragments;
      final slot = spark ? index : index - _sparkCount;
      final time = math.max(0.0, age - particle.delay);
      final drag = spark ? 1.8 : 0.75;
      final travel = (1 - math.exp(-drag * time)) / drag;
      final gravity = spark ? 4.8 : 5.4;
      final height = 0.055 + particle.rise * time - gravity * time * time;
      final heading = particle.angle + angle;
      final vx = math.cos(heading) * particle.speed;
      final vz = math.sin(heading) * particle.speed;
      _transform.position.setValues(
        vx * travel * radius,
        height * radius,
        vz * travel * radius,
      );
      if (age < particle.delay ||
          time > particle.death ||
          height < 0.014 ||
          progress >= 1) {
        _transform.scale.setValues(0, 0, 0);
      } else if (spark) {
        _direction.setValues(
          vx * math.exp(-drag * time),
          particle.rise - 2 * gravity * time,
          vz * math.exp(-drag * time),
        );
        _direction.normalize();
        _transform.quaternion.setFromUnitVectors(_forward, _direction);
        _transform.scale.setValues(
          particle.width * radius,
          particle.width * radius,
          particle.length * (1 - time / particle.death) * radius,
        );
      } else {
        _transform.rotation.set(
          time * particle.spin + index,
          time * particle.spin * 0.73,
          time * particle.spin * 1.31,
        );
        final fade = ((particle.death - time) / 0.11).clamp(0.0, 1.0);
        _transform.scale.setValues(
          particle.width * radius * fade,
          particle.width * particle.stretch * radius * fade,
          particle.width * radius * fade,
        );
      }
      _transform.updateMatrix();
      mesh.setMatrixAt(slot, _transform.matrix);
    }
    sparks.instanceMatrix!.needsUpdate = true;
    fragments.instanceMatrix!.needsUpdate = true;
  }

  static const _volumeVertex = '''
varying vec3 vVolumePosition;
void main() {
  vVolumePosition = position;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}
''';

  static const _volumeFragment = '''
uniform sampler3D uField;
uniform vec3 uFieldFrame0;
uniform vec3 uFieldFrame1;
uniform vec3 uFieldUvScale;
uniform vec3 uFieldMin;
uniform vec3 uFieldExtent;
uniform float uFieldMix;
uniform float uFieldDensityScale;
uniform float uFieldEmissionScale;
uniform float uAge;
uniform float uProgress;
uniform float uAngle;
uniform float uOrthographic;
uniform float uCameraInside;
uniform vec3 uCameraLocal;
uniform vec3 uRayDirection;
uniform vec3 uLightDirection;
varying vec3 vVolumePosition;
const vec3 HALF_EXTENT = vec3(2.35,1.45,2.35);

float hash3(vec3 p) {
  p = fract(p * 0.1031);
  p += dot(p, p.yzx + 33.33);
  return fract((p.x + p.y) * p.z);
}
// 제작 단계에서 계산한 밀도·발광·열도장을 공간·시간 보간. 현재 카메라와 광원은 유지.
vec3 field(vec3 p) {
  float c=cos(uAngle),s=sin(uAngle);
  vec3 q=p;
  q.xz=mat2(c,-s,s,c)*q.xz;
  vec3 uvw=(q-uFieldMin)/uFieldExtent;
  if(any(lessThan(uvw,vec3(0.0))) || any(greaterThan(uvw,vec3(1.0)))) {
    return vec3(0.0);
  }
  vec4 cached=mix(
    texture(uField,uFieldFrame0+uvw*uFieldUvScale),
    texture(uField,uFieldFrame1+uvw*uFieldUvScale),uFieldMix);
  // RG의 상·하위 바이트를 선형 복원해 희박한 연기까지 16비트 밀도 정밀도 유지.
  float density=dot(cached.rg,vec2(256.0/257.0,1.0/257.0))*uFieldDensityScale;
  float emission=cached.b*uFieldEmissionScale;
  // 격자보다 작은 초기 기폭 섬광은 기존 수식으로 보존.
  if(uAge<0.055) {
    float flash=max(0.0,1.0-length(p-vec3(0,0.07,0))/0.085)
      *(1.0-smoothstep(0.008,0.055,uAge));
    density+=flash*5.0;
    emission+=flash*35.0;
  }
  return vec3(density,emission,cached.a);
}

void main() {
  if(uProgress>=1.0) discard;
  // 외부 카메라는 입구면, 내부 카메라는 출구면을 한 번만 렌더.
  if(uCameraInside<0.5 && !gl_FrontFacing) discard;
  if(uCameraInside>0.5 && gl_FrontFacing) discard;
  vec3 direction=uOrthographic>0.5 ? normalize(uRayDirection)
    : normalize(vVolumePosition-uCameraLocal);
  vec3 origin=uOrthographic>0.5 ? vVolumePosition-direction*4.0 : uCameraLocal;
  vec3 safeDirection=sign(direction)*max(abs(direction),vec3(0.00001));
  safeDirection+=vec3(equal(safeDirection,vec3(0.0)))*0.00001;
  vec3 a=(-vec3(1.0)-origin)/safeDirection;
  vec3 b=( vec3(1.0)-origin)/safeDirection;
  vec3 nearPlane=min(a,b),farPlane=max(a,b);
  float begin=max(0.0,max(nearPlane.x,max(nearPlane.y,nearPlane.z)));
  float end=min(farPlane.x,min(farPlane.y,farPlane.z));
  if(end<=begin) discard;
  float stepSize=(end-begin)/32.0;
  float metricStep=length(direction*HALF_EXTENT)*stepSize;
  float jitter=hash3(vec3(gl_FragCoord.xy,17.0));
  vec3 radiance=vec3(0.0);
  float transmission=1.0;
  vec3 light=normalize(uLightDirection);
  float illumination=0.5;
  int shadowStep=-4;
  for(int i=0;i<32;i++) {
    vec3 local=origin+direction*(begin+(float(i)+jitter)*stepSize);
    vec3 p=local*HALF_EXTENT+vec3(0,HALF_EXTENT.y,0);
    if(p.y<0.012) continue;
    vec3 sampleField=field(p);
    float density=sampleField.x;
    if(density<0.005) continue;
    if(i-shadowStep>=4) {
      // 완만한 자체 그림자는 네 적분 구간에서 재사용. 단일 광로의 중간 밀도로 차폐 근사.
      shadowStep=i;
      float shadowDensity=field(p+light*0.24).x;
      illumination=0.10+1.15*exp(-shadowDensity*0.63);
    }
    vec3 ash=mix(vec3(0.068,0.048,0.030),vec3(0.053,0.050,0.044),
      smoothstep(0.25,0.9,p.y));
    ash*=mix(0.60,1.35,sampleField.z);
    vec3 flame=mix(vec3(1.0,0.018,0.0003),vec3(1.0,0.15,0.006),sampleField.z);
    vec3 source=ash*illumination+flame*sampleField.y/max(density,0.001);
    float opacity=1.0-exp(-density*metricStep);
    radiance+=transmission*opacity*source;
    transmission*=1.0-opacity;
    if(transmission<0.015) break;
  }
  float alpha=1.0-transmission;
  if(alpha<0.003) discard;
  gl_FragColor=vec4(radiance/max(alpha,0.001),alpha);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}
''';
}
