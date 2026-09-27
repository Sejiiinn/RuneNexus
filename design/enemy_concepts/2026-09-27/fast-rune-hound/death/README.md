# 빠른 룬 하운드 사망 모션

승인된 낮은 부유·웅크림 시안. `fast-rune-hound-death.blend`는 기존 v9의 102개 강체 메시와 24본 리그를 유지한다. `build_death.py`는 저장된 v9 원본을 독립 Blender 프로세스로 열어 실행한다. 기존 원본과 라이브 Blender 작업은 변경하지 않는다.

- `Death`: 0~0.55초, 비반복. 240Hz로 베이크된 위치·회전 키, 런타임 IK·물리 없음.
- `export_runtime.py`: 사망 blend에서 실행. 기존 정적 PBR 아틀라스에 같은 강체 스킨을 연결하여 `assets/images/stage1_3d/enemies/fast_death.glb`에 저장.
- 정규화 rest 폭 1 / 바닥 0 / Godot +Z 전방, 게임 배율 0.432.
- 본체 투명 소멸과 청록 입자는 Godot 담당. GLB에는 투명도·스케일 소멸을 넣지 않음.
- 대표 렌더: `start.png` 0초, `curl.png` 0.32초, `end.png` 0.55초. 렌더는 소멸 효과를 제외한 포즈 확인용.
- `runtime-export.json`에 삼각형·본·클립·파일 해시와 정규화 검사 결과 저장.

원본 20,214삼각형 / 단일 런타임 메시·스킨·PBR 재질 / 기존 4개 텍스처 유지. 후지 무릎이 등 위로 들리지 않도록 조정했고, 대표 포즈에서 부유와 접힘·바닥 비침범을 확인했다. 게임 최종 소멸은 `game-review/`에서 부모가 통합 확인한다.
