# 벽 일체형 V2 내장 PBR 이관

현재 게임 GLB는 이 형태와 벽 접합을 보존한 [경량본](../optimized-game-distance/README.md)이다. 아래는 고해상도 V2 최초 이관 당시 원본·수치·검증 기록이다.

[승인 멀티뷰](../../environment_concepts/integrated-mounts/multiview-v2.png) → [편집 원본](../foundry-props.blend) → `assets/images/stage1_3d/environment/chapter3_props.glb`. 이전 선반과 외곽 지지 브래킷은 삭제되었다. 새 export는 소품 원본만 평가하며 타일/장착 장면 메시를 섞지 않는다.

## 계약

3개 mesh root `elbow_pipe`, `side_conduit`, `exhaust_vent`는 identity이며 각각 1개 surface다. Blender 1 unit = 게임 1타일, (X,Y,Z) → Godot (X,Z,-Y). 전종 root는 측벽 상단 기준점: tilecenter + outward × .45, 높이 0. Blender 최대 Y=0이며 내측 돌출은 없다. 배기구 하우징은 Z=-.50부터 0, 굴뚝 상단은 +.253이다. 연결관 중심은 이미 소스 내부의 Y=-.135/Z=-.25에 놓여 있으므로 runtime 보정을 더하지 않는다.

## 재질과 파일

기존 챕터 3 타일 raw-channel bake를 재사용했다. 공용 1024 atlas의 Base Color/Emission은 sRGB, Normal과 Metallic/Roughness는 Non-Color다. GLB에는 색·노멀·ORM·발광 4개 이미지가 포함된다. 절차 좌표는 부품별 Object 참조로 고정하고 PBR 채널만 베이크한다. 하이라이트·그림자를 색 이미지에 굽지 않는다. Emission은 정규화 이미지 + KHR_materials_emissive_strength 2.2로 원본을 보존한다.

최종 파일 8091672 bytes, 3종 합계 98388 triangles. 이전 GLB 8,691,336 bytes 대비 약 0.60MB 감소했다. 승인 평가 메시를 보존하며 별도 형태 감량은 적용하지 않았다.

## 확인

[geometry-check.json](geometry-check.json): 원본 SHA256 불변, 병합 정점 오차 < 1e-6, 실제 GLB 재임포트 정점 오차 0, 3종 wallanchor AABB PASS. 원본의 관통 보어·위로 열린 곡관·배기구 깊이·manifold는 [원본 검사](../geometry-check.json)로 확인했다.

[대표 재임포트 렌더](integrated-v2-glb-mounted.png)는 원본/내보내기 통합 시각 검수용 1장이다. `build_props.py`와 `build_presentation.py`는 원본만 저장하고, `render_reimport.py`에서 최종 GLB와 타일을 함께 렌더한다. Android 외형·성능 검수는 부모의 인게임 작업으로 이어진다.
