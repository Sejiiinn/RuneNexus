# 기관총 입체 발사 효과

현행 Android 스테이지 1 Godot 발사 표현. 2026-09-11.

Blender 원본은 `production/machinegun-muzzle.blend`의 `MachineGunMuzzle3D` 장면이다. 1타일을 1단위로 사용하며 Blender -Y가 게임 +Z 발사 방향이다. 중심 화염과 비대칭 압력 화염을 편집할 수 있다. `build_source.py`는 Blender MCP에서 실행한 재현용 제작 스크립트다. 기존 수작업 원본에 덮어쓰기 전에 그 원본을 보존해야 한다.

최종 자산은 `assets/images/stage1_3d/effects/machinegun_muzzle.glb`와 `machinegun_muzzle_noise.bin`이다. 잡음장은 x→y→z 순서의 32³ R8 데이터이며 모든 기관총이 공유한다. 2D 프레임·아틀라스는 생성하지 않는다.

`godot/effects/machinegun_muzzle.gd`가 좌우 총구를 교대하며 55ms의 입체 화염, 320ms의 연기, 150ms의 작은 불티를 표시한다. 연기는 16회 체적 적분으로 렌더하고 발사 순간의 위치·방향에서 분리되어 퍼진다. 포탑당 최근 6발의 슬롯과 불티 24개를 재사용한다. 카메라 전환 시에는 멈춘 연기도 새 시점으로 다시 투영한다. 본게임과 검수 앱이 같은 구현을 사용한다.

실제 투사체 이동·충돌·피해·배속은 기존 Flutter 전투를 따른다. 빠른 근접 탄환이 표시 프레임에 잡히기 전에 충돌해도 포구 효과는 발사 순번으로 재생한다. 총구 표현을 위해 충돌 좌표나 탄속을 변경하지 않는다. 이전 `machinegun_visibility/`의 큰 평면 섬광·연기는 과거 ThreeJS 검수 기록이다.

자동 검증은 `godot/verify_machinegun.gd`와 `verify_runtime.gd`에서 수행한다. 기관총 검사는 MultiMesh의 실제 인스턴스를 읽으므로 준비된 `build/godot/project`에서 `--script res://verify_machinegun.gd`로 실행하고 `--headless`를 사용하지 않는다.

2026-09-11 Godot Metal Mobile에서 기관총 동작 검사가 통과했으며 공통 모델·투영·초기화 회귀 검사도 통과했다. 일반 `lib/main.dart` release APK를 Android 17 ARM64 에뮬레이터에서 실행하여 기관총 2기와 대포가 설치된 스테이지 1의 1배속·4배속 사격, 고정·드론 시점 및 전환 중 연기를 확인했다. 실제 화면에서 화염·주변 조명·연기의 크기를 확인했고 실행 로그에 스크립트·셰이더 오류가 없었다. 본게임과 별도 검수 APK 빌드가 통과했다.

- [실제 본게임 영상](runtime/android-main-machinegun-3d.mp4): 1배속 시작, 약 7초에 4배속, 약 9초 드론 전환, 약 14초 다음 웨이브, 약 17초 고정 시점 복귀. [휴대폰용 Drive 영상](https://drive.google.com/file/d/1BQwB2dp50ZtPDHbHk8pojKnJ6l7qUDsU/view).
- [포구 화염 화면](runtime/android-main-machinegun-flash.png): 같은 APK의 첫 검수 녹화에서 추출한 실제 프레임.
- `runtime/video-metadata.json`은 녹화 파일 정보이며 게임 렌더 FPS 측정이 아니다. 모바일 실기기의 지속 성능·발열 검증은 별도다.
