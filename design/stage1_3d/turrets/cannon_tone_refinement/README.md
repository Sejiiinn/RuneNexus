# 대포 주황 도장 톤 조정

2026-09-11. 쨍한 주황의 붉은 성분을 소폭 낮춰 차분한 황토 주황 쪽으로 조정했다.

- runtime: `assets/images/stage1_3d/turrets/cannon.glb`
- 편집 가능한 Blender 원본: `cannon-muted-orange.blend`
- 재현 스크립트: `refine_tone.py`, 변경·보존 검증: `change.json`

`cannon_matte_orange.001`만 baseColorFactor `[.82,.96,1,1]`로 설정했다. 기존 이미지 텍스처는 그대로 유지하며, roughness .89 / metallic .025 및 다른 강철·포구 재질을 변경하지 않았다. BIN 청크 SHA-256이 변경 전후 동일하므로 메시·텍스처·노드에 연결된 버퍼 데이터는 변하지 않았다. GLB JSON의 해당 재질 factor만 변경했다.

공유 Blender GUI를 건드리지 않고 독립 Blender 프로세스에서 수정 GLB를 import하여 편집 원본을 저장했다. 실제 화면의 조명 아래 최종 인상은 앱 통합 캡처를 기준으로 확인한다.
