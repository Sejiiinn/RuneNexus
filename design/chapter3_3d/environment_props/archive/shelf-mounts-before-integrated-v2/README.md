# 챕터 3 환경 요소 Blender 시안

2026-09-18. 승인된 [멀티뷰 설계](../environment_concepts/foundry-props-multiview.png)를 바탕으로 제작한 실제 3D 원본. Blender 시안 승인 후 [스테이지 11 외곽 장식](../stage11/environment-props/README.md)으로 이식했다.

- [편집 가능한 소품 원본](foundry-props.blend): `elbow_pipe`, `side_conduit`, `exhaust_vent` 독립 루트 3종.
- [소품 렌더](props-preview.png): 왼쪽부터 엘보 파이프·측면 연결관·짧은 배기구.
- [타일 장착 원본](mounted-scene.blend), [장착 렌더](mounted-hero.png), [약 55도 장착 렌더](mounted-game-angle.png).
- [제작 스크립트](build_props.py), [장착 장면 스크립트](build_presentation.py).

청흑색 철·절제된 청동·국소 주황 열원을 유지했다. 관의 보어와 곡관, 열 배출구와 내부 열원은 실제 메시다. 엘보와 배기구는 외곽 서비스 받침에, 연결관은 타일 측면 고정대에 부착한다. 이동·포탑 설치 상면을 점유하지 않는다. 장착 장면은 기존 타일 원본을 복사해 구성하며 타일 원본과 게임 에셋을 변경하지 않는다.

1타일 폭을 1로 삼았다. 엘보 폭 .40·깊이 .487·높이 .487, 연결관 길이 .866·깊이 .258·높이 .36, 배기구 폭 .426·깊이 .394·높이 .539. 연결관의 후면 부착 평면은 로컬 Y=.135이며 원본 루트의 `mount_back_y`에 기록했다.

검증: [형상 기록](geometry-check.json), [장착 위치·원본 해시 기록](presentation-check.json). Blender 5.2.1 Cycles 실제 렌더를 확인한다. 게임용 GLB의 형상·재질 검사는 [내보내기 기록](export/README.md), 인게임 검수는 위 스테이지 11 기록을 따른다.
