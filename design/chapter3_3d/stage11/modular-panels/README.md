# 타일 추가와 교체형 매립 패널

사용자 결정: 원형 타일과 원 없는 포탑 설치 타일을 섞어서 배치한다. 환기구는 기본 타일에 반복해서 붙이지 않고, 막힌 측면 패널 대신 일부에만 장착한다. 파이프·배기구 환경 소품은 후속 범위다.

- 기존 53개 타일과 경로·건설 위치·공용 전투 계약 보존.
- 건설칸 28개: 원 없는 타일 18개, 원형 타일 10개. 둘 다 같은 건설 동작.
- 타일마다 네 측면 교체 좌석, 막힌 철판 207개 + 환기구 5개. 환기구는 노출된 측면에만 배치하며 가까이 몰리지 않도록 한다.
- 후속 가독성 수정의 현재 환기구는 프레임 전면 Godot Z=.485, 열원 Z=.465: 실제 .020 깊이. [열기 표현 복원](../vent-readability/README.md). 실제 구멍과 안쪽 반환면·격자·열원으로 구현. 타일 상판과 몸체 .50 깊이·색·재질 유지.
- 패널은 타일 원점을 공유하며 +Z/+X/-Z/-X 방향으로 회전한다. Blender 원본 4종/패널 2종은 독립적으로 편집 가능하다.
- Godot은 같은 패널 원본을 두 MultiMesh로 배치한다. 맵 생성 시에만 계산하며 매 프레임 재생성하지 않는다. 전체 프레임 성능 개선을 측정한 작업은 아니다.

[Blender 제작·검증](../../tiles/README.md), [GLB 이관](../../export/README.md), [원 없는 타일 시안](../../environment_concepts/plain-turret-tile-multiview.png).

검증 기록:

- Blender ray 검사에서 네 좌석의 기존 외벽이 실제로 제거됐음을 확인. GLB 6종 재임포트 좌표 오차 0.
- 이 단계의 .092 매립 구조는 높은 게임 시점에서 열원이 가려졌다. 프레임/구멍/후퇴 깊이를 유지하고 열원 하단을 -.398까지 확장해 55도에서 읽히도록 수정했다.
- 실제 렌더러(Metal Forward Mobile)에서 53타일·5격자·두 건설 타일 혼합·212패널·5외곽 환기구·좌표/회전/공용 메시·장 전환 조명 복원 검사 0 failures. MultiMesh getter가 실제 변환을 제공하지 않는 dummy renderer에서는 이 검사를 실행하지 않는다.
- Android에서 원 없는 칸과 원형 칸 각각에 기관총 설치 성공: 170→110→50G, 전투력0→15.9→31.8. 근거 [원 없는 칸 설치](android-plain-installed.png), [두 종류 설치](android-both-installed.png). 이 입력 확인 캡처는 열원 하단 수정 전이며 타일 상판·입력 계약은 최종판과 같다.

이 단계의 Android 실제 전장: [혼합 타일과 매립형 패널](android-stage11-final.png). 막힌 측면이 기본이며 노출된 전면 환기구 두 곳의 후퇴한 주황 슬롯이 작은 크기로 보인다. 후면에 배치된 패널은 고정 시점에서 가려진다. [빈 좌석·막힌 패널·환기구의 실제 GLB 비교](../../export/glb-reimport-panel-depth.png). Android17 arm64 검수 앱에서 production RuneNexusApp/Godot/HUD 실행, 메모리 저장 격리. 기존 본게임 저장 유지.

최종 APK 233238673 bytes, PCK 99796560 bytes. 직전 판 대비 APK 535296 / PCK 535296 bytes. 추가 타일과 패널 메시·atlas 증가이며 arm64 단일 ABI, 원본 GLB/Blender/design 중복 없음, PCK 중복 payload 0. 공개 배포 아님. 상세·입력 해시는 final-inputs.json/apk-audit.json.
