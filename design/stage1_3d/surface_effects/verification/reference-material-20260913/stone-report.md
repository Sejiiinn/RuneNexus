# 석재 재질 후보

2026-09-13. Astra 재질 담당 구현. 통합 화면의 채택 판정은 주 에이전트가 수행한다.

`target-reference.jpg`와 `before-android-fixed.png`를 직접 확인했다. 이전 화면은 상면 요철은 보이지만 돌·이끼의 반사 차이가 약하며, 시안의 완만한 면 변화에 비해 건조한 표면으로 읽힌다.

## 변경

- `../../refine_surface_maps.py`: 원본 석재 roughness 맵의 출력 범위 `.58–.88`을 `.40–.70`으로, 원본 이끼 마스크의 혼합 거칠기 `.95`를 `.90`으로 변경. 색·높이·마스크 및 금속성은 유지.
- `../../maps/stage1_surface_build_roughness.png`, `../../maps/stage1_surface_path_roughness.png`: 같은 2048px atlas에 새 채널 베이크.
- `../../surface-maps.json`, `../../terrain-surface.blend`, `../../terrain-candidate.glb`: 현행 파이프라인으로 갱신. `bake_contact_ao.py`와 `repair_surface_uv.py`까지 순서대로 실행.
- `assets/images/stage1_3d/environment/terrain.glb`: 새 후보 연결. 30,688,776 bytes, SHA-256 `fdce7fe0fdb23473b267b4d117c977c2008dbc21f8095d00ccbc9cd2ecad529e`.

기존 cavity/contact PNG도 파이프라인에서 다시 저장되지만 최종 GLB의 AO 채널은 이전과 픽셀 단위로 동일하다. `.blend1`은 Blender 자동 저장 백업이다. 새 런타임 모듈은 필요하지 않아 추가하지 않았다.

## 데이터 검사

`check-stone-data.py`의 결과는 `stone-data-check.json`에 기록했다. 이전 파일은 `stone-before.glb`이다. Blender MCP에서 독립 백그라운드 Blender를 실행했으며 열린 UI 장면은 교체하지 않았다.

- 전후 74,564삼각형, 형상·모든 정점 속성·인덱스·상면/측면 UV·노드 변환·계층 동일.
- 모든 base color·normal 텍스처 동일. 건설/길의 AO·metallic 채널 동일.
- atlas의 흰 빈 영역을 제외한 roughness: 건설 p5 `.847→.686`, 중앙값 `.878→.749`; 길 p5 `.706→.525`, 중앙값 `.749→.569`.
- 실제 최솟값은 건설 `.608`, 길 `.420`이다. `.40`은 원본 입력 범위의 하한이며 상면 전체에 적용한 상수값이 아니다.

## 통합 권고와 미검증

`main.gd`의 기존 normal_scale 건설 `2.0`, 길 `1.5`는 거칠기가 낮아진 후보에서 미세 요철의 반사가 지나치게 강해질 수 있다. 건설 `1.2`, 길 `1.0`으로 원본에 가까운 강도를 권한다. AO light affect는 `.8`을 우선 유지하고 공용 조명·고사리 그림자 변경과 함께 판정한다. 내장 StandardMaterial3D와 기존 mipmap 필터를 유지한다.

재질만으로 시안 전체를 달성했다고 판정하지 않는다. 주 에이전트의 실제 고정/드론 화면에서 흰 반사면, 석재 무늬 손실, 이끼와 돌의 구분을 확인해야 한다. 이 담당은 GPU 캡처·공용 프로젝트 준비·APK 패키징·Android 실행을 수행하지 않았다.
