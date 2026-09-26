# 경량 환경 소품 게임 반영 독립 검수

**PASS.** 승인 경량본을 게임 경로에 반영하고 현재 Godot import·런타임 배치에서 동일한 결과를 확인했다. 미해결 결함 없음.

- 게임 `assets/images/stage1_3d/environment/chapter3_props.glb`를 직접 해시 확인했다. 승인 후보와 동일한 SHA-256 `00f95bb711cfd703726bd164a73065df6007c10cac6875042d59bc113a8130bd`, 4,026,984바이트다. [기존 QHD 외형·형상 검수](../review/independent-review.md)는 같은 입력이므로 재사용한다.
- [격리 프로젝트](project-path.json)의 실제 import 입력을 독립 파싱했다. 노드·메시·accessor 정의와 정점/인덱스 바이트가 게임 GLB와 동일하며 외부화된 텍스처도 embedded 원본과 바이트 단위로 일치한다. 런타임 로드 경로는 `res://assets/environment/chapter3_props.glb`이고 엘보 6,816 / 연결관 9,024 / 배기구 6,588삼각형, 각각 1표면이다.
- [최종 검사 로그](stage-props.log)와 [런타임 결과](integration-check.json)를 확인했다. 스테이지 **11~15 모두 0 failures**: 각 5개 배치, 기존 종류·칸·방향·변환 유지, 벽 체결면과 배기구 기단 높이, 플레이 영역 및 환기 패널 침범 없음, 원본 스케일·공유 메시/PBR, 같은 맵 재적용 시 재생성 없음.
- [최종 스테이지 11 실제 화면](stage11-applied-qhd.png)을 직접 확인했다. 엘보 상향 입구·연결관·주황 3슬롯과 벽 연결을 유지한다. 실제 1440×3120 SubViewport, 3D 배율 1, 줌 1, 논리 440×953.333, HUD 전장 영역 (8,110,424,651.333), safe=0, forge 카메라/조명을 사용한 macOS Godot 화면이다.

검사 스크립트의 최초 타입 추론 오류와 스테이지 로드 전 라이브러리 참조 오류는 제작자가 수정했다. 같은 격리 프로젝트의 관련 검사만 다시 실행한 최종 결과가 위의 0 failures이며, 모델 결함은 아니었다.

[QHD 재현기](../review/reproduce.py)와 [형상 검사기](../review/check_glb.py)는 원본을 고정 커밋 `0c63df5fa22c1f5b7bcfd5a3f3f9ec8b448aa047`에서 읽고 SHA `c4eb491ef578b6e91219b75b3a854ad4bb3b4b3e565cd0d866d55a5daacd7952`를 검증한다. 해당 커밋 원본을 독립 추출해 일치 확인했다. 교체 후 현재 경량 게임 파일을 과거 원본으로 오인하지 않는다.

이번 검수는 에셋 적용 범위에 한정했다. 새 APK·실기기 FPS·전체 게임 회귀·커밋은 수행하지 않았다.
