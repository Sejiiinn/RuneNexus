# Godot GPUParticles3D용 불꽃 시안 아틀라스

승인 `../../vfx/runic-flame-vfx.blend`의 상단 5개 불꽃 메시/절차 재질을 Blender MCP로 별도 씬에 복사하여 베이크했다. 주황 외곽, 밝은 황색 중심, 비대칭 상승 혀 형태를 보존한다. 원본 파일과 본게임 에셋은 수정하지 않았다.

- `flame_flipbook.png`: 1024×1024 RGBA, 4×4 행우선, 256×256 16프레임, 16fps/1초 반복.
- 원점: 셀 x128, 바닥 y234. 알파 영역 전체 합집합 x73..164 / y40..233(상한 제외 bbox x165/y234).
- `flame_flipbook.blend`: 전용 베이크 씬 및 순환 키프레임 원본. `bake_flame.py`는 Blender MCP 실행용. 원본 씬을 먼저 라이브러리 append해야 한다.
- `frames/`: 투명 프레임 16장. `flame_flipbook.xcf`: GIMP 편집 레이어 16개.
- `ember.png`, `ember.xcf`: 64×64 부드러운 주황 외곽/황백색 중심 불티. 작은 sliver를 GIMP MCP로 제작했다.
- `pack_gimp.py`: GIMP 네이티브 패킹. MCP `export_sprite_sheet`가 `ImageBaseType.RGBA` enum 오류를 내므로 네이티브 GIMP API로 패킹하고 최종 PNG는 GIMP MCP export를 사용했다.
- `atlas_validation.json`: 프레임별 알파 bbox, 실제 픽셀 변동, 15→0 이음새 및 픽셀 단위 패킹 검증. 이음새 평균 절대오차1.285/255는 인접 프레임0.793..1.236/255와 유사하다. 프레임17 키는 프레임1과 동일 주기를 닫는다.

제작 도중 render(scene=...)의 현재 창 프레임 복귀 문제를 발견해 실제 씬을 활성화한 뒤 모든 프레임을 다시 렌더했다. 완료 후 ember 3D 복사 호출에서 Blender 프로세스가 종료되어, 저장된 기존 문서를 다시 열었다. 불꽃 원본·16장 렌더·편집원본은 정상 저장되어 있다. 사전에 기존 Blender 문서는 dirty=false였으며 원본은 덮어쓰지 않았다.
