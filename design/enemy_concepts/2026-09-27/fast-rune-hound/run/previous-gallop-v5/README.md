# 빠른 룬 사냥개 — 개의 갤럽 달리기

2026-09-27. 승인된 [3D 원본](../3d/README.md)의 석판·청록 눈과 룬·재질 및 **102메시·20,214삼각형**을 보존한 애니메이션 시안이다. 기존 트롯은 폐기하고, 뒤에서 밀고 앞으로 뻗은 뒤 앞발로 받아 다시 뒷다리를 배 아래 모으는 개의 갤럽으로 제작했다. 게임 이식은 포함하지 않는다.

- [편집 가능한 Blender 원본](fast-rune-hound-run.blend): `Fast_Hound_Run` 씬, 20본 강체 리그, `Run` 액션. 정면은 −Y, 위쪽은 +Z.
- [근접 반복 영상](run-preview.mp4): 사선·25도 드론 시점. [측면 영상](run-side.mp4)도 제공한다.
- [실제 타일 속도 영상](tile-run-preview.mp4): 1타일 격자에서 1배속으로 이동한다. [검수용 Blender](fast-rune-hound-tile-review.blend)는 이동과 추적 카메라를 포함한다.
- [애니메이션 GLB](fast-rune-hound-run.glb): 원래 구운 PBR atlas와 기하를 유지한다. 1메시·1재질·1스킨·20관절이며, 정점마다 본 하나에 가중치 1을 적용했다. 단일 `Run` 클립을 240Hz로 베이크해 런타임 IK·물리가 필요 없다.

착지는 뒤왼발 → 뒤오른발 → 앞오른발 → 앞왼발 순서의 rotary gallop이다. 각 좌우 발에 시차를 두고, 흉곽·허리·골반이 주기당 한 번 접혔다 펴진다. 뒤발 추진 → 앞뒤로 신장 → 앞발 착지와 체중 통과 → 복부 아래 후지 회수가 이어진다. 머리는 안정시키고 꼬리는 후행한다. 각 석판은 강체로 움직이며 다리 길이나 정점 형상을 늘리지 않는다. 앞다리는 어깨 아래에서 접고 손목을 굽혀 회수한 다음 다시 전방으로 뻗는다.

## 재생·거리 계약

수치 원본은 [motion-contract.json](motion-contract.json)이다. **0.5초/30프레임**, 보폭 **0.56875타일**이다. 콘텐츠 속도 `54.6`에 거리 변환 `1/48`을 적용한 실제 속도 **1.1375타일/초**와 접지 발의 후방 이동을 맞췄다. 뒤발 접지 비율은 27%, 앞발은 26%이며 착지 위상은 0, .08, .43, .51이다. 몸통 상하 이동폭은 제작 단위 .085다.

원본은 in-place이며 루트 본은 고정한다. `phase = (실제 누적 이동거리 / stride_tiles) % 1`로 위상을 구하고, `Run`의 `phase × cycle_seconds`를 샘플링한다. 정지하면 위상도 멈춘다. 감속·가속·4배속은 실제 이동거리에 반영하므로 별도의 재생 속도 배수를 중복 적용하지 않는다. Blender는 1~30프레임을 반복하고 31프레임은 1과 같은 접속 키다. GLB 시간 범위는 **0~0.5초**다.

GLB는 원래 정적 폭 `1.9156095982`를 1로 정규화하고 발바닥을 0에 맞춘다. 런타임 표시 배율 `.48`을 적용하면 정적 폭 .48타일이다. 제작 원본 바닥은 `−.0286999680`이며 검수 바닥과 GLB 오프셋은 같은 좌표를 따른다. 영상은 실제 렌더된 포즈를 8주기, 총 4초 반복한다. 타일 영상 이동거리는 4.55타일이다.

## 검증과 재현

[source-validation.json](source-validation.json)은 루프 접속, 177위상 접지·밀림, 강체 행렬과 루트 고정, 121위상 삼각형 교차 검사를 기록한다. 서로 다른 다리, 발/몸통, 하박/머리를 검사하며 원래 연결된 석판과 관절 코어의 의도된 겹침은 제외한다. 접지 오차 허용값은 .0001제작 단위(약 .0000251타일)다. [runtime-export.json](runtime-export.json)은 기하 매핑·관절·클립·시간 계약을 기록한다.

[엄격 독립 검증](independent-review.md)에서 최종 상태의 결과와 확인 범위를 확인할 수 있다. [시각 gate 사이클](gallop-gate-v5/side-cycle.mp4)은 바닥선이 있는 정확한 측면 시점이다. 해당 폴더의 `front-elbows.json`은 241위상 앞 팔꿈치 높이, `limb-intersections.json`은 121위상 다리 교차 검사를 보관한다. 이전에 거절된 모션은 `previous-gallop`, `previous-grounded-trot`, `previous-running-trot`에 보존했으며 현재 결과의 검증 근거로 사용하지 않는다.

[build_gallop.py](build_gallop.py)는 기존 Blender MCP에서 별도 `Fast_Hound_Run` 씬을 생성한다. [build_run.py](build_run.py)는 같은 제작 스크립트의 진입점이다. 이후 저장 파일을 독립 background Blender에서 열어 [validate_run.py](validate_run.py), [export_run.py](export_run.py), [render_run.py](render_run.py), [render_traversal.py](render_traversal.py)를 실행한다. [encode_previews.py](encode_previews.py)는 실제 렌더 프레임을 MP4로 묶는다. 기존 열린 파일과 다른 씬·미저장 작업은 교체하지 않는다.

Blender 5.2.1 LTS와 EEVEE를 사용했다. 편집 원본은 원래 procedural 석재 재질, GLB는 기존 2048px PBR atlas를 유지한다. Godot·Android 화면 검증은 이번 범위에 포함하지 않는다.
