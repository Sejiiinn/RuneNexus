# 포탑 레벨 위치·동기화 수정 검수

2026-09-13. 포탑은 Godot, 배지는 Flutter가 서로 다른 표시 프레임에서 그려 시점 전환 중 떨어져 보이던 문제를 수정했다. 고정 여백 기준도 실제 받침 하단으로 바꿨다.

## 구현

- 기존 `TurretLevelRenderer.drawBadge`의 Lv.1~10 그림을 [단일 atlas](../../../../assets/images/stage1_3d/ui/turret_levels.png)로 재사용한다. 원본 글자·테두리·날개·별·glow를 별도 도형으로 다시 만들지 않았다. [생성기·글꼴·좌표 계약](../README.md).
- `godot/ui/turret_level_labels.gd`가 CanvasLayer의 정면 Sprite2D를 그린다. 기존 `frame_pre_draw`에서 Tween 이후 카메라를 직접 읽으므로 새 Flutter 투영이 도착할 때까지 기다리지 않는다.
- 회전 머리·포신을 제외한 고정 받침의 메시 경계를 생성 시 한 번 읽고, 화면에 투영한 하단 중앙에 배지를 붙인다. 조준 방향에 흔들리지 않고 실제 카메라 확대를 따른다.
- 기존 포탑 배열의 level 값으로 프레임을 선택한다. 철거·유형 교체·전장 초기화에서 배지를 정리한다. 건설 미리보기에는 확정 포탑 배지를 만들지 않는다.
- `turret_levels` 옵션과 `nativeTurretLevels` 표시 응답을 사용한다. Godot이 기능을 알린 경우에만 Flutter 레벨 중복을 숨긴다. 기존 엔진 응답에는 기본 false를 적용하며, 실패·게임 교체·화면 종료에서 원래 Flutter 표시로 복귀한다. 다른 렌더러·전투 수치·저장은 유지한다.

## 실제 Android

일반 `lib/main.dart` ARM64 release APK **6014**를 Android 17 / Goldfish GFXStream Apple M4 에뮬레이터에 기존 데이터 보존 설치했다. Godot 4.7.2 Mobile/Vulkan, 1080×2424.

- 실제 본게임 [고정](android-fixed.png) / [드론](android-drone.png).
- [시점 전환 영상](android-camera.mp4), [고정→드론 중간](video-check-0.png), [드론→고정 중간](video-check-1.png), [다시 드론으로 이동 중](video-check-2.png). 포탑 3기의 배지가 각 받침 하단을 함께 따라가며 이전 좌표에 남지 않는 것을 직접 확인했다. 영상 1.7·4.0·6.3초를 디코딩해 확인했다. [영상 검사](android-video.log). 화면 녹화의 FPS는 게임 성능 수치가 아니다.
- 레벨 배지 중복·글자 누락·배지 잘림 없음. 다른 Flutter 범위·상태 표시의 갱신 경로는 이번 레벨 수정 범위에 포함하지 않았다.
- 로비에서 이어서 진행 후 시점 전환·복귀. 7/40라운드, HP13/20, 403G·조각16, 기존 기관총2기·대포1기를 보존했다. 새 전투·구매·레벨업 없이 고정 시점·1배속·웨이브 대기로 두었다. 실제 레벨업 입력 대신 아래 공용 장면과 기존 코드 검사를 사용했다.
- [실행 로그](android.log)에 Godot 스크립트·Vulkan 파이프라인 오류 없음. 기존 `xr/shaders/enabled` 경고는 남아 있다. 실기기 성능 측정은 수행하지 않았다.

## 관련 검사

- Flutter analyze 오류·경고 없음. [분석](flutter-analyze.log).
- 기존 본게임 Godot 연동·프레임 직렬화 4개, 기존 포탑 모양·레벨 tier·효과 3개 테스트 통과. native 표시 활성화와 실패 시 복귀도 확인했다. [연동](flutter-bridge-test.log), [기존 배지](flutter-badge-test.log).
- Godot 레벨 검사 실패0: 새 Flutter 프레임 없이 전환 네 구간에서 배지 갱신, 받침 부착, 조준 회전, 확대, Lv.10 변경, 철거, 기능 비활성화, 초기화. [레벨](godot-labels.log).
- 기존 공용 카메라·런타임 검사 실패0. [카메라](godot-camera.log), [런타임](godot-runtime.log).
- 여섯 포탑 종류와 Lv.1/2/4/6/8/10을 같은 GPU 장면에서 확인했다. [고정](desktop-angled.png) / [드론](desktop-drone.png)은 데스크톱 검수 장면이며 실제 Android 본게임과 구분한다.
- 기존 준비 테스트와 `git diff --check` 통과. atlas의 알파 여백·글자와 장식을 직접 확인했다. 테스트 엔진의 Ahem 대체 글꼴이 나타났던 중간 출력은 채택하지 않았으며, 대상 Roboto를 명시해 수정했다.

## 설치 파일·용량

`build/apk-main/rune-nexus-attached-levels-arm64.apk`, versionCode6014. 공개 배포·커밋·푸시는 하지 않았다.

직전6013 **241,990,573 → 242,063,845 bytes**, **+73,272 bytes(+0.0303%)**. Godot PCK는 **62,932,068 → 63,005,340 bytes**이며 새 배지 atlas·표시 코드가 추가됐다. 네이티브 라이브러리 총 크기·Flutter 자산 총 크기는 동일하다. `libapp.so` 해시는 변경되어 Flutter의 중복 숨김 코드도 반영됐다. 공용 PCK와 APK 내 PCK SHA-256이 일치하고 ABI는 arm64-v8a 하나다. atlas는 Godot PCK에만 포함하며 Flutter 중복·design·Blender 원본 포함0. [패키지 검사](apk.json), [빌드](apk-build.log).
