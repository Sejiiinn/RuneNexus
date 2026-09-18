# 스테이지 11 외곽 환경 소품

승인된 [Blender 소품](../../environment_props/README.md)의 엘보 파이프·측면 연결관·배기구를 실제 전장 외벽에 배치한다. 원본 재질·중공 형태·주황 열원과 받침/고정대를 유지한다.

`godot/environment/chapter_three_props.gd`가 외부와 연결된 빈 영역을 구분하고 실제 소품 AABB로 이동·건설 상면과 다른 소품의 간섭을 검사한다. 기존 매립 환기구 면과 포탈·코어 주변, 내부 좁은 공간은 제외한다. 같은 맵에서는 같은 배치를 유지하며 전투 난수·저장·맵 좌표를 바꾸지 않는다. 각 종류 첫 배치는 고정 카메라 방향의 노출 면을 선택한다.

검수는 이전 `random-vents/`와 같은 Android17 arm64 에뮬레이터·1080×2424·Godot4.7.2·기본 MSAA2x/높음 그림자·기존 RuneNexusApp/HUD 조건에서 진행한다. 별도 `com.example.rune_nexus.godotpreview` 패키지와 `../android_preview.dart`의 메모리 저장 격리를 사용해 일반 설치본의 진행을 보존한다.

재현: `bash design/chapter3_3d/stage11/environment-props/build_preview.sh`. 공개 배포 없음. `apk-before.json`/`apk-after.json`은 직전 로컬 검수 APK와의 비교이며 공개 배포본 대비 수치가 아니다.

실렌더러 검사 PASS: 엘보 2·연결관 2·배기구 1, 총 5개를 안전거리와 외곽 여유에 맞춰 선택했다. 기존 53타일·5격자·5매립 환기구와 두 설치 타일을 보존했다. 동일 맵 재구성, 원본 메시/PBR 공유, 플레이 영역·환기구 회피, 11→1→6→11 전환 검사 0 failures. [검사 로그](../../environment_props/verification/runtime.log).

첫 Android 확인에서 오른쪽 배기구의 열 배출면이 좁게 보였다. 배기구만 (7,5)의 전면(side0)으로 옮겨 실제 주황 세 슬롯이 카메라를 향하게 했다. 나머지 4개 위치와 환기 패널은 유지했다.

최종 Android 확인 PASS: [기본 화면](android-stage11.png), [배기구 부착 칸 포탑 설치](android-built.png), [드론 시점](android-drone.png), [설치 후 고정 시점](android-final-built.png). 배기구의 주황 3슬롯과 관의 입체 외곽, 기존 환기구를 확인했다. 설치 시 금액 170→110·전투력15.9·레벨표시를 확인했다. 최종 빌드4010은 디버그바를 끄고 촬영했다. 드론 시점의 상단 전장은 기존 HUD가 일부 덮으며 카메라/HUD 배치는 수정하지 않았다. 장시간 전투·실기기 성능은 이번 시각 검수 범위에 포함하지 않았다.

최종 arm64 APK 239,658,577 bytes, PCK 106,216,464 bytes. 직전 로컬 APK/PCK 대비 각각 +6,382,576 bytes이며 원본 형상을 보존한 소품 메시·PBR 추가가 원인이다. 편집 원본·GLB 중복 포함 없음, PCK 논리/실제 중복 payload 0 bytes. [패키지 비교](apk-after.json), [팩 감사](apk-audit.json), [입력 해시](asset-inputs.json).
