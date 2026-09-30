# 갤럭시 S26 Ultra QHD+ 해상도 비교

1440×3120을 실제 Godot 3D 렌더 타깃으로 사용한 원본/경량 비교다. 기존 440×900 캡처를 확대하지 않았다. [삼성 공식 화면 사양](https://developer.samsung.com/galaxy-emulator-skin/galaxy-s.html)을 기준으로 하며, Android 실기기 캡처는 아니다.

- `original-angled-full.png`, `optimized-angled-full.png`: 고정 카메라 전체 1440×3120.
- `original-drone-full.png`, `optimized-drone-full.png`: 드론 카메라 전체 1440×3120.
- `angled-native-pair-left-original-right-optimized.png`, `drone-native-pair-left-original-right-optimized.png`: 각 전체 이미지의 포탑 영역을 픽셀 변경 없이 추출한 비교. 왼쪽 원본, 오른쪽 경량이다.
- `capture-conditions.json`: 물리·논리 viewport, 내부 3D scale, 카메라, 모델 SHA, 이미지 크기.

앱 `boot.gd`/`app_lifecycle.gd`와 같은 440×760 기준에 `canvas_items`/`expand`를 적용한 논리 영역은 약 440×953.333이다. 안전 여백은 연결 기기가 없어 0으로 가정했다. HUD 전장 계산식에 따른 `(8,110,424,651.333)` 영역과 zoom 1을 현재 `battlefield_camera.gd`에 전달했다. UI는 그리지 않고 동일 전장 투영 영역만 적용했다.

macOS 창 크기의 제약을 피하도록 별도 `SubViewport`에 1440×3120을 지정했다. 3D 해상도 배율은 1.0이며 내부 렌더 크기도 1440×3120이다. 2×MSAA, Mobile/Metal 렌더러, 현재 게임 지형·조명·원본 배율·재질을 사용했다. 물리 화면 비율과 논리 투영 비율이 같으므로 카메라 직교 크기와 오프셋을 그대로 적용한다. 전체 이미지나 크롭에는 리사이즈를 하지 않는다.

모델 두 개의 SHA는 이전 독립 검수와 동일하다. 게임 에셋·코드·모델·이전 캡처를 변경하지 않았으며, APK 빌드나 실기기 성능 측정은 포함하지 않았다.

저장소 루트에서 재현:

```sh
python3 design/sniper_tower_concepts/2026-09-26/production/optimized-game-distance/review/s26-ultra/reproduce.py
```

기존 준비 에셋 `build/godot/project`가 필요하다. 스크립트는 임시 격리 프로젝트에 현행 `godot/` 소스를 복사하고 준비 에셋을 읽어 렌더한 뒤 격리 프로젝트를 제거한다.
