# 챕터 3 환경 소품 내장 PBR 이관

승인 원본 `../foundry-props.blend` 및 `../mounted-scene.blend`를 보존한 export copy입니다. 평가 메시·베벨·보어·실제 오렌지 열원·장착 받침과 두 브래킷을 유지합니다. 기존 챕터 3 타일의 raw-channel bake 경로를 재사용했습니다.

- 게임 파일: `assets/images/stage1_3d/environment/chapter3_props.glb`
- 루트: `elbow_pipe`, `side_conduit`, `exhaust_vent`; 모두 identity, 각 1개 mesh surface.
- Blender 1 unit = 게임 1타일. Blender (X,Y,Z) → Godot (X,Z,-Y).
- elbow/exhaust 원점은 소품 바닥 중심. 받침/브래킷은 음의 높이에 포함됩니다. 후면 부착평면 Blender Y=+.290 → Godot Z=-.290. 승인 배치 기준 tile center에서 바깥으로 .755, 높이 0.
- conduit 원점은 관 중심. 후면 부착평면 Blender Y=+.135 → Godot Z=-.135. tile center에서 바깥으로 .585, 게임 높이 -.25.
- 공용 1024 atlas: Base Color(sRGB), Normal(non-color), Metallic/Roughness(non-color ORM), Emission(sRGB). 원본 발광 세기 2.2는 KHR_materials_emissive_strength로 별도 보존하여 PNG clamp를 피합니다.
- 카메라 그림자/하이라이트는 색 텍스처에 구워 넣지 않았습니다. 절차 좌표는 원본 부품별 object-space 참조를 고정한 뒤 병합했습니다.

## 확인

`geometry-check.json`: 원본 두 .blend SHA256 불변, 평가 메시 병합 오차 < 0.000001, GLB 재임포트 정점오차 0. 3종 합계 103,780 triangles. 렌더 `glb-reimport-hero.png`에서 열린 보어, 청흑 철재·청동 림, 열원, 받침/브래킷 보존을 확인했습니다. 승인 형태 보존을 위해 감량하지 않았습니다. Android 최종 외형/성능 판정은 부모 작업의 런타임 검수 범위입니다.

GLB 크기: 8691336 bytes (약 8.29 MiB). atlas보다 원본 고밀도 평가 메시의 비중이 크며, Flutter와 PCK의 중복 포함은 피해야 합니다.

실행: 별도 background Blender로 `export_native.py`, 이어서 `render_reimport.py`.
