# 챕터 1 일반형 — 3D 시안

2026-09-26 제작. [승인 멀티뷰](../05-chapter1-normal-multiview.png)의 긴 가면 흉판·자주색 핵·짧은 이족·원형 철 관절·양쪽 등판을 입체 기하로 구현했다. 후속 피드백에 따라 석재를 중간 회갈색으로 낮추고 금속 반사와 명도 대비를 줄였다.

- 편집 원본: [chapter1-normal-guardian.blend](chapter1-normal-guardian.blend)
- 실제 렌더: [3/4](preview-three-quarter.png), [정면](preview-front.png), [측면](preview-side.png), [후면](preview-back.png)
- 전체 모델: **18,656 삼각형 / 8,950면 / 9,614 정점**, 스튜디오 제외. 숨은 내부 부품도 포함한 evaluated mesh 집계이며 20,000 미만. 부품별 수치는 [mesh-stats.json](mesh-stats.json).
- Blender 5.2.1 LTS / Cycles 48 samples / AgX / 1000×1100. 모든 뷰는 동일 정투영 축척이며 정·측·후면에서는 바닥을 숨겼다.

3D 시안만 제작했으며 게임에는 적용하지 않았다. 부품별 메시와 Blender 절차 재질을 보존한 정적 원본이며 리그·애니메이션·게임용 재질 베이크는 포함하지 않는다. GLB는 별도 제작하지 않았다.

재생성은 Blender에서 [build_guardian.py](build_guardian.py)를 실행하고 [render_views.py](render_views.py)를 실행한다. 예를 들어 Python 콘솔에서 스크립트 절대 경로를 `p`에 지정한 뒤 `exec(compile(open(p).read(), p, 'exec'), {'__file__': p})`를 호출한다. 제작 스크립트는 `C1_Guardian_Concept` 장면만 갱신하고 `libraries.write`로 해당 장면을 별도 원본에 저장하므로, 기존 열린 프로젝트의 장면·파일은 덮어쓰지 않는다.
