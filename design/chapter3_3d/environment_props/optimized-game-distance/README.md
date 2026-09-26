# 챕터 3 파이프·배기구 경량 적용

[벽 일체형 V2 원본](../README.md)의 엘보 파이프·측면 연결관·배기구를 대상으로 별도 경량 모델을 제작했다. 벽 부착점과 높이, 열린 관 입구, 배기구의 매립 주황 3슬롯, 금속 재질을 보존한다. 사용자 승인에 따라 게임용 `assets/images/stage1_3d/environment/chapter3_props.glb`에 적용했다. 타일과 게임 배치·수량은 유지하며 고해상도 제작 원본은 보존한다.

| 소품 1개 | 원본 삼각형 | 경량 삼각형 |
| --- | ---: | ---: |
| 엘보 파이프 | 38,176 | 6,816 |
| 측면 연결관 | 37,728 | 9,024 |
| 배기구 | 22,484 | 6,588 |
| 3종 각 1개 합계 | 98,388 | 22,428 |

관 둘레·곡관 분할과 작은 체결부 베벨을 줄이고, 열창·배기구 3슬롯과 열린 관 내부는 보존했다. [편집 원본](foundry-props-optimized.blend), [GLB](chapter3-props-optimized.glb), [감축 기록](optimization-manifest.json), [형상 검사](geometry-check.json), [제작](build_optimized.py)·[내보내기](export_optimized.py)를 제공한다. PBR 베이크는 기존 1024 해상도와 채널 구성을 유지한다.

같은 조건의 비교란 1440×3120 QHD+ 직접 렌더, 3D 해상도 배율 1.0, 정식 앱의 440×760 기준 expand 배율·HUD 전장 영역, 줌 1.0을 뜻한다. 이번에는 소품이 실제 쓰이는 스테이지 11 지형과 챕터 3 고정·드론 카메라·조명을 사용하고, 원본과 경량본의 위치·방향을 동일하게 유지한다. 안전 영역은 0으로 가정하며 Android 실기기 촬영은 아니다.

[고정 시점 비교](review/angled-native-pairs-left-original-right-optimized.png)와 [드론 시점 비교](review/drone-native-pairs-left-original-right-optimized.png)는 위에서부터 엘보·연결관·배기구, 왼쪽 원본 / 오른쪽 경량본이다. 캡처 픽셀을 확대하지 않았다. [경량본 전체 전장](review/optimized-angled-full.png)과 [카메라 조건](review/capture-conditions.json)을 보존한다. 두 시점에서 주요 윤곽·열린 입구·금속 띠·주황 슬롯을 유지하며, 미세 모서리의 반사 차이는 남는다.

게임 적용은 소품 GLB 교체에 한정하며 타일·배치 코드·카메라·조명·전투 계약은 변경하지 않는다. 커밋·배포·실기기 FPS 측정은 수행하지 않았다.

[독립 검수](review/independent-review.md)는 두 시점의 시각 비교, 중공·주황 슬롯·벽 접합, 원본과 동일한 자동 배치를 PASS로 판정했다. 스테이지 11의 실제 5개 배치는 174,292삼각형에서 38,268개로 약 78.04% 줄었다. GLB는 8,091,672바이트에서 4,026,984바이트로 약 50.23% 줄었다.

게임 에셋 교체 후 [적용 검사](integration/README.md)에서 현재 소스와 격리된 실제 import 경로를 사용했다. 스테이지 11~15 각각 소품 5개·38,268삼각형, 기존 위치·방향·벽 접합·플레이 영역·메시 공유를 확인했고 검사 실패는 0건이다. [최종 QHD 화면](integration/stage11-applied-qhd.png)과 [적용 독립 검수](integration/independent-review.md)를 보존한다. 이전 원본 비교는 고정된 git 커밋에서 고해상도 GLB를 임시 추출해 재현하며 현재 게임 파일을 이전 원본으로 간주하지 않는다.
