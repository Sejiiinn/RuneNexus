# 사용하지 않는 cinematic RGBA 내보내기 기록

승인된 `../cannon_impact_cinematic.blend`의 재질과 애니메이션을 유지한 중간 내보내기다. 사용자가 게임 안의 직접 3D 렌더를 요청하여 이 이미지 재생 경로는 채택하지 않았다. PNG는 이 제작 폴더에만 보관하며 게임은 로드하지 않는다.

- 보관 파일: `cannon_impact.png`, `cannon_shockwave.png`
- 256×256 셀 32개, 왼쪽→오른쪽/위→아래 순서, 8열×4행, 각 2048×1024 RGBA
- 1.1초, 마지막 셀 완전투명
- body 카메라: (2.8, -7, 4.2), target (0, 0, .72), ortho 4.9. 승인 검수 장면의 key/flash만 유지, 바닥/배경 없음.
- ground 카메라: (0, 0, 10), ortho 4.9, 완전 위쪽 정사영
- body 지면 원점: 좌하단 정규좌표 (.50000006, .36658737), PNG 좌상단 정규좌표 (.50000006, .63341263). ground (.5, .5).

`prepare_export.py` → `render_export.py` (METAL 32 samples) → `pack_frames.py`로 OpenRaster 배열 구성 → GIMP에서 ORA를 열고 flatten=false PNG 및 XCF 저장 → `verify_export.py` 순서로 재현한다. 이미지 합성·PNG 내보내기는 GIMP를 사용했다.

64개 셀의 알파와 알파가 0보다 큰 픽셀의 RGB는 원본 렌더와 모두 일치한다. 마지막 32번째 프레임은 양쪽 모두 완전투명이다. 승인 카메라를 유지하여 body 0-based 24·26번 프레임의 매우 작은 불티만 이미지 경계에 각각 최대 알파 8·32로 닿는다. 화염 몸체와 ground는 경계 잘림이 없다. 자세한 결과는 `frame_qa.json`, 좌표는 `export_metadata.json`을 참고한다.
