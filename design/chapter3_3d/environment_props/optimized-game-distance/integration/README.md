# 경량 환경 소품 게임 반영 검사

게임 `assets/images/stage1_3d/environment/chapter3_props.glb`를 승인된 3종 경량 GLB로 교체했다. SHA256은 `00f95bb711cfd703726bd164a73065df6007c10cac6875042d59bc113a8130bd`다. 타일·배치 알고리즘·개수·벽 접합 좌표·VFX·전투 소스는 변경하지 않았다.

현행 소스와 준비 에셋을 임시 격리 프로젝트로 복사하고, 교체된 게임 GLB를 정식 공유 텍스처 처리 후 실제 Godot importer로 다시 읽었다. 외부화 전후 geometry BIN 바이트가 동일함을 확인했다. 기존 `build/godot/project`, 편집기와 사용자 저장에는 쓰지 않았다.

- `stage-props.log`, `integration-check.json`: 스테이지 11~15 각각 5개 자동 배치, 원본과 종류·칸·방향·pose 동일, 벽 접합·기단 높이·플레이 영역 비침범·환기 패널 비가림·메시/재질 공유·동일 맵 재생성 방지 검사 **0 failures**.
- 실제 불러온 메시: 엘보 6,816 / 연결관 9,024 / 배기구 6,588삼각형, 각각 1 surface. 스테이지당 배치 5개의 합은 38,268삼각형이다.
- `stage11-applied-qhd.png`: 교체된 게임 리소스를 현재 장면 경로로 불러온 스테이지 11 대표 화면. 1440×3120 SubViewport, 내부 3D 배율 1.0, zoom 1, 정식 앱 440×760 expand 기준의 논리 viewport·HUD 전장 영역을 적용했다. 안전 여백은 0 가정이다.

Mac Godot 4.7.2 Metal Mobile에서 확인한 화면이며 Android 실기기 캡처는 아니다. 기존 `../review/` QHD 외형 PASS를 재사용했고 새 영상·전체 회귀·APK 빌드는 수행하지 않았다. 커밋·푸시도 이 작업 범위에 포함하지 않는다.

저장소 루트에서 재현:

```sh
python3 design/chapter3_3d/environment_props/optimized-game-distance/integration/reproduce.py
```

기존 `build/godot/project`의 준비 에셋이 필요하다. 검사는 기존 `verify_chapter_three_stage.gd`의 소품 검사만 재사용하고 관련 5개 맵에서 실행한다. 임시 프로젝트 위치는 `project-path.json`에 기록하며 검수 후 제거할 수 있다.

과거 비교 원본은 중복 저장하지 않고 git `0c63df5fa22c1f5b7bcfd5a3f3f9ec8b448aa047:assets/images/stage1_3d/environment/chapter3_props.glb`에서 읽는다. 원본 SHA는 `c4eb491ef578b6e91219b75b3a854ad4bb3b4b3e565cd0d866d55a5daacd7952`이며 불일치 시 재현을 중단한다. `../review/reproduce.py`와 `../review/check_glb.py`도 같은 고정 기준을 사용하며 기존 검수 PNG/JSON은 역사 기록으로 보존한다.
