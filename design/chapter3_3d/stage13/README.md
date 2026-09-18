# 스테이지 13 3D 전장

기존 8×8 맵·경로·건설칸·포탈·코어를 보존하고 승인된 챕터3 금속 타일·벽체 연결형 환경 소품을 재사용한다. 타일40·그레이팅3·매립환기구4·소품5. 기존 배치 규칙·GLB·카메라 각도·조명을 유지했다. 비대칭 빈 테두리가 있는 맵에서 전체 격자 중심과 활성 타일 중심의 차이를 보정해 가장자리 잘림을 해결했다. 사용자 팬·줌은 유지한다. 14~15는 기존 2D를 유지한다.

Flutter 관련18개 테스트 및 analyze PASS. Godot11·12·13 및 다른 장 전환 실렌더러 검사0fail, 준비스크립트 테스트PASS. 각 로그 flutter-tests.log, flutter-analyze.log, runtime.log, preparation-test.log 참조.

최종검수는 기존 Android17 arm64 에뮬레이터1080×2424/Godot4.7.2/MSAA2x·높음그림자/공용조명/실제 RuneNexusApp·HUD 조건을 사용한다. 별도 godotpreview 패키지와 메모리 저장, stage13진입을 위한 앞12스테이지해금으로 일반설치본 진행을 보존한다. 메뉴는XML로 이동하고 최종 대표 화면 위주로 확인한다. 원본입력이 같아 Blender렌더는 반복하지 않는다. 공개 배포 없음.

Android 실제 인게임 최종 확인 PASS: `android-stage13.png`. 왼쪽 코어 받침까지 여백 안에 들어오며 원래 경로·두 건설 타일·주황 열원·벽체 연결 소품을 확인했다. 카메라 회귀 검사에서 11~13의 실제 viewport 투영 중심과 팬·줌 보존을 검증했다(`camera-regression.log`, 0 failures).

최종 arm64 APK 239,387,745 bytes, PCK 105,945,632 bytes. 직전 로컬 Stage12 미리보기 대비 각각 +224 bytes. 원본 GLB/Blend 및 design 자료 미포함, PCK 중복 payload 0 bytes. `apk-after.json`, `apk-audit.json` 참조.

실제 Android 포탑 설치 상호작용 PASS: 건설 타일 선택·기관총 설치·170→110G 차감 확인(`build-interaction.log`). 대표 이미지는 설치 전 전체 배치다.
