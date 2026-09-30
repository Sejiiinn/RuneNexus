# SWIFT 수직 저격 포탑 제작 원본

승인·적용 상태 원본은 [상위 작업 기록](../README.md)을 따른다. 생성 이미지가 아닌 Blender 메시·재질 기반 모델이며 게임 파일은 교체하지 않았다.

- `sniper-c-editable.blend`: 고정 받침 / 회전 요크 / 반동 포신을 분리한 편집 원본. 절차형 금속 표면, 실제 베벨·부품·발광 룬이 들어 있다.
- `sniper-c-hero.png`, `sniper-c-top.png`, `sniper-c-rear.png`, `sniper-c-drone.png`: 모두 최종 SWIFT 원본이다. top은 진짜 수직 정투영이며 drone은 사선 상부다. 단순 타일은 프레젠테이션 전용이며 게임 캡처가 아니다.
- `sniper-c-preview.glb`, `sniper-c-baked-preview.blend`: 형상을 평가한 준비용 파일. 고정 / 조준 / 반동 책임별 3메시와 5재질, 1024² 컬러·거칠기·노멀 PBR 베이크를 포함한다. 최종 런타임 최적화나 게임 적용 완료를 의미하지 않는다.
- `manifest.json`: 형상 크기, 회전 반경, 포구 위치, 해시, 렌더 조건과 한계.

## 제작과 재현

`build_sniper.py`는 기존 `design/fire_tower_concepts/runic_3d/build_model.py`의 bpy 메시·베벨·금속 제작 함수를 재사용한다. `swift_receiver.py`가 승인 [01 SWIFT](../receiver-variants/01-swept-wedge.png)의 낮고 길게 흐르는 쐐기 외피·전방 매립 원형 렌즈·곡선 은색 요크를 제작한다. 전체 포탑을 덮어쓰는 `build_turrets.py`를 실행하지 않는다.

1. Blender MCP에서 별도 네임스페이스로 `build_sniper.py`를 읽고 `build()`를 호출한다. 기존 Blender 장면은 보존하고 독립 제작 장면을 만든다. 반복 제작 때는 이전 C 제작 장면만 백업 후 정리한다.
2. 독립 background Blender에서 `sniper-c-editable.blend --python render_views.py`로 편집 파일과 4뷰를 저장한다. top 카메라는 (0, -0.28, 5), 회전 (0, 0, 0), ORTHO 1.85로 수직 아래를 본다.
3. 독립 background Blender에서 `sniper-c-editable.blend --python export_preview.py`로 PBR 베이크와 준비 GLB를 갱신한다.

모든 출력은 이 폴더 안이다. `C90 Presentation only`의 바닥·타일·조명·카메라는 GLB에 포함하지 않는다.

## 자체 확인

사용자 피드백에 따라 높이를 줄인 수직 팔각 기둥과 120도 간격의 3개 발, 긴 포신을 보존했다. 각진 약실은 낮은 유선형 SWIFT 외피로 바꾸었다. 매립 원형 청록 조준렌즈, 측면 다이아 인레이, 두꺼운 곡선 은색 요크와 관통 트러니언·하부 브리지를 실제 부피로 제작했다. 첫 SWIFT 렌더의 높은 crown과 렌즈 가림을 수정했다. 룬은 얇은 평면 인레이로 유지한다.

`turret_root → turret_head → turret_barrel → muzzle` 계층을 보존했다. 기둥과 발은 root 하위, 링 위 요크는 head 하위, 약실·포신·포구는 barrel 하위다. head 조준 초기 회전과 barrel 초기 위치는 0이다. Blender Z 위 / -Y 전방을 glTF Y 위 / +Z 전방으로 변환한다.

43,380삼각형, 3메시, 5재질, GLB 3,228,344바이트. 고정 받침 최대 반경 0.415507타일, 회전부 최대 반경 1.100504타일이다. 포신은 한 타일 밖으로 뻗는다. 최종 높이는 0.914760타일, 회전 피벗은 0.45타일이다. `check_swift_source.py` / `swift-source-check.json`에서 이전 원본과 고정부·포신의 평가 정점 해시 및 head/barrel/muzzle 좌표 일치를 확인했다. 원본과 GLB 식별·렌더 조건은 manifest.json에 기록한다.

이 범위에서 게임 내 조준·반동·발사 동기화, 본게임 크기 가독성 및 모바일 성능은 검증하지 않았다. 게임 이식 시 해당 조건에 맞춰 확인해야 한다.

금속은 본체 metallic 0.88 / roughness 0.34, 은색 0.94 / 0.26, 청동 0.85 / 0.33, 어두운 기계부 0.80 / 0.40의 새틴 표면을 보존했다. 첫 높이/재질 버전은 `before-height-metal/`, SWIFT 이전 각진 약실은 `before-swift/`에 최소 원본·hero로 보존했다.
