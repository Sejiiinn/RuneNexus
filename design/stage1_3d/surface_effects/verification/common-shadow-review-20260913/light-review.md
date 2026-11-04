# 공통 그림자·접촉 음영 검토

2026-09-13. 현재 `godot/main.gd`, `godot/project.godot`과 Godot 4.7.2 공식 소스를 읽은 검토다. 구현·설정 변경, 실행·캡처·APK 제작은 하지 않았다.

## 결론

고사리 보조 외피부터 확대하기 전에 공통 주광 그림자의 범위·필터·접촉을 먼저 정리하는 방향이 타당하다. 특히 현재 직교 카메라에서는 주광의 그림자 최대 거리 45가 적용되지 않고 카메라 far 100이 사용된다. 작은 전장에 비해 넓은 깊이 범위를 사용해 잎·낮은 돌·기단 모두의 그림자 해상도를 낭비한다. 다만 보조 외피의 높이를 올려도 차이가 없었던 현상을 이 문제 하나로 확정할 수는 없다. 주 에이전트의 외피 ON/OFF 비교와 함께 판정해야 한다.

공통 정책은 같은 광원·방향·해상도·접촉 기준을 사용한다는 뜻이다. 잎의 양면 처리와 투명 coverage, 석재의 AO 데이터, 유리의 투과 같은 소재 차이까지 동일 숫자로 강제하는 것은 아니다.

## 현행 책임과 권고

| 영역 | 현재와 의미 | 검토 권고·한계 |
| --- | --- | --- |
| 주광 shadow map | 주광 1.50, 직교 2048, PCF Medium 3, blur 1.25. 실제 기하가 주광을 가리는 동적 음영이다. | 공통 경로로 포탑·돌·풀·고사리의 접촉을 먼저 검증한다. PCF는 기존 그림자 경계를 평균화하며 없는 덩어리 음영을 생성하지 않는다. |
| 그림자 범위 | 카메라 near 0.1 / far 100. 직교 카메라는 sun max distance 45를 무시한다. | 실제 전장·높은 적·탄체·연기·시점 전환이 들어오는 카메라 깊이 범위를 구해 여유를 두는 방향을 우선 검토한다. 카메라 구도 변경은 필요 없다. 임의 near/far 숫자 적용은 잘림 위험이 있어 권하지 않는다. |
| bias | depth 0.03, normal 0.35. 0.012 depth 후보는 실제 GPU에서 전 지형의 대각선 자기 그림자 줄무늬가 생겨 배제했다. | 범위가 정리된 다음 acne와 기단 이격을 함께 보며 보정한다. 지금 depth bias만 더 낮추거나 모든 모델을 위로 올리는 정책은 부적절하다. |
| opacity | 주광 기본 1.0. | 낮추면 모든 주광 그림자를 밝게 만들 뿐 접촉이 복구되지 않는다. 부분적인 고사리 농도 문제의 해법으로 사용하지 않는다. |
| 환경·보조광 | 환경광 0.16, 그림자 없는 보조 방향광 0.14. | 그늘에서도 면색을 남기는 역할이다. 주광이 차폐돼도 이 빛은 남는다. 전역적으로 줄이면 전체가 어두워지므로 누락된 접촉을 감추는 용도로 쓰지 않는다. |
| AO | 지형 ORM AO와 `ao_light_affect=0.8`. AO는 틈으로 들어오는 간접광 부족의 근사다. | 정적 석재 틈은 AO가 적합하다. 움직이는 포탑·숨기는 식물의 접촉을 지형 텍스처에 고정하면 상태 변화에 맞지 않는다. 0.8은 AO를 직접광에도 강하게 적용하므로 shadow map과 합쳐 과도하게 검어지는지 검토해야 한다. 다른 소재에도 일괄 복사하지 않는다. |
| 내장 SSAO | Godot 4.7.2 Mobile 미지원. | 스위치를 켜는 것만으로 전체 동적 접촉 AO를 얻을 수 없다. 이 요구만으로 엔진 변경이나 별도 후처리를 권하지 않는다. 먼저 지원되는 공통 shadow map과 기존 정적 AO의 역할을 분리한다. |

## 실효 단위 계산

[4.7.2 renderer_scene_cull.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_scene_cull.cpp#L2156)는 직교 카메라에서 최대 그림자 거리 제한을 생략한다. 같은 함수에서 수신 frustum의 외접 구 반경을 R이라 할 때 `bias_scale = 2R + pancake_size`, `shadow_texel_size = 2R / texture_size`를 만든다. pancake 기본값은 20이다.

[light_storage.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/storage_rd/light_storage.cpp#L805)와 [필터 반경 코드](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/renderer_scene_render_rd.cpp#L1225)를 합치면 현재 설정의 광선 방향 depth offset은 `0.03 / 100 × (2R + 20) × 1.25 × 2`다. normal bias는 이 PCF 배율과 무관하게 `0.35 × 2R / 2048`이며 셰이더에서 면 방향에 따라 더 줄어든다.

예를 들어 수신 frustum이 21×21, near/far가 0.1/100이면 2R은 여백 보정을 포함해 약 104.3이다. depth offset은 약 0.0932타일, normal bias의 방향 계수 적용 전 크기는 약 0.0178타일, PCF 샘플 반경의 기본 크기는 약 0.127타일이다. 이는 현재 런타임 viewport 측정값이 아닌 크기 예시다. HUD 투영 크기·zoom에 따라 수신 frustum 크기가 바뀐다. 광선 방향 offset을 그대로 수직 높이라고 취급하면 안 된다. 외피를 0.14타일 올렸는데도 시각 차이가 없었다는 진단은 bias만으로 원인을 확정하는 데 반대되는 증거다.

## 공식 근거

- [4.7.2 Environment 문서 원본](https://github.com/godotengine/godot/blob/4.7.2-stable/doc/classes/Environment.xml#L264): SSAO는 Forward+·Compatibility 지원, Mobile 미지원.
- [4.7.2 Mobile shader](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/shaders/forward_mobile/scene_forward_mobile.glsl#L1982): normal bias와 광선 방향 depth bias를 분리해 적용한다.
- [BaseMaterial3D AO 문서](https://docs.godotengine.org/en/latest/classes/class_basematerial3d.html#class-basematerial3d-property-ao-light-affect): 0은 환경광에만, 1은 직접광에도 AO를 적용한다.
- [4.7.2 Mobile AO 코드](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/shaders/forward_mobile/scene_forward_mobile.glsl#L1844): 환경광에 AO를 적용하고, 이후 direct AO를 `ao_light_affect`로 혼합한다.
