part of 'stage1_scene.dart';

/// 기존 렌더러의 면광원 BRDF 조회표. float 선형 필터 미지원 기기는 half 사용.
Future<void> _loadAreaLightTextures(three.ThreeJS view) async {
  for (final precision in ['float', 'half']) {
    for (var index = 1; index <= 2; index++) {
      final bytes = await rootBundle.load(
        'assets/images/stage1_3d/environment/ltc_${precision}_$index.bin',
      );
      final texture =
          three.DataTexture(
              precision == 'float'
                  ? bytes.buffer.asFloat32List(
                      bytes.offsetInBytes,
                      bytes.lengthInBytes ~/ 4,
                    )
                  : bytes.buffer.asUint16List(
                      bytes.offsetInBytes,
                      bytes.lengthInBytes ~/ 2,
                    ),
              64,
              64,
              three.RGBAFormat,
              precision == 'float' ? three.FloatType : three.HalfFloatType,
            )
            ..magFilter = three.LinearFilter
            ..minFilter = three.NearestFilter
            ..needsUpdate = true;
      final key = 'LTC_${precision.toUpperCase()}_$index';
      three.uniformsLib[key] = texture;
      view.toDispose(() {
        if (identical(three.uniformsLib[key], texture)) {
          three.uniformsLib.remove(key);
        }
        texture.dispose();
      });
    }
  }
}

/// three_js_angle_renderer 0.0.1의 면광원 방향 계산 보정: view × world.
class _Stage1AreaLightView {
  final _lightView = three.Matrix4.identity();
  final _rotation = three.Matrix4.identity();

  // setupLightsView 이후, 재질 uniform 업로드 전에 면 방향만 보정.
  void update(
    three.AngleRenderer renderer,
    three.Object3D scene,
    three.Camera camera,
    three.BufferGeometry geometry,
    three.Object3D object,
    dynamic group,
  ) {
    final renderState = renderer.currentRenderState;
    if (renderState == null) return;
    var index = 0;
    for (final light in renderState.lightsArray) {
      if (light is! three.RectAreaLight) continue;
      final uniforms = renderState.lights.state.rectArea[index++];
      _lightView.multiply2(camera.matrixWorldInverse, light.matrixWorld);
      _rotation.extractRotation(_lightView);
      (uniforms['halfWidth'] as three.Vector3)
        ..setValues(light.width! * 0.5, 0, 0)
        ..applyMatrix4(_rotation);
      (uniforms['halfHeight'] as three.Vector3)
        ..setValues(0, light.height! * 0.5, 0)
        ..applyMatrix4(_rotation);
    }
  }
}
