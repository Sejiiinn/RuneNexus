# 빠른 룬 사냥개 — 앞발 추진과 네 발 순차 달리기

현재 결과는 v6다. [짧은 측면·사선 영상](run-preview.mp4)에서 앞발이 앞에서 받아 몸이 발 위를 지난 뒤, 발끝으로 밀고 떨어져 회수되는 동작을 볼 수 있다. [실제 속도 타일 영상](tile-run-preview.mp4)은 1.1375타일/초의 2주기 이동이다.

- [편집 원본](fast-rune-hound-run.blend): `Fast_Hound_Run` 씬, 22본 강체 리그, `Run` 액션.
- [애니메이션 GLB](fast-rune-hound-run.glb): 단일 `Run`, 0~34/60초, 240Hz 베이크. 원래 PBR atlas와 정점별 단일 본 가중치를 유지한다.
- [측면](run-side.mp4), [사선](run-three-quarter.mp4), [타일 검수 원본](fast-rune-hound-tile-review.blend).

원래 102메시·20,214삼각형과 석판·청록 눈/룬·팔레트를 보존했다. 견갑 2본을 추가해 큰 어깨판과 상박을 분리하고, 접지 중 어깨가 앞으로 지나가며 마지막에 발끝을 축으로 뒤꿈치가 들리도록 했다. 흉곽 높이를 조금 회복했으며 몸 전체의 큰 상하 도약은 늘리지 않았다.

착지는 뒤L→뒤R→앞R→앞L, 위상은 0/.12/.45/.59다. 각 발의 접지 비율은 뒤L .25, 뒤R .30, 앞R .34, 앞L .38이며, 좌우의 도달·회수·발끝 굴림도 다르다. 앞R이 먼저 받아 밀어내고 앞L이 이어받는다. 사용자 요청에 따라 앞뒤 발의 일시적 겹침은 허용한다.

[motion-contract.json](motion-contract.json)이 수치 원본이다. 34프레임/60fps(0.566667초), 보폭 0.644583333타일이며 루트는 in-place다. `phase=(실제 누적 이동거리/stride_tiles)%1`, 재생 시각은 `phase*cycle_seconds`다. 정지 시 위상도 멈추고 감속·가속·4배속은 실제 이동거리로 처리한다. Blender는 1~34프레임을 반복하며 35는 접속 키다.

GLB는 정적 원본 폭 1.9156095982를 1로 정규화하고 바닥을 0으로 옮겼다. 표시 배율 .48을 적용하면 정적 폭 .48타일이다. 콘텐츠 속도 54.6과 거리 변환 1/48을 보존했다. 런타임 IK·물리는 필요 없다.

최신 요청에 따라 검증은 앞발 추진과 네 발 순차의 짧은 영상 확인, 단일 액션·시간·본 수의 내보내기 확인으로 제한했다. [내보내기 기록](runtime-export.json), [최종 파일 대응](final-artifacts.json), [독립 검토](independent-review.md)를 참고한다. v5 원본과 영상·검증은 `previous-gallop-v5`에 보존하며 v6의 검증 결과로 재인용하지 않는다.

[build_run.py](build_run.py)/[build_gallop.py](build_gallop.py)는 기존 Blender MCP의 별도 씬에서 제작한다. [export_run.py](export_run.py)는 저장 원본을 별도 Blender에서 열어 내보낸다. [render_gallop_gate.py](render_gallop_gate.py), [타일 렌더](render_v6_tile_pilot.py), [영상 인코딩](encode_previews.py)이 현재 짧은 영상의 제작 경로다. 기존 열린 원본·다른 씬·미저장 작업은 교체하지 않았다. 게임 이식·커밋은 포함하지 않는다.
