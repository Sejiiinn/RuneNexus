# 챕터 3 — 두꺼운 주조 타일과 교체 측면 패널

현재 원본은 [chapter3-thick-tiles.blend](chapter3-thick-tiles.blend), 조립 화면은 [vent-55deg-source.png](modular_revision/vent-55deg-source.png)다. 기존 3종 상판의 승인 색·재질·두께를 보존하고 [링 없는 타일 시안](../environment_concepts/plain-turret-tile-multiview.png)에 맞춰 중앙 링과 그 4개 앵커만 제거한 4번째 상판을 추가했다. 코너 볼트 4개는 모든 타일에 남긴다.

Android 고정 카메라 55도에서 주황 열원이 점으로 줄어들던 결함을 환기 패널의 실제 입체 구조에서 수정했다. [수정 스크립트](modular_revision/restore_visible_vents.py)는 환기 패널만 변경한다. 프레임 전면 -.485, 열원 전면 -.465로 실제 후퇴 깊이를 .020으로 조정했으며, 개구 높이 .200과 폭 .044인 세 열원이 세로 슬롯으로 읽힌다. 이전 .092 깊이를 유지했던 하단 확장 시도는 현재 기준이 아니다. 발광 재질 강도는 변경하지 않았다. [실제 55도 원본 검증](modular_revision/vent-55deg-source.png), [다른 5루트 메시 보존 검사](modular_revision/vent-preservation.json), [수정 직전 원본](modular_revision/before-readable-vents.blend).

모든 타일 측면의 중앙 보강대 사이에 폭 .296 × 높이 .250인 실제 좌석을 만들었다. 일반 몸체는 외벽 -.450에서 안쪽 -.325까지 오목하게 파고, 격자는 내부 공동으로 실제 열린다. `05_Panel_solid`와 `06_Panel_vent`는 타일 원점 기준 독립 편집 가능한 패널이다. 환기 패널은 구멍·프레임·가로/세로 구조와 안쪽 열원을 가진다. 환기 프레임 전면 -.485보다 열원 전면 -.465가 .020 뒤에 있어, 막힌 벽 위 주황 덧칠이 아니다. 기본 타일에서 기존 측면 벤트는 제거했고, 격자 상부 내부 열판은 유지했다.

- [수정 스크립트](modular_panels.py), [수정 전 원본](modular_revision/before-modular-panels.blend)
- [좌석 ray 검증](modular_revision/verify_seats.py), [결과](modular_revision/seat-verification.json): 모든 4면 좌석 깊이·코너4볼트·열원 후퇴 확인
- [GLB 루트·좌표·재질 계약](../export/README.md), [실제 GLB 재임포트 비교](../export/glb-reimport-panel-depth.png)

원본의 `Preview only` 메시들은 패널 조립 렌더 전용이다. exporter는 지정한 6개 루트의 직접 자식 메시만 사용하여 preview를 포함하지 않는다. 단독 패널 원본 메시들은 숨겨져 있으며 편집 시 표시할 수 있다. 독립 background Blender를 사용했고 열려 있던 적 화상 Blender 문서와 편집 상태는 변경하지 않았다.

`reference_revision/`과 `refine_reference.py`는 직전 승인 색·두께의 제작 이력이다. 기존 내장 측면 주황 슬롯은 현재 교체형 패널로 대체되어 현재 요구로 적용하지 않는다. 최종 인게임 검수는 부모 작업에서 진행한다.
