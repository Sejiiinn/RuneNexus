# 조명·그림자 통합 후보

2026-09-13. `target-reference.jpg`와 `before-android-fixed.png`를 직접 비교하고 조명 영역만 수정했다. 실제 GPU·Android 통합 판정은 주 에이전트가 수행한다. 이 기록 자체는 시각 검증 통과를 뜻하지 않는다.

| 설정 | 변경 전 | 후보 |
| --- | --- | --- |
| 환경광 에너지 | 0.12 | 0.16 |
| 주광 에너지 | 1.58 | 1.50 |
| 보조광 에너지 | 0.10 | 0.14 |
| 주광 그림자 blur | 기본 1.0 | 1.25 |
| 주광 그림자 depth bias | 0.03 | 0.03 유지 |
| 방향광 PCF 필터 | 데스크톱 기본 2 / 모바일 기본 0 | 양쪽 3, Soft Medium |

상면의 직접광을 약간 줄이고 그만큼 그늘의 바닥광을 복구한다. 입사각으로 계산한 흰 수평면의 단순 광량 합은 약 1.36에서 1.36으로 유지된다. 실제 PBR·색·AO·톤매핑 결과의 밝기를 보장하는 계산은 아니므로 통합 화면에서 확인해야 한다. 기대 차이는 기존의 밝은 길·건설석판을 유지하면서 측면과 기단의 어두운 부분에도 색과 면 방향이 남는 것이다.

그림자는 기존 직교 2048, depth bias 0.03, normal bias 0.35를 유지한다. PCF를 모바일에도 명시하고 작은 blur 배율을 추가해 날카로운 경계를 완화한다. 군락 중심 농도와 외곽 coverage는 고사리 담당 변경에 맡기며 그림자 전체 opacity는 건드리지 않는다. 조명 방향·색, 반사 하늘, 코어 보조광, MSAA 2x, 선형 mipmap 필터, 엔진 설정은 유지한다.

통합 진단에서 낮은 고사리 외피의 그림자가 사라져 [Godot 4.7.2 light_storage.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/storage_rd/light_storage.cpp#L805)를 확인했다. PCF 품질 반경과 blur는 normal bias가 아닌 depth bias에 곱해진다. [필터 구현](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/renderer_scene_render_rd.cpp#L1225)의 Hard 반경 1에서 Medium 반경 2로 변경하면 blur 1.25와 함께 실효 depth bias가 2.5배가 된다. 0.03 / 2.5 = 0.012 후보를 실제 GPU에서 확인했으나, 길과 건설석판 전체에 대각선 자기 그림자 줄무늬가 나타나 배제하고 0.03으로 복원했다. [Mobile shader](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/shaders/forward_mobile/scene_forward_mobile.glsl#L1982)는 depth bias를 광선 방향으로 적용한다. 낮은 외피의 접촉 소실은 고사리 담당의 실제 지면 높이·외피 위치 및 그림자 전용 외피 국소 보정으로 해결하며, 전역 bias를 낮춰 지형 결함을 도입하지 않는다.

[Godot ProjectSettings 문서](https://docs.godotengine.org/en/latest/classes/class_projectsettings.html#class-projectsettings-property-rendering-lights-and-shadows-directional-shadow-soft-shadow-filter-quality-mobile)의 모바일 기본 필터 값은 0이다. [RenderingServer 문서](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#enum-renderingserver-shadowquality)에서 Soft Medium은 3이며, [Light3D 문서](https://docs.godotengine.org/en/latest/classes/class_light3d.html#class-light3d-property-shadow-blur)의 blur 배율을 사용한다. PCSS angular distance는 추가하지 않았다. PCF는 그림자 샘플링 비용을 늘리므로 모바일 성능 개선으로 보고하지 않는다.

검사: 변경한 수치·주변 코드와 diff를 확인했다. 공유 Godot 실행·프로젝트 준비·APK 빌드·캡처는 담당 범위에 따라 실행하지 않았다. 통합 시 고정/드론 시점의 기단 접촉, 군락 경계, 석재 반사와 밝기를 함께 확인한다.
