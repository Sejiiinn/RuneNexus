# 스테이지 2~5 환경 장식

2026-09-13. 기존 승인된 스테이지 1의 저장된 군락을 각 실제 맵에 재배치했다. 고사리·넓은 잎·풀과 이끼 바위를 겹치고, 일부 가장자리에 흰꽃·덩굴을 둔다. 모든 건설칸을 채우지 않고 낮은 식생과 빈 공간을 섞는다. 이동 경로·포탈·코어와 영구 장식 주변의 건설 중앙 0.7×0.7 공간을 유지한다.

- 편집 원본: [chapter1-dressing.blend](chapter1-dressing.blend)의 `Chapter1 Stage 2~5 Environment` 네 장면. 각 군락은 별도 메시이며 원본 배치·식물 종류·점유 슬롯 metadata를 유지한다.
- 원본 출처: [스테이지 1 승인 군락](../../stage1_3d/environment_dressing/README.md). 이 작업은 저장된 원본과 독립 마스터를 변경하지 않는다.
- 조립 스크립트: [assemble_dressing.py](assemble_dressing.py). 별도 Blender 백그라운드 프로세스에서 실행한다. 다시 조립하면 이 작업의 맵 복사본이 재생성되므로 수동 편집을 먼저 보존한다. 열린 Blender MCP에서 시작했으나 Blender의 scene library-write 충돌을 확인하여 별도 프로세스의 전체 파일 저장으로 전환했다.
- 저장한 맵 군락만 다시 출력할 때는 Blender에서 `chapter1-dressing.blend`를 열고 [export_dressing.py](export_dressing.py)를 실행한다. 이 경로는 배치를 재생성하지 않고 저장된 메시·정점색·UV를 내보낸다.
- 게임 출력: `assets/images/stage1_3d/environment/dressing_stage2.glb`~`dressing_stage5.glb`. 맵당 식생·바위 두 메시, 공용 불투명 정점색·바람·점유 UV·주광 양면 그림자를 사용한다. 식생의 자동 LOD만 끈다.
- [배치 기록](placement_manifest.json): 원본 SHA-256, 실제 지도별 배치·삼각형·파일 크기. 전체 3,212,524바이트, 맵당 12,218~14,730삼각형. 텍스처·광원·스킨·애니메이션 클립을 추가하지 않는다. 원본과 `design/` 파일은 APK에 넣지 않으며 게임 GLB는 공용 PCK로만 배포한다.

설치한 건설칸의 중앙 식생은 본체와 그림자가 함께 숨고, 철거 시 돌아온다. 가장자리 바위·이끼·덩굴은 유지한다. 각 GLB의 전체 맵 배열이 실제 전장과 일치할 때만 연결해 다른 지도의 위치로 장식을 잘못 배치하지 않는다.

Godot 자동 검사에서 새 네 맵의 2메시·LOD·공용 재질·UV2 슬롯과 뿌리 좌표·전 건설칸 점유/철거·맵 재방문·배열 불일치 격리 및 기존 스테이지 1 환경 회귀가 모두 통과했다. Android 실제 확인은 상위 [1장 전장 검증](../README.md)에 기록한다.
