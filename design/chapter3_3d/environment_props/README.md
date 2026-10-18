# 챕터 3 벽 일체형 환경 소품

2026-09-18. 현행 기준은 [승인 멀티뷰 V2](../environment_concepts/integrated-mounts/multiview-v2.png)다. 이전 선반 부착형은 [이전 원본 백업](archive/shelf-mounts-before-integrated-v2/)으로 보존했다.

2026-09-26에는 같은 외형·벽 접합 구조를 유지한 [경량본](optimized-game-distance/README.md)을 제작하고 QHD+ 비교 후 사용자 승인에 따라 게임용 `chapter3_props.glb`에 적용했다. 고해상도 원본은 보존하며 수치·검수·적용 범위는 해당 기록을 따른다.

- [편집 원본](foundry-props.blend): `elbow_pipe`, `side_conduit`, `exhaust_vent` 독립 루트.
- [타일 장착 원본](mounted-scene.blend): 기존 타일을 복사하여 장착. 타일 원본은 변경하지 않았다.
- [대표 통합 렌더](export/integrated-v2-glb-mounted.png): 실제 GLB를 재임포트하여 원본 타일에 장착한 1장. 중간/각도별 렌더는 생성하지 않는다.
- [제작](build_props.py), [장착](build_presentation.py), [내보내기·형상·재질 검증](export/README.md).

엘보는 선반과 바닥받침 없이 벽의 수직 청동 플랜지에서 바깥으로 나와 위로 휘며 열린 입구로 끝난다. 배기구는 타일 바닥 높이 -.50부터 상판 높이 0까지 이어진 두꺼운 돌출 하우징과 높이 +.253의 짧은 굴뚝, 실제 매립된 3개 주황 슬롯을 사용한다. 연결관의 관·청동 플랜지·열창은 유지하고 후면 고정면을 벽에 밀착한다.

모든 루트는 **타일 측벽 상단 기준점**으로 통일했다. Blender Y=0이 벽, -Y가 바깥, Z=0이 상판, Z=-.50이 타일 바닥이다. 세 형상의 최대 Y는 정확히 0이다. Godot 루트는 tilecenter + outward × .45, 높이 0에 놓는다. 별도 높이/깊이 보정은 없다.

배치는 [`chapter_three_props.gd`](../../../godot/environment/chapter_three_props.gd)가 맵 데이터로 정한다. 3-1~3-5는 바깥 외벽의 5개를 유지한다. 2026-10-18부터 타일 채움 비율이 0.56 미만인 3-6~3-10은 같은 5개 위치를 그대로 두고, 노출 벽면 8면당 1개(최대 12개)가 되도록 두 칸 이상 빈 안쪽 공간에 면한 외벽까지 같은 세 소품을 번갈아 추가한다. 추가분은 카메라 쪽 +Z·+X 면을 우선하고 포탈·코어·전송 장치 주변과 환기 패널은 비운다.

[형상 검사](geometry-check.json)는 manifold·루트 identity·중공 ray 검사 PASS를 기록한다. GLB 재임포트의 정점 오차와 AABB 검사는 [export/geometry-check.json](export/geometry-check.json)에 기록한다. 실제 Android 최종 검수는 [스테이지 11 적용 기록](../stage11/integrated-mounts/README.md)을 따른다.
